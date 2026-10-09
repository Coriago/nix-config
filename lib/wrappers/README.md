# Shared wrapper adapters

Keep personal configuration under `modules/features/<app>/config/`, reusable
application adapters here, and checks under `tests/wrappers/`. Feature modules
handle host integration; they should not contain test fixtures or helper scripts.
The flake exports these adapters as `lib.wrapperModules`.

## Sync and snapshot

Import `lib.wrapperModules.sync-snap` into a `nix-wrapper-modules` wrapper. Declare
named entries using the existing [sync-snap manifest schema](../../packages/sync-snap/README.md):

```nix
# Inside a flake-parts module:
{config, ...}: {
  flake.wrappers.myapp = {pkgs, ...}: {
    imports = [config.flake.lib.wrapperModules.sync-snap];
    package = pkgs.myapp;
    syncSnap = {
      program = "myapp";
      sync.preferences = {
        sources = ["${./config/settings.json}"];
        destination = "\${XDG_CONFIG_HOME}/myapp/settings.json";
        policy = "merge";
        trigger = "on-start";
      };
      snapshot.preferences = {
        sources = ["\${XDG_CONFIG_HOME}/myapp/settings.json"];
        destination = ""; # Require an explicit output when capturing.
        prune_key_contains = ["^session$"];
      };
    };
  };
}
```

`pkgs.myapp` is a placeholder for your application's package. Sync-snap supplies
XDG defaults when those variables are unset. Nix source paths must be interpolated
into strings so their store dependencies are retained. Runtime paths should be
absolute or use the environment expansion supported by sync-snap.

This generates `<binName>-sync` and `<binName>-snapshot [OUTPUT]`, and syncs before
launching the application. `commandPrefix` overrides the command names. Automatic
sync failure leaves the app launch enabled; manual commands report failure.
Merging, validation, per-program locking, hash caching, pruning, and sidecar logs
remain in Rust. The shared shell adapter only resolves arguments and wires the
lifecycle; apps do not need their own scripts.

| Option under `syncSnap` | Purpose |
| --- | --- |
| `program` | Stable program/lock identity |
| `sync.<name>` / `snapshot.<name>` | Existing manifest entries, emitted in name order |
| `enableSync` / `enableSnapshot` | Independent switches, both default true |
| `snapshotFile` | Optional default output override for a single snapshot entry |
| `commandPrefix` | Generated command prefix; defaults to wrapper `binName` |
| `skipSyncIfExists` | Optional app-owned marker; skips automatic sync and refuses manual sync |
| `variables` | Optional runtime bindings for apps with selectable profile/config paths |

Multiple snapshot entries should each declare their destination. A positional
output or `snapshotFile` override requires exactly one entry. Sources within each
entry keep list order; use entry names such as `10-settings` when ordering entries
matters. Manual sync ignores startup triggers, retaining each entry's policy.

## App-specific path selection

Most applications need no bindings. For apps with profile flags, define one:

```nix
syncSnap.variables.root = {
  value = "\${XDG_CONFIG_HOME:-$HOME/.config}/myapp";
  flag = "--config-dir";
  kind = "path";
};
syncSnap.sync.preferences.destination = "@root@/settings.json";
syncSnap.skipSyncIfExists = "@root@/running.lock";
```

Bindings expand `@name@` in manifest strings and the marker path. Their defaults
support runtime environment expansion. Flags accept both syntaxes, last value
wins, and the original app arguments are preserved. `kind` can be `string`, `path`
(normalized absolute path), or `segment` (one directory name). The app adapter must
also pass matching defaults to the application; bindings alone do not set app flags.
Reserve `@name@` placeholders for bindings, including inside transform strings.

An adapter that needs an extra launch environment can override `argv0type` and
invoke `config.passthru.syncSnap.runner` with `launch ENVIRONMENT APP ARGS...`.
The [Brave adapter](brave.nix) demonstrates profile flags, HM output extraction,
and a private policy environment. Its personal choices remain in
[Brave's config](../../modules/features/brave/config/default.nix).

Registration is in `modules/wrapper-modules.nix`; checks are registered separately
in `modules/wrapper-checks.nix`. The [non-browser fixture](../../tests/wrappers/sync-snap/default.nix)
verifies the common module independently, including multiple snapshot outputs
and launching despite invalid runtime configuration.
