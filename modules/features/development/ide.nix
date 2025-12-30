{
  flake.modules.homeManager.development = {pkgs, ...}: {
    programs.vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        jnoortheen.nix-ide
        christian-kohler.path-intellisense
      ];
    };
  };
}
