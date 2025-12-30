{
  flake.modules.nixos.development = {...}: {
    programs.vscode = {
      enable = true;
    };
  };
}
