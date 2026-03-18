{
  flake.modules.nixos.gaming = {pkgs, ...}: {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      gamescopeSession.enable = true;
      protontricks.enable = true;
    };

    hardware.steam-hardware.enable = true;
    hardware.xone.enable = true;

    programs.gamescope = {
      enable = true;
      capSysNice = true;
    };
  };
}
