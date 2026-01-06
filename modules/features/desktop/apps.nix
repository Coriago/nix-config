# Desktop UI Apps
{
  flake.modules.homeManager.desktop = {pkgs, ...}: {
    home.packages = with pkgs; [
      vlc
      discord
    ];
  };
}
