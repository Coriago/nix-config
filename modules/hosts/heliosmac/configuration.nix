{config, ...}: {
  meta.hosts.heliosmac = {
    username = "helios";
    stateVersion = "26.05";
  };

  configurations.nixos.heliosmac = {
    # Unlock the existing encrypted swap partition before its swap unit starts.

    imports = with config.flake.modules.nixos; [
      workstation
      boot
    ];
  };
}
