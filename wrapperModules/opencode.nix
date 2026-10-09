{
  config,
  lib,
  wlib,
  ...
}: {
  imports = [wlib.wrapperModules.opencode wlib.modules.sync-snap];

  sync.enable = lib.mkDefault true;

  envDefault = {
    XDG_CONFIG_HOME = {
      data = "\${HOME}/.config";
      esc-fn = wlib.escapeShellArgWithEnv;
      before = ["OPENCODE_CONFIG" "OPENCODE_TUI_CONFIG"];
    };
    OPENCODE_CONFIG = {
      data = lib.mkForce config.sync.files.opencodeConfig.path;
      esc-fn = wlib.escapeShellArgWithEnv;
    };
    OPENCODE_TUI_CONFIG = {
      data = lib.mkForce config.sync.files.opencodeTuiConfig.path;
      esc-fn = wlib.escapeShellArgWithEnv;
    };
  };
}
