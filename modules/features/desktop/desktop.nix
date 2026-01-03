{
  # NixOS
  flake.modules.nixos.desktop = {
    pkgs,
    config,
    ...
  }: {
    # Uses KDE Plasma for Desktop
    services.xserver.enable = true;
    services.desktopManager.plasma6.enable = true;
    services.displayManager.sddm.enable = true;
    services.displayManager.sddm.wayland.enable = true;

    # Enable x11 for backwards compatibility
    services.xserver = {
      xkb.layout = config.vars.keyLayout;
      xkb.variant = "";
    };
  };
}
