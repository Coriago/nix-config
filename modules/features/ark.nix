{
  flake.modules.nixos.ark = {pkgs, ...}: {
    environment.systemPackages = [pkgs.kdePackages.ark];
    xdg.mime.defaultApplications = {
      "application/zip" = "org.kde.ark.desktop";
      "application/x-zip-compressed" = "org.kde.ark.desktop";
      "application/x-7z-compressed" = "org.kde.ark.desktop";
      "application/x-tar" = "org.kde.ark.desktop";
    };
  };
}
