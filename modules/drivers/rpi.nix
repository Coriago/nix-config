# Raspberry Pi 5 hardware configuration
{inputs, ...}: {
  flake.modules.nixos.rpi5 = {
    config,
    pkgs,
    ...
  }: {
    imports = with inputs.nixos-raspberrypi.nixosModules; [
      raspberry-pi-5.base
      raspberry-pi-5.page-size-16k
      raspberry-pi-5.display-vc4
    ];

    environment.systemPackages = with pkgs; [
      raspberrypi-eeprom
    ];

    hardware.raspberry-pi.config.all = {
      options = {
        enable_uart = {
          enable = true;
          value = true;
        };
      };
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

    boot.loader.raspberry-pi.bootloader = "kernel";
    boot.kernelParams = [
      # Needed for k3s
      "cgroup_enable=cpuset"
      "cgroup_memory=1"
      "cgroup_enable=memory"
      # Fixes for nvme drive ssd
      "nvme_core.default_ps_max_latency_us=0"
      "pcie_aspm=off"
      "pcie_port_pm=off"
    ];

    system.nixos.tags = [
      "raspberry-pi-${config.boot.loader.raspberry-pi.variant}"
      config.boot.loader.raspberry-pi.bootloader
      config.boot.kernelPackages.kernel.version
    ];

    # Disable power management to prevent issues
    powerManagement.enable = false;

    # Networking for headless
    networking.useNetworkd = true;
    # mDNS
    networking.firewall.allowedUDPPorts = [5353];
    systemd.network.networks = {
      "99-ethernet-default-dhcp".networkConfig.MulticastDNS = "yes";
      "99-wireless-client-dhcp".networkConfig.MulticastDNS = "yes";
    };
    # Remove wait online
    systemd.services.NetworkManager-wait-online.enable = false;
    systemd.network.wait-online.enable = false;
    # Prevent total shutdown to prevent outages
    systemd.services = {
      systemd-networkd.stopIfChanged = false;
      # Services that are only restarted might be not able to resolve when resolved is stopped before
      systemd-resolved.stopIfChanged = false;
    };
    networking.wireless.enable = false;
    networking.wireless.iwd = {
      enable = true;
      settings = {
        Network = {
          EnableIPv6 = true;
          RoutePriorityOffset = 300;
        };
        Settings.AutoConnect = true;
      };
    };
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
      disk.primary = {
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
