# sync-snap

A shared Rust CLI for writable, partially declarative application configuration:

- `sync` materializes a packaged baseline into runtime files.
- `snapshot` exports runtime preferences into a repository baseline.
- `run` attempts startup sync, then executes the application even if sync fails.

Both operations are optional for each application. This package implements the
[agreed design](../../docs/proposal-portable-mutability.md); it does not enable any
host features or automatically integrate existing wrappers.

## Build and invoke

```sh
nix build .#sync-snap
./result/bin/sync-snap --help

sync-snap sync --config config.toml --program myapp
sync-snap sync --config config.toml --all --startup
sync-snap snapshot --config config.toml --program myapp
sync-snap snapshot --config config.toml --all
sync-snap run --config config.toml --program myapp -- /path/to/myapp --app-option
```

Before newly created files are tracked by Git, use `nix build path:.#sync-snap`.
The flake exposes `packages.<system>.sync-snap` and `checks.<system>.sync-snap`.
The derivation runs the Rust tests and includes jq in the executable's runtime PATH.

Select exactly one of `--program NAME` and `--all`. Standalone commands exit
nonzero if any selected operation fails; `--all` continues with other programs.
`run` releases synchronization locks and uses `exec`, preserving application
arguments, signals, and exit status. Even a missing or malformed manifest does
not prevent execution. An invalid CLI invocation or a missing application
executable still fails normally.

## Direct arguments (no manifest required)

```sh
sync-snap sync --program myapp \
  --destination '${XDG_CONFIG_HOME}/myapp/settings.json' \
  --source /path/to/baseline.json --policy merge \
  --destination '${XDG_CONFIG_HOME}/myapp/other.toml' \
  --source /path/to/other.toml --policy fill-missing

sync-snap snapshot --program myapp \
  --destination /path/to/snapshot.json \
  --source '${XDG_CONFIG_HOME}/myapp/settings.json' \
  --prune-key-contains '^session$'
```

Each `--destination` begins a file entry. Following `--source` arguments append
ordered inputs to that entry. `--source-format json|toml|raw` and
`--source-optional true|false` modify the most recent source. Entry options are
`--format`, `--policy`, `--trigger`, `--directory true|false`, and repeatable
`--prune-key-contains`, `--prune-value-contains`, `--transform` filters. Scalar
options use their last value within the entry. Defaults match the manifest schema
below (CLI policy defaults to `seed`; the Nix addon explicitly chooses `merge`).
Put file options after their destination and source modifiers after their source.

`--program` supplies the lock/cache identity. Relative paths resolve against the
working directory. Literal HOME/XDG placeholders are expanded by Rust; shell
variables can also be expanded by the caller with normal shell quoting. No extra
configuration environment variables are required. `run` accepts the same file
arguments followed by `-- APP ARGS...` and still launches after sync failures.
Multiple destinations retain program-wide sync validation and locking in one
invocation. Direct options cannot be combined with `--config`; `--all` requires
that legacy manifest interface. OS command-line size limits apply to declarations,
not config contents, which are read from files.

The standalone [Nix addon](../../lib/sync-snap/README.md) generates this interface
from wrapper `constructFiles` and `sync.files`/`snapshot.files` declarations.

## Manifest

Version 1 accepts TOML (`.toml`) or JSON. Unknown fields are errors. This example
uses TOML; relative paths are relative to the resolved manifest's directory.

```toml
version = 1

[[programs.myapp.sync]]
destination = "${XDG_CONFIG_HOME}/myapp/settings.json"
sources = [
  { path = "/nix/store/…-baseline/settings.toml", format = "toml" },
  "/nix/store/…-personal/settings.json",
]
policy = "merge"
trigger = "on-start"
format = "json"

[[programs.myapp.snapshot]]
destination = "snapshots/myapp.json"
sources = [
  "/nix/store/…-baseline/settings.json",
  { path = "${XDG_CONFIG_HOME}/myapp/settings.json", optional = true },
]
prune_key_contains = ['(?i)password', '^machine\.']
prune_value_contains = ['(?i)hdmi']
transform = ['del(.meta.login)']
```

Replace the illustrative store paths with generated baseline paths. A wrapper
can generate a manifest with `pkgs.writeText` and `builtins.toJSON`, then launch
`${syncSnap}/bin/sync-snap run --config ${manifest} --program myapp -- ${app}/bin/myapp "$@"`.
Use the unwrapped application executable to avoid recursion. The app itself must
be told to use the chosen runtime location when that differs from its defaults.
Snapshots should target a writable checkout, separate from handwritten settings;
snapshotting does not commit changes, rebuild packages, or reload applications.

