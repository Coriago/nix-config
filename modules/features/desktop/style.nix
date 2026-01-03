{inputs}: {
  # NixOS
  flake.modules.nixos.desktop = {
    pkgs,
    config,
    ...
  }: {
    imports = [
      inputs.stylix.nixosModules.stylix
    ];

    stylix.enable = true;
    stylix.image = pkgs.fetchurl {
      url = "https://getwallpapers.com/wallpaper/full/7/3/0/168494.jpg";
      hash = "sha256-S/6kgloXiIYI0NblT6YVXfqELApbdHGsuYe6S4JoQwQ=";
    };
    stylix.polarity = "dark";
  };
}
