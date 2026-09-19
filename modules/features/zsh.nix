{
  flake.modules.nixos.base = {pkgs, ...}: {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
    };
    users.defaultUserShell = pkgs.zsh;
  };
}
