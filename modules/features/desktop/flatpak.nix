# Flatpak apps
# These are sandboxed apps typically installed in 'software center' or 'discover store'.
# Some apps work great this way and others have limitations due to sandboxing.
{inputs, ...}: {
  flake.modules.nixos.desktop = {...}: {
    imports = [
      inputs.nix-flatpak.nixosModules.nix-flatpak
    ];

    services.flatpak = {
      enable = true;
      remotes = [
        {
          name = "flathub";
          location = "https://flathub.org/repo/flathub.flatpakrepo";
        }
      ];
      packages = [
        "com.stremio.Stremio" # Stremio
      ];
    };
  };

  flake.modules.homeManager.desktop = {...}: {
    # Uncomment if flatpak apps don't show up in application launchers
    # home.sessionVariables = {
    #   XDG_DATA_DIRS = "$XDG_DATA_DIRS:/usr/share:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share";
    # };
  };
}
