{config, ...}: {
  meta.hosts.heliosdesk = {
    username = "helios";
    stateVersion = "26.05";
  };

  configurations.nixos.heliosdesk = {
    imports = with config.flake.modules.nixos; [
      workstation
      boot
      nvidia
      keyboard
      local-llm
      cachyos-kernel
      gaming
    ];

    liveConfig.enable = true;
  };
}
