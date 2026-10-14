{ lib, rustPlatform, dejavu_fonts }:
rustPlatform.buildRustPackage {
  pname = "corne-overlay";
  version = "0.1.0";
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;
  CORNE_OVERLAY_FONT = "${dejavu_fonts}/share/fonts/truetype/DejaVuSans.ttf";
  meta = {
    description = "Estimated W-CORNE layer overlay using Vial matrix polling";
    mainProgram = "corne-overlay";
    platforms = lib.platforms.linux;
  };
}
