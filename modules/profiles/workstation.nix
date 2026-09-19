{config, ...}: {
  flake.modules.nixos.workstation = {hostmeta, ...}: {
    imports = with config.flake.modules.nixos; [
      base
      development
      kde
    ];

    home-manager.users.${hostmeta.username} = {
      imports = with config.flake.modules.homeManager; [
        base
      ];
    };
  };
}
