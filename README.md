<p align="center">
  <img src="https://www.svgrepo.com/show/373927/nix.svg" width="20%">
</p>

# Nix Config

## Setup

TODO

## Deploy

`nixos apply`

# Overview

## Portable OpenCode v2

```sh
nix run .#myopencode
nix run .#myopencode -- mcp list
```

`myopencode` wraps `llm-agents.packages.${system}.opencode2` with
nix-wrapper-modules. It includes **Playwright MCP and its matching browsers**, packaged by Nix,
for browser automation. No npm installation or API key
is needed for the MCP server itself. Authenticate your AI provider normally:

```sh
nix run .#myopencode -- auth login
```

Playwright runs headlessly with an isolated browser profile, so it works without
a graphical session and does not persist browser logins between sessions.

The wrapper supplies default configuration through `OPENCODE_CONFIG`. An explicit
`OPENCODE_CONFIG` overrides that default; ordinary user/project configuration and
credentials continue to use OpenCode's normal locations. OpenCode updates are
managed through the flake rather than self-update.

OpenCode v2 normally reuses a background service. After changing this wrapper's
configuration, quit the UI and restart the service through the wrapper:

```sh
nix run .#myopencode -- service restart
```

For a private server tied to the current editor session instead:

```sh
nix run .#myopencode -- --standalone
```

The NixOS `development` bundle installs the `myopencode` executable. Package and
MCP settings live in `modules/features/development/ai.nix`. The smoke test checks
OpenCode's MCP connection, browser startup, JavaScript execution, and snapshots:

```sh
nix build .#checks.x86_64-linux.myopencode --no-link -L
```

## Portable Neovim

```sh
nix run .#myneovim
nix run .#myneovim -- path/to/file.nix
```

`myneovim` is a self-contained editor built with nix-wrapper-modules, using a
Kickstart.nvim-derived configuration. Nix supplies plugins, compiled Treesitter
parsers, language servers, formatters, and search tools. No Mason or plugin-manager
installation is needed on first launch. It uses its own `myneovim` data/cache/state
directories and ignores your existing Neovim configuration.

The same package is installed as `nvim` by the NixOS `development` module.

| Language | LSP | Formatter |
| --- | --- | --- |
| Nix | nixd | Alejandra |
| Lua | lua-language-server | StyLua |
| Python | Pyright | Ruff |
| Go | gopls | gofmt |
| Rust | rust-analyzer | rustfmt |
| JavaScript / TypeScript | typescript-language-server | prettierd |

Project dependencies still belong to the project (for example, its Python virtual
environment or Cargo dependencies). Clipboard access uses the host's graphical
session when available; the editor also works in a terminal over SSH.

### Project tooling and fallback versions

The wrapper **appends** its tools to `PATH`. Tools inherited from a Nix dev shell,
an activated virtual environment, or a version-manager shim take precedence over
the bundled fallbacks. This applies to language servers and formatters as well as
compilers/runtimes. An installed but broken tool is not silently replaced by a
different version.

The editor owns its UI, plugins, and syntax parsers. Projects own their dependency
environments and toolchain requirements. The fallback versions are pinned by this
repository's `flake.lock`; they are useful for standalone editing, not a guarantee
of compatibility with every project.

#### Python and uv

From a uv project directory:

```sh
uv sync
nix run "$HOME/.config/nixos#myneovim" -- .
```

Pyright selects an interpreter in this order:

1. An explicitly configured LSP `python.pythonPath`.
2. An activated `VIRTUAL_ENV` or `CONDA_PREFIX`.
3. `UV_PROJECT_ENVIRONMENT`, if set and created.
4. The project's `.venv`, searching ancestors up to the repository boundary for
   shared uv workspace environments.
5. `python3` on the inherited `PATH`, then the bundled fallback.

Pyright runs as a separate language-server process, but uses the selected Python
environment to resolve imports and installed packages. Ruff is taken from that
environment when installed there, otherwise from `PATH`. Pyright's project config
(`pyrightconfig.json` or `[tool.pyright]`) still controls analysis settings.

