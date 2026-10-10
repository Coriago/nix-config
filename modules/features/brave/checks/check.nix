{
  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: let
    package = self'.packages.mybrave;
    snapshotCheck = package.wrap {
      snapshot.defaultDir = "\${HOME}/snapshot";
    };
    restoreCheck = package.wrap ({config, ...}: {
      preferences.homepage = "https://explicit.invalid/";
      sync.files.bravePreferences.sources = [
        {
          path = "\${HOME}/snapshot/Preferences.json";
          format = "json";
        }
        config.constructFiles.bravePreferences.path
      ];
    });
  in {
    checks.mybrave =
      pkgs.runCommand "brave-policy-check" {
        nativeBuildInputs = [(pkgs.python3.withPackages (p: [p.websocket-client]))];
      } ''
        python3 ${./check.py} ${lib.getExe package} \
          ${snapshotCheck}/bin/brave-snapshot ${lib.getExe restoreCheck}
        touch "$out"
      '';
  };
}
