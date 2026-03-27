# Bluetooth configuration for NixOS
{
  flake.modules.nixos.bluetooth = {pkgs, ...}: {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      # package = pkgs.bluez5-experimental;
      # settings.Policy.AutoEnable = "true";
      # settings.General.Enable = "Source,Sink,Media,Socket";
    };
    # services.blueman.enable = true;
    # boot.kernelParams = ["btusb.enable_autosuspend=n"];
    # environment.systemPackages = with pkgs; [blueman];
    # services.blueman.enable = true;
  };
}
