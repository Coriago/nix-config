{config, ...}: let
  local = config;
in {
  perSystem = {
    pkgs,
    lib,
    ...
  }: let
    portable = local.flake.wrappers.myumbriel.wrap {inherit pkgs;};
  in {
    checks.myumbriel = pkgs.runCommand "umbriel-config-check" {} ''
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      ${lib.getExe portable} validate
      touch "$out"
    '';
  };
}
