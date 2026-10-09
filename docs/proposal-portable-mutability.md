# Portable applications with partially declarative configuration

## Goal

Keep enough configuration declarative to automate a useful personal setup while
allowing normal runtime editing, including application GUI settings. Fully
declarative configuration can be awkward to interact with; entirely unmanaged
configuration loses that automation. Portability is an additional choice.

This document records the agreed design. The first implementation is
[`packages/sync-snap`](../packages/sync-snap/README.md), a shared Rust codebase
with `sync`, `snapshot`, and `run` CLI subcommands. Its README specifies the actual
manifest format; the YAML examples here illustrate the design.

## Responsibilities

- **Wrapper:** package the application, dependencies, and configuration baseline.
- **Syncer:** materialize selected packaged configuration in writable runtime files.
- **Snapshotter:** extract and prune runtime configuration into a repository baseline.
- **liveConfig:** optionally use checkout files directly during local development.

The syncer and snapshotter are independently optional. Native baseline/override
support does not prevent an application from opting into syncing when the packaged
baseline should take priority. Home Manager or wrapper modules can generate the
baseline; runtime ownership is a separate decision.

```text
repository snapshot + handwritten/Nix settings
    → packaged baseline
    → optional syncer → writable runtime config → application edits
                              ↓
                       optional snapshotter
                              ↓
                       repository snapshot
```

Keep generated snapshots separate from handwritten configuration. Snapshotting
neither commits changes nor rebuilds the package automatically. Each application
must declare how its snapshot feeds back into the baseline and which explicit
Nix settings take precedence over it.

A portable wrapper should normally use a distinct runtime location. Using the
ordinary application profile intentionally shares that machine's preferences and
state. Portability, runtime mutability, and configuration ownership are independent
choices; none is determined solely by using Home Manager or a wrapper.

## Syncer

Role: copy or merge packaged configuration into a runtime location.

### Policies and triggers

Each destination has a named policy, independently paired with a trigger:

| Policy | Missing destination | Existing destination |
| --- | --- | --- |
| `seed` | Create from combined sources | Leave untouched |
| `fill-missing` | Create from combined sources | Recursively add missing object keys; preserve existing values |
| `merge` | Create from combined sources | Recursively merge objects; source values win for supplied keys; preserve other destination keys |
| `replace` | Create from combined sources | Replace the entire file |

Triggers retain the names `on-init`, `on-start`, and `never`. `never` disables
automatic invocation; manual invocation remains possible. `on-init` means that
the individual destination file does not exist, not that the package was rebuilt.
`on-start + seed` also initializes missing files without a separate marker.

`on-start + merge` deliberately reapplies packaged values. Unsnapshotted runtime
changes to those keys are lost at the next synchronization. `seed` preserves them,
but does not propagate later baseline changes. `fill-missing` can restore a key
that was deliberately deleted at runtime. These are explicit ownership choices.

Missing keys are not deletion instructions: `merge` preserves runtime-only keys,
whereas `replace` removes them by replacing the document. Remembering a previous
baseline to distinguish user edits/deletions from changed defaults is outside the
initial scope.

### Sources and formats

- Both tools process sources first to last. Later sources win on conflicts.
- Combine sources before applying the sync policy to the destination.
- Structured objects merge recursively. Arrays are whole values, as specified below.
- Infer each source's format from its suffix, with an explicit per-source override.
  Infer the destination format independently, also allowing an override. TOML input
  converted to JSON output must still be parsed as TOML.
- Raw content is copied without parsing from exactly one source, using `seed` or
  `replace`. Directory copying overlays individual raw files and never removes
  runtime-only files or files that disappeared from the source.
- There is no sorting option or general promise to preserve comments/whitespace.

Illustrative configuration; this is not an existing Nix API:

```yaml
sync_store_config:
  "${XDG_CONFIG_HOME}/myapp/config.toml":
    trigger: on-start
    policy: merge
    store_paths:
      - /nix/store/.../defaults.toml
      - /nix/store/.../personal.toml

  "${XDG_CONFIG_HOME}/myapp/extras":
    trigger: on-start
    policy: replace
    store_paths:
      - path: /nix/store/.../extra-settings
        format: toml
    destination_format: json
```

