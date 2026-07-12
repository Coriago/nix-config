{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  makeWrapper,
  glib,
  dbus,
  atk,
  gdk-pixbuf,
  pango,
  gtk3,
  udev,
  xdotool,
  libxcb,
  wayland,
  libGL,
  libxkbcommon,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
  libayatana-appindicator,
}: let
  libPath = lib.makeLibraryPath [
    libGL
    libxkbcommon
    wayland
    libx11
    libxcursor
    libxi
    libxrandr
    libayatana-appindicator
  ];
in
  rustPlatform.buildRustPackage rec {
    pname = "keypeek";
    version = "0.7.0";

    src = fetchFromGitHub {
      owner = "srwi";
      repo = "keypeek";
      rev = version;
      hash = "sha256-KMd26TSDHnTMIbtZmq4SgGuj3t8NbCbgAY3jz8TQa3g=";
    };

    cargoHash = "sha256-b7nS8BTkKfwoLnNlaoH5zV91o76fWtbytS2OMb6Mv6I=";

    nativeBuildInputs = [
      pkg-config
      makeWrapper
    ];

    buildInputs = [
      glib
      dbus
      atk
      gdk-pixbuf
      pango
      gtk3
      udev
      xdotool
      pkg-config
      libxcb
      wayland
      libGL
      libxkbcommon
    ];

    postInstall = ''
      wrapProgram "$out/bin/keypeek" --prefix LD_LIBRARY_PATH : "${libPath}"
    '';

    meta = {
      description = "Live on-screen keyboard overlay that mirrors your active QMK/Vial/ZMK layers in real time";
      homepage = "https://github.com/srwi/keypeek";
      license = lib.licenses.gpl3Only;
      mainProgram = "keypeek";
    };
  }
