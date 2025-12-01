{
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
