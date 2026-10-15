{config, ...}: {
  flake.modules.nixos.zsh = {
    hostmeta,
    pkgs,
    ...
  }: {
    home-manager.users.${hostmeta.username}.imports = [
      config.flake.modules.homeManager.zsh
    ];
    programs.zsh = {
      enable = true;
      enableCompletion = true;
    };
    users.defaultUserShell = pkgs.zsh;
    environment.pathsToLink = ["/share/zsh"];
  };

  flake.modules.homeManager.zsh = {...}: {
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
