{
  flake.modules.nixos.gaming = {...}: {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      gamescopeSession.enable = false;
      protontricks.enable = true;
    };

    hardware.xone.enable = true;

    programs.gamescope = {
      enable = false;
      capSysNice = false;
    };
  };
}
