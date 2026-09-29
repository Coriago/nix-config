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
      local-llm
      cachyos-kernel
    ];
  };
}
