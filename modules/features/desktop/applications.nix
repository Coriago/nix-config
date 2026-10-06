{
  flake.modules.homeManager.desktop = {pkgs, ...}: {
    programs = {
      brave.enable = true;
      firefox.enable = true;
      discord.enable = true;
    };

    home.sessionVariables.BROWSER = "brave";

    fonts.fontconfig.enable = true;

    home.packages = with pkgs; [
      orca-slicer
      krita
      vlc
      ghostty
      nerd-fonts.jetbrains-mono
      kdePackages.ark
      herdr
    ];
  };
}
