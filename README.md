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
MCP settings live in `modules/features/development/opencode.nix`. The smoke test checks
OpenCode's MCP connection, browser startup, JavaScript execution, and snapshots:

```sh
nix build .#checks.x86_64-linux.myopencode --no-link -L
```

## Local LLM over Tailscale

The `local-llm` feature on `heliosdesk` serves **Qwen3 8B Q4_K_M** using
`ollama-cuda`. It is sized for the RTX 3080 Ti's 12 GiB VRAM: ~5.2 GB weights,
32K context, Flash Attention, Q8 KV cache, and one concurrent request/model.
Requests from multiple hosts queue; idle models unload after five minutes.
GPU residency and speed still depend on other desktop/GPU workloads.

`meta.localLLM` in `modules/meta.nix` is the shared source for the serving host,
model, port, context/output limits, and OpenCode endpoint. Only the desktop
imports the server feature; every `myopencode` wrapper includes its provider.

Apply on `heliosdesk` with `nixos apply`. The model loader downloads the model
on service startup (allow ~5.2 GB disk space plus runtime storage):

```sh
journalctl -u ollama-model-loader -f
ollama list
```

Both hosts must be signed into the tailnet, with MagicDNS enabled and Tailscale
policy allowing TCP 11434 to `heliosdesk`. The NixOS firewall opens this port
only on the Tailscale interface. The API has no separate authentication;
tailnet peers allowed by that policy can also manage Ollama models.

From any connected host:

```sh
curl http://heliosdesk.li-taipan.ts.net:11434/api/tags
nix run .#myopencode -- run --model ollama/qwen3:8b-q4_K_M "Say hello"
```

Or select the model with `/models`. Restart an existing OpenCode background
service after updating the wrapper. For an independently installed OpenCode v2,
add this to `~/.config/opencode/opencode.jsonc`:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "providers": {
    "ollama": {
      "settings": {
        "baseURL": "http://heliosdesk.li-taipan.ts.net:11434/v1"
      },
      "models": {
        "qwen3:8b-q4_K_M": {
          "capabilities": { "tools": true, "input": ["text"], "output": ["text"] },
          "limit": { "context": 32768, "output": 8192 }
        }
      }
    }
  }
}
```

During inference, use `ollama ps` on the desktop to verify `100% GPU` and
`nvidia-smi` to inspect VRAM usage. Service logs are available with
`journalctl -u ollama`. If gaming or other GPU workloads force CPU offload,
reduce `meta.localLLM.contextLength` and rebuild. Model tags are fetched at
deployment time by Ollama, independently of `flake.lock`.

### Hybrid agent workflow

The wrapper adds an optional, experimental **`local-summary`** subagent backed
by `meta.localLLM.model` over Tailscale. It replaces `local-scout`: local testing
found citation errors and repeated search failures, so general repository
discovery is no longer its role. Its `fast` variant disables Qwen3 thinking.
It has only the read tool and a four-step budget, for low-consequence extraction
or summaries of explicitly named files when requested.

Keep a capable cloud model selected for the primary Build/Plan agent. Use it
for architecture, implementation, debugging, and final verification. Prefer its
direct, targeted search/read tools for ordinary lookups.
The built-in `explore` and `general` agents retain their normal model inheritance
for harder research. The primary model is still your choice through `/models`.

Example delegation:

> Use local-summary to read modules/meta.nix, lines 66–74, and extract the
> configured model, port, and context length with short verbatim excerpts.
> Verify the findings before using them.

Recommended session guidance:

> Use direct tools for routine lookups. Reserve local-summary for explicitly
> requested summaries of known files. Use stronger agents for independent
> investigations or reviews only when the extra work is justified.

The opt-in guidance is in the agent description; it is model-driven routing,
not an enforced approval mechanism. Child sessions start fresh, so supply exact
paths and a concrete question. Local inference avoids API charges for the child,
but delegation, verification, and retries still consume primary-model tokens.
Net cost savings and end-to-end speed improvements have not been demonstrated.
Compare correctness, cloud token usage, total latency, and retries on real tasks
before expanding its role. The local server serializes inference: parallel local agents add
queueing, and first use after idle includes model-loading time. If the desktop
is offline, use the regular agents; there is no automatic cloud fallback.

Try the updated wrapper with `nix run .#myopencode`; after installing it through
`nixos apply`, restart its background service with `myopencode service restart`.
The fast model variant is also selectable explicitly as
`ollama/qwen3:8b-q4_K_M#fast`.

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
