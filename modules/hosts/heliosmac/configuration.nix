{config, ...}: {
  meta.hosts.heliosmac = {
    username = "helios";
    stateVersion = "26.05";
  };

  configurations.nixos.heliosmac = {
    imports = with config.flake.modules.nixos; [
      workstation
      boot
    ];
  };
}
