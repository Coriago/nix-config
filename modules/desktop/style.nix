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
}
