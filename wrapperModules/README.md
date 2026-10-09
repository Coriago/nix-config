# Custom wrapper modules

Files here are flake-parts modules declaring `flake.wrappers.<name>`.
`flake.nix` discovers them through `import-tree`, alongside `modules/`.
The standard upstream integration exports the wrapper modules and packages.

To extend an upstream wrapper and add sync/snapshot support:

```nix
{locallib, ...}: {
  flake.wrappers.myapp = {wlib, ...}: {
    imports = [wlib.wrapperModules.myapp locallib.sync-snap];
    sync.enable = true;
  };
}
```

`locallib` is a shared flake-parts argument defined in `modules/flake-parts.nix`.
Capture it in the outer module as above. There is no custom `wlib` or registration layer.
It provides `sync-snap` and [directory-mappings](../lib/directory-mappings/README.md)
as independently importable wrapper addons.

## OpenCode

Run `nix run path:.#opencode`. Configure upstream `settings` and `tui-settings`
through `flake.wrappers.opencode` or extend `wrappers.opencode.wrap`.
The module imports upstream OpenCode and the sync-snap addon, enables sync, and
points `OPENCODE_CONFIG` / `OPENCODE_TUI_CONFIG` to the computed sync file paths.
Like upstream, these are `envDefault` values: caller-provided paths take precedence.
Sync still manages its declared destinations when a caller selects another config.

Default writable files:

- `${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode-config.json`
- `${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode-tui-config.json`

The shared sync-snap addon supplies `$HOME/.config` as the `envDefault` for
XDG_CONFIG_HOME before application environment defaults are expanded.
If supplied, XDG_CONFIG_HOME should be an absolute path. `sync.defaultDir` and individual destination overrides update the
file mappings and application environment together. Sources are generated JSON;
keep the runtime files valid JSON, since sync-snap does not parse JSONC comments.

The default baseline is `{}` for each file. Sync merges declared values on each
launch while preserving runtime-only keys. The native global/project config
layers still apply; these environment variables select custom files rather than
isolating all OpenCode configuration. See the [OpenCode config documentation](https://opencode.ai/docs/config/).

For OpenCode v2, the additional `cli-settings` option configures `cli.json`:

```nix
cli-settings.theme = {
  name = "lucent-orng";
  mode = "system"; # or "dark" / "light"
};
```

It defaults to `{}`, which leaves `cli.json` unmanaged. When nonempty, it uses
the same constructFiles and sync-snap flow. OpenCode v2 always reads this file
from `${XDG_CONFIG_HOME:-$HOME/.config}/opencode/cli.json`. There is no supported
file-path environment override. The wrapper stores it under `sync.defaultDir`
and automatically maps that directory onto OpenCode's native directory when
the configured paths differ. This app-specific mapping belongs to the wrapper;
features choose `sync.defaultDir` and personal settings. Runtime-only keys survive sync; declared keys
are reapplied at launch. Keep this file valid JSON too.
See the [v2 CLI configuration documentation](https://opencode.ai/v2/docs/cli/config).

`myopencode` uses this wrapper with OpenCode v2 and stores all three config files
in `syncopencode/`. The wrapper supplies `directoryMappings` to present that directory at
OpenCode's native `opencode/` path. The feature declares the directory and personal theme in
`modules/features/opencode-agent/opencode.nix`. The generic wrapper
still inherits upstream's default package; select a v2 package to use `cli-settings`.
Snapshot remains disabled.
