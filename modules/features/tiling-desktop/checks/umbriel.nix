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
    checks.myumbriel = pkgs.runCommand "umbriel-config-check" {
      nativeBuildInputs = [pkgs.stdenv.cc pkgs.pkg-config pkgs.python3];
      buildInputs = [pkgs.kdePackages.qtbase];
    } ''
      export HOME="$TMPDIR/home"
      export XDG_RUNTIME_DIR="$TMPDIR/runtime"
      mkdir -p "$HOME/.local/share/color-schemes" "$XDG_RUNTIME_DIR"
      chmod 700 "$XDG_RUNTIME_DIR"
      ${lib.getExe portable} validate

      # Test the generated session environment, not a system-installed plugin.
      python - ${portable.generatedConfig} <<'PY'
      import os, pathlib, shlex, sys, tomllib
      env = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())["environment"]
      assert env["QT_QPA_PLATFORMTHEME"] == "qtengine"
      pathlib.Path("qt-env").write_text("\n".join(
          f"export {key}={shlex.quote(value)}" for key, value in env.items()
      ))
      PY
      source ./qt-env
      export QT_QPA_PLATFORM=offscreen
      cat > "$HOME/.local/share/color-schemes/noctalia.colors" <<'COLORS'
      [General]
      Name=Noctalia test
      [Colors:Window]
      BackgroundNormal=17,34,51
      COLORS
      $CXX ${./qtengine-check.cpp} -o qtengine-check $(pkg-config --cflags --libs Qt6Widgets)
      ./qtengine-check
      touch "$out"
    '';
  };
}
