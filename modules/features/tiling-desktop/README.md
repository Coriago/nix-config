# Desktop configuration

## Noctalia

`mynoctalia` consumes the [generic v5 adapter](../../../wrapperModules/noctalia/README.md).
Preferences remain in the feature and `snapshot/mynoctalia/noctalia/config.toml`;
the feature preserves the Nix wallpaper, plugin/theme choices and GTK integration.

Runtime files are:

- `$XDG_CONFIG_HOME/syncnoctalia/noctalia/config.toml`: replaced from the baseline.
- `$XDG_STATE_HOME/syncnoctalia/noctalia/settings.toml`: merged with the same baseline.

Explicit Nix settings override captured settings when building the next package.
Launch sync reapplies declared values; settings-only GUI keys survive. During the
session GUI settings override config. IPC and CLI inspection do not trigger sync.
The standard HOME-based XDG fallbacks apply when these variables are unset.

Capture current overrides before relaunching if you want them saved:

```sh
nix run path:.#snapshot-mynoctalia
```

Snapshot combines config first, then settings, prunes nonportable/private fields,
and exports one master baseline. There are no automatic snapshot hooks, reset
scripts, or systemd sync/reset actions. The old `snapshotFile` and
`resetOverridesOnStart` interfaces are removed. Use `noctalia-sync` for an explicit
reset of declared preferences; undeclared runtime keys remain. See the adapter
for pruning details and its two-file/include scope.

The new profile does not import the old `mynoctalia` state directory or run its
hooks. The old runtime data is left on disk. The reviewed former
`noctalia/snapshot.toml` baseline was moved into the shared snapshot layout.
Snapshot export never starts Noctalia and never syncs away unsaved overrides.

NixOS still launches the wrapped application through the normal Noctalia session
service. This is application startup only; sync belongs to the wrapper. The
standalone Umbriel package autostarts Noctalia, while the NixOS package leaves
startup to that existing service. Launcher applications retain the existing
`shell.launch_apps_as_systemd_services` preference.

## Greeter sync

The greeter module sets `passwordlessSyncUsers` from `hostmeta.username`.
The upstream Polkit rule allows that account's active local session to run the
packaged, constrained appearance-sync helper without a password. Auto-sync is
already enabled in the Noctalia snapshot. A keyring is not involved in this
authorization.

After rebuilding and switching, use Noctalia Settings → Security → Noctalia
Greeter → Sync Now to check it, or let the next appearance change trigger sync.
The rule takes effect without a reboot. Synced state remains local under
`/var/lib/noctalia-greeter`; declarative greeter settings take precedence.

