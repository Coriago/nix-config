{
  flake.modules.nixos.gaming = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      retroarch-full
    ];
    hardware.xone.enable = true;
  };
}
