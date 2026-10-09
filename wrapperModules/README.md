# Custom wrapper modules

Files here are flake-parts modules declaring `flake.wrappers.<name>`.
`flake.nix` discovers them through `import-tree`, alongside `modules/`.
The standard upstream integration exports the wrapper modules and packages.

To extend an upstream wrapper and add sync/snapshot support:

```nix
{SyncSnapWrapperModule, ...}: {
  flake.wrappers.myapp = {wlib, ...}: {
    imports = [wlib.wrapperModules.myapp SyncSnapWrapperModule];
    sync.enable = true;
  };
}
```

`SyncSnapWrapperModule` is a shared flake-parts argument defined in `modules/flake-parts.nix`.
Capture it in the outer module as above. There is no custom `wlib` or registration layer.

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

Snapshot remains disabled for this first trial. The existing `myopencode` package
and host installation are separate and have not been migrated to this wrapper.
