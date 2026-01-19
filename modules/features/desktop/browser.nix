# Desired Browser
{
  # NixOS
  flake.modules.nixos.desktop = {...}: {
    environment.variables = {
      BROWSER = "brave";
      EDITOR = "code -w";
    };
  };

  # HomeManager
  flake.modules.homeManager.desktop = {...}: {
    programs.brave = {
      enable = true;
      extensions = [
        {id = "cjpalhdlnbpafiamejdnhcphjbkeiagm";} # ublock origin
        {id = "nngceckbapebfimnlniiiahkandclblb";} # bitwarden
      ];
    };
  };
}
