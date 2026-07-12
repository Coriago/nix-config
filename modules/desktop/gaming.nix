{
  flake.modules.nixos.desktop-extras = {pkgs, ...}: {
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

    environment.systemPackages = with pkgs; [
      (opentrack .overrideAttrs
        (old: {
          nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.makeWrapper];
          postFixup =
            (old.postFixup or "")
            + ''
              wrapProgram $out/bin/opentrack \
                --set QT_QPA_PLATFORM xcb
            '';
        }))
      python3
      p7zip
    ];
    services.joycond.enable = true;
    boot.kernelModules = ["hid_nintendo"];
  };
}
