{locallib, ...}: {
  flake.wrappers.noctalia = {
    config,
    lib,
    pkgs,
    wlib,
    ...
  }: let
    toml = pkgs.formats.toml {};
    baseline = {
      content = builtins.toJSON config.settings;
      builder = ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
    };
  in {
    # The upstream noctalia-shell adapter targets v4 JSON, not v5 TOML.
    imports = [locallib.sync-snap];
    options = {
      configHome = lib.mkOption {
        type = lib.types.str;
        default = "\${XDG_CONFIG_HOME}";
        description = "Noctalia config home root (the application appends /noctalia). Supports HOME/XDG placeholders; sync.defaultDir follows this option.";
      };
      stateHome = lib.mkOption {
        type = lib.types.str;
        default = "\${XDG_STATE_HOME}";
        description = "Noctalia state home root (the application appends /noctalia). GUI overrides live here in settings.toml, separately from private state.toml.";
      };
      settings = lib.mkOption {
        type = toml.type;
        default = {};
        description = "One baseline for config.toml (replace) and settings.toml (merge). Explicit settings override the saved snapshot. Settings-only runtime keys survive sync.";
      };
    };
    config = {
      package = lib.mkDefault pkgs.noctalia;
      sync.enable = lib.mkDefault true;
      sync.defaultDir = lib.mkDefault config.configHome;
      # Inspection and IPC must not reset live GUI changes.
      sync.startupCondition = lib.mkDefault ''
        case "''${1-}" in
          ""|-d|--daemon) true ;;
          *) false ;;
        esac
      '';
      envDefault.XDG_STATE_HOME = {
        data = "\${HOME}/.local/state";
        esc-fn = wlib.escapeShellArgWithEnv;
        before = ["NOCTALIA_STATE_HOME"];
      };
      env = {
        NOCTALIA_CONFIG_HOME = {
          data = config.configHome;
          esc-fn = wlib.escapeShellArgWithEnv;
        };
        NOCTALIA_STATE_HOME = {
          data = config.stateHome;
          esc-fn = wlib.escapeShellArgWithEnv;
        };
      };
      constructFiles = {
        noctaliaConfig = baseline // {relPath = "noctalia/config.toml";};
        noctaliaSettings = baseline // {relPath = "noctalia/settings.toml";};
      };
      sync.files = {
        noctaliaConfig.policy = lib.mkDefault "replace";
        noctaliaSettings = {
          destinationDir = lib.mkDefault config.stateHome;
          # Import exactly the same master snapshot and declared config as config.toml.
          sources = config.sync.files.noctaliaConfig.sources;
          policy = lib.mkDefault "merge";
        };
      };
      snapshot.files = {
        noctaliaSettings.enable = false;
        noctaliaConfig = {
          sources = [
            config.sync.files.noctaliaConfig.path
            {
              path = config.sync.files.noctaliaSettings.path;
              optional = true;
            }
          ];
          # Prune the merged result, including unsafe values from either layer.
          pruneKeyContains = [
            "^(config_version|desktop_widgets|lockscreen_widgets|hooks|include|storage)(\\.|$)"
            "^calendar\\.accounts(\\.|$)"
            "^accessibility\\.ui_scale$"
            "^wallpaper\\.last(\\.|$)"
            "(^|\\.)(monitor|monitors|output|outputs|screen|screens|connector|connectors|monitor_overrides|screen_overrides|device|devices|device_id|device_name|backlight|latitude|longitude|city|country|address)(\\.|$)"
            "(?i)(password|credential|secret|token)"
            "(?i)(path|paths|directory|directories|file|files|folder|folders)$"
          ];
          pruneValueContains = [
            "/nix/store/"
            "(^|[@[:space:]])(DP|HDMI-A|HDMI|eDP|DVI-D|DVI-I|VGA|DisplayPort)-[0-9]+"
            "(^|[[:space:]\"'])(/|~/|\\$[A-Za-z_{]|\\.\\.?/)"
            "file://"
          ];
          transform = [''walk(if type == "object" then with_entries(select(.value != {})) else . end)''];
        };
      };
    };
  };
}
