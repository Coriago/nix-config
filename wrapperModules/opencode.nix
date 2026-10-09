{locallib, ...}: {
  flake.wrappers.opencode = {
    config,
    lib,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.opencode locallib.sync-snap locallib.directory-mappings];

    options.cli-settings = lib.mkOption {
      type = wlib.types.structuredValueWith {typeName = "JSON";};
      default = {};
      example = {
        theme = {
          name = "lucent-orng";
          mode = "system";
        };
      };
      description = ''
        OpenCode v2 CLI preferences, including theme settings. Nonempty settings
        are synced to sync.defaultDir/cli.json and presented at OpenCode's native
        config location. Requires sync.enable for runtime delivery.
      '';
    };

    config = {
      sync.enable = lib.mkDefault true;

      constructFiles.opencodeCliConfig = lib.mkIf (config.cli-settings != {}) {
        relPath = "cli.json";
        content = builtins.toJSON config.cli-settings;
      };
      # OpenCode's native config directory is fixed, including v2's cli.json.
      directoryMappings = lib.mkDefault (lib.optionals (config.sync.defaultDir != "\${XDG_CONFIG_HOME}/opencode") [
        {
          source = config.sync.defaultDir;
          target = "\${XDG_CONFIG_HOME}/opencode";
        }
      ]);

      envDefault = {
        OPENCODE_CONFIG = {
          data = lib.mkForce config.sync.files.opencodeConfig.path;
          esc-fn = wlib.escapeShellArgWithEnv;
        };
        OPENCODE_TUI_CONFIG = {
          data = lib.mkForce config.sync.files.opencodeTuiConfig.path;
          esc-fn = wlib.escapeShellArgWithEnv;
        };
      };
    };
  };
}
