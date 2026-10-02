local: {
  flake.modules.nixos.workstation = {config, ...}: {
    imports = with local.config.flake.modules.nixos; [
      base
      desktop
      development
      pi-agent
      # kde
      tiling-desktop
      neovim
      tailscale
    ];

    home-manager.users.${config.hostmeta.username} = {
      imports = with local.config.flake.modules.homeManager; [
        base
        desktop
      ];
    };
  };
}
