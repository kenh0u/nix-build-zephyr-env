{
  description = "A pure and hermetic Zephyr development environment using OCI containers and Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-build-oci-env.url = "github:kenh0u/nix-build-oci-env";
  };

  outputs = { self, nixpkgs, nix-build-oci-env }: {
    lib = {
      buildZephyrEnv = { pkgs }: import ./default.nix {
        inherit pkgs;
        buildOCIEnv = nix-build-oci-env.lib.buildOCIEnv { inherit pkgs; };
      };
    };
  };
}
