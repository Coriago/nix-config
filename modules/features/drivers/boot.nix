# Common bootloader configuration
{
  flake.modules.nixos.boot = {
    lib,
    pkgs,
    ...
  }: {
    boot.loader = {
      systemd-boot.enable = true;
      systemd-boot.consoleMode = "auto";
      efi.canTouchEfiVariables = true;
      grub.enable = lib.mkForce false;
    };

    # Use latest kernel
    boot.kernelPackages = pkgs.linuxPackages_latest;
  };
}
