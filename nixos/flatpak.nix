{...}: {
  # Enable flatpak system service (required for nix-flatpak home-manager module)
  services.flatpak = {
    enable = true;
    remotes = [
      {
        name = "flathub";
        location = "https://flathub.org/repo/flathub.flatpakrepo";
      }
    ];
    packages = [
      {
        appId = "com.stremio.Stremio";
        origin = "flathub";
      }
    ];
  };
}
