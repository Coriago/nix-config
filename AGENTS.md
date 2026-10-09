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
- Do not create a repository-root `tests/` directory. Keep tests beside the module or application they cover: use `check.nix` for a single-file check, or a local `checks/` directory when multiple files are needed.

## Useful documentation sites

- Add official documentation sites to this list whenever they prove useful during a task. Include a short description, prefer canonical URLs, and avoid duplicate entries.
- nix-wrapper-modules: https://nix-community.github.io/nix-wrapper-modules/ — wrapper options, integration, and examples.
- flake-parts: https://flake.parts/options/flake-parts.html — `perSystem` options and conventional `apps` outputs; prefer the pinned modules' option documentation.
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
- Home Manager file behavior: https://nix-community.github.io/home-manager/index.xhtml#sec-usage-dotfiles-advanced — out-of-store links, directory linking, collision handling, and activation hooks.

- qtengine: https://github.com/kossLAN/qtengine — KDE-compatible Qt platform theme; README covers JSON configuration and `QTENGINE_CONFIG`.
- GTK theme discovery: https://docs.gtk.org/gtk3/class.CssProvider.html — theme search precedence and `GTK_DATA_PREFIX`; https://docs.gtk.org/gtk3/running.html — runtime environment variables and their limits.
- Umbriel portal: https://github.com/noctalia-dev/xdg-desktop-portal-umbriel — screen capture interfaces, share picker, and backend configuration.
- Noctalia Greeter sync: https://docs.noctalia.dev/greeter/sync/ — appearance synchronization and the NixOS passwordless Polkit authorization option.

- Alacritty: https://alacritty.org/ — configuration, release history, and links to versioned feature and escape-sequence documentation.
- kitty: https://sw.kovidgoyal.net/kitty/ — terminal features, shell integration, performance methodology, protocols, and multiplexer caveats.
- Ghostty: https://ghostty.org/docs/ — terminal features, versioned release notes, Linux integration, configuration, and terminfo troubleshooting.
- Ghostty keybindings: https://ghostty.org/docs/config/keybind — trigger prefixes, conditional consumption with `performable:`, and explicit `unbind` actions. CLI binding listings can omit flags; preserve native defaults when disabling selected shortcuts.
- Noctalia app theming: https://docs.noctalia.dev/noctalia/theming/app-theming/ — supported applications, writable theme files, and apply/reload hooks.
- Herdr: https://herdr.dev/docs/ — terminal multiplexer configuration, graphics support, keyboard handling, and session persistence.

- Dolphin: https://docs.kde.org/stable_kf6/en/dolphin/dolphin/ — file management, remote protocols, panels, and preferences.
- KIO-FUSE: https://github.com/KDE/kio-fuse — remote-file access for applications without KIO support and D-Bus activation.
- Thunar: https://docs.xfce.org/xfce/thunar/start — file manager features, plugins, preferences, and GVfs requirements for remote storage.
- GVfs: https://wiki.gnome.org/Projects/gvfs/doc — on-demand backends, session requirements, and FUSE access to remote mounts.
- GNOME Files remote storage: https://help.gnome.org/gnome-help/nautilus-connect.html — server connections and supported network protocols.

## Wrapper reference

- Bubblewrap: https://github.com/containers/bubblewrap — per-process directory bind mounts; consult the pinned version's `bwrap.xml` for namespace and mount behavior.

- OpenCode v2 CLI config: https://opencode.ai/v2/docs/cli/config — native `cli.json` location, theme preferences, runtime updates, and inline overrides.

- Rust file locks: https://doc.rust-lang.org/std/fs/struct.File.html#method.try_lock — advisory OS locks, contention, and release on handle closure.
- tempfile: https://docs.rs/tempfile/latest/tempfile/struct.NamedTempFile.html — atomic persistence, permission defaults, and explicit durability requirements.
- Rust packaging: https://nixos.org/manual/nixpkgs/stable/#rust — `buildRustPackage`, Cargo lockfile vendoring, and build/check hooks; prefer the pinned nixpkgs copy of this manual.
- sync-snap: [packages/sync-snap/README.md](packages/sync-snap/README.md) — Rust sync/snapshot CLI, manifest schema, launch behavior, locking/cache, and validation limits.

- jq: https://jqlang.org/manual/ — filter output semantics, structured paths, `del`, and `delpaths` for snapshot transformations.

- hm-wrapper-modules: https://github.com/sini/hm-wrapper-modules — Home Manager output extraction and bubblewrap presentation; generated config is read-only by default, and compatibility with the pinned HM/wrapper libraries must be checked.

- Brave policies: https://support.brave.app/hc/en-us/articles/360039248271-Group-Policy — fixed Linux policy directories and versioned templates. Chromium preferences: https://www.chromium.org/administrators/configuring-other-preferences/ — recommended policies versus one-time initial preferences.
- Bitwarden browser setup: https://bitwarden.com/help/browserext-deploy/ — extension deployment; https://bitwarden.com/help/disable-browser-autofill/ — default-manager permission and built-in autofill limitations.
- Chrome extension policies: https://support.google.com/chrome/a/answer/9867568 — `ExtensionSettings`, automatic installation modes, and toolbar pinning.
- Chrome external extensions: https://developer.chrome.com/docs/extensions/how-to/distribute/install-extensions — generated JSON manifests, update URLs, and uninstall behavior; Home Manager's Brave module uses user-level manifests.
- Home Manager Chromium/Brave: https://github.com/nix-community/home-manager/blob/master/modules/programs/chromium.nix — option descriptions for extensions, native messaging, dictionaries, and `finalPackage`; read the pinned local module before adapting its generated file layout. It currently has no native browser-preferences `settings` option.

- Repository standard: [docs/wrappers.md](docs/wrappers.md) — configuration ownership, portable defaults, live sources, GUI writeback, module example, and validation. Follow it for new wrappers and incremental changes; distinguish its proposed conventions from existing per-app behavior.
- Noctalia wrapper: https://nix-community.github.io/nix-wrapper-modules/wrapperModules/noctalia-shell.html
- Review `settings`, `outOfStoreConfig`, and `autoCopyConfig` together before implementing writable settings. The module provides configuration generation and non-overwriting runtime copying; evaluate those facilities before adding custom copy logic.
- The pinned `noctalia-shell` wrapper targets legacy JSON configuration. This repo's `mynoctalia` uses Noctalia v5 TOML layers; assess version compatibility before reusing the legacy options.