`uv sync` is responsible for provisioning the Python version and packages specified
by the project. The editor doesn't create/sync environments or install packages on
opening a file. A `.python-version` file alone isn't an installed environment.

Automatic interpreter discovery is **per LSP workspace**, not global shell
activation. To also make `:terminal`, `:!python`, and other child processes inherit
the project's Python environment, launch the editor through uv:

```sh
uv run nix run "$HOME/.config/nixos#myneovim" -- .
```

For an existing environment without uv's automatic sync, use `uv run --no-sync`.
After creating/replacing an environment while the editor is running, reopen the
editor so the Python language server discovers it afresh. Inspect the
selected interpreter using:

```vim
:lua =vim.lsp.get_clients({name='pyright', bufnr=0})[1].config.settings.python.pythonPath
```

#### Rust and rustup

Put rustup's shims on your shell's `PATH` (usually `$HOME/.cargo/bin`). In a project
with `rust-toolchain.toml`, provision the selected toolchain and components:

```sh
rustup show
rustup component add rust-src rustfmt rust-analyzer
nix run "$HOME/.config/nixos#myneovim" -- .
```

Cargo metadata, rust-analyzer startup, and rustfmt run in the relevant project
directory, allowing rustup to honor `rust-toolchain.toml`, directory overrides,
and `RUSTUP_TOOLCHAIN`. Missing rustup components should be installed for the
selected toolchain; a rustup shim on `PATH` takes precedence over bundled tools.

The editor no longer sets a global `RUST_SRC_PATH`. Bundled standard-library
sources are supplied to rust-analyzer only when its selected compiler is the
bundled rustc. Other toolchains discover their own sources, and an inherited
`RUST_SRC_PATH` is preserved. `Cargo.toml`'s `rust-version` alone does not select a
compiler; use rustup or a project development environment for that.

#### Go

Launch from a shell with the desired Go installation or version-manager shims on
`PATH`. gopls inherits that environment and starts in the project root. Formatting
uses `go env GOROOT` from the file's directory to locate the matching `gofmt`.

Go's own `GOTOOLCHAIN` mechanism handles `go.mod`/`go.work` `go` and `toolchain`
directives. With automatic selection enabled, Go may download a required newer
toolchain. Run `go version` / `go env GOROOT` in the project first to provision and
inspect it. A `go` directive isn't an exact version pin; use `GOTOOLCHAIN` or a
version manager/dev shell when an exact version is required. The editor preserves
your `GOTOOLCHAIN`, `GOROOT`, `GOPATH`, and proxy settings.

#### Nix development shells

Inside any project's shell:

```sh
nix develop
nix run "$HOME/.config/nixos#myneovim" -- .
```

The project shell's tools win over editor fallbacks. Shell environments are
inherited at launch; opening another directory doesn't automatically enter its
Nix shell or activate direnv. Launch a new editor from the appropriate environment
when switching between projects with different shell-level requirements.

Project discovery is implemented in
`modules/features/development/neovim/lua/project-tools.lua`. Offline integration
checks cover real uv and rustup projects plus inherited Go tooling:

```sh
nix build .#checks.x86_64-linux.myneovim .#checks.x86_64-linux.myneovim-projects --no-link -L
```

The leader key is **Space**:

- `<leader>sf`: find files; `<leader>sg`: search text; `<leader>sh`: search help.
- `gd`: definition; `grr`: references; `grn`: rename; `gra`: code action; `K`: hover.
- `<leader>f`: format the buffer or selection (no automatic format-on-save).
- `Ctrl-Space`: completion menu; `Ctrl-n`/`Ctrl-p`: select; `Ctrl-y`: accept.
- `:checkhealth vim.lsp`: inspect language-server health.

Edit `modules/features/development/neovim/init.lua` for editor behavior and
`modules/features/development/neovim.nix` for plugins/tools. Rerun the command to
rebuild with your changes. Plugins and tools are pinned through `flake.lock`.
