# Live desktop configuration

## Noctalia v5

`mynoctalia` wraps pinned `pkgs.noctalia` (5.2.0), not the legacy
Quickshell `pkgs.noctalia-shell`. The old `noctalia/*.json` files are preserved
for reference/rollback and are no longer loaded. Plugins and palettes are not
migrated. The new files intentionally leave v5 defaults implicit.

Precedence (last wins):

1. Noctalia built-in defaults.
2. Wrapper `settings` (Nix; suitable for fetched wallpaper paths, etc.).
3. `noctalia-v5/config.toml` (curated, hand-edited settings).
4. `noctalia-v5/settings.toml` (GUI-owned settings, when live mode is enabled).

The existing NixOS `liveConfig.enable` selects live paths under
`liveConfig.root`. No host/profile enablement is changed by these modules.
Noctalia watches included files and the GUI override file, including atomic
replacement of symlink targets. There is no synchronization daemon.

Only the GUI settings file is linked into the checkout:

```
${XDG_STATE_HOME:-~/.local/state}/mynoctalia/noctalia/settings.toml
    -> <checkout>/modules/features/tiling-desktop/noctalia-v5/settings.toml
```

`state.toml`, plugin repositories, and other state remain alongside that link,
not in Git. Cache/data/credential storage keeps its upstream locations. Current
volume and brightness are not copied into Git by the wrapper. Persistent
settings can still include monitor selectors, local paths, or account metadata:
review GUI diffs before committing; this is not a portability/privacy filter.

`noctalia-state.py` only provisions this link. It never merges settings, rewrites
TOML, or replaces existing data. Conflicting files/links cause a clear error;
reconcile them and move the old file aside explicitly. The checkout file must
exist. To disable live mode, first move the settings symlink aside (optionally
replace it with a regular copy). This prevents silent continued writes to Git.

Without live mode, both repository TOML files become a store-backed baseline.
GUI changes still work, but are saved in a regular user-state `settings.toml`.
Existing user overrides always win; rebuilding does not reset them.

Useful commands (run the installed wrapper, not an unwrapped package):

```
noctalia config validate
noctalia config export
noctalia msg panel-toggle launcher
noctalia msg settings-toggle
```

For Nix-supplied values, set `wrappers.mynoctalia.settings` in the NixOS module,
or `.wrap { settings = ...; }` on the standalone package. Clear the matching key
in GUI `settings.toml` to let the baseline win again. Do not export the full
resolved config back over your Nix source: that would flatten fetched paths and
pin all built-in defaults.

## Umbriel

The same `settings`/`liveConfigDir` wrapper interface uses native TOML includes:

1. Umbriel built-in defaults.
2. Nix `settings` (existing autostart and keybinds).
3. `umbriel/config.toml` (editable overrides).

With live mode enabled, saving `umbriel/config.toml` triggers Umbriel's native
reload. Without live mode it is a store snapshot. Nix expressions stay in Nix;
there is no attempt to round-trip store paths into source expressions.

Umbriel tables merge by key; scalars and ordinary arrays use the last value.
Rule lists accumulate; `[]` clears earlier entries. Duplicate device/workspace
selectors can be errors. Invalid reloads retain the last valid config.
Autostart, environment, Xwayland, and DRM changes require a session restart.
This provides live file editing, not a new compositor GUI config writer.
Noctalia's optional compositor theme generators are not enabled here.

Validate with `umbriel validate`. The wrapper keeps subcommands such as `msg`
intact and selects its config for session startup and validation.

## Rebuilds versus live reload

Editing live TOML needs no rebuild. Changing Nix settings needs a rebuild **and
launching the new wrapper** (restart Noctalia / restart the Umbriel session).
Already-running processes retain their old store-backed baseline; these modules
do not force a compositor restart on rebuild. GUI overrides continue to win.
A session restart is also needed for the initial v4-to-v5 migration.

## Checks

```
nix build 'path:.#checks.x86_64-linux.mynoctalia' \
          'path:.#checks.x86_64-linux.myumbriel' --no-link
```

These use the real pinned applications' CLI validators and Noctalia's config
exporter, exercising precedence, HOME/XDG paths, conflicting state, settings-only
linking, simulated atomic edits, and invalid live TOML. They do not launch a GUI
or prove in-session hot reload; that behavior is provided by upstream watchers.
The `path:` form includes new, untracked files without altering Git staging.

References:
- https://docs.noctalia.dev/noctalia/configuration/
- https://docs.noctalia.dev/noctalia/getting-started/installation/
- https://docs.noctalia.dev/umbriel/configuration/
- Pinned nix-wrapper-modules `noctalia-shell` and `niri` modules: v4-only copy
  support versus generated config/include/validation separation. The v5 wrapper
  uses `wlib.modules.default` because the pinned v4 wrapper is incompatible.
