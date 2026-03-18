local: {
  flake.modules.nixos.gaming = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      retroarch-full
      lutris
    ];

    services.joycond.enable = true;

    boot.kernelModules = ["hid_nintendo"];
  };
}
