{
  flake.modules.nixos.desktop = {pkgs, ...}: {
    services.desktopManager.plasma6.enable = true;
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };

    services.xserver = {
      enable = true;
      xkb.layout = "us";
      xkb.variant = "";
    };

    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      config = {
        common.default = ["gtk"];
      };

      extraPortals = [pkgs.xdg-desktop-portal-gtk];
    };
  };
}
