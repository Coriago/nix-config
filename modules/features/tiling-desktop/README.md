# Desktop configuration

## Noctalia

The model is:

```
config.toml   = snapshot.toml merged with explicit Nix settings
snapshot.toml = config.toml merged with pruned settings.toml, then store paths removed
```

Both merges are recursive: the right side wins, nested tables merge, and lists
replace. Nix always generates `config.toml`. Noctalia's writable `settings.toml`
contains GUI overrides, which take precedence at runtime.

Run `noctalia-snapshot-preferences` to replace
`noctalia/snapshot.toml`. The colors-changed and Noctalia logout/reboot/shutdown
hooks run the same snapshot operation. They do not cover crashes, compositor
exits, or shutdowns outside Noctalia. `snapshotFile` sets the destination; its
default is this repo under `$HOME/.config/nix-config`.

GUI overrides are pruned before merging. The filter removes monitor
selectors/layouts, local paths, credentials, hooks, and identified bookkeeping
such as `config_version`. If a GUI override is rejected, its baseline value is
retained. After merging, values containing `/nix/store/` paths are removed from either
layer, including generated hooks and wallpaper paths. Lists containing such
values are removed as a whole. Nix supplies these values again in `config.toml`;
build-specific paths therefore do not churn the snapshot. Other baseline
preferences are preserved: keep host-specific choices out of that baseline
when they should not enter the shared snapshot. Review the snapshot diff; the
GUI filter is a denylist, not a guarantee of portability or privacy.

An empty or missing `settings.toml` produces the baseline snapshot without store paths. Clearing an
override therefore restores the baseline value in the next snapshot instead
of deleting that preference. The previous destination file is not merged in;
each snapshot is rebuilt from the current baseline and pruned GUI overrides.
Malformed or missing baseline config and malformed GUI settings leave the
previous snapshot intact. Native `config export` merges unfiltered overrides;
filtering that result would lose a baseline value hidden by a rejected local
override, so this helper prunes first to implement the model above.

Explicit Nix choices still win when the snapshot is used for the next build.
Raw settings/state stay under `${XDG_STATE_HOME:-~/.local/state}/mynoctalia/noctalia`.
The manual snapshot command uses its package's baseline and state directory;
hooks inherit the running shell's configuration/state roots. Rebuild and switch
before using a new package's baseline. Use Nix fetchers for durable baseline assets.

The NixOS module runs `mynoctalia` through the upstream Noctalia user service,
bound to `umbriel-session.target`. The standalone Umbriel package autostarts
Noctalia; the NixOS Umbriel package leaves startup to the service.

Run `noctalia-reset-overrides` to remove fields from local `settings.toml` that
are defined in the package's generated `config.toml`. Tables are compared
recursively; arrays and scalar values are removed as whole fields. Values do
not need to match. Fields absent from `config.toml` remain, and the portability
filter is not involved. Reset only edits `settings.toml`.
The next snapshot retains the baseline values for fields removed by reset.

The systemd service runs this reset before every start, including login,
manual restarts, crash restarts, and restarts during a rebuild switch. It uses
the same package as the shell being started, so the new baseline takes effect
before Noctalia reads its settings. Save GUI preferences to the snapshot before
rebuilding if you want them included in that baseline. Reset does not write the
snapshot. Standalone launches still use the manual reset command.

`nixos-rebuild switch` (or `test`) restarts a changed Noctalia user service using
the pinned NixOS switch implementation. A build alone does not affect the
running desktop. To restart manually, use `systemctl --user restart noctalia`.
Noctalia's native `shell.launch_apps_as_systemd_services` setting is enabled so
launcher/dock/taskbar applications survive shell restarts; `systemd-run` is
bundled. Disabling that setting can cause those applications to stop with the
shell service.

When migrating from compositor autostart, an already-running Noctalia instance
causes service startup to be skipped. Log out and back in once after switching
to complete that migration. Subsequent changes do not require logout or reboot.

The Nix wallpaper uses `wallpaper.default.path`. Saved
`wallpaper.monitors.<connector>.path` selections take precedence over that
default and survive the selective reset. To replace them on connected outputs,
use the wallpaper picker's ALL view or `noctalia msg wallpaper-set <path>`.

## Umbriel

`myumbriel.settings` generates its TOML directly. No checkout includes or live
configuration machinery. Rebuild and restart the session after changing it.

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

The default `myumbriel.qtengineSettings.theme.colorScheme` is
`~/.local/share/color-schemes/noctalia.colors`. The pinned qtengine expands `~`
but not environment variables in this field (confirmed in its implementation).
For a custom `XDG_DATA_HOME`, override this setting with the corresponding path.
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
nix build 'path:.#nixosConfigurations.heliosdesk.config.system.build.toplevel' 'path:.#nixosConfigurations.heliosmac.config.system.build.toplevel' --no-link
```

Checks test pruning before merging, empty/missing GUI overrides, snapshots after
reset, a simulated snapshot/rebuild roundtrip, inherited hook paths, invalid
input preservation, and actual CLI precedence.
The Umbriel check also runs a Qt6 application offscreen to verify that the bundled
qtengine plugin loads its generated JSON and applies a simulated color scheme,
and checks GTK's actual theme loader against both bundled theme variants.
The GTK hook check renders the upstream GTK templates through the Noctalia CLI
on a private D-Bus with a fresh home and an empty PATH, checks dconf light/dark
selection, and verifies existing CSS survives without duplicate imports.
These are not live desktop/GUI tests and do not trigger a real shutdown or system
activation.
