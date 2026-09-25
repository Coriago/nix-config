local: {
  flake.modules.nixos.workstation = {config, ...}: {
    imports = with local.config.flake.modules.nixos; [
      base
      development
      kde
    ];

    home-manager.users.${config.hostmeta.username} = {
      imports = with local.config.flake.modules.homeManager; [
        base
      ];
    };
  };
}
