local: {
  flake.modules.nixos.gaming = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      lutris
    ];
    services.joycond.enable = true;
    boot.kernelModules = ["hid_nintendo"];
  };
}
