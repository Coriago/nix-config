# Linux Desktop Environment
# Other possible desktop environments: Gnome, KDE Plasma, Hyperland, Niri, etc.
{inputs, ...}: {
  # NixOS
  flake.modules.nixos.desktop = {
    config,
    pkgs,
    ...
  }: {
    # Uses KDE Plasma for Desktop
    services.xserver.enable = true;
    services.desktopManager.plasma6.enable = true;
    services.displayManager.sddm.enable = true;
    services.displayManager.sddm.wayland.enable = true;
    home-manager.sharedModules = [inputs.plasma-manager.homeModules.plasma-manager];

    environment.sessionVariables = {
      # Set default Qt platform to Wayland with XCB fallback
      QT_QPA_PLATFORM = "wayland;xcb";
    };

    # Enable x11
    services.xserver = {
      xkb.layout = config.vars.keyLayout;
      xkb.variant = "";
    };

    # AppImage Support
    programs.fuse.enable = true;
    programs.appimage = {
      enable = true;
      binfmt = true;
    };
    programs.nix-ld.libraries = with pkgs; [
      zstd
    ];
  };
}
