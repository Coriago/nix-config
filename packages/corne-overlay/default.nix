{ lib, rustPlatform, dejavu_fonts, fontconfig, at-spi2-core, glib }:
rustPlatform.buildRustPackage {
  pname = "corne-overlay";
  version = "0.2.0";
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;
  buildInputs = [at-spi2-core glib];
  CORNE_OVERLAY_FONT = "${dejavu_fonts}/share/fonts/truetype/DejaVuSans.ttf";
  postInstall = ''
    pluginDir=$out/share/noctalia/plugins/corne-overlay
    mkdir -p "$pluginDir"
    cp -r plugin/. "$pluginDir/"
    substituteInPlace "$pluginDir/service.luau" \
      --replace-fail '@out@' "$out" \
      --replace-fail '@fontconfig@' '${fontconfig}'
  '';
  meta = {
    description = "Estimated W-CORNE layer overlay using Vial matrix polling";
    mainProgram = "corne-overlay";
    platforms = lib.platforms.linux;
  };
}
