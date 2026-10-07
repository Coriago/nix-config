local: {
  flake.modules.nixos.desktop-apps = {
    config,
    pkgs,
    ...
  }: {
    imports = with local.config.flake.modules.nixos; [
      ghostty
    ];
    programs.kdeconnect.enable = true;
    environment.systemPackages = with pkgs; [
      kdePackages.partitionmanager
      kdePackages.isoimagewriter
      ark
    ];

    home-manager.users.${config.hostmeta.username} = {
      imports = [
        local.config.flake.modules.homeManager.desktop-apps
      ];
    };
  };

  flake.modules.homeManager.desktop-apps = {pkgs, ...}: {
    programs = {
      brave.enable = true;
      discord.enable = true;
    };

    home.sessionVariables.BROWSER = "brave";
    home.packages = with pkgs; [
      orca-slicer
      krita
      vlc
    ];
  };
}
