# Sync/snapshot addon

This is a **helper module importing `wlib.modules.default`**. Upstream calls
modules that select an application package “wrapper modules”; this helper leaves
`package` and application-specific options to the importing wrapper. It uses no
Home Manager evaluation. Custom wrappers import `lib/sync-snap` directly; see [wrapperModules](../../wrapperModules/README.md).

## Smallest example

Inside a custom wrapper module:

```nix
{pkgs, ...}: {
  imports = [../../lib/sync-snap]; # Adjust for your module's location.
  package = pkgs.myapp; # Replace with the actual package.
  constructFiles.settings = {
    relPath = "settings.json";
    content = builtins.toJSON {theme = "dark";};
  };
  sync.enable = true;
  snapshot.enable = true;
}
```

For an executable named `myapp`, this produces:

```text
constructFiles.settings → packaged settings.json
                         ↓ sync before launch
              $XDG_CONFIG_HOME/myapp/settings.json ← app GUI writes
                         ↓ myapp-snapshot
              /home/helios/.config/nix-config/snapshot/settings.json
```

The application wrapper must tell the app to read that runtime location when it
differs from its native default. This addon cannot infer application config flags.
It neither imports snapshots back into the baseline nor changes the app's reload
behavior; wrappers can explicitly include captured files in `sources`.

## Options and generated defaults

`sync.enable` and `snapshot.enable` both default to `false`. They are independent;
a snapshot-only wrapper still gets the automatic reverse mappings.

| Option | Default |
| --- | --- |
| `sync.defaultDir` | `${XDG_CONFIG_HOME}/<binName>`; unset XDG falls back to `$HOME/.config` |
| `snapshot.defaultDir` | `/home/helios/.config/nix-config/snapshot` |
| `sync.files.<name>.sources` | Corresponding `constructFiles.<name>.path` |
| `sync.files.<name>.destinationDir` | `sync.defaultDir` |
| `sync.files.<name>.destinationPath` | Corresponding `constructFiles.<name>.relPath` |
| `sync.files.<name>.policy` | `merge` |
| `sync.files.<name>.format` | `null` (infer from destination suffix) |
| `snapshot.files.<name>.sources` | Final sync destination, including path overrides |
| `snapshot.files.<name>.destinationDir` | `snapshot.defaultDir` |
| `snapshot.files.<name>.destinationPath` | Final sync relative destination path |

Mappings are generated from `constructFiles`, then snapshot mappings from
`sync.files`. You may add entries directly. For entries with no generated mapping,
`destinationPath` defaults to the entry name and `sources` defaults to `[]`.
Automatic values use `mkDefault`, so normal assignments override them.

Both kinds of entry also have `enable` (true), `format` (null), and `directory`
(false). Disabling a sync file disables its generated snapshot by default; either
can be overridden independently. `sync.enable = false` does not disable snapshots.
Snapshot format/directory defaults follow the sync entry.

Both kinds expose a read-only `path`, computed from `destinationDir` and
`destinationPath`. Application environment variables can refer to this path;
HOME/XDG placeholders require runtime expansion (for example using
`wlib.escapeShellArgWithEnv`). The addon supplies the standard
`XDG_CONFIG_HOME` fallback through `envDefault` and orders it before application
environment values. Applications do not need their own fallback configuration.

`esc-fn` controls shell quoting: the upstream default keeps `$` expressions
literal, while `wlib.escapeShellArgWithEnv` expands HOME/XDG at launch and quotes
paths containing spaces. Fixed store paths do not need expansion. Keep this
setting on runtime path values rather than changing escaping globally.

Sync entries have `trigger` (`on-start`, `on-init`, `never`). Policies are `seed`,
`fill-missing`, `merge`, and `replace`. Raw files/directories require `seed` or
`replace`; the requested `merge` default is for structured JSON/TOML.
Snapshot entries have `pruneKeyContains`, `pruneValueContains`, and `transform`
lists, matching the Rust CLI's regex pruning and ordered jq filters.

Sources accept path strings, Nix paths, or
`{path = "..."; format = "json"; optional = true;}`. Source format defaults to
null and optional defaults to false. Destination format does not override source
format. Specify source format for extensionless files such as `Preferences`.
Destination paths must be relative without `.` or `..` components.

```nix
sync.files.settings = {
  destinationPath = "profiles/default.json";
  policy = "fill-missing";
};
snapshot.defaultDir = "/home/helios/.config/nix-config/snapshot/myapp";
snapshot.files.settings.pruneKeyContains = ["^session$"];
# A constructFiles helper executable is not runtime configuration:
sync.files.helper.enable = false;
```

Every `constructFiles` entry is included unless disabled. The `_syncSnap` prefix
is reserved for the addon's commands and excluded from discovery. No app-name
subdirectory is added to snapshots automatically: choose an app-specific
`snapshot.defaultDir` to avoid collisions between apps with identical filenames.

## Execution: arguments, not a manifest

The helper converts file declarations into safely quoted CLI arguments:

```sh
sync-snap sync --program myapp \
  --destination '${XDG_CONFIG_HOME}/myapp/settings.json' \
  --source /nix/store/…/settings.json --policy merge --trigger on-start
```

Every `--destination` starts another entry. All sync files run in **one process**
so the engine can validate/stage all outputs before publishing any. HOME/XDG path
expansion happens in Rust; ordinary file contents never become command arguments.
There is no generated manifest, jq argument adapter, or runtime temporary file.
Very large numbers of file declarations are subject to the OS argument-size limit.

The supported `runShell` hook adds `sync --startup` before application execution,
logging failure and continuing to launch. It composes with application flags and
`argv0type`; it does not replace the launcher. This initial addon requires the
upstream default `wrapperImplementation = "nix"` when sync is enabled. Mirrored
wrapper variants inherit the hook; variants overriding hooks must retain it.

When enabled, `bin/<binName>-sync` and `bin/<binName>-snapshot` are generated as
small `exec` shims. They accept extra Rust CLI flags (for example `--state-dir`).
Set output paths in
`snapshot.files` or `snapshot.defaultDir`. Manual sync ignores startup triggers.
An empty enabled file set is a no-op. The program/lock identity is `binName`.

File locks protect sync-snap operations,
not writes made by an already-running app.

See [sync-snap's documentation](../../packages/sync-snap/README.md) for policies,
arrays, sidecar errors, locking, and publication limits.

## Standalone check

`check.nix` is a disposable fake-app check, deliberately not registered in the
flake. Evaluate it with the repository's pinned `pkgs` and `wlib`, then build the
returned derivation. It checks generated paths, overrides, reverse snapshots,
independent enable switches, pruning, multi-file failure behavior, arguments,
and launch after sync failure. It does not run a real application or a GUI.
