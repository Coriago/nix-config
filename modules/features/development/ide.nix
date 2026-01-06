# Development IDE configuration
# I may move this to desktop since it's a UI app that would be needed for minimal managment of nix config unless a better UI is developed.
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
