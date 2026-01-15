# Desktop UI Apps
{
  flake.modules.homeManager.desktop = {pkgs, ...}: {
    home.packages = with pkgs; [
      vlc
      discord
      kitty
      rpi-imager
    ];

    programs.vscode = {
      enable = true;
      mutableExtensionsDir = true;
      profiles.default.extensions = with pkgs.vscode-extensions; [
        jnoortheen.nix-ide
        christian-kohler.path-intellisense

        # TypeScript / Node.js development
        dbaeumer.vscode-eslint
        esbenp.prettier-vscode
      ];
    };
  };
}
