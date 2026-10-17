{config, ...}: {
  meta.hosts.heliosdesk = {
    username = "helios";
    stateVersion = "26.05";
  };

  configurations.nixos.heliosdesk = {
    imports = with config.flake.modules.nixos; [
      base
      development
      workstation
      boot
      nvidia
      cachyos-kernel
      gaming
    ];

    liveConfig.enable = true;
  };
}
