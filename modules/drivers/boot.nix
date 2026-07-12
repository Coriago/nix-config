# Common bootloader configuration
{inputs, ...}: {
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
      systemd-boot.configurationLimit = 10;
    };

    # Use latest kernel
    # boot.kernelPackages = pkgs.linuxPackages_latest;
    boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;

    nix.settings.substituters = ["https://cache.xinux.uz"];
    nix.settings.trusted-public-keys = ["cache.xinux.uz:BXCrtqejFjWzWEB9YuGB7X2MV4ttBur1N8BkwQRdH+0="];
    nixpkgs.overlays = [inputs.nix-cachyos-kernel.overlays.default];
  };
}
