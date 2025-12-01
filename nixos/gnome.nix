{
  # services.xserver.displayManager.gdm.enable = true;
  # services.xserver.desktopManager.gnome.enable = true;
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true;
  dconf.settings = {
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/switch-input/"
      ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/switch-input" = {
      name = "Switch monitor input";
      command = "switch-input";
      binding = "<Super><Shift>I";
    };
  };
}
