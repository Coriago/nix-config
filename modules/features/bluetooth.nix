# Bluetooth configuration for NixOS
{
  flake.nixosModules.bluetooth = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [blueman];
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    services.blueman.enable = true;
  };
}
