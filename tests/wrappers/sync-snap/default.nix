# A second, non-browser adapter exercises the shared module without Brave/HM.
{
  pkgs,
  wlib,
}: let
  source = pkgs.writeText "fixture.json" ''{"declared":true}'';
  app = wlib.evalPackage {
    inherit pkgs;
    imports = [../../../lib/wrappers/sync-snap.nix];
    package = pkgs.writeShellScriptBin "fixture" ''exit 23'';
    syncSnap = {
      program = "fixture";
      sync.main = {
        destination = "\${HOME}/runtime.json";
        sources = ["${source}"];
        policy = "merge";
      };
      snapshot = {
        first = {
          destination = "\${HOME}/first.json";
          sources = ["\${HOME}/runtime.json"];
        };
        second = {
          destination = "\${HOME}/second.json";
          sources = ["\${HOME}/runtime.json"];
        };
      };
    };
  };
in
  pkgs.runCommand "wrapper-sync-snap-check" {nativeBuildInputs = [pkgs.jq];} ''
    export HOME="$TMPDIR/home" XDG_STATE_HOME="$TMPDIR/state"
    mkdir -p "$HOME"
    ${app}/bin/fixture-sync
    jq -e '.declared' "$HOME/runtime.json"
    ${app}/bin/fixture-snapshot
    cmp "$HOME/first.json" "$HOME/second.json"
    if ${app}/bin/fixture-snapshot "$HOME/ambiguous.json"; then exit 1; fi
    test ! -e "$HOME/ambiguous.json"
    printf '{invalid' > "$HOME/runtime.json"
    status=0
    ${app}/bin/fixture || status=$?
    test "$status" = 23
    test -s "$HOME/.runtime.json.sync-error.log"
    touch "$out"
  ''
