# Raspberry Pi 5 hardware configuration
{inputs, ...}: {
  flake.modules.nixos.rpi5 = {config, ...}: {
    imports = with inputs.nixos-raspberrypi.nixosModules; [
      raspberry-pi-5.base
      raspberry-pi-5.page-size-16k
      raspberry-pi-5.display-vc4
    ];

    hardware.raspberry-pi.config.all = {
      base-dt-params = {
        # Enables PCIe for SSD
        pciex1 = {
          enable = true;
          value = "on";
        };
        pciex1_gen = {
          enable = true;
          value = "3";
        };
      };
    };

    system.nixos.tags = [
      "raspberry-pi-${config.boot.loader.raspberryPi.variant}"
      config.boot.loader.raspberryPi.bootloader
      config.boot.kernelPackages.kernel.version
    ];
  };

  flake.modules.nixos.rpi5-disks = {...}: {
    imports = [
      inputs.disko.nixosModules.disko
    ];

    services.udev.extraRules = ''
      # Ignore partitions with "Required Partition" GPT partition attribute
      # On our RPis this is firmware (/boot/firmware) partition
      ENV{ID_PART_ENTRY_SCHEME}=="gpt", \
        ENV{ID_PART_ENTRY_FLAGS}=="0x1", \
        ENV{UDISKS_IGNORE}="1"
    '';

    disko.devices = {
      disk.nvme0 = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            # REQUIRED PARTITIONS FOR RPI
            FIRMWARE = {
              label = "FIRMWARE";
              priority = 1;
              type = "0700"; # Microsoft basic data
              attributes = [0]; # Required Partition
              size = "1024M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot/firmware";
                mountOptions = [
                  "noatime"
                  "noauto"
                  "x-systemd.automount"
                  "x-systemd.idle-timeout=1min"
                ];
              };
            };

            ESP = {
              label = "ESP";
              type = "EF00"; # EFI System Partition
              attributes = [2]; # Legacy BIOS Bootable, for U-Boot to find extlinux config
              size = "1024M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "noatime"
                  "noauto"
                  "x-systemd.automount"
                  "x-systemd.idle-timeout=1min"
                  "umask=0077"
                ];
              };
            };

            # Customizable partitions
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
