
{ inputs, ... }:
{
  flake.modules.nixos.diskLayout =
    { config, lib, ... }:
    {
      imports = [ inputs.disko.nixosModules.disko ];

      options.diskLayout.device = lib.mkOption {
        type = lib.types.str;
        example = "/dev/disk/by-id/nvme-example";
        description = "Whole disk selected during onboarding.";
      };

      config.disko.devices.disk.main = {
        type = "disk";
        device = config.diskLayout.device;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

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
}
