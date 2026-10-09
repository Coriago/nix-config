# Standalone fixture only: deliberately not registered in the flake or any host.
{
  pkgs,
  wlib,
}: let
  app = wlib.evalPackage ({config, ...}: {
    inherit pkgs;
    imports = [./default.nix];
    package = pkgs.writeShellScriptBin "fixture" ''
      test "$FIXTURE_CONFIG" = "$XDG_CONFIG_HOME/fixture/custom/settings.json" || exit 1
      test -f "$FIXTURE_CONFIG" || exit 1
      printf '%s\n' "$@"
      exit 23
    '';
    envDefault.FIXTURE_CONFIG = {
      data = config.sync.files.preferences.path;
      esc-fn = wlib.escapeShellArgWithEnv;
    };
    constructFiles = {
      preferences = {
        relPath = "nested/settings.json";
        content = ''{"declared":true,"secret":"remove"}'';
      };
      other = {
        relPath = "other.toml";
        content = "enabled = true";
      };
      helper = {
        relPath = "helper.txt";
        content = "not configuration";
      };
    };
    sync.enable = true;
    sync.files = {
      helper.enable = false;
      preferences.destinationPath = "custom/settings.json";
    };
    snapshot.enable = true;
    snapshot.defaultDir = "\${HOME}/snapshots";
    snapshot.files.preferences.pruneKeyContains = ["^secret$"];
  });
  disabled = app.wrap {
    sync.enable = pkgs.lib.mkForce false;
    snapshot.enable = pkgs.lib.mkForce false;
  };
  snapshotOnly = app.wrap {sync.enable = pkgs.lib.mkForce false;};
in
  pkgs.runCommand "sync-snap-addon-check" {nativeBuildInputs = [pkgs.jq];} ''
    export HOME="$TMPDIR/home" XDG_CONFIG_HOME="$TMPDIR/config with spaces" XDG_STATE_HOME="$TMPDIR/state"
    mkdir -p "$HOME"
    test ! -e ${disabled}/bin/fixture-sync
    test ! -e ${disabled}/bin/fixture-snapshot
    test ! -e ${snapshotOnly}/bin/fixture-sync
    test -x ${snapshotOnly}/bin/fixture-snapshot
    test ! -e ${app}/share/sync-snap
    fallback_status=0
    env -u XDG_CONFIG_HOME ${app}/bin/fixture || fallback_status=$?
    test "$fallback_status" = 23
    jq -e '.declared' "$HOME/.config/fixture/custom/settings.json"
    status=0
    ${app}/bin/fixture 'argument with spaces' > args || status=$?
    test "$status" = 23
    test "$(cat args)" = 'argument with spaces'
    jq -e '.declared' "$XDG_CONFIG_HOME/fixture/custom/settings.json"
    test -f "$XDG_CONFIG_HOME/fixture/other.toml"
    test ! -e "$XDG_CONFIG_HOME/fixture/helper.txt"
    ${app}/bin/fixture-snapshot
    jq -e '.declared and (has("secret") | not)' "$HOME/snapshots/custom/settings.json"
    test -f "$HOME/snapshots/other.toml"
    # One malformed output must prevent publication of the other output too.
    printf 'enabled = false\n' > "$XDG_CONFIG_HOME/fixture/other.toml"
    printf '{invalid' > "$XDG_CONFIG_HOME/fixture/custom/settings.json"
    if ${app}/bin/fixture-sync; then exit 1; fi
    grep -q false "$XDG_CONFIG_HOME/fixture/other.toml"
    status=0
    ${app}/bin/fixture || status=$?
    test "$status" = 23
    test -s "$XDG_CONFIG_HOME/fixture/custom/.settings.json.sync-error.log"
    touch "$out"
  ''
