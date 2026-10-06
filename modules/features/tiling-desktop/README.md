# Desktop configuration

## Noctalia

The flow is:

```
local settings.toml → filter script → synced.toml
                                      ↓
                         deep merge with Nix settings
                                      ↓
                            generated config.toml
```

Run `noctalia-sync-preferences` to replace `noctalia-v5/synced.toml` with filtered
GUI settings. Noctalia's logout/reboot/shutdown session hooks run the same command.
Those hooks do not cover crashes, compositor exits or shutdowns outside Noctalia.
The package's `syncFile` wrapper option selects the destination; its default is
this repo under `$HOME/.config/nix-config`. The NixOS module installs
`self.packages.<system>.mynoctalia` directly, and Umbriel references that same
package for autostart and IPC. No `liveConfig` dependency or runtime links.

The filter removes monitor layouts/selectors, local paths, credentials, hooks
and identified bookkeeping. Other preferences and Nix store paths remain.
Review the diff: this is a denylist, not a guarantee of portability or privacy.
The export replaces the previous snapshot; absent GUI keys disappear, including
keys Noctalia removed because they matched the baseline. It does not accumulate
historical preferences. Keep durable choices in Nix `settings` when appropriate.

Nix uses `lib.recursiveUpdate synced settings`: explicit Nix values win, nested
tables merge, and lists replace. Local GUI overrides still win at runtime.
Raw settings/state stay under `${XDG_STATE_HOME:-~/.local/state}/mynoctalia/noctalia`.
Rebuild and restart Noctalia to load a new generated baseline. Store-path strings
do not keep assets alive; prefer Nix fetchers in `settings` for portable assets.

## Umbriel

`myumbriel.settings` generates its TOML directly. No checkout includes or live
configuration machinery. Rebuild and restart the session after changing it.

## Application theming

GTK uses the system-installed `adw-gtk3` theme. Home Manager selects it through
dconf on activation; Noctalia's GTK templates can subsequently change the mode.
No `nwg-look` step is required. Enable GTK 3/4 templates in Noctalia if desired.

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
also need their own plugin/theme access. GTK dconf activation remains NixOS/Home
Manager integration rather than part of the portable Umbriel package.

References: [Noctalia GTK/Qt guide](https://docs.noctalia.dev/noctalia/templates/official/gtk-qt/)
and [qtengine 0.2.2](https://github.com/kossLAN/qtengine/tree/0.2.2).

## Validation

```
nix build 'path:.#checks.x86_64-linux.mynoctalia' 'path:.#checks.x86_64-linux.myumbriel' --no-link
nix build 'path:.#nixosConfigurations.heliosdesk.config.system.build.toplevel' --no-link
```

Checks test filtering, snapshot replacement and the actual CLI configuration.
The Umbriel check also runs a Qt6 application offscreen to verify that the bundled
qtengine plugin loads its generated JSON and applies a simulated color scheme.
These are not live desktop/GUI tests and do not trigger a real shutdown or system
activation.
