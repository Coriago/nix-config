{ appimageTools, fetchurl, lib }:
appimageTools.wrapType2 (finalAttrs: {
  pname = "nuvio";
  version = "0.1.33-alpha";

  src = fetchurl {
    url = "https://github.com/NuvioMedia/NuvioDesktop/releases/download/0.1.33-alpha/Nuvio-Linux-x86_64-0.1.33-alpha.AppImage";
    sha256 = "35fbb8d4d1060aed169f6203dba3d655ed554fd25e384aaeb7c4e4e0f75fb4e0";
  };

  extraPkgs = pkgs: [ pkgs.mpv-unwrapped pkgs.webkitgtk_4_1 ];

  extraInstallCommands = ''
    install -Dm444 ${finalAttrs.contents}/Nuvio.desktop $out/share/applications/Nuvio.desktop
    substituteInPlace $out/share/applications/Nuvio.desktop \
      --replace-fail 'Exec=AppRun %u' "Exec=$out/bin/nuvio %u"
    install -Dm444 ${finalAttrs.contents}/Nuvio.png $out/share/icons/hicolor/256x256/apps/Nuvio.png
  '';

  meta = {
    description = "Nuvio desktop media player (alpha)";
    homepage = "https://github.com/NuvioMedia/NuvioDesktop";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "nuvio";
  };
})
