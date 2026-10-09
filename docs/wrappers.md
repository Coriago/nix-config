# Wrapper package standard

Build each application as a portable `nix-wrapper-modules` package containing
its dependencies and a useful configuration baseline. Keep mutable preferences
in a location the application can write. On an opted-in host, let selected
configuration files resolve to the checkout at runtime. Capture useful GUI
preferences back into a reviewed repository baseline when the application makes
that practical.

The common standard is the ownership and lifecycle of configuration. Config
discovery, saving, and reloading remain application-specific adapters. Reuse
native configuration layers and upstream wrapper options where they fit the chosen
ownership policy. For partially declarative writable files, the optional
[sync-snap package](../packages/sync-snap/README.md) implements shared sync and
snapshot operations, including baseline priority when native overrides would
otherwise win. Use the [shared Nix adapter](../lib/sync-snap/README.md) for
`sync` and `snapshot` options, generated commands, and startup wiring. Keep personal settings
in `modules/features/<app>/config/`, custom wrappers in `wrapperModules/`, and
checks in `tests/wrappers/`. See the [agreed lifecycle design](proposal-portable-mutability.md).

This guide defines the approach for new wrappers and incremental migrations. The
inventory below describes current behavior; proposed options and examples do not
change installed applications or enable features on hosts.

## Configuration ownership

| Component | Owner and location | How it changes |
| --- | --- | --- |
| Executable, plugins, tools, generated executable paths | Nix store | Build a new package |
| Handwritten preferences and application code | Tracked files beside the feature | Edit; build for a store snapshot, reload for a live source |
| Captured GUI baseline | A separate tracked `snapshot.toml` or equivalent | Explicit export or opted-in event hook; review its diff |
| Local GUI overrides and theme output | Application's writable user directories | Application, GUI, or theme generator |
| Sessions, history, caches, device details, credentials | Application state/cache directories or runtime secret provider | Application/runtime only |
| Host services, sessions, portals, activation, checkout selection | NixOS or Home Manager feature module | Host configuration and activation |

Keep hand-edited files and exporter-owned snapshots separate. One file should
have one writer. Avoid putting the application's entire configuration directory
in Git when that directory also contains state, credentials, or downloaded data.
Use application-specific config/state variables before changing global XDG roots:
children of a terminal, editor, or desktop shell inherit its environment.

An embedded baseline makes a package self-contained, but does not make its whole
runtime reproducible. Writable overrides, project settings, and live files are
intentional runtime inputs. Tests should supply isolated, known versions of them.

## Make three independent choices

| Choice | Default for a new wrapper | Alternatives |
| --- | --- | --- |
| Source of curated configuration | Store snapshot | Runtime checkout path selected by host integration |
| Mutable preferences | Native writable overlay, if supported | Non-overwriting initial copy for apps that require a writable main file |
| Repository writeback | Disabled until a destination and policy are selected | Filtered manual export; automatic export on documented events; direct writes to a dedicated repo file |

These choices compose. A store baseline can have editable GUI overrides. A live
handwritten config can coexist with GUI overrides that stay local. Exporting
preferences does not require making the runtime config a symlink.

Do not implement a universal `mode = "mutable"` that ambiguously controls all
three. Reuse existing upstream option names. For a new custom adapter, use
`settings` for generated configuration and `configFile` or `configDir` for a
runtime source where those meanings fit. Document whether a path *replaces* the
baseline or adds another layer. Add `snapshotFile` only when there is an exporter;
prefer a nullable destination defaulting to `null` for new adapters. These are
design conventions, not options automatically supplied by this repository.

## Prefer native configuration layers

The usual preference order, where the app supports it, is:

```text
application defaults
    < packaged preferences or captured baseline
    < handwritten live or local preferences
    < writable GUI overrides
```

Reserve a small, explicit set of settings for Nix-owned integration: executable
paths, packaged plugin registration, and required hooks. Keep those separate from
preferences where possible. If the app offers a final policy layer, use it only
for settings that must win and document them. Otherwise avoid giving two layers
ownership of the same setting.

There are two different merges:

- Nix option merging selects the configuration used to build a package.
  `lib.mkDefault`, `lib.mkForce`, and `lib.mkBefore` operate here.
- The application merges the files, arguments, and environment it reads at
  runtime. Nix priority does not force an app to ignore a later GUI override.

