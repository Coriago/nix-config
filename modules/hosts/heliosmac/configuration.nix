{config, ...}: {
  meta.hosts.heliosmac = {
    username = "helios";
    stateVersion = "26.05";
  };

  configurations.nixos.heliosmac = {
    imports = with config.flake.modules.nixos; [
      base
      development
      workstation
      tailscale
      boot
      power-usage
    ];
    liveConfig.enable = true;
  };
}
