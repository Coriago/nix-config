{
  appimageTools,
  fetchurl,
  lib,
}:
appimageTools.wrapType2 (finalAttrs: {
  pname = "fritchii";
  version = "6.2";

  src = fetchurl {
    url = "https://github.com/Frizti/Fritchii/releases/download/fritchii-v${finalAttrs.version}/Fritchii-v${finalAttrs.version}-Linux-x86_64.AppImage";
    hash = "sha256-xlA41pDRyYvWQVaMphDCnrhedsgNqSWlmUkFhJrlv+g=";
  };

  extraInstallCommands = ''
    install -Dm444 ${finalAttrs.contents}/io.github.frizti.fritchii.desktop \
      $out/share/applications/io.github.frizti.fritchii.desktop
    substituteInPlace $out/share/applications/io.github.frizti.fritchii.desktop \
      --replace-fail 'TryExec=lichii' 'TryExec=fritchii' \
      --replace-fail 'Exec=lichii %f' "Exec=$out/bin/fritchii %f"
    install -Dm444 ${finalAttrs.contents}/fritchii.png \
      $out/share/icons/hicolor/512x512/apps/fritchii.png
  '';

  meta = {
    description = "Nintendo Switch emulator tuned for Ocarina of Time";
    homepage = "https://github.com/Frizti/Fritchii";
    license = lib.licenses.gpl3Only;
    mainProgram = "fritchii";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
