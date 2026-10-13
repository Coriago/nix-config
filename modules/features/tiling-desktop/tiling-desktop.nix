{config, ...}: let
  local = config;
in {
  flake.modules.nixos = {
    tiling-desktop = {...}: {
      imports = [
        local.flake.modules.nixos.desktop-essentials
        local.flake.modules.nixos.noctalia
        local.flake.modules.nixos.umbriel
        local.flake.modules.nixos.noctalia-greeter
        local.flake.modules.nixos.display-management
        local.flake.modules.nixos.file-manager
        local.flake.modules.nixos.keyring
      ];
    };

    display-management = {
      pkgs,
      hostmeta,
      ...
    }: {
      environment.systemPackages = with pkgs; [
        # wdisplays
        ddcutil
        ddcui
      ];
      hardware.i2c.enable = true;
      users.users.${hostmeta.username}.extraGroups = ["i2c"];
      # Use noctalia display plugin instead of kanshi/wdisplays
      # services.kanshi.enable = true;
    };

    keyring = {pkgs, ...}: {
      # Registers Secret Service and enables login PAM unlock. Greetd inherits
      # the login stack, so Noctalia Greeter needs no separate PAM wiring.
      services.gnome.gnome-keyring.enable = true;
      # Keep the existing OpenSSH agent; enabling keyring otherwise enables GCR.
      services.gnome.gcr-ssh-agent.enable = false;
      environment.systemPackages = [pkgs.seahorse];
    };

    file-manager = {pkgs, ...}: {
      environment.systemPackages = with pkgs; [
        kdePackages.dolphin
        kdePackages.kio-extras
      ];
      services.udisks2.enable = true;
    };
  };
}
