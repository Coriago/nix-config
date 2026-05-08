# OpenRGB configuration for NixOS
{
  flake.modules.nixos.openrgb = {
    pkgs,
    lib,
    config,
    ...
  }: {
    # Allow userspace access to SMBus regions (required for motherboard RGB on many systems)
    boot.kernelParams = ["acpi_enforce_resources=lax"];
    boot.blacklistedKernelModules = ["sp5100_tco" "spd5118"];
    boot.kernelModules = [
      # "nct6687"
      "nct6775"
      "nct6775-i2c"
      "nzxt-smart2"
      # "i2c-nct6793"
    ];

    # Install i2c-tools for bus detection
    environment.systemPackages = with pkgs; [
      i2c-tools
      pciutils
      lm_sensors

      openrgb-with-all-plugins
      liquidctl
    ];

    programs.coolercontrol.enable = true;
    services.udev.packages = [pkgs.liquidctl];

    services.hardware.openrgb.enable = true;

    # Add user to i2c group for device access
    users.users.${config.vars.username}.extraGroups = ["i2c" "wireshark"];

    # Tenmporary for diag
    programs.wireshark.enable = true;
    programs.wireshark.package = pkgs.wireshark;
    # users.users.${config.vars.username}.extraGroups = ["wireshark"];

    # Set loglevel for OpenRGB systemd service
    systemd.services.openrgb = {
      serviceConfig.ExecStart = let
        openrgbCfg = config.services.hardware.openrgb;
      in
        lib.mkForce (lib.escapeShellArgs (
          [
            (lib.getExe openrgbCfg.package)
            "--server"
            "--server-port"
            openrgbCfg.server.port
            "--loglevel"
            "6"
          ]
          ++ lib.optionals (lib.isString openrgbCfg.startupProfile) [
            "--profile"
            openrgbCfg.startupProfile
          ]
        ));
    };
  };
}
