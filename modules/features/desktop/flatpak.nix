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
        "com.stremio.Stremio"
      ];
    };
  };

  flake.modules.homeManager.desktop = {...}: {
    xdg.userDirs.enable = true;

    # Add extra XDG_DATA_DIRS for flatpak apps
    home.sessionVariables = {
      XDG_DATA_DIRS = "$XDG_DATA_DIRS:/usr/share:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share";
    };
  };
}
