{
  inputs,
  config,
  ...
}: let
  hostname = "rpiserver1";
  username = "node";
in {
  # Global Variables module
  ############################
  flake.modules.generic.${hostname} = {
    imports = with config.flake.modules; [generic.variables];
    vars = {
      username = username;
      stateVersion = "25.11";
      email = "gagemiller155@gmail.com";
    };
  };

  # Nixos host configuration
  ###############################
  flake.modules.nixos.${hostname} = {...}: {
    # Import nixos modules for this host
    imports = with config.flake.modules; [
      generic.${hostname}
      nixos.base

      # Drivers
      nixos.rpi5
      nixos.rpi5-disks
    ];

    home-manager.users.${username} = {
      # Import Home Manager modules
      imports = with config.flake.modules; [
        generic.${hostname}
        homeManager.base
      ];
    };

    # Host Overrides
    #----------------------------------#
    networking.hostName = hostname;
  };

  # Final Configuration
  ######################
  flake.nixosConfigurations.${hostname} = inputs.nixos-raspberrypi.lib.nixosSystem {
    specialArgs = inputs;
    modules = [
      config.flake.modules.nixos.${hostname} # The module defined above
    ];
  };

  # Installer SD Card
  flake.nixosConfigurations.rpi5-installer-sd-card = inputs.nixos-raspberrypi.nixosConfigurations.rpi5-installer.extendModules {
    modules = [
      config.flake.modules.generic.rpiserver1
      (nixargs: {
        users.users.nixos.openssh.authorizedKeys.keys = [
          nixargs.config.vars.sshPublicKey
        ];
        users.users.root.openssh.authorizedKeys.keys = [
          nixargs.config.vars.sshPublicKey
        ];
      })
    ];
  };

  # Installer Disko
  # Come back later
  flake.nixosConfigurations.rpi5-installer-disko = inputs.nixos-raspberrypi.lib.nixosSystem {
    specialArgs = inputs;
    modules = [
      config.flake.modules.generic.rpiserver1
      config.flake.modules.nixos.rpi5
      config.flake.modules.nixos.rpi5-disks
      inputs.nixos-images.nixosModules.image-installer
      (nixargs: {
        imports = [
          (nixargs.modulesPath + "/profiles/installation-device.nix")
        ];
        boot.swraid.enable = nixargs.lib.mkForce false;
        disko.devices.disk.primary.device = ""; # For safety, this is left empty
        users.users.nixos.openssh.authorizedKeys.keys = [
          nixargs.config.vars.sshPublicKey
        ];
        users.users.root.openssh.authorizedKeys.keys = [
          nixargs.config.vars.sshPublicKey
        ];
        environment.systemPackages = with nixargs.nixpkgs; [
          raspberrypi-eeprom
        ];
      })
    ];
  };
}
