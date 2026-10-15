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
        # A previous version merged preferences into the main file. They must
        # disappear so that the native include can control them after migration.
        mkdir -p "$HOME/.config/syncumbriel"
        printf '[layout]\nmode = "master"\n[keybinds]\n"Mod+Q" = "session-quit"\n' > "$HOME/.config/syncumbriel/config.toml"
        ${portable}/bin/umbriel-sync
        ${lib.getExe portable} config validate

        # Test the generated session environment, not a system-installed plugin.
        python - ${portable.generatedConfig} <<'PY'
        import os, pathlib, shlex, sys, tomllib
        settings = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
        runtime = tomllib.loads((pathlib.Path.home() / ".config/syncumbriel/config.toml").read_text())
        assert runtime == settings
        assert "layout" not in settings
        assert "Mod+Q" not in settings["keybinds"]
        extra = pathlib.Path(settings["include"]["files"][0])
        assert extra == pathlib.Path("${portable.configuration.constructFiles.umbrielExtraConfig.outPath}")
        assert extra.read_bytes() == pathlib.Path("${../umbriel/configExtras.toml}").read_bytes()
        preferences = tomllib.loads(extra.read_text())
        assert preferences["layout"]["mode"] == "scrolling"
        assert abs(preferences["layout"]["scrolling"]["default_extent_fraction"] - 2 / 3) < 1e-8
        assert not (pathlib.Path.home() / ".config/syncumbriel/configExtras.toml").exists()
        env = settings["environment"]
        assert env["QT_QPA_PLATFORMTHEME"] == "qtengine"
        assert env["ACCESSIBILITY_ENABLED"] == "1"
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
