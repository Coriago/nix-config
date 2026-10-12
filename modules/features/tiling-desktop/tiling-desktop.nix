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
      ];
    };

    display-management = {
      pkgs,
      config,
      ...
    }: {
      environment.systemPackages = with pkgs; [
        wdisplays
        ddcutil
        ddcui
      ];
      hardware.i2c.enable = true;
      users.users.${config.hostmeta.username}.extraGroups = ["i2c"];
      services.kanshi.enable = true;
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
