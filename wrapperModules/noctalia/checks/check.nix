{config, ...}: let
  local = config;
in {
  perSystem = {
    pkgs,
    lib,
    ...
  }: let
    package = local.flake.wrappers.noctalia.wrap {
      inherit pkgs;
      configHome = "\${XDG_CONFIG_HOME}/fixture config";
      stateHome = "\${XDG_STATE_HOME}/fixture state";
      snapshot.enable = true;
      snapshot.sourceDir = ./baseline;
      snapshot.defaultDir = "\${HOME}/snapshot";
      settings = {
        theme.mode = "light";
        bar.default.position = "top";
        bar.default.start = ["launcher" "clock"];
      };
    };
    probe = package.wrap ({lib, ...}: {
      package = lib.mkForce (pkgs.writeShellScriptBin "noctalia" ''
        printf '%s\n' "$NOCTALIA_CONFIG_HOME" "$NOCTALIA_STATE_HOME" "$@"
      '');
    });
    restore = package.wrap ({
      config,
      lib,
      ...
    }: {
      configHome = lib.mkForce "\${HOME}/restored/config";
      stateHome = lib.mkForce "\${HOME}/restored/state";
      sync.files.noctaliaConfig.sources = [
        "\${HOME}/snapshot/noctalia/config.toml"
        {
          path = config.constructFiles.noctaliaConfig.path;
          format = "toml";
        }
      ];
    });
  in {
    checks.noctalia-wrapper =
      pkgs.runCommand "noctalia-wrapper-check" {
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
