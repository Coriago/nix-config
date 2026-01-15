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
    modules = [
      config.flake.modules.nixos.${hostname} # The module defined above
    ];
  };
}
