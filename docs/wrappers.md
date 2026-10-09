# Creating and using wrappers

Use this pattern for new wrappers and deliberate migrations. The working reference
is [OpenCode's adapter](../wrapperModules/opencode.nix) and its
[configured feature](../modules/features/opencode-agent/opencode.nix).
Older wrappers may use different conventions; the original proposal is historical.

## Where things belong

| Location | Responsibility |
| --- | --- |
| `wrapperModules/<app>.nix` | Generic application adapter: extend an upstream wrapper or create one, expose settings/plugin options, generate config, handle discovery and app-specific exceptions. |
| `modules/features/<app>/` | Main user interface: consume the adapter, choose preferences, plugins, runtime libraries/tools, config directory, sync policy/triggers, and whether to enable snapshots. |
| `lib/` | Reusable addons and flake integration, independent of any application. |
| `snapshot/<package-name>/` | Reviewed, generated baseline captured from runtime settings. Keep handwritten preferences in the feature. |

An adapter may enable sync to deliver writable settings. It should not choose a
personal theme or runtime directory, or enable snapshot export. Sensible pruning
of known application state and credentials belongs in the adapter. Expose reusable
plugin configuration options there when doing so keeps features declarative and
readable; plugin selection and preferences remain feature choices.

## Create an adapter

1. Read the pinned application's config documentation and the upstream wrapper's
   options, defaults, and implementation. Check config discovery, file format,
   writeback, plugin loading, and version compatibility. Consult
   [documentation references](references.md).
2. Add a flake-parts module under `wrapperModules/` declaring
   `flake.wrappers.<app>`. `flake.nix` imports this directory automatically.
   Extend `wlib.wrapperModules.<app>` when suitable. For a new wrapper, use
   `wlib.modules.default`, select its package, and expose the needed options.
3. Import shared addons through the outer flake-parts `locallib` argument.
   `locallib.sync-snap` provides writable config and optional export;
   `locallib.directory-mappings` handles fixed native directories when needed.
   The sync addon already imports `wlib.modules.default`. No Home Manager
   evaluation or custom extension of `wlib` is needed.
4. Use `constructFiles` for generated config. The sync addon derives file mappings
   from those entries. Point the app's config flags/environment at
   `config.sync.files.<entry>.path`, rather than the immutable generated file.
   Exclude helper executables or other non-config entries from sync.
5. Put missing app options and path exceptions in this adapter. Prefer native
   config path options; use directory mappings for fixed locations. Document
   app-specific limitations beside the adapter.

The key part of the OpenCode adapter is:

```nix
{locallib, ...}: {
  flake.wrappers.opencode = {config, lib, wlib, ...}: {
    imports = [wlib.wrapperModules.opencode locallib.sync-snap];
    sync.enable = lib.mkDefault true;
    envDefault.OPENCODE_CONFIG = {
      data = lib.mkForce config.sync.files.opencodeConfig.path;
      esc-fn = wlib.escapeShellArgWithEnv;
    };
  };
}
```

This is an excerpt, not a replacement for the full adapter. The existing module
also redirects TUI config and exposes `cli-settings`. OpenCode v2 cannot override
its native `cli.json` path, so the adapter maps `sync.defaultDir` onto the native
OpenCode directory. The feature only chooses where it wants config stored.

`envDefault` lets an explicit caller environment win. `mkForce` replaces the
upstream module's default path, not the caller's environment. `esc-fn` expands
HOME/XDG variables at launch while quoting paths; fixed store paths do not need it.
The sync addon supplies the XDG config home fallback centrally.

## Configure a feature

Consume the adapter with `.wrap`; keep preferences and dependencies here. This
minimal OpenCode v2 example shows the shape of the existing feature:

```nix
{config, inputs, ...}: {
  perSystem = {pkgs, lib, system, self', ...}: {
    packages.myopencode = config.flake.wrappers.opencode.wrap {
      inherit pkgs;
      package = inputs.llm-agents.packages.${system}.opencode2;
      exePath = "bin/opencode2";
      binName = "opencode";
      sync.defaultDir = "\${XDG_CONFIG_HOME}/syncopencode";
      snapshot.enable = true;
      cli-settings.theme.name = "gruvbox";
      settings.autoupdate = false;
    };
    apps.myopencode = {
      type = "app";
      program = lib.getExe' self'.packages.myopencode "opencode";
    };
  };
}
```

Reuse existing wrapper options for dependencies and plugins. Add packaged tools
through the appropriate PATH/library options; keep generated integration paths
separate from captured preferences. If plugin setup needs reusable translation
or file generation, expose an adapter option instead of adding feature scripts.

A thin NixOS feature may install `self.packages.${system}.myopencode`. Do not enable
that feature on hosts or edit profiles without a request. The package remains
buildable and runnable without installing it into NixOS.

## Run, edit, and capture

```sh
nix run path:.#myopencode
nix run path:.#snapshot-myopencode
nix run path:.#snapshot-all
```

Sync runs before app launch, materializing writable config from packaged inputs.
Its default merge preserves runtime-only keys and reapplies declared values on
eligible starts. Runtime edits need no rebuild; hot reload depends on the app.
Choose sync triggers in the feature when edits should survive multiple launches.
A sync error is logged and does not prevent the application from launching.

Snapshot export is manual. Setting `snapshot.enable = true` on a feature package
automatically registers `snapshot-<package-name>` and includes it in `snapshot-all`.
No separate registration or app-close hook is needed. The command captures runtime
files without first launching or syncing the app. For `myopencode`, the default
export destination is `/home/helios/.config/nix-config/snapshot/myopencode/`.

Review exports using [the snapshot review guide](snapshot-review.md). Existing
structured snapshots are embedded automatically on the next build/run, with
explicit declared settings taking precedence. `snapshot.autoMerge = false`
disables all automatic imports; `snapshot.files.<entry>.autoMerge = false`
disables one. Export enablement and baseline import are independent choices.
Changing the export directory also requires considering the baseline source path;
see the [addon reference](../lib/sync-snap/README.md).

Use `path:.` to test new untracked modules or snapshots without changing staging.
A regular Git flake includes tracked files only. Snapshot capture does not commit
files, and a newly captured baseline does not change an already-built wrapper.

OpenCode uses a persistent service: restart it through the wrapper after changing
packaged configuration (`nix run path:.#myopencode -- service restart`), or use
`--standalone` for an independent session. Caller overrides and native config
layers still apply. Directory mappings affect only the wrapped process tree;
already-running external services do not inherit them.

## Validate the result

Keep checks beside the adapter, addon, or feature in `check.nix`, or `checks/` for
multiple files. There is no root `tests/` directory. Follow the existing
[OpenCode check](../modules/features/opencode-agent/checks/check.nix) for flake
registration and isolated runtime directories.

Build the package and relevant checks. Test config discovery, preference delivery,
runtime edits across launches, and any claimed plugin/path behavior. With snapshots
enabled, capture representative settings, review pruning, and verify the resulting
baseline. Distinguish a simulated app, a real CLI check, and actual GUI save/reload.

```sh
nix build path:.#myopencode path:.#checks.x86_64-linux.myopencode --no-link -L
```

When changing a package or module used by hosts, also build each affected
`nixosConfigurations.<host>.config.system.build.toplevel`. Do not activate a system
or restart the user's active session just to validate it.

## Detailed references

- [Sync/snapshot addon](../lib/sync-snap/README.md): options, file mappings, triggers, registration, and baseline imports.
- [Sync-snap engine](../packages/sync-snap/README.md): policies, arrays, pruning, cache/locks, and error behavior.
- [Directory mappings](../lib/directory-mappings/README.md): fixed-path adaptation and its runtime requirements.
- [Snapshot review](snapshot-review.md): what to retain, prune, and verify.
