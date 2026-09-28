{
  flake.modules.nixos.boot = {lib, ...}: {
    boot.loader = {
      systemd-boot.enable = true;
      systemd-boot.consoleMode = "auto";
      efi.canTouchEfiVariables = true;
      grub.enable = lib.mkForce false;
      systemd-boot.configurationLimit = 10;
    };
  };
}
