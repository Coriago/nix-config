{
  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: let
    portable = self'.packages.myumbriel;
  in {
    checks.myumbriel =
      pkgs.runCommand "umbriel-config-check" {
        nativeBuildInputs = [pkgs.stdenv.cc pkgs.pkg-config pkgs.python3 pkgs.xvfb-run];
        buildInputs = [pkgs.kdePackages.qtbase pkgs.gtk3];
      } ''
        export HOME="$TMPDIR/home"
        export XDG_RUNTIME_DIR="$TMPDIR/runtime"
        mkdir -p "$HOME/.local/share/color-schemes" "$XDG_RUNTIME_DIR"
        chmod 700 "$XDG_RUNTIME_DIR"
        ${portable}/bin/umbriel-sync
        ${lib.getExe portable} config validate

        # Test the generated session environment, not a system-installed plugin.
        python - ${portable.generatedConfig} <<'PY'
        import os, pathlib, shlex, sys, tomllib
        settings = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
        assert settings["layout"]["mode"] == "scrolling"
        assert abs(settings["layout"]["scrolling"]["default_extent_fraction"] - 2 / 3) < 1e-8
        env = settings["environment"]
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

        # Use GTK's real theme loader with no host/user theme search paths.
        export XDG_DATA_DIRS="$TMPDIR/empty-data"
        $CC ${./gtk-theme-check.c} -o gtk-theme-check $(pkg-config --cflags --libs gtk+-3.0)
        xvfb-run ./gtk-theme-check
        touch "$out"
      '';
  };
}
