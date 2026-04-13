{
  flake.modules.nixos.desktop-extras = {...}: {
    services.audiobookshelf = {
      enable = true;
      openFirewall = true;
      port = 8000;
      host = "0.0.0.0";
    };

    services.qbittorrent.enable = true;

    # services.qbittorrent.user = ;
  };
}
