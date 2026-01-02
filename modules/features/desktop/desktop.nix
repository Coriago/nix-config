{
  flake.modules.nixos.desktop = {
    pkgs,
    config,
    ...
  }: {
    # Uses KDE Plasma for Desktop
    services.desktopManager.plasma6.enable = true;
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };

    # Enable x11 for backwards compatibility
    services.xserver = {
      enable = true;
      xkb.layout = config.vars.keyLayout;
      xkb.variant = "";
    };

    # Portal support for sandbox apps
    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
    };
  };
}
