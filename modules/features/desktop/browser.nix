{
  flake.modules.nixos.desktop = {...}: {
    environment.variables = {
      BROWSER = "brave";
    };
  };

  flake.modules.homeManager.desktop = {...}: {
    programs.brave = {
      enable = true;
      extensions = [
        {id = "cjpalhdlnbpafiamejdnhcphjbkeiagm";} # ublock origin
      ];
    };
  };
}
