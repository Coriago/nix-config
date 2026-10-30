{inputs, ...}: {
  configurations.nixos.heliosurface = {
    config,
    lib,
    modulesPath,
    ...
  }: {
    imports = [
      inputs.nixos-hardware.nixosModules.microsoft-surface-common
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

    boot.initrd.availableKernelModules = ["xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc"];
    boot.initrd.kernelModules = [];
    boot.kernelModules = ["kvm-intel"];
    boot.extraModulePackages = [];

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    diskLayout.device = "/dev/nvme0n1";
    services.iptsd.enable = true;
  };
}
