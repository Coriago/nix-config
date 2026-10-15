{
  flake.modules.nixos.iphone = {pkgs, ...}: {
    services.usbmuxd.enable = true;
    environment.systemPackages = with pkgs; [
      libimobiledevice
      ifuse
    ];
  };
}
