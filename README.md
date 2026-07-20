# nix-build-zephyr-env

A reproducible Nix build environment for **vanilla Zephyr RTOS** (upstream `zephyrproject-rtos/zephyr`).

Unlike [nix-build-ncs-env](https://github.com/kenh0u/nix-build-ncs-env) (which wraps the Nordic nRF Connect SDK) this flake targets the unmodified Zephyr tree, so it is not limited to any particular vendor or architecture — ESP32, nRF, STM32, RISC-V, native_posix, etc. are all supported as long as the matching Zephyr SDK toolchain is present in the OCI image.

## Features
- **Deterministic Zephyr Source**: Automates `west init` and `west update` into a fixed-output derivation (FOD) so that exactly the same source tree (pinned by tag, branch, or commit SHA) is produced on every build.
- **Git Metadata Patching**: Strips `.git` directories and rewrites CMake scripts that unconditionally depend on `.git/index`, preventing CMake from failing inside the read-only Nix store.
- **Daemonless OCI**: Relies on [nix-build-oci-env](https://github.com/kenh0u/nix-build-oci-env) to provide the official `zephyrprojectrtos/zephyr-build` Docker image via `bubblewrap` — no Docker daemon, no `root`.
- **Transparent `west` Wrapper**: Injects a `west` wrapper that activates the in-container Python venv (`/opt/python/venv`), locates the Zephyr SDK under `/opt/toolchains/zephyr-sdk-*`, and routes every `west` subcommand seamlessly into the toolchain container. `west build`, `west flash`, and `west debug` behave exactly as on a procedural install, communicating with programmers via the bound host `/dev`.

## Usage

This module exports a `lib.buildZephyrEnv` function.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-build-zephyr-env.url = "github:kenh0u/nix-build-zephyr-env";
  };

  outputs = { self, nixpkgs, nix-build-zephyr-env }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    devShells.${system}.default = nix-build-zephyr-env.lib.buildZephyrEnv {
      inherit pkgs;
    } {
      # Tag, branch, or commit SHA accepted by `west init --mr`
      zephyrVersion = "v4.4.1";
      # Fixed-output hash of the zephyr-source derivation.
      # Start with lib.fakeSha256 and let `nix develop` print the real value.
      zephyrHash = "sha256-AJaf5zod5jhc5p/lkwnjOR2gY2jLfyyDNnwE+6qqLKI=";
      # Optional: west blobs to fetch (e.g. [ "hal_espressif" ] for ESP Wi-Fi/BLE blobs)
      zephyrBlobs = [];

      toolchainImageName = "zephyrprojectrtos/zephyr-build";
      toolchainDigest = "sha256:da6f5f57573309d759282edd2b3e530767eb8bc6c1760563a7ef301a0182ac6e";
      toolchainSha256 = "sha256-40FsAZHI6WKJMBBOQB6CFQtLv8qATQuaLgoBr+RZ85g=";
    };
  };
}
```

Run `nix develop` in your application repository and use `west build` as normal. All tooling executes transparently inside the FHS environment.
