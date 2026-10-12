{
  lib,
  rustPlatform,
  makeWrapper,
  jq,
}:
rustPlatform.buildRustPackage {
  pname = "sync-snap";
  version = "0.1.0";
  src = lib.cleanSourceWith {
    src = ./.;
    filter = path: type:
      !(builtins.elem (builtins.baseNameOf path) ["target" ".git"])
      && lib.cleanSourceFilter path type;
  };
  cargoLock.lockFile = ./Cargo.lock;
  nativeBuildInputs = [makeWrapper];
  nativeCheckInputs = [jq];
  postFixup = ''
    wrapProgram "$out/bin/sync-snap" --prefix PATH : ${lib.makeBinPath [jq]}
  '';
  meta = {
    description = "Synchronize writable application configuration and export filtered snapshots";
    mainProgram = "sync-snap";
    platforms = lib.platforms.linux;
  };
}
