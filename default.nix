{ pkgs, buildOCIEnv }:
{ zephyrVersion, zephyrHash, zephyrBlobs ? [], toolchainImageName, toolchainDigest, toolchainSha256 }:

let
  ociEnv = buildOCIEnv {
    imageName = toolchainImageName;
    imageDigest = toolchainDigest;
    sha256 = toolchainSha256;
  };

  # Fixed-Output Derivation for Zephyr source
  zephyrSource = pkgs.stdenv.mkDerivation {
    name = "zephyr-source-${zephyrVersion}";
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = zephyrHash;
    
    nativeBuildInputs = [ pkgs.git pkgs.python3Packages.west pkgs.cacert pkgs.wget pkgs.python3 ];
    
    phases = [ "buildPhase" ];
    buildPhase = ''
      export HOME=$TMPDIR
      mkdir -p $out
      cd $out
      west init -m https://github.com/zephyrproject-rtos/zephyr --mr ${zephyrVersion}
      west update
      
      # Fetch requested blobs
      for blob in ${pkgs.lib.escapeShellArgs zephyrBlobs}; do
        west blobs fetch "$blob"
      done

      west config zephyr.base zephyr
      find . -name ".git" -type d -exec rm -rf {} + || true
      find . -type f -name "*.cmake" -exec sed -i -e 's/''${ABSOLUTE_GIT_DIR}\/index//g' -e 's/''${ABSOLUTE_GIT_DIR}//g' -e 's/''${ZEPHYR_BASE}\/.git//g' {} + || true
    '';
  };

in
pkgs.mkShell {
  nativeBuildInputs = [
    ociEnv
    (pkgs.writeShellScriptBin "west" ''
      if [ -z "$IN_OCI_SHELL" ]; then
        exec oci-shell /bin/sh -c '
          exec west "$@"
        ' _ "$@"
      else
        exec ${pkgs.python3Packages.west}/bin/west "$@"
      fi
    '')
  ];
  
  ZEPHYR_BASE = "${zephyrSource}/zephyr";
  # The Docker image zephyrprojectrtos/zephyr-build has SDK in /opt/toolchains/zephyr-sdk-*
  ZEPHYR_TOOLCHAIN_VARIANT = "zephyr";
}
