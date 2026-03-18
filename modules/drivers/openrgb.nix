# OpenRGB configuration for NixOS
{
  flake.modules.nixos.openrgb = {
    pkgs,
    config,
    ...
  }: {
    # Load i2c-dev and i2c-piix4 for SMBus access (required for motherboard/RAM RGB on AMD)
    boot.kernelModules = ["i2c-dev" "i2c-piix4"];

    # Allow userspace access to SMBus regions (required for motherboard RGB on many systems)
    boot.kernelParams = ["acpi_enforce_resources=lax"];

    # Install i2c-tools for bus detection
    environment.systemPackages = [pkgs.i2c-tools pkgs.pciutils];

    # Add user to i2c group for device access
    users.users.${config.vars.username}.extraGroups = ["i2c"];

    services.hardware.openrgb = {
      enable = true;
      package = pkgs.openrgb-with-all-plugins;
    };
  };
}
