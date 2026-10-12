{config, ...}: let
  local = config;
in {
  perSystem = {
    pkgs,
    lib,
    ...
  }: let
    package = local.flake.wrappers.umbriel.wrap {
      inherit pkgs;
      configDir = "\${XDG_CONFIG_HOME}/fixture compositor";
      snapshot.enable = true;
      snapshot.autoMerge = false;
      snapshot.defaultDir = "\${HOME}/snapshot";
      settings = {
        layout.mode = "scrolling";
        layout.scrolling.default_extent_fraction = 0.5;
        keybinds."Mod+Q" = "window-close";
      };
    };
    probe = package.wrap ({lib, ...}: {
      package = lib.mkForce (pkgs.writeShellScriptBin "umbriel" ''printf '%s\n' "$@"'');
    });
    restore = package.wrap ({
      config,
      lib,
      ...
    }: {
      configDir = lib.mkForce "\${HOME}/restored";
      sync.files.umbrielConfig.sources = [
        "\${HOME}/snapshot/config.toml"
        {
          path = config.constructFiles.umbrielConfig.path;
          format = "toml";
        }
      ];
    });
  in {
    checks.umbriel-wrapper =
      pkgs.runCommand "umbriel-wrapper-check" {
        nativeBuildInputs = [(pkgs.python3.withPackages (p: [p.tomli-w]))];
      } ''
        export HOME="$TMPDIR/home"
        export XDG_CONFIG_HOME="$HOME/config" XDG_STATE_HOME="$HOME/state" XDG_CACHE_HOME="$HOME/cache"
        mkdir -p "$HOME"
        python3 ${./check.py} ${lib.getExe package} ${lib.getExe probe} ${lib.getExe restore}
        touch "$out"
      '';
  };
}
