{
  flake.modules.nixos.desktop = {...}: {
    networking.networkmanager.enable = true;
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      ipv4 = true;
      ipv6 = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };
    programs.kdeconnect.enable = true;
  };
}