Define runtime path expansion explicitly, including the standard fallback for an
unset `XDG_CONFIG_HOME`. These descriptive paths do not authorize arbitrary shell
expression evaluation.

## Snapshotter

Role: combine selected runtime/baseline inputs, prune unwanted values, and save a
snapshot beside the declarative configuration.

The same export operation should be callable manually for one registered program,
for all programs, or through an application event/service hook. Triggering is
independent of extraction; a continuously running service is not required.

Processing order:

1. Read and combine sources in order, with later sources winning.
2. Apply key-path and value pruning.
3. Apply ordered jq transformations.
4. Validate and serialize the result before publishing the snapshot.

`prune_key_contains` matches regexes against full key paths, such as
`general.user.0.password`. Literal dots and backslashes in keys are escaped with
backslashes; array indices use decimal numbers. `prune_value_contains` matches
strings directly and other scalars in their JSON representation. It does not
match containers' serialized text. Regexes are case-sensitive unless the pattern
explicitly selects case-insensitive matching.

`transform` is a list of jq filters. Each receives the complete document and must
return exactly one complete document suitable for the destination format.
`.meta.login` selects a value; `del(.meta.login)` removes that field. See the
[jq manual](https://jqlang.org/manual/#del).

A keep/select list is deferred. Initially, inspect produced snapshots and refine
pruning as desired preferences and unwanted data become clear. Regex pruning is
not a guarantee of automatically identifying every secret or machine-specific value.

```yaml
snapshot_config:
  "/home/user/.config/nix-config/snapshot/app/config.toml":
    config_paths:
      - /nix/store/.../config.toml
      - "${XDG_CONFIG_HOME}/myapp/config.toml"
    prune_key_contains:
      - "password"
      - "duck[1-9]+"
    prune_value_contains:
      - "hdmi"
    transform:
      - 'del(.meta.login)'
      - '.servers |= map(select(.role != "backend"))'
```

Runtime values override the store baseline in this example. The second transform
explicitly removes matching objects from that particular list; it is not the
implicit array-pruning policy. The example assumes `servers` is an array.

## Error behavior

If any participating source is invalid, fail the operation. Do not publish a
partial result because other sources succeeded. Leave the destination unchanged,
or absent if it did not exist. Parsing a required destination, transforming data,
and serializing the result must also succeed before replacing the destination.

An existing destination under `replace` need not parse: it is not an input.
An existing destination under `seed` is a no-op; sources unused by that no-op
need not be read. An existing destination under `merge` or `fill-missing` must parse.

Write an error log file in the destination directory. Identify the operation,
destination, failing source/stage, and useful diagnostics without dumping config
contents or sensitive values. Also report failure to the caller.

Use `.<filename>.sync-error.log` or `.<filename>.snapshot-error.log` beside the
destination. Replace the sidecar with the latest failure and clear it after a
successful operation for that destination. If the directory is absent, it may be
created. If it is unwritable, report both the operation and logging failures to
stderr/service logs. A malformed manifest may prevent discovery of destinations;
in that case stderr is the available diagnostic channel.

The syncer runs before application startup, but failure must not prevent the app
from launching. `sync-snap run` attempts startup synchronization, logs failures,
releases locks, then executes the application regardless of sync success. Standalone
`sync` and `snapshot` commands return failure status for diagnostic/automation use.

## Application choices

### Neovim and liveConfig

Neovim could use the syncer to create a writable runtime Lua tree, allowing runtime
edits. A checkout link is more useful for the preferred workflow of editing Lua
in the repository.

Use liveConfig when configuration lives outside Nix expressions and either needs
no evaluated Nix values or can receive them through a separate generated file or
injection mechanism. Select checkout links for local development and packaged
sources for portable use elsewhere.

### Noctalia and baseline priority

Native baseline/override layers do not make syncing unnecessary. Sometimes the
packaged baseline should take priority over current GUI overrides. Snapshotting
provides the choice to capture those overrides first or discard them deliberately.

The adapter must target the files that actually control precedence. Copying the
baseline alone will not reset a higher-priority override file. A reset can explicitly
replace that preferences file with an appropriate empty/initial document, preserving
unrelated application state. A failed baseline sync must not silently trigger a
separate override reset; their transaction relationship needs a defined policy.

## Array and error semantics

### Arrays

- **Whole-value handling:** `fill-missing` preserves an existing array,
  including an empty one. `merge` replaces it when supplied by the source.
  When combining sources, the later array wins.
- **Object identity:** do not merge by array index or assume whole-object equality
  identifies an item. Changing `{id: "work", size: 12}` to size `14` need not create
  a new logical item. Appending unique objects would often create duplicates here.
- **Future keyed merging:** require an explicit identity field per config path and
  rules for duplicate IDs, ordering, and removal. Do not infer identity generically.
- **Automatic pruning:** drop the entire containing array when pruning removes or
  partially changes an element. This propagates through enclosing arrays. It avoids
  retaining partial objects or silently shifting positions, but can discard useful
  preferences. Explicit jq transforms can express an intentional narrower edit.
  If the root itself is an array and must be dropped, the result is an empty array.
- **References:** removing an object can leave references elsewhere in the document.
  Structural filtering alone cannot guarantee application-level validity.

### Errors and publication

- **Sync transaction scope:** read, validate, serialize, and stage every selected
  output for one program before publishing any. Invalid inputs or staging failures
  leave all its configuration destinations unchanged. Creating directories, temporary
  files, logs, and lock files does not count as configuration publication. Each file
  is atomically replaced, but several replacements are not a filesystem transaction:
  a later publication failure can leave earlier files updated. Stop publishing further
  files and report the failure; do not claim rollback.
- **Snapshot scope:** process each destination as it is reached. Do not coordinate
  a simultaneous view of application files for now. A failed snapshot file keeps its
  previous contents while other files continue. A single destination with several
  sources still requires all its participating sources to be valid.
- **Missing inputs:** distinguish required inputs from explicitly optional inputs.
  A missing optional GUI override may be normal; a malformed existing override still
  fails. An empty source list is an error when an operation needs sources. If all
  explicitly optional sources are absent, leave the destination untouched.
- **Raw files:** require exactly one source and reject structured merge policies.
  Never execute Lua/scripts to obtain mergeable data.
- **Type changes:** a non-object conflict follows the selected policy, including
  object/scalar changes. Unsupported output values fail before publication. The
  initial structured formats are JSON and TOML; unsupported formats can be copied
  raw. TOML datetimes and non-finite floats are rejected in structured mode rather
  than silently changing their types through JSON.
- **Concurrent invocations:** hold a per-program OS file lock while syncing, so
  simultaneous launches serialize their sync attempts. Snapshot operations use the
  same lock to avoid racing the syncer. Locks are released before application launch
  and automatically on process exit. Lock acquisition has a bounded wait; timeout is
  logged and does not prevent `run` from launching the app. This does not lock an
  already-running application or prevent it from writing configuration.
- **Hash skipping:** record successful sync fingerprints covering tool/cache version,
  entry settings, resolved paths, source contents/presence, and resulting destination
  contents. Skip parsing/merging/writing when sources, policy, and runtime contents
  are unchanged. A GUI edit invalidates the cache, so `merge` still reapplies the
  baseline. Do not use source hashes alone. Corrupt/missing cache data is a cache
  miss. Only save successful fingerprints; unchanged files/cache are not rewritten.
- **Symlinks/directories:** reject symlink destination files and directory roots;
  permit source links and detect directory cycles. Resolve parent directory aliases.
  Never replace a whole profile/state directory to update selected config files.
- **Empty results:** an intentionally empty object/array is a valid snapshot. Missing
  sources, invalid transforms, or jq producing zero/multiple documents are different
  conditions, not instructions to erase the destination.
