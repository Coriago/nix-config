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
      nvidia
      gaming
      # cachyos-kernel
    ];

    # services.nixmox.joinSeed = "100.74.103.111:8080";
  };
}
