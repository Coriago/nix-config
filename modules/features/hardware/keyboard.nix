{
  flake.modules.nixos.keyboard = {
    hostmeta,
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
    users.users.${hostmeta.username}.extraGroups = ["plugdev"];

  };
}
