{
  flake.modules.nixos.desktop = {
    pkgs,
    config,
    ...
  }: {
    system.environment.systemPackages = with pkgs; [
      audiobookshelf
    ];

    services.audiobookshelf = {
      enable = true;
      openFirewall = true;
      port = 8000;
    };
  };
}