| Field | Default / behavior |
| --- | --- |
| `version` | Required; must be `1` |
| `programs.NAME.sync` / `.snapshot` | Ordered entry lists; default empty |
| `destination` | Required output file or directory path |
| `sources` | Required ordered list of path strings or source objects |
| Source `path` | Required in a source object |
| Source `format` | Infer independently from the source suffix |
| Source `optional` | `false`; only absence is optional, not invalid contents |
| `format` | Destination format: `json`, `toml`, or `raw`; inferred if absent |
| `policy` | `seed`; used by sync |
| `trigger` | `on-start`; used by automatic sync |
| `directory` | `false`; raw directory overlay when enabled |
| `prune_key_contains` | Empty list of regexes; snapshot only |
| `prune_value_contains` | Empty list of regexes; snapshot only |
| `transform` | Empty list of ordered jq filters; snapshot only |

Only `.json` and `.toml` infer structured formats; other suffixes infer `raw`.
Explicitly set source formats for extensionless Nix store files. Sync rejects
pruning/transformation options when processing an entry. Snapshot ignores sync
policy/trigger fields, except for the restrictions on raw directory entries.

Paths support `~/` and `${HOME}`, `${XDG_CONFIG_HOME}`, `${XDG_STATE_HOME}`,
`${XDG_CACHE_HOME}`, and `${XDG_DATA_HOME}`. Unset or relative XDG variables use
their standard HOME-based defaults. No shell expressions, bare `$VAR`, globbing,
or `..` components are supported. Parent directory symlinks are resolved;
destination file symlinks and directory-root symlinks are rejected. Source
symlinks are supported, with cycle detection when traversing directories.

## Sync policies and triggers

Sources combine first to last: later values win, objects merge recursively, and
arrays are whole values. Then the policy applies to the destination:

| Policy | Existing destination |
| --- | --- |
| `seed` | Keep unchanged; do not read unused sources |
| `fill-missing` | Add missing object keys recursively; preserve existing values |
| `merge` | Recursively merge objects; source wins on other conflicts |
| `replace` | Replace the complete file; old contents need not parse |

All policies initialize missing destinations. Empty arrays, `false`, zero, and
empty strings are existing values. Type conflicts follow the policy too.
There is no array appending, index matching, inferred identity, or deletion marker.
`merge` preserves destination-only keys; use `replace` to remove them.

`run` and `sync --startup` honor triggers:

- `on-start`: process on every launch, subject to policy and hash skipping.
- `on-init`: process only when the individual destination is absent.
- `never`: skip automatic sync.

Manual `sync` ignores triggers but retains each entry's policy. In particular,
manual `seed` still preserves an existing file. An `on-start` merge intentionally
reapplies declared values after GUI edits. `fill-missing` can restore a key removed
at runtime. There is no three-way merge against the previous baseline.

Every participating output for one program is read, validated, serialized, and
staged before publishing any. A preparation failure leaves all its configuration
files unchanged. Successful files are individually replaced atomically. Publication
across multiple files is **not** a filesystem transaction: a later rename/fsync
failure can leave earlier outputs updated. Further publication stops; there is no
rollback. Directories and diagnostic/state files may still be created on failure.

## Snapshot filtering

Each destination is processed and published independently, in manifest order.
Failures preserve that file and do not stop later entries. All sources for an
individual destination must succeed before it can be published. Live files are
read as encountered; there is no simultaneous snapshot of a running application.

The pipeline combines sources, applies pruning, runs jq filters, then validates
and serializes the result. Regex matching uses Rust's `regex` syntax: unanchored
by default, with inline flags such as `(?i)`, but no look-around or backreferences.

- Key patterns match full paths, e.g. `general.user.0.password`. Literal dots and
  backslashes in keys are escaped with backslashes. Array indices are decimal.
  Object keys consisting of digits can look like array indices in a path.
- Value patterns match strings directly and other scalars by their JSON text.
  They do not inspect serialized container text.
- Pruning any part of an array element drops the entire containing array. This
  propagates through enclosing arrays. A pruned root array becomes `[]`.
  Empty objects outside arrays remain valid results.
- jq filters intentionally allow finer edits, including array element removal.
  Each must produce exactly one object or array. Zero/multiple outputs, scalar
  outputs, process failures, and unrepresentable output values are errors.

