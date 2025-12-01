{...}: {
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
    update.onActivation = true;
  };
}
