{config, ...}: let
  local = config;
in {
  flake.modules.nixos.tiling-desktop = {...}: {
    imports = [
      local.flake.modules.nixos.noctalia

      # Compositor choice. Swap niri for umbriel here while testing.
      local.flake.modules.nixos.niri
      # local.flake.modules.nixos.umbriel

      # Login manager choice. Swap plasma-login-manager for noctalia-greeter here.
      local.flake.modules.nixos.plasma-login-manager
      # local.flake.modules.nixos.noctalia-greeter
    ];
  };
}
