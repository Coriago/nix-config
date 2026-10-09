# Custom wrapper modules

Add a `<name>.nix` file here. `flake.nix` discovers these files automatically and
exports `wrapperModules.<name>`, `wrappers.<name>`, and `packages.<system>.<name>`.
Each file is an ordinary wrapper module, not a flake-parts or NixOS module.
Assets and README files are ignored; discovery currently covers this directory's
immediate `.nix` files.

All flake-registered wrappers receive the extended `wlib`. Import
`wlib.modules.sync-snap` to use the shared addon. `wlib.wrapperModules` still
contains upstream application modules, so extending one does not import yourself.
For standalone evaluation, use this flake's `lib.wlib.evalPackage`.

The pinned upstream flake-parts integration creates its own fixed `wlib`.
`lib/wrapper-flake-module.nix` preserves its registration/package-selection
interface while evaluating with the extended library from
`lib/wrapper-module-lib.nix`. Recheck this small integration when updating upstream.

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

An unset XDG_CONFIG_HOME defaults to `$HOME/.config` through `envDefault`.
If supplied, XDG_CONFIG_HOME should be an absolute path. `sync.defaultDir` and individual destination overrides update the
file mappings and application environment together. Sources are generated JSON;
keep the runtime files valid JSON, since sync-snap does not parse JSONC comments.

The default baseline is `{}` for each file. Sync merges declared values on each
launch while preserving runtime-only keys. The native global/project config
layers still apply; these environment variables select custom files rather than
isolating all OpenCode configuration. See the [OpenCode config documentation](https://opencode.ai/docs/config/).

Snapshot remains disabled for this first trial. The existing `myopencode` package
and host installation are separate and have not been migrated to this wrapper.
