{
  inputs,
  config,
  ...
}: {
  # Global Variables module
  # reusable for different configurations
  flake.modules.generic.heliosdesk = {
    imports = with config.flake.modules; [
      generic.variables
    ];

    vars = {
      username = "helios";
      stateVersion = "25.11";
      timeZone = "America/New_York";
      locale = "en_US.UTF-8";
      email = "gagemiller155@gmail.com";
      monitors = {
        "left" = {
          width = 2560;
          height = 1440;
          refreshRate = 144;
          x = 0;
          y = 0;
          serial = "1APR9UA001811";
        };
        "center" = {
          primary = true;
          width = 2560;
          height = 1440;
          refreshRate = 144;
          x = 2560;
          y = 0;
          serial = "2OMR6UA000303";
        };
        "right" = {
          width = 5120;
          height = 1440;
          refreshRate = 165;
          x = 0;
          y = 0;
          serial = "1APR9UA001815";
        };
        "tv" = {
          width = 1920;
          height = 1080;
          refreshRate = 60;
          replicaOf = "center";
        };
      };
    };
  };

  # Nixos host configuration
  flake.modules.nixos.heliosdesk = {lib, ...}: {
    imports = with config.flake.modules; [
      # Import nixos modules for this host
      generic.heliosdesk
      nixos.base
      nixos.desktop
      nixos.gaming
      nixos.bluetooth
      nixos.gpu
      nixos.boot
      nixos.audio
    ];

    home-manager.users.helios = {
      imports = with config.flake.modules; [
        # Import Home Manager modules
        generic.heliosdesk
        homeManager.base
        homeManager.development
        homeManager.desktop
      ];
    };

    # Host Overrides
    ############################
    networking.hostName = "heliosdesk";
    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      grub.enable = lib.mkForce false;
    };
    # Disable integrated AMD iGPU
    boot.blacklistedKernelModules = ["amdgpu"];
    boot.kernelParams = ["module_blacklist=amdgpu"];
  };

  # Final Configuration
  flake.nixosConfigurations.heliosdesk = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      config.flake.modules.nixos.heliosdesk # The module defined below
    ];
  };
}
