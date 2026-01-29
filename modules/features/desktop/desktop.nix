# Linux Desktop Environment
# Other possible desktop environments: Gnome, KDE Plasma, Hyperland, Niri, etc.
{inputs, ...}: {
  # NixOS
  flake.modules.nixos.desktop = {config, ...}: {
    # Uses KDE Plasma for Desktop
    services.xserver.enable = true;
    services.desktopManager.plasma6.enable = true;
    services.displayManager.sddm.enable = true;
    services.displayManager.sddm.wayland.enable = true;
    home-manager.sharedModules = [inputs.plasma-manager.homeModules.plasma-manager];

    # Enable x11
    services.xserver = {
      xkb.layout = config.vars.keyLayout;
      xkb.variant = "";
    };
  };
}
