{
  delib,
  modulesPath,
  lib,
  config,
  ...
}:
delib.host {
  name = "desktop";

  system = "x86_64-linux";

  # useHomeManagerModule = false;
  home.home.stateVersion = "25.05";

  # If you're not using NixOS, you can remove this entire block.
  nixos = {
    system.stateVersion = "25.05";

    # nixos-generate-config --show-hardware-config
    # other generated code here...
    imports = [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

    boot.initrd.availableKernelModules = ["nvme" "ahci" "xhci_pci" "thunderbolt" "usbhid" "usb_storage" "sd_mod" "sr_mod"];
    boot.initrd.kernelModules = [];
    boot.kernelModules = ["kvm-amd"];
    boot.extraModulePackages = [];

    fileSystems."/" = {
      device = "/dev/disk/by-uuid/824be5dc-102e-40ea-a117-ff230ffd2611";
      fsType = "ext4";
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-uuid/3B1A-809A";
      fsType = "vfat";
      options = ["fmask=0077" "dmask=0077"];
    };

    swapDevices = [];

    # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
    # (the default) this is the recommended approach. When using systemd-networkd it's
    # still possible to use this option, but it's recommended to use it in conjunction
    # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
    networking.useDHCP = lib.mkDefault true;
    # networking.interfaces.enp8s0.useDHCP = lib.mkDefault true;
    # networking.interfaces.wlp9s0.useDHCP = lib.mkDefault true;

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
}
