# Pi adapter

`flake.wrappers.pi` adapts the pinned Pi package (currently 1.0.4). The input
already embeds both Bun workers, so the former 0.99.1 package workaround is gone.
The configured `mypi` package lives in `modules/features/pi-agent/`.

## Configuration and extensions

- `agentDir` selects the writable agent directory and derives `sync.defaultDir`.
  It defaults to Pi's native `${HOME}/.pi/agent`. The wrapper sets
  `PI_CODING_AGENT_DIR` unconditionally so discovery, sync, and snapshots agree.
  To choose another location, override `agentDir` on the wrapper; a caller's
  `PI_CODING_AGENT_DIR` does not redirect this configured package.
- `settings` and `keybindings` produce native `settings.json` and
  `keybindings.json` files, even when the declared layer is empty. Sync merges
  saved baselines and declared values into writable files on every launch.
  Runtime-only keys survive; explicit Nix values reapply. Choose other triggers
  in the feature if declared preferences should remain editable across launches.
- `extensions` accepts packaged extension files/directories. Explicit CLI
  extension arguments preserve native behavior with `--no-extensions` and avoid
  replacing Pi's user-installed package list. Subcommands are kept first in argv.
- Optional `chromeDevtools.server` accepts a packaged `chrome-devtools-mcp`
  executable, including the feature's chosen browser. The adapter registers it
  through Pi's native extension API and passes the writable
  `chrome-devtools.json` generated from `chromeDevtools.settings` via `--config`.
  CLI browser selection stays in the supplied server package.

Pi's documented agent-directory environment variable provides native discovery;
no directory mappings or Home Manager evaluation are necessary. Project config
and trust rules remain Pi's own. Extension implementation files stay in the Nix
store; writable preferences use sync. Restart Pi (or use native `/reload` where
supported) after edits; Nix/plugin/code changes require rebuilding.

Sync defaults on. Snapshot export defaults off in this generic adapter and is
turned on by the feature. As with the shared addon, disabling sync means the
caller must provide the runtime files. Low-level sync path overrides must remain
aligned with Pi's native file discovery.

## Snapshot review

Only `settings.json`, `keybindings.json`, and the optional
`chrome-devtools.json` are captured. Authentication, MCP/model endpoint files,
project trust, sessions, and history are not snapshot inputs.

Settings retain model/thinking, UI, terminal, tool, and interaction preferences.
The adapter removes `lastChangelogVersion`, `trackingId`, and `deviceId` (generated
state/identifiers), `sessionDir` and `httpProxy` (private runtime locations), shell
and editor commands, and resource declarations (`packages`, `extensions`,
`skills`, `prompts`, `themes`). Resource lists can contain local paths or private
repositories; keep portable declarations in the feature. Store paths are also
pruned. Whole resource arrays are deliberately omitted; ordinary preference
arrays retain their order. A store value in any other array removes that whole
array under the shared engine's rules.

Browser snapshots retain headless/isolation, viewport, tool-category, and similar
preferences. They omit endpoint URLs, WebSocket headers, profile/executable/log
paths, proxies, browser arguments, filesystem roots, and ffmpeg paths, including
documented hyphenated aliases. Packaged executable wiring is regenerated.
Keybindings contain action/key mappings and need no state pruning.

The independent `checks.pi-wrapper` fixture runs the real offline CLI/RPC with
isolated HOME/XDG paths, including spaces. It verifies native settings discovery,
explicit extensions, subcommand argument order, snapshot capture without startup
sync, synthetic private-field pruning, whole resource-array removal, and a fresh
runtime restored from captured settings with explicit Nix settings winning.
Browser pruning uses a simulated server; the feature check exercises real
Chromium/MCP and codemode with a simulated model response. These are automated
CLI/headless checks, not an interactive TUI save/reload test.

## References

Read the pinned package's `README.md` and `docs/{configuration,settings,packages,
keybindings,environment-variables,cli,rpc}.md` for Pi's configuration contract.
The settings implementation additionally identifies `trackingId`, `deviceId`,
and `lastChangelogVersion` as generated fields.

Chrome DevTools MCP's pinned npm README links its
[versioned configuration guide](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/chrome-devtools-mcp-v1.10.1/docs/configuration.md),
which documents `--config` and the option aliases used by pruning.

The feature baseline was captured using the real snapshot command after an
isolated `--version` launch, with a copy of the existing user `settings.json`.
Review retained only model/provider selection, theme, cursor, and TUI preferences;
`lastChangelogVersion` was removed. Keybindings were empty. Browser settings
retained the four declared headless/isolation/privacy preferences. Credentials,
sessions, and the live runtime directory were not copied or changed. The retained
`noctalia` theme name depends on the external theme file generated by Noctalia;
that theme asset is not part of this preference snapshot.

The captured feature baseline was rebuilt into `mypi` and loaded by the real Pi
RPC process in another fresh HOME/XDG environment. All three files matched the
reviewed preferences; no model request was made. Both affected NixOS systems,
`heliosdesk` and `heliosmac`, were built without activation.
