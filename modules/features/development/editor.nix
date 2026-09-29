{
  flake.modules.homeManager.development = {...}: {
    programs.vscode.enable = true;
    home.sessionVariables.EDITOR = "nvim";
  };
}
