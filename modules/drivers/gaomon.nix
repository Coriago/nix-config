# Gaomon tablet driver configuration for NixOS
{self, ...}: {
  flake.modules.nixos.gaomon = {
    pkgs,
    config,
    ...
  }: let
    gaomon-driver = self.packages.${pkgs.stdenv.hostPlatform.system}.gaomon-driver;
  in {
    # Load kernel modules required by the driver for virtual input devices
    boot.kernelModules = ["uinput" "uhid"];

    # Install udev rules for Gaomon USB devices (vendor 256c)
    services.udev.packages = [gaomon-driver];

    # Install the GUI configuration tool
    environment.systemPackages = [gaomon-driver];

    # Systemd service for the huionCore daemon (handles USB tablet communication)
    systemd.services.gaomon-core = {
      description = "Gaomon tablet driver daemon";
      wantedBy = ["graphical.target"];
      after = ["graphical.target"];
      serviceConfig = {
        ExecStart = "${gaomon-driver}/bin/gaomon-core";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
