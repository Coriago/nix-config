{
  inputs,
  config,
  ...
}: {
  flake.nixosConfigurations.heliosdesk = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      config.flake.modules.nixos.heliosdesk # The module defined below
    ];
  };

  flake.modules.generic.heliosdesk = {
    imports = with config.flake.modules; [
      generic.variables
    ];

    # Global Variables
    vars = {
      username = "helios";
      stateVersion = "25.05";
      timeZone = "America/New_York";
      locale = "en_US.UTF-8";
      email = "gagemiller155@gmail.com";
    };
  };

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

    # System Config or Overrides
    networking.hostName = "heliosdesk";
    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      grub.enable = lib.mkForce false;
    };
  };
}
