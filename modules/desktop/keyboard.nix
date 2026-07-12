{
  inputs,
  self,
  ...
}: {
  # NixOS
  flake.modules.nixos.desktop-extras = {
    config,
    pkgs,
    ...
  }: {
    # KeyPeek: live on-screen keyboard overlay for QMK/Vial/ZMK layers
    environment.systemPackages = with self.packages.${pkgs.stdenv.hostPlatform.system}; [
      keypeek
    ];

    # HID device access for QMK/Vial keyboards
    users.users.${config.vars.username}.extraGroups = ["plugdev"];
  };

  # Home Manager
  flake.modules.homeManager.desktop-extras = {...}: {
    # No home-manager specific keypeek config yet;
    # app stores its settings in ~/.config/keypeek
  };
}
