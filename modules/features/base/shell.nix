{
  # General/Common settings

  # NixOS
  flake.modules.nixos.base = {pkgs, ...}: {
    programs.zsh.enable = true;
    users.defaultUserShell = pkgs.zsh;
  };

  # Home Manager
  flake.modules.homeManager.base = {
    config,
    lib,
    ...
  }: {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntax-highlighting.enable = true;
      historySubstringSearch.enable = true;
      history = {
        ignoreDups = true;
        save = 10000;
        size = 10000;
      };
    };

    profileExtra = ''
      ${lib.optionalString (config.home.sessionPath != []) ''
        export PATH="$PATH''${PATH:+:}${
          lib.concatStringsSep ":" config.home.sessionPath
        }"
      ''}
      # Include flatpak export directories so flatpak apps appear in application menus
      export XDG_DATA_DIRS="$XDG_DATA_DIRS:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share"
    '';
  };
}
