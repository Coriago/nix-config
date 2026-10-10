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

## Documentation references

- Consult [docs/references.md](docs/references.md) for relevant official websites. Add useful sites there, rather than expanding this file.
- Use Context7 for library/API documentation when available: resolve the library ID, then query the relevant version. Fetch full official pages as needed; snippets do not replace complete documentation reads.

## Wrapper standard

- Follow [docs/wrappers.md](docs/wrappers.md) when creating or adapting wrappers. The current reference is OpenCode; the original portable-mutability proposal is historical.
- `wrapperModules/` extends/adapts upstream wrapper modules or creates new ones. Put application behavior, config discovery, fixed paths, missing settings options, and reusable plugin configuration interfaces here. Do not put personal preference values or chosen runtime config directories here.
- `modules/features/` consumes generic wrapper modules. This is the main user interface: keep it clean, declaring preferences, runtime directories, plugins, and runtime libraries/tools. Move reusable plugin wiring into wrapper options when it would complicate the feature.
- Shared mechanisms belong in `lib/`, imported through `locallib` (currently `sync-snap` and `directory-mappings`). Use custom wrapper modules directly; do not introduce Home Manager evaluation for this pattern.
- Include `locallib.sync-snap` in new wrapper adapters by default and set `sync.enable = lib.mkDefault true` when delivering configuration. Enable `snapshot.enable` in their configured features by default; keep it disabled in generic adapters. If sync or snapshot is a poor fit, document the specific application limitation and omit or constrain that part. Sync and snapshot are independent. Do not retroactively migrate unrelated existing wrappers without a request.
- Application-specific snapshot pruning defaults belong in `wrapperModules/`: known state fields, private information, credentials, and nonportable generated values. Feature-specific exceptions belong in the feature.
- When implementing a wrapper whose feature enables snapshots, run its snapshot command at the end, inspect the output, refine pruning, and verify the retained baseline. Follow [docs/snapshot-review.md](docs/snapshot-review.md). Use isolated runtime data first; do not expose secrets in tool output or automatically stage/commit exports. Report unavailable runtime/GUI validation explicitly.
- Keep sync/snapshot option and engine details in [lib/sync-snap](lib/sync-snap/README.md) and [packages/sync-snap](packages/sync-snap/README.md); the wrapper guide should remain a concise creation/use workflow.
