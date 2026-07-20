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
    
    nativeBuildInputs = [ pkgs.git (pkgs.python3.withPackages (ps: [ ps.west ps.requests ps.jsonschema ])) pkgs.cacert pkgs.wget ];
    
    phases = [ "buildPhase" ];
    buildPhase = ''
      export HOME=$TMPDIR
      mkdir -p $out
      cd $out
      # west init --mr does not accept a raw commit SHA (it passes it to
      # `git clone --branch`, which only understands refs), so clone the
      # manifest repository ourselves and pin it to the exact revision
      # (tag, branch, or 40-char SHA) before handing it to west.
      git init zephyr
      cd zephyr
      git remote add origin https://github.com/zephyrproject-rtos/zephyr
      git fetch --depth 1 origin ${zephyrVersion}
      git checkout FETCH_HEAD
      cd ..
      west init -l zephyr
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
          export PATH=/opt/python/venv/bin:$PATH
          export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
          export ZEPHYR_SDK_INSTALL_DIR=$(ls -d /opt/toolchains/zephyr-sdk-* 2>/dev/null | head -n1)
          exec west "$@"
        ' _ "$@"
      else
        exec ${(pkgs.python3.withPackages (ps: [ ps.west ps.requests ps.jsonschema ]))}/bin/west "$@"
      fi
    '')
  ];

  ZEPHYR_BASE = "${zephyrSource}/zephyr";
  ZEPHYR_TOOLCHAIN_VARIANT = "zephyr";
}
