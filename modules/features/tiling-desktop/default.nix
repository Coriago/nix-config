{config, ...}: let
  local = config;
in {
  flake.modules.nixos.tiling-desktop = {pkgs, ...}: {
    imports = [
      local.flake.modules.nixos.noctalia
      local.flake.modules.nixos.umbriel
      local.flake.modules.nixos.noctalia-greeter
    ];

    environment.systemPackages = with pkgs; [
      wdisplays
      thunar
      

    ];
    services.kanshi.enable = true;
  };
}
