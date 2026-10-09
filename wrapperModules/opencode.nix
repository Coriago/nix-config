{SyncSnapWrapperModule, ...}: {
  flake.wrappers.opencode = {
    config,
    lib,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.opencode SyncSnapWrapperModule];

    sync.enable = lib.mkDefault true;

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
}
