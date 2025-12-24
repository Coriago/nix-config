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

  flake.nixosModules.heliosdesk = {lib, ...}: {
    # Top level Modules to use
    imports = [
      self.nixosModules.variables
      self.nixosModules.basic
    ];

    # Global Variables
    vars = {
      user.name = "helios";
      stateVersion = "25.05";
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
