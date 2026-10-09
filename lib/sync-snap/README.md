# Sync/snapshot addon

This is a **helper module importing `wlib.modules.default`**. Upstream calls
modules that select an application package “wrapper modules”; this helper leaves
`package` and application-specific options to the importing wrapper. It uses no
Home Manager evaluation. Custom wrappers import `locallib.sync-snap`; see
[wrapperModules](../../wrapperModules/README.md) for the shared flake-parts argument.

## Smallest example

Capture `locallib` in the outer flake-parts module:

```nix
{locallib, ...}: {
  flake.wrappers.myapp = {pkgs, ...}: {
    imports = [locallib.sync-snap];
    package = pkgs.myapp; # Replace with the actual package.
    constructFiles.settings = {
      relPath = "settings.json";
      content = builtins.toJSON {theme = "dark";};
    };
    sync.enable = true;
    snapshot.enable = true;
  };
}
```

For an executable named `myapp`, this produces:

```text
constructFiles.settings → packaged settings.json
                         ↓ sync before launch
              $XDG_CONFIG_HOME/myapp/settings.json ← app GUI writes
                         ↓ myapp-snapshot
              /home/helios/.config/nix-config/snapshot/myapp/settings.json
```

The application wrapper must tell the app to read that runtime location when it
differs from its native default. This addon cannot infer application config flags.
Existing structured snapshots are embedded as baseline inputs by default; the
application's reload behavior remains application-specific.

## Options and generated defaults

`sync.enable` and `snapshot.enable` both default to `false`. They are independent;
a snapshot-only wrapper still gets the automatic reverse mappings.

| Option | Default |
| --- | --- |
| `sync.defaultDir` | `${XDG_CONFIG_HOME}/<binName>`; unset XDG falls back to `$HOME/.config` |
| `snapshot.name` | Package attribute name supplied by flake integration; standalone wrappers fall back to `binName` |
| `snapshot.defaultDir` | `/home/helios/.config/nix-config/snapshot/<snapshot.name>` |
| `snapshot.autoMerge` | `true` |
| `snapshot.files.<name>.autoMerge` | `true`; effective only when global `snapshot.autoMerge` is also true |
| `snapshot.sourceDir` | `snapshot/<snapshot.name>` inside the evaluated flake source |
| `sync.files.<name>.sources` | Existing structured snapshot, then corresponding `constructFiles.<name>.path` |
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
is reserved for the addon's commands and excluded from discovery. Each app gets
its own snapshot directory by default. File-relative paths remain beneath it,
for example `snapshot/myapp/nested/settings.json`. Explicit `snapshot.defaultDir`
and per-file destination overrides remain supported.

## Automatic registration, manual execution

Enable snapshot export inside the configured package in its feature:

```nix
snapshot.enable = true;
```

`snapshot.enable` defaults to `false`. The imported `flake-module.nix` discovers
enabled packages in `perSystem.packages` and exposes conventional Nix apps:

```sh
nix run .#snapshot-myopencode
nix run .#snapshot-all
```

Use `path:.#...` while testing new untracked files. There is no separate
registration list or export variant. The feature's enabled package supplies the
generated snapshot executable directly, without starting the application,
running sync, or entering directory mappings. Snapshot sources already point
at the actual writable files.

The default export directory for this registration is
`/home/helios/.config/nix-config/snapshot/myopencode`. Flake integration supplies
the actual package attribute name to the addon, even if its binary is named
`opencode`. Explicit destination settings still take precedence. Package names
use letters, digits, hyphens and underscores; `all` is reserved.

`snapshot-all` processes registered names alphabetically, continues on failure,
and exits nonzero if any snapshot fails. With no registrations it succeeds
without doing anything. CLI arguments are forwarded to each command, such as
`--lock-timeout-ms 5000`. No application-close hooks or Git commits are added.
Existing Rust validation, pruning,
sidecar logging and unchanged-output skipping apply.

## Automatically importing snapshots

`snapshot.autoMerge = true` reads existing JSON/TOML snapshots during Nix
evaluation, validates their syntax and object/array root, and embeds their bytes
in the package closure. Each generated sync file looks up the corresponding
snapshot entry's `destinationPath` beneath `snapshot.sourceDir`. Missing files
are ignored; malformed files fail evaluation with the source path in the error.

The source order is **snapshot, then declared config**. Sync-snap's existing
merge combines them when materializing the writable runtime file: declared
values win conflicts, snapshot-only keys survive, nested objects merge, and
arrays are replaced whole. The wrapper's `settings` options and original
`constructFiles` contents still represent the hand-declared layer. Runtime sync
policies such as `seed` and `fill-missing` continue to apply afterwards.

Importing is independent of `snapshot.enable`, so a package can use a saved
baseline without exposing an export command. Set `snapshot.autoMerge = false`
to disable all automatic imports, even if an individual entry explicitly enables
them. For a per-file exception, use:

```nix
snapshot.files.opencodeTuiConfig.autoMerge = false;
```

This still exports that file when snapshotting; it only disables importing its
saved baseline. Other files continue to auto-merge. Disabled snapshot entries, raw files and raw
directories are not auto-merged. Explicit `sync.files.<name>.sources` replaces
the generated source list, including its automatic snapshot input.

`sourceDir` is a build input; `defaultDir` is a writable export destination. Their
defaults refer to the same repository directory before and after Nix copies the
flake into the store. This avoids impure reads of `/home/helios` during builds.
If you export elsewhere, set `snapshot.sourceDir` to the matching Nix-accessible
source directory too. Per-file destination directories do not change sourceDir.
Files must be included in the flake source: Git flakes omit untracked snapshots;
`path:.` includes them while testing. A new snapshot affects the next build/run,
not an already-built wrapper, and never becomes a runtime dependency on the repo.

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

## Check

Run `nix build path:.#checks.x86_64-linux.sync-snap-addon`. The adjacent
`check.nix` uses a disposable fake app. It checks generated paths, overrides, reverse snapshots,
independent enable switches, pruning, multi-file failure behavior, arguments,
and launch after sync failure. Registry checks verify disabled/unrelated packages
are excluded, runtime edits are captured without startup sync, and `snapshot-all`
continues after failure. AutoMerge checks cover missing files, disabling imports,
JSON/TOML merging, nested keys, and whole-array replacement. It does
not run a real application or a GUI.
