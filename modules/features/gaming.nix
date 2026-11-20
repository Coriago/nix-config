{self, ...}: {
  flake.modules.nixos.gaming = {pkgs, ...}: {
    environment.systemPackages = [self.packages.${pkgs.stdenv.hostPlatform.system}.fritchii];

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      gamescopeSession.enable = false;
      protontricks.enable = true;
    };

    hardware.xone.enable = true;
    hardware.xpad-noone.enable = false;

    programs.gamescope = {
      enable = false;
      capSysNice = false;
    };
  };
}