Filters are trusted configuration, run without a shell. jq is started only when
filters are present. `--jq PATH` overrides its executable. jq stderr is suppressed
to avoid leaking preference values; diagnostics identify the failing filter index.
There is currently no transform timeout or keep/select-list feature. Inspect
snapshots before committing: pruning does not automatically discover all secrets
or validate application-specific references and schemas.

## Formats and directory copying

Structured documents must have an object or array root. JSON/TOML conversion
preserves their common data model, not comments, original whitespace, or key order.
TOML output requires an object root and rejects null and integers outside signed
64-bit range. TOML datetimes and non-finite floats are rejected in structured mode.
TOML uses finite 64-bit floats; converting JSON decimal numbers can lose precision.
Use raw copying when exact bytes or unsupported format features matter.

Raw files require exactly one declared source, with no pruning or transforms.
Raw sync supports `seed` and `replace`; it does not execute Lua or other scripts.

```toml
[[programs.editor.sync]]
destination = "${XDG_CONFIG_HOME}/editor/lua"
sources = ["/nix/store/…-lua-baseline"]
directory = true
format = "raw"
policy = "seed"
trigger = "on-start"
```

Directory entries overlay regular source files in sorted traversal order using
raw copying. They support one source, `seed`/`replace`, and no structured formats
or filtering. Runtime-only files and files removed from the source are retained;
empty source directories are not recreated. Source/destination trees must not
overlap. Snapshot directory entries use the same traversal and copy each file.

## Failures, locking, and cache

A missing required source fails; a missing explicitly optional source is skipped.
Malformed existing optional files still fail. An empty source list fails when
sources are needed. If all optional sources are absent, leave the destination
untouched. A `seed` no-op or skipped trigger need not validate unused inputs.

Failures write `.<filename>.sync-error.log` or
`.<filename>.snapshot-error.log` beside the destination, replacing the previous
failure. A successful operation for that file clears its sidecar. Directory
expansion errors use a sidecar beside the directory root. Errors also go to
stderr; if the destination directory cannot be created/written, stderr reports
the logging failure. Manifest-level failures may leave only stderr diagnostics
because destinations could not be discovered. Config parser diagnostics omit
source text and values; paths and stages remain visible. Manifest errors may
include manifest text, so do not embed secrets in the manifest itself.

New directories are created with mode 0700 and new files with mode 0600. Existing
destination permission bits are preserved. Temporary files are created beside
their destination, flushed before rename, and the parent directory is flushed
afterward. Identical output bytes are not rewritten. Destination hashes are
rechecked before publication to catch intervening edits, but this cannot eliminate
all races with an already-running application's writes.

Both operations acquire a per-program OS file lock. Lock/cache files live in
`${XDG_STATE_HOME}/sync-snap`; `--state-dir PATH` overrides that location. All
invocations for a program must share its name and state directory to coordinate.
Do not assign different program names to writers of the same destination. The
default lock wait is 2000 ms (`--lock-timeout-ms` changes it); timeout is a sync
failure, so `run` logs it and launches anyway. Locks are released on process exit;
the stable lock files remain and should not be deleted while tools are running.
Locks protect these tools, not application writes or the application's lifetime.

Successful sync fingerprints include tool/cache version, entry settings, resolved
paths, source presence/contents, and the resulting destination bytes. A cache hit
skips structured parsing, merging, staging, and rewriting. It still reads/hashes
input and destination bytes: startup cost remains proportional to file size.
GUI edits invalidate the cache. Missing/corrupt caches are safe misses; unchanged
cache contents are not rewritten. Snapshot has no hash cache.

Sync preparation retains parsed data and staged outputs as needed; files are read
in full rather than streamed. Lock waiting is bounded, but general file I/O and
jq execution have no overall deadline. A slow sync can delay launch; a failed
sync does not cancel launch.

## Development and validation

```sh
cargo fmt --check
cargo clippy --all-targets --locked -- -D warnings
cargo test --locked
```

Run these from this directory with Rust/Cargo and jq available. Integration tests
use temporary files and real subprocesses to cover policy/type/array semantics,
cache invalidation, optional inputs, pruning/transforms, conversion failures,
symlink rejection, permissions, program-wide validation, concurrent launches, and
application execution despite sync/lock/manifest failures. These are CLI and
filesystem tests; each future wrapper still needs its own application-specific
configuration and GUI validation.
