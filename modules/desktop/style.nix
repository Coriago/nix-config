# Common Styling using Stylix
# stylix is a generic styling engine for many different linux desktop environments.
{inputs, ...}: {
  # NixOS
  flake.modules.nixos.desktop = {
    pkgs,
    config,
    ...
  }: {
    # Enable Stylix
    imports = [inputs.stylix.nixosModules.stylix];
    disabledModules = ["${inputs.stylix}/modules/vscode/nixos.nix"];
    stylix.enable = true;

    # Wallpaper
    stylix.image = pkgs.fetchurl {
      url = config.vars.wallpaper;
      hash = config.vars.wallpaperHash;
    };

    # Theme
    # Comment this out and theme will be set by wallpaper colors
    stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/${config.vars.theme}.yaml";
  };

  # Home Manager
  flake.modules.homeManager.desktop = {...}: {
    # Disable stylix on vscode otherwise settings.json can't be changed
    stylix.targets.vscode.enable = false;
    stylix.targets.firefox.enable = false;

    # Get rid of warnings
    stylix.targets.qt.enable = false;
    gtk.gtk4.theme = null;
  };
}
