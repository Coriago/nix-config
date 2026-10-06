{config, ...}: let
  local = config;
in {
  flake.modules.nixos.tiling-desktop = {pkgs, ...}: {
    imports = [
      local.flake.modules.nixos.noctalia

      # Compositor choice. Swap niri for umbriel here while testing.
      # local.flake.modules.nixos.niri
      local.flake.modules.nixos.umbriel
      local.flake.modules.nixos.noctalia-greeter
    ];

    environment.systemPackages = with pkgs; [
      wdisplays
    ];

    # Keep profiles writable: wdisplays' "Save to kanshi Config" owns this file.
    services.kanshi.enable = true;
  };
}
