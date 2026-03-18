# Shell
{
  # NixOS
  flake.modules.nixos.base = {pkgs, ...}: {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
    };
    users.defaultUserShell = pkgs.zsh;
    environment.pathsToLink = ["/share/zsh"];
  };

  # Home Manager
  flake.modules.homeManager.base = {...}: {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      historySubstringSearch.enable = true;
      history = {
        ignoreDups = true;
        save = 10000;
        size = 10000;
      };
      oh-my-zsh = {
        enable = true;
        theme = "robbyrussell";
      };
    };
  };
}
