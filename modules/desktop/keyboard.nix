{
  inputs,
  self,
  ...
}: {
  # NixOS
  flake.modules.nixos.desktop-extras = {
    config,
    pkgs,
    lib,
    ...
  }: {
    # KeyPeek: live on-screen keyboard overlay for QMK/Vial/ZMK layers
    # https://github.com/srwi/keypeek
    #
    # For Vial keyboards (like this setup), KeyPeek reads the layout directly
    # from the keyboard over the Vial protocol. No keyboard_info.json needed.
    # Just connect the keyboard in KeyPeek and select it from the dropdown.
    #
    # If you ever switch to QMK with a userspace repo, see the KeyPeek README
    # for how to add the srwi/keypeek_layer_notify module.
    #
    environment.systemPackages = with pkgs; [
      vial # GUI for live keyboard configuration
      qmk # QMK CLI (useful for info, udev rules, etc.)
      qmk_hid # Command-line HID tool for QMK devices
      self.packages.${pkgs.stdenv.hostPlatform.system}.keypeek
    ];

    services.udev.packages = [
      pkgs.vial
    ];
    hardware.keyboard.qmk.enable = true;

    # HID device access for Vial/QMK keyboards
    users.users.${config.vars.username}.extraGroups = ["plugdev"];

    # Bluetooth support for ZMK keyboards
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;
  };

  # Home Manager
  flake.modules.homeManager.desktop-extras = {...}: {
    # No home-manager specific keypeek config yet;
    # app stores its settings in ~/.config/keypeek
  };
}
