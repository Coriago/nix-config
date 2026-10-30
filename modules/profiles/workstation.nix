local: {
  flake.modules.nixos.workstation = {
    hostmeta,
    pkgs,
    ...
  }: {
    imports = with local.config.flake.modules.nixos; [
      ghostty
      brave
      ark
      printing
      tiling-desktop
      keyboard
      linux-compat
    ];

    hardware.bluetooth.enable = true;
    networking.networkmanager.enable = true;
    security.rtkit.enable = true;

    services = {
      upower.enable = true;
      power-profiles-daemon.enable = true;
    };

    programs = {
      kdeconnect.enable = true;
    };

    environment.systemPackages = with pkgs; [
      kdePackages.partitionmanager
      kdePackages.isoimagewriter
      orca-slicer
      krita
      vlc
      local.self.packages.${pkgs.stdenv.hostPlatform.system}.nuvio
    ];

    home-manager.users.${hostmeta.username} = {...}: {
      programs.discord.enable = true;
    };
  };
}
