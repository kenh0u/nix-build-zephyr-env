{
  description = "A pure and hermetic Zephyr development environment using OCI containers and Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-build-oci-env.url = "github:kenh0u/nix-build-oci-env";
  };

  outputs = { self, nixpkgs, nix-build-oci-env }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    buildOCIEnv = nix-build-oci-env.lib.${system}.buildOCIEnv;
    buildZephyrEnv = import ./default.nix { inherit pkgs buildOCIEnv; };
  in {
    lib.${system} = {
      inherit buildZephyrEnv;
    };
  };
}
