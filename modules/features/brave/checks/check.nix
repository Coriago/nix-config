{
  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: {
    # Check the assembled feature; generic browser behavior has its own fixtures.
    checks.mybrave =
      pkgs.runCommand "mybrave-launch-check" {
        nativeBuildInputs = [(pkgs.python3.withPackages (p: [p.websocket-client]))];
        PYTHONPATH = "${../../../../wrapperModules/brave/checks}";
      } ''
        export HOME="$TMPDIR/home"
        export XDG_CONFIG_HOME="$HOME/config" XDG_CACHE_HOME="$HOME/cache"
        export XDG_DATA_HOME="$HOME/data" XDG_STATE_HOME="$HOME/state"
        mkdir -p "$HOME"
        python3 ${./launch.py} ${lib.getExe self'.packages.mybrave} \
          ${lib.escapeShellArg self'.packages.mybrave.configuration.userDataDir}
        touch "$out"
      '';
  };
}
