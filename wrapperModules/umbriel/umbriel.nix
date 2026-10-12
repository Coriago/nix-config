{locallib, ...}: {
  flake.wrappers.umbriel = {
    config,
    lib,
    pkgs,
    wlib,
    ...
  }: {
    imports = [locallib.sync-snap];
    options = {
      configDir = lib.mkOption {
        type = lib.types.str;
        default = "\${XDG_CONFIG_HOME}/umbriel";
        description = "Writable directory containing config.toml. Supports HOME/XDG placeholders; sync.defaultDir follows this option.";
      };
      settings = lib.mkOption {
        type = (pkgs.formats.toml {}).type;
        default = {};
        description = "Umbriel TOML preferences merged over the saved snapshot and into the writable runtime config.";
      };
    };
    config = {
      package = lib.mkDefault pkgs.umbriel;
      passthru = {
        providedSessions = config.package.providedSessions or [];
        generatedConfig = config.constructFiles.umbrielConfig.outPath;
      };
      constructFiles.umbrielConfig = {
        relPath = "config.toml";
        content = builtins.toJSON config.settings;
        builder = ''${pkgs.remarshal}/bin/json2toml "$1" "$2"'';
      };
      sync.enable = lib.mkDefault true;
      sync.defaultDir = lib.mkDefault config.configDir;
      sync.startupCondition = lib.mkDefault ''
        case "''${1-}" in
          ""|-s|-c) true ;;
          *) false ;;
        esac
      '';
      # Keep subcommands first; validation reads the runtime file without syncing.
      runShell = [
        {
          name = "UMBRIEL_CONFIG";
          after = ["SYNC_SNAP"];
          data = ''
            case "''${1-}" in
              ""|-s|-c) set -- -c ${wlib.escapeShellArgWithEnv config.sync.files.umbrielConfig.path} "$@" ;;
              config)
                if [ "''${2-}" = validate ]; then
                  shift 2
                  set -- config validate -c ${wlib.escapeShellArgWithEnv config.sync.files.umbrielConfig.path} "$@"
                fi
                ;;
            esac
          '';
        }
      ];
      snapshot.files.umbrielConfig = {
        pruneKeyContains = [
          "^(include|environment|drm|output)(\\.|$)"
          "^input\\.device(\\.|$)"
          "(^|\\.)(output|map_to_output)(\\.|$)"
          "(?i)(password|credential|secret|token)"
        ];
        pruneValueContains = ["/nix/store/" "(^|[@[:space:]:])(DP|HDMI-A|HDMI|eDP|DVI-D|DVI-I|VGA|DisplayPort)-[0-9]+"];
        transform = [''walk(if type == "object" then with_entries(select(.value != {})) else . end)''];
      };
    };
  };
}
