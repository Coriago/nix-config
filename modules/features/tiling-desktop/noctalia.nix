{config, ...}: let
  local = config;
in {
  flake.wrappers.mynoctalia = {
    config,
    lib,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.noctalia-shell];

    options.settingsFile = lib.mkOption {
      type = lib.types.str;
      default = "/home/helios/.config/nix-config/modules/features/tiling-desktop/noctalia-settings.json";
      description = "Settings file read and written by Noctalia, including GUI edits.";
    };

    # A direct checkout path permits atomic saves; a store file/symlink does not.
    # Leave settings unset so the wrapper does not generate a read-only JSON file.
    config.env.NOCTALIA_SETTINGS_FILE = config.settingsFile;
  };

  flake.modules.nixos.noctalia = {config, ...}: {
    imports = [local.flake.wrappers.mynoctalia.install];

    wrappers.mynoctalia = {
      enable = true;
      settingsFile =
        if config.liveConfig.enable
        then "${config.liveConfig.root}/modules/features/tiling-desktop/noctalia-settings.json"
        else toString ./noctalia-settings.json;
    };
  };
}
