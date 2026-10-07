# Agent instructions

## Documentation before implementation

- Before configuring or integrating a tool, library, or Nix module, gather and read its relevant documentation fully. Read the overview, options, defaults, caveats, examples, and relevant linked pages—not just search matches or a single option.
- Prefer documentation for the version pinned in this repository. Look locally first; if documentation is missing or incomplete, fetch the official online documentation. Always read documentation URLs supplied by the user.
- Continue reading truncated files or fetched pages until complete. Source-code inspection supplements documentation; it is not a substitute for reading the documentation.
- Prefer supported upstream options over custom scripts or reimplementing existing features. Explain any necessary deviation based on documented limitations and the pinned implementation.
- If documentation cannot be retrieved, say so rather than guessing. Distinguish documented behavior, implementation details, and assumptions.
- Validate the intended behavior with focused checks. Clearly distinguish builds, simulated tests, and actual application/GUI tests.
- When changing NixOS modules or packages used by them, also build the affected NixOS configurations (`nixosConfigurations.<host>.config.system.build.toplevel`), not just standalone output packages or flake checks. Package builds and evaluation alone do not validate system integration. Do not activate/switch the system merely to validate it; report any build failures or checks you could not complete.

## Repository boundaries

- Do not modify profiles or enable features on hosts unless explicitly requested. The user decides when to enable modules.
- Preserve unrelated working-tree changes and Git staging. Do not stage or reset files merely to run checks.

## Useful documentation sites

- Add official documentation sites to this list whenever they prove useful during a task. Include a short description, prefer canonical URLs, and avoid duplicate entries.
- nix-wrapper-modules: https://nix-community.github.io/nix-wrapper-modules/ — wrapper options, integration, and examples.
- Context7: https://context7.com/docs/ — documentation lookup and MCP setup; Pi integration: https://context7.com/docs/clients/pi
- Pi: https://github.com/earendil-works/pi/tree/main/packages/coding-agent/docs — agent configuration, extensions, and native MCP.
- Bun: https://bun.sh/docs/bundler/executables — standalone executable builds, worker entrypoints, and embedded assets.
- Use Context7 for library/API documentation when available: resolve the library ID, then query the relevant version. Fetch full official pages as needed; snippets do not replace complete documentation reads.

- Umbriel: https://docs.noctalia.dev/umbriel/ — compositor configuration, keybinds, and session startup.
- Niri: https://niri-wm.github.io/niri/ — compositor configuration, window management, screencasting, and application compatibility.
- Noctalia v5: https://docs.noctalia.dev/noctalia/configuration/ — TOML layers, GUI settings versus runtime state, includes, and hot reload. Hooks: https://docs.noctalia.dev/noctalia/automation/hooks/
- Tomli-W: https://github.com/hukkin/tomli-w — TOML serialization for filtered preference exports.
- Neovim LSP: https://neovim.io/doc/user/lsp.html — client capabilities, configuration merging, and file-watching defaults.
- inotifywait: https://man7.org/linux/man-pages/man1/inotifywait.1.html — recursive Linux file watching, events, and limitations.

- wdisplays: https://github.com/artizirk/wdisplays — display GUI; release README documents saving layouts to kanshi.
- kanshi: https://gitlab.freedesktop.org/emersion/kanshi — monitor-profile daemon; README and man pages cover configuration and reloads.

- Home Manager dconf: https://nix-community.github.io/home-manager/options.xhtml#opt-dconf.settings — declarative user settings; NixOS requires `programs.dconf.enable`.

- qtengine: https://github.com/kossLAN/qtengine — KDE-compatible Qt platform theme; README covers JSON configuration and `QTENGINE_CONFIG`.
- GTK theme discovery: https://docs.gtk.org/gtk3/class.CssProvider.html — theme search precedence and `GTK_DATA_PREFIX`; https://docs.gtk.org/gtk3/running.html — runtime environment variables and their limits.
- Umbriel portal: https://github.com/noctalia-dev/xdg-desktop-portal-umbriel — screen capture interfaces, share picker, and backend configuration.
- Noctalia Greeter sync: https://docs.noctalia.dev/greeter/sync/ — appearance synchronization and the NixOS passwordless Polkit authorization option.

- Alacritty: https://alacritty.org/ — configuration, release history, and links to versioned feature and escape-sequence documentation.
- kitty: https://sw.kovidgoyal.net/kitty/ — terminal features, shell integration, performance methodology, protocols, and multiplexer caveats.
- Ghostty: https://ghostty.org/docs/ — terminal features, versioned release notes, Linux integration, configuration, and terminfo troubleshooting.
- Noctalia app theming: https://docs.noctalia.dev/noctalia/theming/app-theming/ — supported applications, writable theme files, and apply/reload hooks.
- Herdr: https://herdr.dev/docs/ — terminal multiplexer configuration, graphics support, keyboard handling, and session persistence.

- Dolphin: https://docs.kde.org/stable_kf6/en/dolphin/dolphin/ — file management, remote protocols, panels, and preferences.
- KIO-FUSE: https://github.com/KDE/kio-fuse — remote-file access for applications without KIO support and D-Bus activation.
- Thunar: https://docs.xfce.org/xfce/thunar/start — file manager features, plugins, preferences, and GVfs requirements for remote storage.
- GVfs: https://wiki.gnome.org/Projects/gvfs/doc — on-demand backends, session requirements, and FUSE access to remote mounts.
- GNOME Files remote storage: https://help.gnome.org/gnome-help/nautilus-connect.html — server connections and supported network protocols.

## Wrapper reference

- Noctalia wrapper: https://nix-community.github.io/nix-wrapper-modules/wrapperModules/noctalia-shell.html
- Review `settings`, `outOfStoreConfig`, and `autoCopyConfig` together before implementing writable settings. The module provides configuration generation and non-overwriting runtime copying; evaluate those facilities before adding custom copy logic.
