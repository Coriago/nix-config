# Bluetooth configuration for NixOS
{
  flake.modules.nixos.bluetooth = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [blueman];
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    services.blueman.enable = true;
  };
}
