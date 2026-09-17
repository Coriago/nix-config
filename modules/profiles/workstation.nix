{config, ...}: {
  flake.modules.nixos.workstation-profile = {hostmeta, ...}: {
    imports = with config.flake.modules.nixos; [
      base
      cachyos-kernel
      kde
    ];

    home-manager.users.${hostmeta.username} = {
      imports = with config.flake.modules.homeManager; [
        base
      ];
    };
  };
}
