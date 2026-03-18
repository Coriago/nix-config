# Monitor manager
# This is a monitor utility for changing monitor settings like source selection without needing to use physical buttons using DDC/CI.
{
  # NixOS
  flake.modules.nixos.monitor = {pkgs, ...}: {
    hardware.i2c.enable = true;
    environment.systemPackages = with pkgs; [
      ddcutil
      ddcui
    ];
  };
  # TODO ADD SCRIPT
}
