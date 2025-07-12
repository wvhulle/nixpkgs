{
  lib,
  fetchFromGitHub,
  buildNpmPackage,
  buildFHSEnv,
  nodejs,
  pkgs,
}:

let
  unwrapped =
    with pkgs;
    buildNpmPackage rec {
      pname = "aider-desk-unwrapped";
      version = "0.20.0";

      src = fetchFromGitHub {
        owner = "hotovo";
        repo = "aider-desk";
        rev = "v${version}";
        hash = "sha256-KimMIWG/U9Pc1tV9/WBwA453o29vjTh9pYlIZRcjuIo=";
      };

      dependencies = with pkgs; [
        uv
      ];

      npmDepsHash = "sha256-i0DqDeybyvQ7UF6G7Pb32O08hXmddWtExtWXN3txIkU=";

      nativeBuildInputs = [
        nodejs
        electron
        (pkgs.callPackage ../../da/dart-sass/package.nix { })
        pkgs.python3
        pkgs.pkg-config
        pkgs.sqlite
        pkgs.nodePackages.node-gyp
        pkgs.nodePackages.node-pre-gyp
        pkgs.stdenv.cc
      ];

      buildInputs = [
        pkgs.sqlite
      ];

      npmFlags = [ "--ignore-scripts" ];
      
      # Override npmConfigHook to handle better-sqlite3 specially
      preConfigure = ''
        # Prepare for building native modules
        export npm_config_build_from_source=true
        export npm_config_nodedir=${pkgs.nodejs}/include/node
      '';

      postPatch = ''
        # Allow overriding resources directory via environment variable
        substituteInPlace src/main/constants.ts \
          --replace "process.resourcesPath" "process.resourcesPath)" \
          --replace "is.dev ? path.join(__dirname, '..', '..', 'resources') : process.resourcesPath)" \
                    "process.env.AIDER_DESK_RESOURCES_DIR || (is.dev ? path.join(__dirname, '..', '..', 'resources') : process.resourcesPath)"
      '';

      preBuild = ''
        runHook preConfigure
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
        
        # Rebuild better-sqlite3 for Electron
        echo "Rebuilding better-sqlite3 for Electron..."
        export npm_config_runtime=electron
        export npm_config_target=35.6.0
        export npm_config_disturl=https://electronjs.org/headers
        export npm_config_cache=$TMPDIR/.npm
        export npm_config_build_from_source=true
        
        cd node_modules/better-sqlite3
        ${pkgs.nodePackages.node-gyp}/bin/node-gyp rebuild \
          --runtime=electron \
          --target=35.6.0 \
          --dist-url=https://electronjs.org/headers \
          --module_name=better_sqlite3 \
          --module_path=build/Release
        cd ../..
        
        runHook postBuild
      '';

      installPhase = ''
                runHook preInstall
                mkdir -p $out/lib/aider-desk

                # Copy the contents of the `out` directory created by electron-vite
                cp -r out/* $out/lib/aider-desk/

                # Copy node_modules for runtime dependencies
                cp -r node_modules $out/lib/aider-desk/

                # Copy resources directory including connector
                cp -r resources $out/lib/aider-desk/

                # Create the expected directory structure for renderer files
                mkdir -p $out/lib/aider-desk/main/src/renderer
                ln -s ../../../renderer/progress.html $out/lib/aider-desk/main/src/renderer/progress.html

                # Add uv as runtime dependency in the expected location
                mkdir -p $out/lib/resources/linux
                ln -s ${pkgs.uv}/bin/uv $out/lib/resources/linux/uv
                
                # Create symlink for connector to be found in the expected location
                ln -s ../aider-desk/resources/connector $out/lib/resources/connector

                # Create a minimal electron module stub
                rm -rf $out/lib/aider-desk/node_modules/electron
                rm -f $out/lib/aider-desk/node_modules/.bin/electron
                mkdir -p $out/lib/aider-desk/node_modules/electron
                
                # Create a stub that provides the minimal API needed by the app
                cat > $out/lib/aider-desk/node_modules/electron/index.js <<'EOF'
        // Minimal electron module stub for aider-desk
        // This provides just enough API to let the app start

        const noop = () => {};
        const noopWithReturn = (val) => () => val;

        module.exports = {
          app: {
            isPackaged: false,
            getPath: () => process.env.HOME || '.',
            getName: () => 'aider-desk',
            getVersion: () => '0.20.0',
            quit: noop,
            on: noop,
            whenReady: () => Promise.resolve(),
            setPath: noop,
            requestSingleInstanceLock: () => true,
            disableHardwareAcceleration: noop,
            commandLine: {
              appendSwitch: noop
            }
          },
          BrowserWindow: class BrowserWindow {
            constructor() {
              this.webContents = {
                on: noop,
                send: noop,
                openDevTools: noop
              };
            }
            loadFile() { return Promise.resolve(); }
            loadURL() { return Promise.resolve(); }
            on() {}
            show() {}
            hide() {}
            close() {}
            isDestroyed() { return false; }
            setMenu() {}
          },
          ipcMain: {
            on: noop,
            handle: noop,
            removeHandler: noop
          },
          dialog: {
            showOpenDialog: () => Promise.resolve({ canceled: true, filePaths: [] }),
            showSaveDialog: () => Promise.resolve({ canceled: true, filePath: undefined }),
            showMessageBox: () => Promise.resolve({ response: 0 })
          },
          shell: {
            openExternal: () => Promise.resolve()
          },
          Menu: {
            buildFromTemplate: () => ({}),
            setApplicationMenu: noop
          },
          nativeTheme: {
            themeSource: 'system',
            on: noop
          },
          protocol: {
            registerFileProtocol: noop
          },
          session: {
            defaultSession: {
              clearCache: () => Promise.resolve()
            }
          }
        };
        EOF
                
                cat > $out/lib/aider-desk/node_modules/electron/package.json <<'EOF'
        {
          "name": "electron",
          "main": "index.js"
        }
        EOF


                # Create the wrapper script
                mkdir -p $out/bin
                cat > $out/bin/aider-desk <<EOF
            #!/bin/sh
            exec ${electron}/bin/electron $out/lib/aider-desk/main/index.js "$@"
            EOF
                chmod +x $out/bin/aider-desk
                
                # Verify better-sqlite3 module was built
                if [ -f $out/lib/aider-desk/node_modules/better-sqlite3/build/Release/better_sqlite3.node ]; then
                  echo "better-sqlite3 module found at expected location"
                  ls -la $out/lib/aider-desk/node_modules/better-sqlite3/build/Release/
                else
                  echo "Warning: better-sqlite3 module not found at expected location"
                fi
                
                runHook postInstall
      '';

      makeCacheWritable = true;

      meta = {
        description = "Aider Desk: Desktop app for Aider, the AI pair programmer (unwrapped)";
        homepage = "https://github.com/hotovo/aider-desk";
        license = lib.licenses.mit;
      };
    };
in
buildFHSEnv {
  pname = "aider-desk";
  version = unwrapped.version;

  runScript = "${pkgs.writeScript "aider-desk-run" ''
    #!/bin/bash
    # Setup writable resources directory
    RESOURCES_DIR="${unwrapped}/lib/aider-desk/resources"
    ADDITIONAL_RESOURCES_DIR="${unwrapped}/lib/resources"
    WRITABLE_RESOURCES="$HOME/.local/share/aider-desk/resources"

    # Copy resources if not present or if source is newer
    if [ ! -d "$WRITABLE_RESOURCES" ] || [ "$RESOURCES_DIR/connector/connector.py" -nt "$WRITABLE_RESOURCES/connector/connector.py" ]; then
      mkdir -p "$WRITABLE_RESOURCES"
      cp -r "$RESOURCES_DIR"/* "$WRITABLE_RESOURCES/"
      # Also copy the additional resources (uv, etc.)
      if [ -d "$ADDITIONAL_RESOURCES_DIR" ]; then
        cp -r "$ADDITIONAL_RESOURCES_DIR"/* "$WRITABLE_RESOURCES/"
      fi
      # Fix UV executable - replace symlink with actual executable
      if [ -L "$WRITABLE_RESOURCES/linux/uv" ]; then
        rm "$WRITABLE_RESOURCES/linux/uv"
        cp "${pkgs.uv}/bin/uv" "$WRITABLE_RESOURCES/linux/uv"
      fi
      chmod -R u+w "$WRITABLE_RESOURCES"
    fi

    # Export the environment variable for the patched application
    export AIDER_DESK_RESOURCES_DIR="$WRITABLE_RESOURCES"

    # Clean up any read-only files in the electron config directory that might cause issues
    ELECTRON_CONFIG_DIR="$HOME/.config/Electron-dev"
    if [ -d "$ELECTRON_CONFIG_DIR/aider-connector" ]; then
      find "$ELECTRON_CONFIG_DIR/aider-connector" -type f -exec chmod u+w {} \; 2>/dev/null || true
    fi

    # Verify better-sqlite3 module exists
    BETTER_SQLITE3_NODE="${unwrapped}/lib/aider-desk/node_modules/better-sqlite3/build/Release/better_sqlite3.node"
    if [ ! -f "$BETTER_SQLITE3_NODE" ]; then
      echo "ERROR: better-sqlite3 native module not found at $BETTER_SQLITE3_NODE"
      echo "The application may not function properly."
    fi

    # Run electron with the application
    cd ${unwrapped}/lib/aider-desk
    exec ${pkgs.electron}/bin/electron main/index.js "$@"
  ''}";

  targetPkgs =
    pkgs: with pkgs; [
      # Basic system libraries for dynamic linking
      glibc

      # Wayland and X11 libraries for Electron (supports both)
      wayland
      libxkbcommon
      xorg.libX11
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXrandr
      xorg.libxcb

      # Audio
      alsa-lib

      # GTK and graphics
      gtk3
      cairo
      pango
      gdk-pixbuf
      atk

      # Other Electron dependencies
      libdrm
      libnotify
      nspr
      nss
      cups
      dbus
      expat
      fontconfig
      glib

      # For uv and Python environments
      zlib
      libffi
      openssl
      ncurses
      readline
      sqlite
      tk
      libgcc.lib

      # Standard build tools that might be needed
      gcc
      binutils
      
      # SQLite for better-sqlite3
      sqlite
      
      # Node.js and npm for runtime rebuilding if needed
      nodejs
      python3
    ];

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    mkdir -p $out/share/icons

    # Copy any desktop files or icons from the unwrapped package if they exist
    if [ -d "${unwrapped}/share/applications" ]; then
      cp -r ${unwrapped}/share/applications/* $out/share/applications/
    fi
    if [ -d "${unwrapped}/share/icons" ]; then
      cp -r ${unwrapped}/share/icons/* $out/share/icons/
    fi
  '';

  meta = {
    description = "Aider Desk: Desktop app for Aider, the AI pair programmer";
    longDescription = ''
      Aider Desk is a desktop application for the Aider AI pair programming tool.
      This version is wrapped in an FHS environment to support dynamic Python environments.
      See https://github.com/hotovo/aider-desk for more information.
    '';
    homepage = "https://github.com/hotovo/aider-desk";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "aider-desk";
    platforms = pkgs.electron.meta.platforms;
  };
}