Reference: [Greeter sync and authorization](https://docs.noctalia.dev/greeter/sync/).

## Umbriel

`umbriel/config.toml` holds the declarative layout defaults, read by
the feature when Nix generates its TOML. The default layout is scrolling;
new columns use two-thirds of the available scrolling extent (width with the
default workspace axis). Existing columns keep their current sizes.

Both standalone and NixOS packages use writable
`$XDG_CONFIG_HOME/syncumbriel/config.toml`, through the
[generic adapter](../../../wrapperModules/umbriel/README.md). Sync merges captured
preferences and explicit Nix settings into this file before compositor launch.
There is no root-owned `/etc/umbriel/config.toml` deployment or sync service.

Umbriel watches the runtime file and reloads valid edits. After a rebuild, invoke
the newly built package's `umbriel-sync` or start a new session to apply its
baseline; switching alone no longer copies compositor preferences into place.
Environment, autostart, DRM and binary changes require a new session.
`umbriel config validate` reads the runtime file without syncing it first.

Capture preferences with `nix run path:.#snapshot-myumbriel`. The export is
`snapshot/myumbriel/config.toml`; store paths and host/session wiring are pruned.
The adapter's `configDir` option keeps application discovery, sync and snapshot
aligned. GTK/Qt packages and application launch commands remain feature choices.

The generated config optionally includes
`$XDG_CONFIG_HOME/umbriel/noctalia.toml`, where Noctalia's enabled Umbriel template
writes its colors. The wrapper defaults `XDG_CONFIG_HOME` to `~/.config` when unset.
Umbriel watches the included file and reloads theme changes natively; a missing
file is allowed. Explicit Nix settings take precedence over included colors.

## Application theming

`myumbriel` bundles `adw-gtk3` through `settings.environment.GTK_DATA_PREFIX`.
This supplies GTK 3's fallback theme directory without forcing `GTK_THEME`, so
GUI theme choices and Noctalia's light/dark switching remain effective. User
themes and themes found through the existing XDG data paths retain precedence.

`mynoctalia` also bundles the theme, GNOME settings schemas, dconf backend, and
commands needed by its upstream GTK template hook. The GTK 3/4 templates already
enabled in the snapshot generate writable CSS and select `adw-gtk3` or
`adw-gtk3-dark` through GSettings when applied, including at shell startup.
Home Manager no longer assigns the GTK theme on activation. Disabling those
templates leaves appearance management to the user and upstream undo hooks.
GTK 4 receives Noctalia's generated CSS and color-scheme preference; `adw-gtk3`
provides the GTK 3 base theme.

NixOS still enables dconf's D-Bus service. Package runs on another distribution
need a working user D-Bus/dconf service; bundling client tools does not register
host services. Package runs also share the user's GTK CSS and dconf state unless
tested with a separate home/config and session bus.

`myumbriel` bundles the Qt6 `qtengine` plugin and JSON configuration. Its
`settings.environment` selects the plugin, provides its store plugin path and
points `QTENGINE_CONFIG` at the generated JSON. Umbriel publishes these settings
to the managed session's user services as well as its children. No global
qt6ct installation or GUI scheme selection is needed; Fusion is the base style.
The configured `QT_PLUGIN_PATH` contains the bundled plugin directory; override
`settings.environment.QT_PLUGIN_PATH` to include other external plugin roots.

Noctalia's generated baseline enables `kcolorscheme` alongside the exported
template list. Existing local GUI overrides still take precedence: if necessary,
enable **KColorScheme** in Settings → Templates. Noctalia writes the mutable
colors while the qtengine JSON stays in the store. Restart the desktop session
for environment changes, and restart existing Qt apps after changing schemes.

The feature's Qt configuration sets `theme.colorScheme` to
`~/.local/share/color-schemes/noctalia.colors`. The pinned qtengine expands `~`
but not environment variables in this field (confirmed in its implementation).
For a custom `XDG_DATA_HOME`, edit that feature setting to use the corresponding path.
The pinned nixpkgs qtengine package supports Qt6 only, not Qt5; sandboxed apps
also need their own plugin/theme access.

References: [Noctalia GTK/Qt guide](https://docs.noctalia.dev/noctalia/templates/official/gtk-qt/)
and [qtengine 0.2.2](https://github.com/kossLAN/qtengine/tree/0.2.2).

## Desktop portals

The pinned NixOS `programs.umbriel` module already installs and registers
`xdg-desktop-portal-umbriel`, the portal frontend, and the GTK fallback backend.
Umbriel's backend implements ScreenCast and Screenshot, including the screen/window
share picker and PipeWire capture. The shipped `umbriel-portals.conf` selects
`umbriel;gtk`: GTK supplies supported interfaces such as FileChooser and Settings.
These portals do not install GTK themes or replace a file manager.

Keep their D-Bus/systemd registration and backend selection in NixOS integration.
A separate portal wrapper is unnecessary with the upstream defaults; merely
adding its executable to the compositor's PATH would not register it. A standalone
or nested `myumbriel` run uses the host's portal setup and does not create an
isolated portal session. Custom capture commands or limits can be configured later
if needed, using the backend's supported configuration.

Reference: [Umbriel portal README](https://github.com/noctalia-dev/xdg-desktop-portal-umbriel).

## Validation

```
nix build 'path:.#checks.x86_64-linux.mynoctalia' 'path:.#checks.x86_64-linux.myumbriel' 'path:.#checks.x86_64-linux.noctalia-gtk' --no-link
nix build 'path:.#checks.x86_64-linux.umbriel-reload' --no-link
nix build 'path:.#nixosConfigurations.heliosdesk.config.system.build.toplevel' 'path:.#nixosConfigurations.heliosmac.config.system.build.toplevel' --no-link
```

The adapter checks live in `wrapperModules/noctalia/checks/` and
`wrapperModules/umbriel/checks/`. Run them with:

```sh
nix build path:.#checks.x86_64-linux.noctalia-wrapper path:.#checks.x86_64-linux.umbriel-wrapper --no-link
```

They validate native configuration precedence, launch sync, IPC isolation,
snapshot pruning and restoration with independent fixtures. The separate watcher
check verifies atomic file replacement. Launch probes are simulated; configuration
validation/export uses the real applications.

Feature checks validate the assembled personal preferences and wallpaper. The
Umbriel check runs a Qt6 application offscreen and GTK's real theme loader to
verify bundled assets. The GTK template check renders Noctalia's upstream templates
on a private D-Bus, checks light/dark dconf selection and preserved CSS, and
validates missing/generated/malformed Umbriel theme includes. Native template
hooks are application theming behavior, not automatic snapshot hooks.

These are CLI, filesystem and offscreen toolkit checks, not live desktop/GUI
save/reload tests. No system is activated or compositor session restarted.
