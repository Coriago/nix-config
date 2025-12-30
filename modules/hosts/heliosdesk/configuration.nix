{
  inputs,
  self,
  ...
}: {
  flake.nixosConfigurations.heliosdesk = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.heliosdesk # The module defined below
    ];
  };

  flake.homeConfigurations.helios = inputs.home-manager.lib.homeManagerConfiguration {
    modules = [
      self.nixosModules.heliosdesk.home-manager.users.helios
    ];
  };

  flake.nixosModules.heliosdesk = {lib, ...}: {
    # Set Global Variables
    username = "helios";
    stateVersion = "25.05";
    timeZone = "America/New_York";
    locale = "en_US.UTF-8";

    # Import all reusable code here
    imports = [
      # self.modules.generic.variables
      self.modules.nixos.base
      # self.nixosModules.desktop
      # self.nixosModules.gaming
      # self.nixosModules.development
      # self.modules.nixos.audio
      # self.modules.nixos.bluetooth
    ];

    # Integrated Home Manager
    home-manager.users.helios = {...}: {
      imports = [
        self.modules.homeManager.base
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
