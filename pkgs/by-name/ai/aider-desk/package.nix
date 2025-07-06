{
  lib,
  fetchFromGitHub,
  buildNpmPackage,
  nodejs,
  pkgs,
}:

with pkgs;
buildNpmPackage rec {
  pname = "aider-desk";
  version = "0.20.0";

  src = fetchFromGitHub {
    owner = "hotovo";
    repo = "aider-desk";
    rev = "v${version}";
    hash = "sha256-KimMIWG/U9Pc1tV9/WBwA453o29vjTh9pYlIZRcjuIo=";
  };

  npmDepsHash = "sha256-i0DqDeybyvQ7UF6G7Pb32O08hXmddWtExtWXN3txIkU=";

  nativeBuildInputs = [
    nodejs
    electron
    (pkgs.callPackage ../../da/dart-sass/package.nix { })
  ];

  npmFlags = [ "--ignore-scripts" ];

  preBuild = ''
    runHook preConfigure
    # The build process expects a sass binary at a specific path.
    # We remove the vendored directory and create a symlink pointing
    # to the pure dart-sass package from Nix instead.
    rm -rf node_modules/sass-embedded-linux-x64
    mkdir -p node_modules/sass-embedded-linux-x64/dart-sass
    ln -s ${
      pkgs.callPackage ../../da/dart-sass/package.nix { }
    }/bin/sass node_modules/sass-embedded-linux-x64/dart-sass/sass
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR
    npm run build
    runHook postBuild
  '';

  # 🔹 FINAL installPhase 🔹
  # Corrected to copy from the `out` directory created by the build.
  installPhase = ''
        runHook preInstall
        mkdir -p $out/lib/aider-desk

        # Copy the contents of the `out` directory created by electron-vite
        cp -r out/* $out/lib/aider-desk/

        # Copy node_modules for runtime dependencies
        cp -r node_modules $out/lib/aider-desk/

        # Copy static assets if they exist
        if [ -d main/src/renderer ]; then
          mkdir -p $out/lib/aider-desk/main/src
          cp -r main/src/renderer $out/lib/aider-desk/main/src/
        fi

        # Copy uv binary if it exists
        if [ -f resources/linux/uv ]; then
          mkdir -p $out/lib/aider-desk/resources/linux
          cp resources/linux/uv $out/lib/aider-desk/resources/linux/
        fi

        # Create the wrapper script
        mkdir -p $out/bin
        cat > $out/bin/aider-desk <<EOF
    #!/bin/sh
    exec ${electron}/bin/electron $out/lib/aider-desk/main/index.js "$@"
    EOF
        chmod +x $out/bin/aider-desk
        runHook postInstall
  '';

  makeCacheWritable = true;

  meta = {
    description = "Aider Desk: Desktop app for Aider, the AI pair programmer";
    longDescription = ''
      Aider Desk is a desktop application for the Aider AI pair programming tool.
      See https://github.com/hotovo/aider-desk for more information.
    '';
    homepage = "https://github.com/hotovo/aider-desk";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "aider-desk";
  };
}
