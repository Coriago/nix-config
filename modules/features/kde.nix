{config, ...}: let
  local = config;
in {
  flake.modules.nixos.kde = {...}: {
    imports = [local.flake.modules.nixos.desktop-services];

    services = {
      desktopManager.plasma6.enable = true;
      displayManager.plasma-login-manager.enable = true;
      xserver.enable = true;
    };
  };
}
