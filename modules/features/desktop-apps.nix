local: {
  flake.modules.nixos.desktop-apps = {
    hostmeta,
    pkgs,
    ...
  }: {
    imports = with local.config.flake.modules.nixos; [
      ghostty
      brave
    ];
    programs.kdeconnect.enable = true;
    environment.systemPackages = with pkgs; [
      kdePackages.partitionmanager
      kdePackages.isoimagewriter
      ark
    ];

    home-manager.users.${hostmeta.username} = {
      imports = [
        local.config.flake.modules.homeManager.desktop-apps
      ];
    };
  };

  flake.modules.homeManager.desktop-apps = {pkgs, ...}: {
    programs = {
      discord.enable = true;
    };

    home.packages = with pkgs; [
      orca-slicer
      krita
      vlc
    ];
  };
}
