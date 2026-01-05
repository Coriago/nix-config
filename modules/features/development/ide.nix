{
  flake.modules.homeManager.development = {pkgs, ...}: {
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
