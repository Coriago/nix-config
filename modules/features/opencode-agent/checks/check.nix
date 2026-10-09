{
  perSystem = {
    pkgs,
    self',
    ...
  }: {
    checks.myopencode =
      pkgs.runCommand "myopencode-smoke-test" {
        nativeBuildInputs = [pkgs.python3];
      } ''
        export HOME="$TMPDIR/home"
        export XDG_CONFIG_HOME="$HOME/.config"
        export XDG_DATA_HOME="$HOME/.local/share"
        export XDG_STATE_HOME="$HOME/.local/state"
        export XDG_CACHE_HOME="$HOME/.cache"
        unset OPENCODE_CONFIG OPENCODE_TUI_CONFIG
        mkdir -p "$HOME"
        python ${./check.py} ${self'.packages.myopencode}
        touch "$out"
      '';
  };
}
