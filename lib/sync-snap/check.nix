# Isolated addon and manual registry checks; no host configuration is modified.
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
  guarded = app.wrap {sync.startupCondition = ''test "''${1-}" != inspect'';};
  disabled = app.wrap {
    sync.enable = pkgs.lib.mkForce false;
    snapshot.enable = pkgs.lib.mkForce false;
  };
  snapshotOnly = app.wrap {sync.enable = pkgs.lib.mkForce false;};
  merged = app.wrap {
    snapshot.sourceDir = ./checks/snapshots;
    sync.defaultDir = "\${HOME}/merged";
    constructFiles.preferences.content = pkgs.lib.mkForce ''
      {"declared":true,"nested":{"conflict":"nix"},"array":[{"new":true}]}
    '';
  };
  noMerge = merged.wrap {
    snapshot.autoMerge = false;
    snapshot.files.preferences.autoMerge = true;
    sync.defaultDir = pkgs.lib.mkForce "\${HOME}/no-merge";
  };
  selectiveMerge = merged.wrap {
    snapshot.files.preferences.autoMerge = false;
    sync.defaultDir = pkgs.lib.mkForce "\${HOME}/selective-merge";
  };
  missing = merged.wrap {snapshot.sourceDir = pkgs.lib.mkForce "${./checks/snapshots}/absent";};
  timed = app.wrap {
    sync.defaultDir = "\${HOME}/timed";
    sync.files.preferences = {
      trigger = "onDuration";
      duration = "1hr";
    };
  };
  registry =
    (pkgs.lib.evalModules {
      modules = [
        (import ./flake-module.nix {lib = pkgs.lib;}).perSystem
        {
          config._module.args = {inherit pkgs;};
          options.apps = pkgs.lib.mkOption {type = pkgs.lib.types.attrsOf pkgs.lib.types.raw;};
          options.packages = pkgs.lib.mkOption {type = pkgs.lib.types.lazyAttrsOf pkgs.lib.types.package;};
          config.packages = {
            first = app.wrap {
              snapshot.files.preferences.sources = ["\${HOME}/missing.json"];
            };
            last = app;
            disabled = disabled;
            unrelated = pkgs.hello;
          };
        }
      ];
    }).config.apps;
in
  assert !(registry ? snapshot-disabled);
  assert !(registry ? snapshot-unrelated);
  assert builtins.length missing.configuration.sync.files.preferences.sources == 1;
    pkgs.runCommand "sync-snap-addon-check" {nativeBuildInputs = [pkgs.jq];} ''
      export HOME="$TMPDIR/home" XDG_CONFIG_HOME="$TMPDIR/config with spaces" XDG_STATE_HOME="$TMPDIR/state"
      mkdir -p "$HOME"
      ${timed}/bin/fixture-sync --startup
      printf '{"declared":false}' > "$HOME/timed/custom/settings.json"
      ${timed}/bin/fixture-sync --startup
      jq -e '.declared == false' "$HOME/timed/custom/settings.json"
      test -f "$XDG_STATE_HOME/sync-snap/fixture.trigger"
      ${timed}/bin/fixture-sync
      jq -e '.declared' "$HOME/timed/custom/settings.json"
      ${merged}/bin/fixture-sync
      jq -e '.declared and .captured == 42 and .nested.saved and .nested.conflict == "nix" and .array == [{"new":true}]' "$HOME/merged/custom/settings.json"
      grep -q 'enabled = true' "$HOME/merged/other.toml"
      grep -q 'saved = true' "$HOME/merged/other.toml"
      ${noMerge}/bin/fixture-sync
      jq -e 'has("captured") | not' "$HOME/no-merge/custom/settings.json"
      ${selectiveMerge}/bin/fixture-sync
      jq -e 'has("captured") | not' "$HOME/selective-merge/custom/settings.json"
      grep -q 'saved = true' "$HOME/selective-merge/other.toml"
      # Disabling an import must not disable capture of that file.
      ${selectiveMerge}/bin/fixture-snapshot
      jq -e '.declared and .nested.conflict == "nix"' "$HOME/snapshots/custom/settings.json"
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
      # A client/inspection invocation must not reset runtime edits.
      printf '{"declared":false}' > "$XDG_CONFIG_HOME/fixture/custom/settings.json"
      status=0
      ${guarded}/bin/fixture inspect || status=$?
      test "$status" = 23
      jq -e '.declared == false' "$XDG_CONFIG_HOME/fixture/custom/settings.json"
      ${guarded}/bin/fixture-sync
      jq -e '.declared' "$XDG_CONFIG_HOME/fixture/custom/settings.json"
      ${app}/bin/fixture-snapshot
      jq -e '.declared and (has("secret") | not)' "$HOME/snapshots/custom/settings.json"
      test -f "$HOME/snapshots/other.toml"
      # Snapshot registration must export edits without first running startup sync.
      printf '{"declared":false,"secret":"remove"}' > "$XDG_CONFIG_HOME/fixture/custom/settings.json"
      ${registry.snapshot-last.program}
      jq -e '.declared == false and (has("secret") | not)' "$HOME/snapshots/custom/settings.json"
      # 'all' must report failure but still run the next registered package.
      printf '{"declared":true}' > "$XDG_CONFIG_HOME/fixture/custom/settings.json"
      if ${registry.snapshot-all.program} > registry.log 2>&1; then exit 1; fi
      grep -q 'snapshot-first: failed' registry.log
      grep -q 'snapshot-last' registry.log
      jq -e '.declared' "$HOME/snapshots/custom/settings.json"
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
