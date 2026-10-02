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
- Noctalia v5: https://docs.noctalia.dev/noctalia/configuration/ — TOML layers, GUI settings versus runtime state, includes, and hot reload. Hooks: https://docs.noctalia.dev/noctalia/automation/hooks/
- Tomli-W: https://github.com/hukkin/tomli-w — TOML serialization for filtered preference exports.

## Wrapper reference

- Noctalia wrapper: https://nix-community.github.io/nix-wrapper-modules/wrapperModules/noctalia-shell.html
- Review `settings`, `outOfStoreConfig`, and `autoCopyConfig` together before implementing writable settings. The module provides configuration generation and non-overwriting runtime copying; evaluate those facilities before adding custom copy logic.
