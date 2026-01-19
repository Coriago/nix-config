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
      nixos.base-homemanager-rpi

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
    age.rekey.hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOshmG6Skkup8Y2xWNWuZSx5V3YCNla6H78ZX4a2OSjK";
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
}
