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
      syncFile = "\${HOME}/synced.toml";
    };
  in {
    checks.mynoctalia = pkgs.runCommand "noctalia-config-check" {} ''
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      ${python}/bin/python ${./noctalia-check.py} ${../noctalia-sync.py} ${lib.getExe wrapper}
      touch "$out"
    '';
  };
}
