{
  flake.modules.nixos.desktop = {
    config,
    pkgs,
    ...
  }: {
    environment.systemPackages = with pkgs; [
      vial
      qmk
      qmk_hid
    ];
    hardware.keyboard.qmk.enable = true;
    services.udev.packages = [pkgs.vial];
    users.users.${config.hostmeta.username}.extraGroups = ["plugdev"];

  };
}
