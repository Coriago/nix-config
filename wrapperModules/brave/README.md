# Brave adapter checks

The adapter is in [brave.nix](brave.nix). Its [checks](checks/check.nix)
instantiate `flake.wrappers.brave` directly with synthetic preferences and runtime
locations; they do not depend on `packages.mybrave` or personal feature settings.

```sh
nix build path:.#checks.x86_64-linux.brave-wrapper-preferences \
  path:.#checks.x86_64-linux.brave-wrapper-isolation --no-link -L
```

`brave-wrapper-preferences` checks policy delivery, edits across restarts, writable
sync files, snapshot pruning, restoration to a different profile, and explicit
preference precedence. Captured preferences are checked explicitly; synthetic private and future fields
must be absent.

`brave-wrapper-isolation` launches actual headless Brave and compares
simultaneous wrappers with different profile paths, homepage and search settings.
Its contrast fixture adds Stylus and an inert prebuilt CRX extension. The CRX fixture is a packed Manifest V3
extension with no permissions, scripts or network access, version 1.0.0 and name
`Wrapper prebuilt extension fixture`. Its signing key is disposable and not
included. The check asserts actual local CRX installation, not only the manifest.

`BRAVE_TEST_NETWORK=1` enables the additional manual Web Store lifecycle check:
simulate Bitwarden's saved UI-removal blocklist in a disposable browser profile,
verify external installation respects it,
then relaunch under the required policy and verify Bitwarden and
Stylus are installed, enabled and required. Offline flake checks do not claim
Web Store download validation. These checks do not exercise interactive GUI
rendering, Bitwarden sign-in, or its default-manager permission prompt.

The [feature launch check](../../modules/features/brave/checks/check.nix) remains
with the feature and checks the assembled personal package can render a page.

## Snapshot review (Brave 1.97.56)

[preferences.jq](preferences.jq) captures ordinary settings-screen controls from
both Preferences and Local State. The reviewed list contains boolean toggles,
checkboxes and numeric selections exposed by the pinned browser's
`chrome.settingsPrivate.getAllPrefs()` API, plus native telemetry switches,
content defaults and selected text/list settings. The exact paths are checked in;
snapshotting does not launch Brave or query the UI. Unknown keys remain excluded.

This covers GTK/system appearance (`extensions.theme.system_theme`, GTK = 1),
bookmark-bar visibility, sponsored ads, toolbar/tabs/new-tab appearance, privacy,
autofill/password-manager switches, clearing-data choices, accessibility,
performance and other settings controls. Local State uses the same filter, so
browser-wide choices are not lost. In particular, it retains
`brave.p3a.enabled`, `brave.stats.reporting_enabled` and
`user_experience_metrics.reporting_enabled` without copying their counters,
identifiers or reporting payloads. `brave.web_discovery_enabled` is included too.

Neither `brave.accelerators` nor `brave.default_accelerators` is exported.
Keybindings are outside this baseline. A setting about a feature is distinct from
its data: password saving is retained, passwords are not; Wallet UI toggles are
retained, wallet contents are not; data-clearing checkboxes are retained, browsing
history is not. Exact leaf selection allows GTK appearance beneath `extensions`
without including extension state, accounts or credentials.

The schema review omits virtual `generated.*` settings, policy-only fields,
import-dialog choices, onboarding/queued notification state, CPU detection
overrides and survey enrollment. Native stored keys are needed for generated UI
controls. This is not a complete profile backup: per-site exceptions, extension
storage, databases and Secure Preferences remain excluded. Only settings actually
saved by Brave are captured; absent defaults are not synthesized. Explicitly
stored defaults may pin upstream behavior.

The remaining text/list choices include homepage, languages, WebRTC handling,
startup URLs and spelling dictionaries. Arrays preserve order and empty values.
Local file URLs and store paths are pruned; pruning a startup URL removes the
whole array under sync-snap's array rules. Review URLs before committing.

The wrapper defaults to merge for both browser-owned files and `onEveryBoot`
for all Brave sync entries. The feature inherits these defaults: existing
profiles receive baseline values, runtime-only keys survive, and explicit Nix
values win. Changed inputs are eligible immediately.

For mutable policies, `sync.condition` checks Chromium's hostname/PID singleton
lock before automatic or manual sync. It refuses live local PIDs, foreign hosts,
malformed locks and unmatched live socket state. Dead local PIDs permit sync,
including stale locks after reboot. PID reuse can conservatively defer sync.
The check never deletes a lock or kills a browser. It is a preflight check rather
than atomic exclusion against simultaneous independent browser starts. Snapshot
is not blocked: reading saved files is safe, but can miss unflushed changes.

`brave-wrapper-merge` uses real headless Brave to verify merging into existing
files, preservation of runtime-only fields, same-boot edits, manual resync and
refusal to sync while the browser is running. It also exercises synthetic
foreign-host and dead-PID locks. Shared guard behavior is tested in the addon.

The real headless test changes GTK appearance and sponsored ads through Brave's
settings API, captures ordinary controls and disabled telemetry, rejects synthetic
private data and keybindings, and checks fresh-profile restoration. It does not
verify GTK rendering in an interactive desktop session. The saved live profile
is reviewed through a temporary export before refreshing repository snapshots;
no running browser is forced to flush preferences.
