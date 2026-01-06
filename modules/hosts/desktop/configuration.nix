{
  inputs,
  config,
  ...
}: {
  # Global Variables module
  ############################
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
      theme = "equilibrium-dark";
      wallpaper = "https://getwallpapers.com/wallpaper/full/2/e/a/524916.jpg";
      wallpaperHash = "sha256-YqFWMRjdM8dGbSJQomvoNtwmq2ppfwq6r0UYYpx6sVA=";
      monitors = {
        "left" = {
          serial = "1APR9UA001811";
        };
        "center" = {
          serial = "2OMR6UA000303";
        };
        "right" = {
          serial = "1APR9UA001815";
        };
      };
    };
  };

  # Nixos host configuration
  ###############################
  flake.modules.nixos.heliosdesk = {lib, ...}: {
    # Import nixos modules for this host
    imports = with config.flake.modules; [
      generic.heliosdesk
      nixos.base
      nixos.desktop
      nixos.gaming

      # Drivers
      nixos.bluetooth
      nixos.gpu
      nixos.boot
      nixos.audio
      nixos.monitor
    ];

    home-manager.users.helios = {
      # Import Home Manager modules
      imports = with config.flake.modules; [
        generic.heliosdesk
        homeManager.base
        homeManager.development
        homeManager.desktop
      ];
    };

    # Host Overrides
    #----------------------------------#
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
  ######################
  flake.nixosConfigurations.heliosdesk = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      config.flake.modules.nixos.heliosdesk # The module defined above
    ];
  };
}
