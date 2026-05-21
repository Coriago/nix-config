{
  # Make nixos easier and more compatible with debian.
  # Not the nix way but it is easier
  flake.modules.nixos.desktop = {pkgs, ...}: {
    programs.nix-ld.enable = true;
    # Common Dynamic Libraries for Desktop Programs
    programs.nix-ld.libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      fuse3
      icu
      nss
      openssl
      curl
      expat
      binutils
      lld
      linuxHeaders
    ];

    environment.systemPackages = with pkgs; [
      apt
    ];

    # AppImage Support
    programs.appimage = {
      enable = true;
      binfmt = false;
    };
  };
}
