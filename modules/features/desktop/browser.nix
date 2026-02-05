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
  flake.modules.homeManager.desktop = {pkgs, ...}: {
    programs.brave = {
      enable = true;
      extensions = [
        {id = "cjpalhdlnbpafiamejdnhcphjbkeiagm";} # ublock origin
        {id = "nngceckbapebfimnlniiiahkandclblb";} # bitwarden
      ];
    };

    home.packages = with pkgs; [
      chromium # For Playwright browser automation and testing
    ];
  };
}
