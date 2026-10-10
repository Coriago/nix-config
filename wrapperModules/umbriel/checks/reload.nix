{
  perSystem = {pkgs, ...}: {
    checks.umbriel-reload =
      pkgs.runCommand "umbriel-reload-check" {
        nativeBuildInputs = [pkgs.stdenv.cc pkgs.pkg-config];
        buildInputs = [pkgs.wayland pkgs.wlroots_0_20];
      } ''
        # Exercise the pinned native watcher against sync-snap-style atomic replacements.
        $CXX -std=c++23 -I${pkgs.umbriel.src}/src \
          ${./umbriel-reload-check.cpp} \
          ${pkgs.umbriel.src}/src/config/config_watcher.cpp \
          ${pkgs.umbriel.src}/src/core/log.cpp \
          $(pkg-config --cflags --libs wayland-server wlroots-0.20) -o watcher-check
        ./watcher-check
        touch "$out"
      '';
  };
}
