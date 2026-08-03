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
    # IMPORTANT: KeyPeek requires a firmware module on ALL supported keyboards
    # (QMK, Vial, ZMK). The module broadcasts live layer-change events over
    # HID/serial so the overlay stays in sync with your active layers.
    #
    # Without the srwi/keypeek_layer_notify module compiled into your firmware,
    # KeyPeek will detect the keyboard and show the static layout, but it will
    # NOT update when you switch layers or press keys.
    #
    # -- Firmware Setup (required for Vial too) --
    # 1. In your qmk_firmware or Vial fork, add the module repo:
    #    mkdir -p modules
    #    git submodule add https://github.com/srwi/qmk-modules.git modules/srwi
    #    git submodule update --init --recursive
    # 2. In your keymap folder, add `srwi/keypeek_layer_notify` to keymap.json:
    #    { "modules": ["srwi/keypeek_layer_notify"] }
    # 3. Enable RAW HID in rules.mk:
    #    RAW_ENABLE = yes
    # 4. Build and flash:
    #    qmk compile -kb <your_keyboard> -km <your_keymap>
    # 5. (QMK only) Export layout info:
    #    qmk info -kb <your_keyboard> -m -f json > keyboard_info.json
    #
    environment.systemPackages = with pkgs; [
      vial # GUI for live keyboard configuration
      qmk # QMK CLI (useful for info, udev rules, etc.)
      qmk_hid # Command-line HID tool for QMK devices
      # self.packages.${pkgs.stdenv.hostPlatform.system}.keypeek
      # self.packages.${pkgs.stdenv.hostPlatform.system}.build-corne-firmware
    ];

    services.udev.packages = [
      pkgs.vial
    ];
    hardware.keyboard.qmk.enable = true;

    # HID device access for Vial/QMK keyboards
    users.users.${config.vars.username}.extraGroups = ["plugdev"];
  };

  # Home Manager
  flake.modules.homeManager.desktop-extras = {...}: {
    # No home-manager specific keypeek config yet;
    # app stores its settings in ~/.config/keypeek
  };
}
