# Pi agent

`mypi` uses nix-wrapper-modules to wrap
`inputs.llm-agents.packages.${system}.pi` and provides the `pi` executable.
Pi is pinned to 0.99.1, which includes native MCP support. The `pi-agent` NixOS
feature is enabled by the workstation profile.

```sh
nix run .#mypi
# Or install through the system configuration:
nixos apply
pi
```

Authenticate with Pi's `/login` or your provider's usual environment variables.
Settings, credentials, and sessions use Pi's normal `~/.pi/agent` directory
(or an explicit `PI_CODING_AGENT_DIR`).

## Bundled plugins

| Package | Version | Purpose |
| --- | --- | --- |
| `pi-web-access` | 0.34.0 | Web search and extraction; `/websearch` |
| `@juicesharp/rpiv-ask-user-question` | 2.12.0 | Structured `ask_user_question` tool |

Nix installs the plugins and their locked npm dependencies at build time. They
load from the store via `--extension`; no `pi install` is needed. `pi list` and
`pi config` manage additional user-installed packages, not this bundled set.
Use `pi --verbose` to see startup resources. Bundled extensions remain explicit
even with `--no-extensions`, which only disables automatic discovery.

Web access supports keyless Exa search. Additional provider settings go in
`~/.pi/web-search.json`, as documented by pi-web-access.

## Chrome DevTools MCP

The wrapper also bundles `chrome-devtools-mcp` 1.10.1 and nixpkgs Chromium,
including the browser's runtime dependencies. No `npx`, browser download, or
separately installed Chrome is needed at launch. Both Pi and the MCP server
are wrapped with nix-wrapper-modules.

Open `/mcp` **inside Pi** to see `chrome-devtools`. Its tools are available
through Pi's built-in `codemode` support. For example, ask Pi to open a page,
inspect its console, or take a screenshot.

The bundled `config/chrome-devtools.ts` extension registers the server through
Pi's native `registerMcpServer` API. The wrapper supplies the server executable
path automatically. Pi's shell-level `pi mcp list` only lists file-configured
servers; it does not load extensions. User/project `mcp.json` entries named
`chrome-devtools` override this registration.

Browser settings live in `config/chrome-devtools.json`. Defaults are headless
mode and a temporary isolated profile, with usage statistics and CrUX requests
disabled. The browser sandbox stays enabled. The MCP wrapper pins the browser
executable and disables npm update checks.

The files in `config/` use `liveConfig.link`. With live config enabled, edit
them and restart Pi or use `/reload` without rebuilding. For example, change
`headless` to `false` to show the browser in a graphical session. With live config
disabled, they are bundled as a store snapshot. Package/browser updates and
Nix-generated executable paths still require a build.

## Context7 MCP

`config/context7.ts` registers the official remote server at
`https://mcp.context7.com/mcp` through Pi's native MCP API. Its documentation
lookup tools are exposed directly. No local server or npm install is required.
Anonymous access works at lower rate limits; optionally export
`CONTEXT7_API_KEY` before launching Pi for authenticated access. The key is read
at runtime and is never embedded in the Nix store.

Restart Pi or use `/reload`, then inspect `context7` in `/mcp`. As with Chrome
DevTools, this extension registration is not listed by shell-level `pi mcp list`.
A user/project `mcp.json` entry named `context7` overrides the bundled registration.
See [Context7's Pi guide](https://context7.com/docs/clients/pi).

## Updating and checking

Pi and Chromium follow `flake.lock`. Plugin and MCP server versions and resource entry points are
in `plugins/package.json`; transitive dependencies are pinned in
`plugins/package-lock.json`.

After changing plugin versions, regenerate the lock from this repository:

```sh
nix shell --inputs-from . nixpkgs#nodejs -c npm install \
  --prefix modules/features/pi-agent/plugins \
  --package-lock-only --ignore-scripts --legacy-peer-deps --no-audit --no-fund
```

Update `npmDepsHash` in `default.nix` (set it to `lib.fakeHash`, build, then
use the reported actual hash). Plugin updates require a rebuild.

```sh
nix build .#checks.x86_64-linux.mypi --no-link -L
```

The offline check verifies Context7 registration with and without a runtime key;
it disables the remote connection via a test-only `mcp.json` override. It also
verifies both plugins, Pi's native MCP connection, browser
startup, JavaScript execution, snapshots, and screenshots. It uses a config
snapshot even when live config is enabled. Only the build-sandbox test variant
passes `--no-sandbox` to Chromium, because nested browser namespaces are not
available there.
