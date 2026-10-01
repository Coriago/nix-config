{
  inputs,
  self,
  ...
}: {
  flake.modules.nixos.pi-agent = {pkgs, ...}: {
    environment.systemPackages = [self.packages.${pkgs.stdenv.hostPlatform.system}.mypi];
  };

  perSystem = {
    pkgs,
    lib,
    system,
    self',
    liveConfig,
    ...
  }: let
    pi = inputs.llm-agents.packages.${system}.pi;
    plugins = pkgs.buildNpmPackage {
      pname = "mypi-plugins";
      version = "1.0.0";
      src = ./plugins;
      npmDepsFetcherVersion = 2;
      npmDepsHash = "sha256-0YdKrZDcVPFfJlARYeI874CpDF6lZT+zuqtWDwe7Oys=";
      # Pi supplies its own SDK to extensions; do not install another copy.
      npmFlags = ["--legacy-peer-deps"];
      npmInstallFlags = ["--ignore-scripts"];
      dontNpmBuild = true;
      installPhase = ''
        runHook preInstall
        mkdir -p "$out/share/pi-plugins"
        cp -r package.json node_modules "$out/share/pi-plugins/"
        runHook postInstall
      '';
    };
    mkBrowserServer = configDir:
      inputs.wrapper-modules.lib.wrapPackage {
        inherit pkgs;
        package = plugins;
        exePath = "share/pi-plugins/node_modules/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js";
        binName = "chrome-devtools-mcp";
        flags = {
          "--executablePath" = lib.getExe pkgs.chromium;
          "--config" = "${configDir}/chrome-devtools.json";
        };
        env.CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS = "1";
        meta.description = "Chrome DevTools MCP with packaged Chromium";
      };
    mkPi = configDir: browserServer:
      inputs.wrapper-modules.lib.wrapPackage {
        inherit pkgs;
        package = pi;
        env.PI_CHROME_DEVTOOLS_MCP = lib.getExe' browserServer "chrome-devtools-mcp";
        suffixVar = [
          {
            name = "cli-tools";
            data = ["PATH" ":" (lib.makeBinPath [pkgs.git pkgs.nodejs pkgs.ripgrep])];
          }
        ];
        runShell = [
          ''
            # Keep subcommands first; only sessions load the bundled extensions.
            case "''${1:-}" in
              install|remove|uninstall|update|list|config|auth|mcp) ;;
              *) set -- --extension ${plugins}/share/pi-plugins \
                   --extension ${configDir}/chrome-devtools.ts "$@" ;;
            esac
          ''
        ];
        meta.description = "Pi with Chrome DevTools MCP, web access, and user questions";
      };
    configDir = liveConfig.link ./config;
    wrapper = mkPi configDir (mkBrowserServer configDir);
    # Nix's build sandbox cannot host Chromium's nested user-namespace sandbox.
    # Only this test variant disables it; the installed browser keeps it enabled.
    testBrowserServer = (mkBrowserServer ./config).wrap {
      appendFlag = ["--chrome-arg=--no-sandbox"];
    };
    testWrapper = mkPi ./config testBrowserServer;
  in {
    packages.mypi = wrapper;
    apps.mypi = {
      type = "app";
      program = lib.getExe self'.packages.mypi;
      meta.description = "Pi coding agent with bundled extensions";
    };
    checks.mypi =
      pkgs.runCommand "mypi-smoke-test" {
        nativeBuildInputs = [pkgs.python3];
      } ''
        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        python ${./check.py} ${lib.getExe testWrapper} ${./check.ts}
        python ${./browser-check.py} ${lib.getExe' testBrowserServer "chrome-devtools-mcp"}
        touch "$out"
      '';
  };
}
