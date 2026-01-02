{
  flake.modules.homeManager.development = {pkgs, ...}: {
    home.packages = with pkgs; [
      rpi-imager
      nix-inspect
      nvd
    ];
  };
}
