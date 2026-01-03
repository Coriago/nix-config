{inputs, ...}: {
  # NixOS
  flake.modules.nixos.desktop = {pkgs, ...}: let
    # Find themes here
    # https://tinted-theming.github.io/tinted-gallery/
    set_theme = "equilibrium-dark";
  in {
    # Enable Stylix
    imports = [
      inputs.stylix.nixosModules.stylix
    ];
    stylix.enable = true;

    # Wallpaper
    stylix.image = pkgs.fetchurl {
      url = "https://getwallpapers.com/wallpaper/full/2/e/a/524916.jpg";
      hash = "sha256-YqFWMRjdM8dGbSJQomvoNtwmq2ppfwq6r0UYYpx6sVA=";
    };

    # Theme
    # Comment this out and theme will be set by wallpaper colors
    stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/${set_theme}.yaml";
  };
}
