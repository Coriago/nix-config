{
  inputs,
  config,
  ...
}: {
  flake.nixosConfigurations.heliosdesk = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      config.flake.nixosModules.heliosdesk # The module defined below
    ];
  };

  flake.nixosModules.heliosdesk = {lib, ...}: {
    # Set Global Variables
    vars = {
      username = "helios";
      stateVersion = "25.05";
      timeZone = "America/New_York";
      locale = "en_US.UTF-8";
    };

    # Import modules for this host
    imports = with config.flake.modules; [
      generic.variables
      nixos.base
    ];

    # Integrated Home Manager
    home-manager.users.helios = {config, ...}: {
      imports = [
        config.flake.modules.homeManager.base
      ];
    };

    # System Config or Overrides
    networking.hostName = "heliosdesk";
    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      grub.enable = lib.mkForce false;
    };
  };
}
