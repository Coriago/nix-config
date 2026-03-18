# Bluetooth configuration for NixOS
{
  flake.modules.nixos.bluetooth = {pkgs, ...}: {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    # environment.systemPackages = with pkgs; [blueman];
    # services.blueman.enable = true;
  };
}
