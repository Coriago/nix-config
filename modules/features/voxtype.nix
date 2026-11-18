{
  flake.modules.nixos.voxtype = {hostmeta, pkgs, ...}: {
    # evdev hotkeys read keyboard devices; dotool fallback writes through uinput.
    hardware.uinput.enable = true;
    users.users.${hostmeta.username}.extraGroups = ["input" "uinput"];

    home-manager.users.${hostmeta.username}.services.voxtype = {
      enable = true;
      package = pkgs.voxtype.override {vulkanSupport = true;};
      loadModels = ["base.en"];
      settings = {
        state_file = "auto";
        hotkey = {
          enabled = true;
          key = "SCROLLLOCK";
          mode = "toggle";
        };
        whisper = {
          backend = "local";
          model = "base.en";
          language = "en";
          streaming = true;
        };
        streaming.interval_secs = 0.3;
        output = {
          mode = "type";
          auto_submit = false;
        };
      };
    };
  };
}
