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
    # Import all reusable code here
    imports = [
      self.nixosModules.variables
      self.nixosModules.basic
      self.nixosModules.desktop
      self.nixosModules.gaming
      self.nixosModules.development
      self.nixosModules.audio
      self.nixosModules.bluetooth
    ];

    # Set Global Variables for this Host
    vars = {
      user.name = "helios";
      stateVersion = "25.05";
      timeZone = "America/New_York";
      locale = "en_US.UTF-8";
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
