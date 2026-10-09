# Registration and optional host integration only; personal settings are in config/.
{config, ...}: let
  local = config;
in {
  flake.modules.nixos.brave = {
    config,
    liveConfig,
    ...
  }: {
    imports = [local.flake.wrappers.mybrave.install];
    wrappers.mybrave = {
      configDir = liveConfig.link ./config/recommended;
      syncSnap.snapshotFile = "${config.liveConfig.root}/modules/features/brave/config/snapshot.json";
    };
    home-manager.users.${config.hostmeta.username}.programs.brave = {
      enable = true;
      package = config.wrappers.mybrave.wrapper;
    };
  };
  perSystem = {self', ...}: {
    apps.mybrave-sync = {
      type = "app";
      program = "${self'.packages.mybrave}/bin/brave-sync";
    };
    apps.mybrave-snapshot = {
      type = "app";
      program = "${self'.packages.mybrave}/bin/brave-snapshot";
    };
  };
}
