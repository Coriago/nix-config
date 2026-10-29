{locallib, ...}: {
  flake.wrappers.lazygit = {
    config,
    lib,
    pkgs,
    wlib,
    ...
  }: {
    imports = [locallib.sync-snap];

    options = {
      settings = lib.mkOption {
        type = (pkgs.formats.yaml {}).type;
        default = {};
        description = "LazyGit configuration written to config.yml.";
      };
      configDir = lib.mkOption {
        type = lib.types.str;
        default = "\${XDG_CONFIG_HOME}/lazygit";
        description = "Writable LazyGit configuration and state directory.";
      };
    };

    config = {
      package = lib.mkDefault pkgs.lazygit;
      runtimePkgs = [pkgs.git];
      constructFiles.lazygitConfig = {
        relPath = "config.yml";
        content = builtins.readFile ((pkgs.formats.yaml {}).generate "lazygit-config.yml" config.settings);
      };
      sync.enable = lib.mkDefault true;
      # Snacks captures stderr with stdout when discovering the config directory.
      sync.startupCondition = ''
        case "''${1-}" in
          -cd|--print-config-dir) false ;;
          *) true ;;
        esac
      '';
      sync.defaultDir = lib.mkDefault config.configDir;
      # LazyGit migrates configs as YAML; sync-snap only merges JSON/TOML.
      # Replace on input changes, preserving runtime edits between rebuilds.
      sync.files.lazygitConfig = {
        format = "raw";
        policy = lib.mkDefault "replace";
      };
      envDefault = {
        CONFIG_DIR = {
          data = config.configDir;
          esc-fn = wlib.escapeShellArgWithEnv;
        };
        LG_CONFIG_FILE = {
          data =
            if config.sync.enable
            then config.sync.files.lazygitConfig.path
            else config.constructFiles.lazygitConfig.path;
          esc-fn = wlib.escapeShellArgWithEnv;
        };
      };
    };
  };
}
