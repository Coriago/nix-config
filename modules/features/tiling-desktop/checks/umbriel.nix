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
    checks.umbriel-reload = pkgs.runCommand "umbriel-reload-check" {
      nativeBuildInputs = [pkgs.stdenv.cc pkgs.pkg-config];
      buildInputs = [pkgs.wayland pkgs.wlroots_0_20];
    } ''
      # Exercise the pinned native watcher against NixOS-style atomic copies.
      $CXX -std=c++23 -I${pkgs.umbriel.src}/src \
        ${./umbriel-reload-check.cpp} \
        ${pkgs.umbriel.src}/src/config/config_watcher.cpp \
        ${pkgs.umbriel.src}/src/core/log.cpp \
        $(pkg-config --cflags --libs wayland-server wlroots-0.20) -o watcher-check
      ./watcher-check
      touch "$out"
    '';
    checks.myumbriel = pkgs.runCommand "umbriel-config-check" {
      nativeBuildInputs = [pkgs.stdenv.cc pkgs.pkg-config pkgs.python3 pkgs.xvfb-run];
      buildInputs = [pkgs.kdePackages.qtbase pkgs.gtk3];
    } ''
      export HOME="$TMPDIR/home"
      export XDG_RUNTIME_DIR="$TMPDIR/runtime"
      mkdir -p "$HOME/.local/share/color-schemes" "$XDG_RUNTIME_DIR"
      chmod 700 "$XDG_RUNTIME_DIR"
      ${lib.getExe portable} validate

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
