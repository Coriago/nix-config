local: {
  flake.modules.nixos.workstation = {config, ...}: {
    imports = with local.config.flake.modules.nixos; [
      base
      development
      desktop-apps
      pi-agent
      # kde
      tiling-desktop
      neovim
      tailscale
    ];
  };
}
