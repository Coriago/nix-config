{config, ...}: let
  local = config;
in {
  perSystem = {
    pkgs,
    lib,
    ...
  }: let
    python = pkgs.python3.withPackages (p: [p.tomli-w]);
    wrapper = local.flake.wrappers.mynoctalia.wrap {
      inherit pkgs;
      settings.theme.mode = "light";
      snapshotFile = "\${HOME}/snapshot.toml";
    };
  in {
    checks.mynoctalia = pkgs.runCommand "noctalia-config-check" {} ''
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      ${python}/bin/python ${./noctalia-check.py} ${../noctalia-snapshot.py} ${lib.getExe wrapper} ${../noctalia-reset.py}
      touch "$out"
    '';
  };
}
