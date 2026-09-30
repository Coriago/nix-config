local: {
  flake.modules.nixos.workstation = {config, ...}: {
    imports = with local.config.flake.modules.nixos; [
      base
      desktop
      development
      kde
      # niri
      tailscale
    ];

    # services.displayManager = {
    #   plasma-login-manager.enable = true;
    #   defaultSession = "niri";
    # };

    home-manager.users.${config.hostmeta.username} = {
      imports = with local.config.flake.modules.homeManager; [
        base
        desktop
        development
      ];
    };
  };
}