Publish the actual runtime order in each feature's README. Record nested-table,
array, repeated-key, reset, and deletion behavior; there is no universal deep
merge. For example, Noctalia's GUI layer wins over generated Nix preferences,
whereas this repo's Ghostty wrapper loads writable host config before its
generated keybinding policy. Ghostty processes includes after the containing
file; Noctalia and Umbriel apply the containing file after its includes.
See [Ghostty configuration](https://ghostty.org/docs/config),
[Noctalia configuration](https://docs.noctalia.dev/noctalia/configuration/), and
[Umbriel configuration](https://docs.noctalia.dev/umbriel/configuration/).

For live editing alongside Nix-generated values, generate a small entry file
whose native includes point to the selected runtime files. Alternatively use
the application's multiple-config-file flags. Only parse source text with
`builtins.readFile`/`fromTOML` when a build-time snapshot is intended. A Nix merge
of a source file is not a runtime include.

### Applications that need writable main files

Use supported upstream seeding facilities first. A seed copies missing defaults
to a writable location on first use without overwriting existing preferences.
It is an initialization mechanism: rebuilding does not update existing files.
Provide explicit instructions for comparing, adopting, or resetting defaults.
Reset should back up the old file and run with the application stopped if it
writes settings on exit.

Avoid copying generated store paths into long-lived mutable preferences. Such
copies can retain obsolete executable/plugin paths after an upgrade; plain text
outside the store does not keep a dependency alive through garbage collection.
Prefer regenerating a separate Nix-owned include. If the application cannot
separate those values, document an explicit migration procedure.

The pinned upstream `noctalia-shell` adapter illustrates seeding:
`settings` generates JSON, `outOfStoreConfig` defaults to `null`, and
`autoCopyConfig` defaults to `true`. Selecting an out-of-store directory points
the application there and enables non-overwriting copying of missing files;
disabling `autoCopyConfig` leaves its copy command available. These are
**application-specific options**, not generic wrapper facilities.
The [pinned option documentation and implementation](https://github.com/nix-community/nix-wrapper-modules/blob/1db3c116a6aa61823f8d8f3c47c306846428fc54/wrapperModules/n/noctalia-shell/module.nix)
target the older JSON application. This repo uses Noctalia 5.2.1 with native
TOML config and separate GUI state, so its custom adapter is appropriate.

If no upstream facility exists, keep any seed helper narrow: preserve existing
files and symlinks, handle simultaneous first launches, make copied files
user-writable, and test interrupted initialization. Do not overwrite the mutable
tree on every launch or activation.

## Package structure and host integration

Keep application files with their feature:

```text
modules/features/example/
  example.nix       # portable wrapper, optional host integration, checks
  README.md         # ownership, precedence, paths, reload, export, reset
  config/           # handwritten application files
  snapshot.toml     # optional exporter-owned baseline
  checks/           # tests that need separate files
```

Prefer `flake.wrappers.myexample` for a reusable application wrapper. The imported
flake-parts integration already creates `packages.<system>.myexample`, an
importable `wrapperModules.myexample`, and the wrapper's `.install` integration.
Add `apps.myexample` only when useful for selecting/documenting its entrypoint.
Use upstream `wlib.wrapperModules.<app>` when it fits; otherwise import
`wlib.modules.default` and implement the application's adapter. Small internal
tools such as Pi's browser server can continue using `lib.wrapPackage`.
See the [pinned getting-started guide](https://github.com/nix-community/nix-wrapper-modules/blob/1db3c116a6aa61823f8d8f3c47c306846428fc54/ci/docs/md/getting-started.md).

Import `<wrapper>.install` inside an optional NixOS feature and configure
`wrappers.<name>`. When an upstream NixOS service accepts a package, pass the
customized wrapper through its `package` option instead. All launch paths must
use the same intended variant: terminal command, desktop file, D-Bus activation,
user service, and compositor keybinding. Use
`config.wrappers.<name>.wrapper` for a host-customized installed package, rather
than `self.packages` which denotes the portable variant.

Default desktop-file patching does not prove that D-Bus/systemd/session launch
paths are patched. Ghostty adds these explicitly; Umbriel replaces the upstream
unit's hard-coded `ExecStart`. Keep service registration, portals, permissions,
and session setup in NixOS integration. A wrapper can bundle their client tools
without supplying a functioning host service.

Prefer `flags`, `env`, `envDefault`, `runtimePkgs`, and `constructFiles` to shell
glue. `envDefault` preserves a caller-supplied variable; `env` sets it. At the
pinned wrapper version, `runtimePkgs` appends to `PATH` by default, which lets
project tools take precedence; use absolute paths for integration tools that
must be the packaged version. Reserve `runShell` for actual adaptation such as
Pi/Umbriel subcommands that must precede flags.

Use `constructFiles.<name>.path` inside the wrapper and `.outPath` outside it;
the former supports the output placeholder without a dependency cycle. Expose
generated configuration through `passthru.generatedConfig` when tests/exporters
need it. Runtime environment expansion requires the default `nix` wrapper
implementation and a deliberate escaping function, for example:

```nix
env.MYAPP_STATE_HOME = {
  data = "\${XDG_STATE_HOME:-$HOME/.local/state}/myapp";
  esc-fn = wlib.escapeShellArgWithEnv;
};
```

`MYAPP_STATE_HOME` is illustrative: use it only if the app supports that variable.
Use ordinary shell escaping for literal paths. Do not assume `$HOME` or `~`
expands inside an application config format. The pinned
[wrapper options](https://github.com/nix-community/nix-wrapper-modules/blob/1db3c116a6aa61823f8d8f3c47c306846428fc54/modules/makeWrapper/module.nix)
and [file construction options](https://github.com/nix-community/nix-wrapper-modules/blob/1db3c116a6aa61823f8d8f3c47c306846428fc54/modules/constructFiles/module.nix)
document these distinctions.

## Live configuration

[`modules/liveconfig.nix`](../modules/liveconfig.nix) supplies `liveConfig` as a
**NixOS module argument**, not a `perSystem` or wrapper argument. Its behavior is:

- `link ./config` returns the original source path when the host toggle is off.
- When on, it produces a store symlink pointing to the corresponding absolute
  path under `config.liveConfig.root`.
- `forceLink` selects that behavior regardless of the toggle. Prefer `link` for
  normal feature integration so the host toggle remains effective.

The derivation creates a symlink; it never copies or validates the live target's
contents. The source must be inside this flake and the root must be absolute.
A missing/moved checkout leaves a dangling runtime path; there is no automatic
fallback to the embedded version. For an opted-in live source, surface that
problem instead of silently running old preferences. The portable flake package
remains the recovery option. Enabling/disabling live config or moving its root
requires updating the installed wrapper once.

Pass the link to an application that reads it at runtime. Do not parse, copy,
substitute, or dereference it during evaluation/building. The normal portable
package and its sandbox checks must not depend on the host checkout. Keep Nix
string contexts on generated store dependencies; the helper's narrow context
discard for calculating a checkout-relative name is not a general technique for
config generation.

Home Manager's `config.lib.file.mkOutOfStoreSymlink` is an alternative when the
app requires a link at a fixed user path. Pass an absolute **string** describing
the runtime checkout, not a flake path literal that can refer to its store copy.
Use either Home Manager or the wrapper to own a destination, never both.
Home Manager `onChange` is an activation hook; it does not watch subsequent repo
edits. See [Home Manager file behavior](https://nix-community.github.io/home-manager/index.xhtml#sec-usage-dotfiles-advanced).

### A reusable module example

This complete feature example uses the pinned Ghostty adapter. It deliberately
has a different name from the installed `myghostty`; it is a pattern to adapt,
not an additional terminal to enable. Put the following in
`modules/features/example/example.nix` and place a `config/ghostty.conf` beside
it. The config can start with `font-size = 14`.

```nix
{config, ...}: let
  local = config;
in {
  flake.wrappers.myterminal = {
    config,
    lib,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.ghostty];

    options.configFile = lib.mkOption {
      type = lib.types.oneOf [lib.types.path lib.types.package lib.types.str];
      default = ./config/ghostty.conf;
      description = "Preferences read by Ghostty after the generated defaults.";
    };

    config.settings = {
      font-size = lib.mkDefault 12;
      config-file = ["${config.configFile}"];
    };
  };

  flake.modules.nixos.example = {
    config,
    lib,
    liveConfig,
    ...
  }: {
    imports = [local.flake.wrappers.myterminal.install];
    wrappers.myterminal = {
      enable = true;
      configFile = lib.mkIf config.liveConfig.enable
        (lib.mkForce (liveConfig.link ./config/ghostty.conf));
    };
  };
}
```

The portable output includes both generated defaults and the repo file in its
closure. With live config enabled, the host variant reads preferences through
the checkout link; the generated default remains embedded. Native include order
means `font-size = 14` beats `12`. The upstream wrapper disables ordinary host
config by default. A runtime file can be selected explicitly through `configFile`
instead, but this example does not seed it or create a GUI exporter.

String interpolation keeps a Nix path input in the package closure; a runtime
absolute string or live-link derivation selects a runtime source. For relative
includes or adjacent assets, interpolate the containing directory and append
the filename so the complete tree is available in the store.

Ghostty requires a reload action (`Ctrl+Shift+,` with upstream bindings), and
some settings affect only new terminals or need a restart. Add this to the
feature's README rather than promising automatic reload. For a multi-file app,
use a `configDir` option and select the whole runtime directory, as Pi does.
Keep relative includes and assets inside that directory.

### Reload is an application capability

A symlink does not notify an app or re-run its initialization. Validate the
actual access path and the application's reload mechanism. In particular:

| Event | Required behavior to check |
| --- | --- |
| Editor writes an existing file | New value loads without rebuilding |
| Editor atomically renames a replacement over the file | Later saves still trigger reload; watcher is not stuck on the old inode |
| Included file is created, removed, or replaced | Optional/required include rules and watching behave as documented |
| Repo directory or symlink target is replaced | Watcher either recovers or documented restart is required |
| Syntax error followed by correction | Recovery works; report whether last valid config remains active |

Prefer native watching, IPC, or explicit reload actions. Add a custom watcher
only for a documented gap, and test debounce, atomic saves, new directories,
shutdown, and feedback from generated files. Changing packages, plugins,
Nix-generated paths, or Nix expressions always needs a new package build.

## GUI preference writeback

### Filtered export is the default pattern

Let the GUI write its normal local overrides. Export selected preferences into a
separate snapshot, then review and commit that file as the next portable baseline.
This is a one-way capture step, not continuous two-way synchronization.

```text
repo snapshot + explicit Nix integration -> packaged baseline
packaged baseline + local GUI overrides  -> effective application preferences
selected effective preferences          -> reviewed repo snapshot -> next build
```

Define what a snapshot represents: a full portable baseline, a preferences-only
overlay, or just the GUI delta. Do not silently change between these meanings.
Also define what clearing a GUI override means: return to the baseline, remove a
snapshot key, or write an explicit application reset value.

Use the native export command when it exposes the right data. Otherwise explain
the limitation before introducing a parser. Prefer an allowlist of portable
preference sections for new exporters. Preserve the old destination on parse or
validation failure, serialize deterministically, avoid rewriting identical
output, and replace via a temporary file in the destination directory. Reject
destinations that alias the inputs or unexpectedly point through symlinks.

Exclude credentials, cache/history, session IDs, monitor/device selections,
machine-local paths, and generated `/nix/store/` references from a shared
snapshot. Exact filtering is app-specific. Do not export every upstream default:
that needlessly pins values that could improve in later releases. Keep store
paths in generated Nix integration and source portable assets through fetchers.

For automatic exports, make the destination and trigger policy explicit. Use
documented app save/change hooks when available. Logout alone misses crashes and
external shutdowns. Scope exports to the correct running instance, serialize
concurrent exporters, and prevent export/reload loops by skipping identical
output. Avoid multiple machines writing one checkout. Do not automatically stage,
commit, or push GUI changes.

The existing [Noctalia exporter](../modules/features/tiling-desktop/noctalia-snapshot.py)
implements this particular contract:

```text
baseline      = recursiveMerge(repo snapshot, explicit Nix settings)
effective     = nativeMerge(baseline, GUI overrides)
next snapshot = removeStorePaths(recursiveMerge(baseline, prune(GUI overrides)))
```

Pruning before merging retains a baseline value when the GUI's replacement is
machine-local and rejected. Filtering a native merged export afterwards would
lose that distinction. Its recursive merge replaces arrays and scalars. Clearing
an override restores the baseline in the next snapshot. Its filter is a denylist,
so reviewing the diff remains necessary. It does not load arbitrary native include
trees: it reads the generated baseline file and GUI settings directly. Extending
Noctalia with live includes also requires revisiting this exporter contract.

Run `noctalia-snapshot-preferences` using the installed package matching the
running shell. Inspect `git diff -- modules/features/tiling-desktop/noctalia/snapshot.toml`
before adopting it. The hooks inherit the running shell's config/state roots;
the standalone command uses its own package's baseline.

### Direct writes into the checkout

Use direct writeback only when the app's settings file contains an acceptable
set of preferences and its save behavior is verified. Give the GUI a dedicated
file or narrow directory in the repo; do not let it serialize over handwritten
configuration or an independently generated snapshot.

Many applications save by writing a sibling temporary file and renaming it.
That can replace a file symlink instead of updating the target. A store symlink
used as the writable file path can also fail because its parent is read-only.
A directory symlink can allow child files to be atomically replaced in the
checkout, but is unsuitable if the app replaces the directory or also stores
private state there. Prefer a documented app path option when available.

Noctalia 5.2.1 explicitly supports preserving a `settings.toml` symlink and
writing to its target. This is a viable optional direct-write adapter, but it
would capture raw GUI overrides, including values the current exporter filters.
It is not enabled by the existing repo wrapper. Keep a direct GUI file separate
from `snapshot.toml`. The existing reset helper refuses a `settings.toml` file
symlink, so `resetOverridesOnStart` would fail service startup with that layout.
A directory link can instead expose a regular child file to the reset helper,
which would modify the checkout. Disable automatic reset for direct writeback.
See [Noctalia's versioned configuration documentation](https://github.com/noctalia-dev/noctalia/blob/v5.2.1/docs/user/configuration/index.mdx).

### Adoption and rollback

Rebuilding never implies deleting writable preferences. A new baseline can be
hidden by an old GUI override; provide an explicit reset/adopt operation scoped
to keys owned by that baseline. Back up mutable settings before destructive
resets. Runtime GUI changes, live checkout edits, and application schema
migrations are not reverted by a Nix generation rollback.

In the current Noctalia feature, `noctalia-reset-overrides` removes overridden
keys present in the generated baseline. `resetOverridesOnStart` defaults to
false but is enabled on `heliosdesk`; it also runs after service crash/rebuild
restarts. Export desired GUI changes before rebuilding in that workflow. See
the [desktop guide](../modules/features/tiling-desktop/README.md) for exact
snapshot/reset semantics and limitations.

## Current wrapper inventory

| Wrapper | Embedded configuration | Writable and live behavior | Reload or adoption |
| --- | --- | --- | --- |
| [myneovim](../modules/features/neovim/neovim.nix) | Lua tree, plugins, tools, generated integration info | Host overrides `settings.config_directory` with `liveConfig.link`; data/cache/state isolated by `NVIM_APPNAME` | Restart Neovim for configuration changes; no general automatic Lua reload |
| [mypi](../modules/features/pi-agent/pi-agent.nix) | Extensions, browser settings, MCP executable, plugin dependencies | Host overrides `configDir` with a live link; Pi keeps native user settings/credentials/sessions | `/reload` or restart; ensure browser/MCP subprocess restarts for its config changes |
| [myghostty](../modules/features/ghostty/ghostty.nix) | Keybinding policy | Ordinary host config enabled for writable Noctalia themes; no repo live-source option currently | Reload action or theme hook; packaged keybindings are loaded after host config |
| [mynoctalia](../modules/features/tiling-desktop/noctalia.nix) | Snapshot merged with Nix settings into store TOML | Native GUI overrides in `$XDG_STATE_HOME/mynoctalia/noctalia`; filtered snapshot command/hooks; no live baseline currently | GUI state is reloadable; changing repo snapshot needs rebuild; old overrides can mask it |
| [myumbriel](../modules/features/tiling-desktop/umbriel.nix) | TOML and Qt integration | Standalone store file; NixOS root-owned `/etc/umbriel/config.toml`; writable optional Noctalia theme include | Native reload after activation replaces `/etc` file or theme changes; editing repo baseline still needs build/activation |
| [myopencode](../modules/features/opencode-agent/opencode.nix) | Generated provider/agent/MCP JSON | Upstream `envDefault.OPENCODE_CONFIG` allows explicit caller override; native user/project config and credentials remain; no live repo JSON currently | Restart the persistent service after wrapper config changes; standalone session avoids service reuse |

The global live toggle currently affects **Neovim and Pi only**. Noctalia's
snapshot destination is independently hard-coded by default under
`$HOME/.config/nix-config`, and snapshot hooks are installed even for the portable
package. Changing `liveConfig.root` does not change that destination. These are
current differences from the proposed opt-in writeback convention.

## Incremental adoption

1. Use the wrapper declaration and thin optional host integration for new
   features. Move OpenCode to `flake.wrappers` when it next needs host overrides;
   its current `perSystem` package is valid but lacks the common install surface.
2. Keep Neovim and Pi as examples of runtime source selection. Add app-level path
   overrides where useful; the global toggle need not force every app live.
3. When adding live Noctalia/Umbriel baselines, split ordinary preferences from
   generated executable paths/hooks and use native includes. Do not just wrap
   the current `builtins.readFile` input in a live link. Verify include precedence
   and the snapshot export together.
4. Make Noctalia's writeback destination/automatic hooks explicitly selectable,
   derive host destinations from `liveConfig.root`, and keep export independent
   of whether source files are live. Preserve its existing snapshot format.
5. Add direct GUI writeback only for apps/files that pass the save/reload checks.
   Prefer filtered capture for mixed preference/state files.

These are follow-up implementation steps. Host profiles, live toggles, and
existing reset/export behavior require deliberate per-feature changes.

## Validation checklist

Before calling an adapter complete, check the behaviors it claims to support:

| Check | Evidence |
| --- | --- |
| Portable launch | Clean temporary home/XDG dirs, no checkout, packaged tools/config resolve |
| Precedence | Conflicting test values in each supported layer, including arrays/repeated keys and explicit caller overrides |
| Writable config | Edits survive a second launch and an upgraded baseline; invalid input preserves existing data |
| Live source | Edit after building without rebuilding; verify both ordinary writes and atomic replacements through the actual link path |
| GUI writeback | Real app save preserves the intended link/destination; only the intended repo file changes |
| Export | Missing/empty/malformed overrides, rejected fields, arrays, clearing/reset, no-op exports, and roundtrip into a new baseline |
| Host integration | Desktop/D-Bus/systemd commands select the host wrapper; build every affected NixOS toplevel |

Use isolated paths and a private session bus for tests that might contact a
running desktop. A stub tests argument/environment construction; a CLI test
tests parsing/merging; a watcher harness tests filesystem notifications. None
alone proves a GUI saved preferences or an active desktop applied a setting.
Record those distinctions with the results.

The module example above was built as a portable package and through both host
selection branches against the pinned inputs. With configuration loading
reconstructed in temporary XDG directories, Ghostty's real CLI confirmed include
precedence, independence from the original source file, and reads after ordinary
edits and atomic replacement through a store symlink. The host test supplied a
temporary live target with spaces in its path. This verifies subsequent config
reads, not hot reload in an existing GUI process or GUI writeback. Documentation
changes do not change a host configuration and require no system activation.

Existing focused checks, selected according to the change:

```sh
nix build .#checks.x86_64-linux.myneovim --no-link -L
nix build .#checks.x86_64-linux.mypi --no-link -L
nix build .#checks.x86_64-linux.myghostty --no-link -L
nix build .#checks.x86_64-linux.mynoctalia --no-link -L
nix build .#checks.x86_64-linux.myumbriel .#checks.x86_64-linux.umbriel-reload --no-link -L
nix build .#checks.x86_64-linux.myopencode --no-link -L
```

Ghostty's `+show-config` and `+validate-config` bypass this upstream wrapper's
injected config flags. Its existing test explicitly reconstructs config loading
under a temporary XDG directory. Umbriel's wrapped `validate` checks generated
settings even when `configPath` selects another runtime file. Test the runtime
path separately instead of assuming these commands cover it.

When modifying modules or packages used by a host, also build that host:

```sh
nix build .#nixosConfigurations.heliosdesk.config.system.build.toplevel --no-link -L
nix build .#nixosConfigurations.heliosmac.config.system.build.toplevel --no-link -L
```

Builds do not activate a generation. Do not switch/restart the user's session
merely to validate a change. Git flake references include tracked files; new
untracked module/config files need a suitable source snapshot for testing. Use
`path:.#...` when appropriate to test the working tree without changing staging;
it includes files outside Git's tracked set. Live runtime reads can see untracked
files that a later Git-flake build would omit.

## Version references

The inventory and examples use the repository's `flake.lock`, including
`nix-wrapper-modules` revision `1db3c116a6aa61823f8d8f3c47c306846428fc54`, Ghostty
1.3.1, Noctalia 5.2.1, and Umbriel `0-unstable-2026-10-04`. Read the new pinned
documentation and repeat affected checks when updating inputs. Current online
docs can describe a newer CLI or different configuration ownership. The upstream
Noctalia wrapper HTML page was unavailable during this review; its pinned module
contains the complete option descriptions used above.
