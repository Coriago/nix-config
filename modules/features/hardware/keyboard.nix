{
  flake.modules.nixos.keyboard = {
    hostmeta,
    pkgs,
    ...
  }: {
    environment.systemPackages = with pkgs; [
      vial
    ];
    hardware.keyboard.qmk.enable = true;
    services.udev.packages = [pkgs.vial];
    users.users.${hostmeta.username}.extraGroups = ["plugdev"];
  };
}
