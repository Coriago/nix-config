{...}: let
  gamescopeArgs = [
    "--rt"
    # "--expose-wayland"
    # "--adaptive-sync"
    # "--backend sdl"
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
    enable = true;
  };
}
