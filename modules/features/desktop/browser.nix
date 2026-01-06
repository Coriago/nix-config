# Desired Browser
{
  # NixOS
  flake.modules.nixos.desktop = {...}: {
    environment.variables = {
      BROWSER = "brave";
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
