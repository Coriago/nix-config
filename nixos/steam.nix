{
  pkgs,
  nixpkgs-unstable,
  ...
}: let
  gamescopeArgs = [
    "--rt"
    "--expose-wayland"
    "--backend wayland"
    # "--adaptive-sync"
    # "--backend sdl"
    # -W 2560 -H 1440 -w 2560 -h 1440 -r 240 -f --force-grab-cursor
  ];
in {
  programs.steam = {
    # protontricks.enable = true;

    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    gamescopeSession.enable = true;
    gamescopeSession.args = gamescopeArgs;
  };
  programs.gamescope = {
    enable = true;
    capSysNice = true;
    args = gamescopeArgs;
  };

  programs.gamemode = {
    enable = false;
  };

  # services.ananicy = {
  #   enable = true;
  #   package = pkgs.ananicy-cpp;
  #   rulesProvider = pkgs.ananicy-rules-cachyos;
  # };
}
