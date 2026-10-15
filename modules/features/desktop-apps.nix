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
      kdePackages.ark
    ];
    xdg.mime.defaultApplications = {
      "application/zip" = "org.kde.ark.desktop";
      "application/x-zip-compressed" = "org.kde.ark.desktop";
      "application/x-7z-compressed" = "org.kde.ark.desktop"; # Optional: for 7z files
      "application/x-tar" = "org.kde.ark.desktop"; # Optional: for tarballs
    };

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
