# Application adapters

Follow [Creating and using wrappers](../docs/wrappers.md). Files here are
flake-parts modules declaring `flake.wrappers.<app>`, automatically imported by
`flake.nix`. Capture the shared `locallib` argument in the outer module to import
addons into a wrapper.

Include `locallib.sync-snap` in new adapters by default and enable configuration
sync when suitable. Enable snapshot export in their configured features, with
reviewed pruning in the adapter; generic adapters leave export disabled. Document
any application-specific exception. Leave unrelated older wrappers alone.

Keep application behavior here: config discovery, fixed native paths, generated
files, missing settings options, reusable plugin interfaces, and sensible snapshot
pruning defaults. Features consume these modules and choose preferences, runtime
directories, dependencies, plugins, and snapshot enablement. An adapter may enable
sync when needed to deliver writable config. Derive `sync.defaultDir` from an
existing application runtime-location option inside the adapter; features should
configure that public option. Direct sync paths are a fallback or documented
implementation exception.

[OpenCode](opencode.nix) is the reference adapter. It extends the upstream module,
redirects config/TUI environment defaults to writable sync files, and adds
`cli-settings` for v2. Nonempty CLI settings create `cli.json`; the generic package
still inherits upstream's version, so select a v2 package to use this option.
Its directory mapping presents the feature's chosen config directory at OpenCode's
fixed native location. Other contents of the original directory are hidden in the
wrapped process, not copied over. Caller config environment overrides still win;
sync continues managing its declared destinations. Keep synced files valid JSON,
not JSONC. The app's native configuration layers still apply.

The [myopencode feature](../modules/features/opencode-agent/opencode.nix) selects
v2, personal settings and tools, `syncopencode/`, and manual snapshot export.
See [snapshot review](../docs/snapshot-review.md) when adding pruning rules.

[Brave](brave/default.nix) is a Linux adapter for recommended policies and external
extension manifests. It uses process-local directory mappings for Brave's fixed
discovery paths, with temporary parent directories for missing root-owned policy
paths. Profiles remain writable. Browser-owned Preferences are seeded only when
missing, and snapshots retain a typed scalar allowlist instead of full profile
state. The [mybrave feature](../modules/features/brave/README.md) chooses Bitwarden,
Google, the homepage, `userDataDir`, and snapshot export. The adapter derives
its sync directory from `userDataDir`; `profileDirectory` controls the relative
Preferences path for launch, sync, and snapshot.

Keep reusable adapter checks beside their module, as in
[Brave](brave/checks/check.nix), and instantiate the generic wrapper with test
settings. Feature checks cover the assembled package and chosen integrations.
