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
`wrappers.mynoctalia.syncFile` selects the destination; its default is this repo
under `$HOME/.config/nix-config`. No `liveConfig` dependency or runtime links.

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

## Validation

```
nix build 'path:.#checks.x86_64-linux.mynoctalia' 'path:.#checks.x86_64-linux.myumbriel' --no-link
nix build 'path:.#nixosConfigurations.heliosdesk.config.system.build.toplevel' --no-link
```

Checks test filtering, snapshot replacement and the actual CLI configuration;
they do not launch a GUI or trigger a real shutdown. No system activation.
