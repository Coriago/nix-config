{config, ...}: {
  meta.hosts.heliosurface = {
    username = "helios";
    stateVersion = "26.11";
  };

  configurations.nixos.heliosurface = {
    imports = with config.flake.modules.nixos; [
      base
      boot
      diskLayout
      workstation
      development
      nvidia-laptop
      gaming
      cachyos-kernel
      surface-kernel
    ];
  };
}
