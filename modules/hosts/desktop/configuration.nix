{
  inputs,
  config,
  ...
}: let
  hostname = "heliosdesk";
  username = "helios";
in {
  # Global Variables module
  ############################
  flake.modules.generic.${hostname} = {
    imports = with config.flake.modules; [generic.variables];
    vars = {
      username = username;
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
  flake.modules.nixos.${hostname} = {
    pkgs,
    lib,
    ...
  }: {
    # Import nixos modules for this host
    imports = with config.flake.modules; [
      generic.${hostname}
      nixos.base
      nixos.base-homemanager
      nixos.desktop
      nixos.gaming
      nixos.development

      # Drivers
      nixos.bluetooth
      nixos.gpu
      nixos.boot
      nixos.audio
      nixos.monitor
      nixos.openrgb
    ];

    home-manager.users.${username} = {
      # Import Home Manager modules
      imports = with config.flake.modules; [
        generic.${hostname}
        homeManager.base
        homeManager.development
        homeManager.desktop
      ];
    };

    # Host Overrides
    #----------------------------------#
    networking.hostName = hostname;
    age.rekey.hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAz7gDRD7wKds16rl9PPW0HKY3C3CWJbELtUfkXNIwAu root@heliosdesk";
    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      grub.enable = lib.mkForce false;
    };

    # Disable integrated AMD iGPU
    boot.blacklistedKernelModules = ["amdgpu"];
    boot.kernelParams = ["module_blacklist=amdgpu"];

    # Allow cross platform building
    boot.binfmt.emulatedSystems = ["aarch64-linux"];

    # TEMPORARY REMOVE
    networking.firewall.allowedTCPPorts = [3000 8000];
    networking.firewall.allowedUDPPorts = [3000 8000];

    environment.systemPackages = [pkgs.qemu pkgs.disko];
  };

  # Final Configuration
  ######################
  flake.nixosConfigurations.${hostname} = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      config.flake.modules.nixos.${hostname} # The module defined above
    ];
  };
}
