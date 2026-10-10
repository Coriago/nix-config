{
  inputs,
  locallib,
  ...
}: {
  flake.wrappers.pi = {
    config,
    lib,
    pkgs,
    wlib,
    ...
  }: let
    json = wlib.types.structuredValueWith {typeName = "JSON";};
    browserEnabled = config.chromeDevtools.server != null;
    browserServer = inputs.wrapper-modules.lib.wrapPackage {
      inherit pkgs;
      package = config.chromeDevtools.server;
      exePath = "bin/chrome-devtools-mcp";
      binName = "chrome-devtools-mcp";
      flags."--config" = {
        data = config.sync.files.chromeDevtools.path;
        esc-fn = wlib.escapeShellArgWithEnv;
      };
    };
    extensions = config.extensions ++ lib.optional browserEnabled ./chrome-devtools.ts;
  in {
    imports = [locallib.sync-snap];
    options = {
      agentDir = lib.mkOption {
        type = lib.types.str;
        default = "\${HOME}/.pi/agent";
        description = "Writable Pi agent directory. Supports HOME/XDG placeholders; sync.defaultDir follows this option. The wrapper sets PI_CODING_AGENT_DIR to keep discovery and delivery aligned.";
      };
      settings = lib.mkOption {
        type = json;
        default = {};
        description = "Pi settings.json preferences, merged over the saved baseline.";
      };
      keybindings = lib.mkOption {
        type = lib.types.attrsOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
        default = {};
        description = "Pi keybindings.json action bindings; an empty list disables an action.";
      };
      extensions = lib.mkOption {
        type = lib.types.listOf (lib.types.oneOf [lib.types.path lib.types.package lib.types.str]);
        default = [];
        description = "Extension files or package directories passed explicitly to sessions, including with --no-extensions. Package/auth/MCP subcommands retain their native argument order.";
      };
      chromeDevtools = {
        server = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = "Optional packaged chrome-devtools-mcp executable, including its chosen browser. Enables native MCP registration and writable chrome-devtools.json.";
        };
        settings = lib.mkOption {
          type = json;
          default = {};
          description = "Chrome DevTools MCP JSON preferences; server executable and browser selection belong in the supplied package.";
        };
      };
    };
    config = {
      package = lib.mkDefault inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
      sync.enable = lib.mkDefault true;
      sync.defaultDir = lib.mkDefault config.agentDir;
      env.PI_CODING_AGENT_DIR = {
        data = config.agentDir;
        esc-fn = wlib.escapeShellArgWithEnv;
      };
      env.PI_CHROME_DEVTOOLS_MCP = lib.mkIf browserEnabled (lib.getExe' browserServer "chrome-devtools-mcp");
      constructFiles = {
        piSettings = {
          relPath = "settings.json";
          content = builtins.toJSON config.settings;
        };
        piKeybindings = {
          relPath = "keybindings.json";
          content = builtins.toJSON config.keybindings;
        };
        chromeDevtools = lib.mkIf browserEnabled {
          relPath = "chrome-devtools.json";
          content = builtins.toJSON config.chromeDevtools.settings;
        };
      };
      runShell = lib.optional (extensions != []) {
        name = "PI_EXTENSIONS";
        after = ["SYNC_SNAP"];
        data = ''
          case "''${1:-}" in
            install|remove|uninstall|update|list|config|auth|mcp) ;;
            *) set -- ${lib.concatMapStringsSep " " (extension: "--extension " + wlib.escapeShellArgWithEnv "${extension}") extensions} "$@" ;;
          esac
        '';
      };
      snapshot.files = {
        piSettings = {
          pruneKeyContains = [
            "^(lastChangelogVersion|trackingId|deviceId|sessionDir|httpProxy|shellPath|shellCommandPrefix|externalEditor|npmCommand|packages|extensions|skills|prompts|themes)$"
          ];
          pruneValueContains = ["/nix/store/"];
        };
        chromeDevtools = lib.mkIf browserEnabled {
          pruneKeyContains = [
            "^(browserUrl|browser-url|wsEndpoint|ws-endpoint|wsHeaders|ws-headers|userDataDir|user-data-dir|executablePath|executable-path|proxyServer|proxy-server|logFile|log-file|chromeArg|chrome-arg|filesystemRoot|filesystem-root|workspace|experimentalFfmpegPath|experimental-ffmpeg-path|config)$"
          ];
          pruneValueContains = ["/nix/store/"];
        };
      };
    };
  };
}
