{
  flake.modules.nixos.desktop-essentials = {pkgs, ...}: {
    hardware.bluetooth.enable = true;
    networking.networkmanager.enable = true;
    security.rtkit.enable = true;

    services = {
      upower.enable = true;
      power-profiles-daemon.enable = true;
      printing = {
        enable = true;
        drivers = [pkgs.hplip];
      };
      avahi = {
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
    };
  };
}
