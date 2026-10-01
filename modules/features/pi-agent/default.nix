{
  config,
  inputs,
  ...
}: let
  local = config;
  mkPlugins = pkgs:
    pkgs.buildNpmPackage {
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
  mkBrowserServer = {
    configDir,
    lib,
    pkgs,
    plugins,
  }:
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
in {
  flake.wrappers.mypi = {
    config,
    lib,
    pkgs,
    wlib,
    ...
  }: let
    system = pkgs.stdenv.hostPlatform.system;
    plugins = mkPlugins pkgs;
  in {
    imports = [wlib.modules.default];

    options = {
      configDir = lib.mkOption {
        type = lib.types.oneOf [lib.types.path lib.types.package lib.types.str];
        default = ./config;
        description = "Pi extension and Chrome DevTools MCP config directory.";
      };
      browserServer = lib.mkOption {
        type = lib.types.package;
        default = mkBrowserServer {
          inherit lib pkgs plugins;
          inherit (config) configDir;
        };
        description = "Wrapped Chrome DevTools MCP server used by Pi.";
      };
    };

    config = {
      package = inputs.llm-agents.packages.${system}.pi;
      env.PI_CHROME_DEVTOOLS_MCP = lib.getExe' config.browserServer "chrome-devtools-mcp";
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
                 --extension ${config.configDir}/chrome-devtools.ts "$@" ;;
          esac
        ''
      ];
      meta.description = "Pi with Chrome DevTools MCP, web access, and user questions";
    };
  };

  flake.modules.nixos.pi-agent = {
    config,
    lib,
    liveConfig,
    pkgs,
    ...
  }: {
    imports = [local.flake.wrappers.mypi.install];

    wrappers.mypi = {pkgs, ...}: {
      enable = true;
      configDir = lib.mkIf config.liveConfig.enable (lib.mkForce (liveConfig.link ./config));
    };
  };

  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: let
    plugins = mkPlugins pkgs;
    # Nix's build sandbox cannot host Chromium's nested user-namespace sandbox.
    # Only this test variant disables it; the installed browser keeps it enabled.
    testBrowserServer =
      (mkBrowserServer {
        inherit lib pkgs plugins;
        configDir = ./config;
      }).wrap {
        appendFlag = ["--chrome-arg=--no-sandbox"];
      };
    testWrapper = local.flake.wrappers.mypi.wrap {
      inherit pkgs;
      configDir = ./config;
      browserServer = testBrowserServer;
    };
  in {
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
