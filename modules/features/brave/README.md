# Brave

`mybrave` adds Bitwarden using the same user-level external-extension JSON format
as the pinned Home Manager `programs.brave.extensions` implementation. Brave
downloads the extension from the Chrome Web Store and handles its updates.

Recommended policies set Google as the search engine, disable built-in password
saving, and set `https://homepage.backyard-host.com/` as the Home button's URL.
The Home button is shown. Homepage, startup pages, and new-tab pages are distinct;
this feature changes the homepage. These defaults remain editable in Brave's UI;
an existing explicit preference or mandatory host policy takes precedence.
Fresh profiles also disable the browser's automatic sign-in through a native
preference. Existing profiles keep their saved setting until changed in Brave
or through Bitwarden's default-manager action.

```sh
nix run path:.#mybrave
nix run path:.#snapshot-mybrave
nix build path:.#mybrave path:.#checks.x86_64-linux.mybrave --no-link -L
```

Close an already-running Brave session normally before launching this wrapper.
Brave can otherwise reuse that existing process, which has no wrapper mappings.
The optional `flake.modules.nixos.brave` installs the package; no host/profile
enables it. Existing Home Manager Brave installations are unchanged.

After Bitwarden is installed, sign in and accept **Make Bitwarden your default
password manager** and **Allow**. The same option is in Bitwarden's **Settings →
Autofill**. Installing the extension and disabling browser password saving cannot
grant this optional extension permission. Previously saved browser passwords
can still autofill, and browser automatic sign-in is not controlled by
`PasswordManagerEnabled`; Bitwarden's default-manager action disables the
competing settings. See [Bitwarden's instructions](https://bitwarden.com/help/disable-browser-autofill/).

The generic [adapter](../../../wrapperModules/brave.nix) exposes `extensions`,
`recommendedPolicies`, `preferences`, `userDataDir`, and `profileDirectory`.
It imports sync-snap and enables sync by default. `mybrave` chooses
`$XDG_CONFIG_HOME/syncbrave` for writable policies/manifests and enables snapshot
export. The directory-mappings addon presents those synced files at Brave's
fixed discovery paths. Browser profiles and login state stay in the normal
writable data directory; `profileDirectory` defaults to `Default`.

Policies and extension manifests use the normal merge-on-start sync behavior.
They are generated wiring and are excluded from snapshots. Native `Preferences`
uses **seed**: a missing file is initialized from the reviewed snapshot followed
by explicit `preferences`, but an existing profile is never externally rewritten.
This exception avoids racing a running browser and preserves browser edits.
Changing a baseline does not update an existing profile; use Brave's UI for those
edits. Do not change its policy to `merge` while Brave could be running.
`sync.enable = false` retains packaged policy/extension delivery and disables
preference seeding; snapshot export remains independent.

Close Brave normally before capturing. `snapshot-mybrave` reads only the selected
profile's `Preferences` and writes `snapshot/mybrave/Preferences.json` in this repo.
It does not launch or sync Brave first. The next build embeds the baseline for
fresh-profile seeding. Snapshot capture is manual; nothing is staged or committed.

The adapter's snapshot allowlist retains only scalar homepage URL/type, Home and
bookmark-bar visibility, and built-in password-saving/automatic-sign-in settings.
It validates their value types and excludes file/store paths. All other fields,
including account information, history/session data, extension storage, paths,
device state, and protected search-engine/integrity data, are dropped. Cookies,
login databases, `Local State`, and `Secure Preferences` are never sources.
No arrays are retained. Review exported homepage URLs before saving a baseline;
personal URLs can themselves contain private information. Extend the allowlist
only after reviewing the field's schema and portability.

The mapped recommended-policy and external-manifest directories hide other files
at those locations only inside the wrapped process. Mandatory host policies and
unrelated `/etc` files remain visible. Include any other externally managed
extensions in `extensions`; hiding their manifests can cause their removal.
Policies can make Brave display “Managed by your organization”. Linux user
namespaces must be available. Inspect defaults at `brave://policy`.

The check runs real headless Brave with extensions and background networking
disabled. It verifies effective defaults and writable synced files, edits and
restarts the browser, captures a filtered snapshot, checks synthetic private and
future fields are excluded, and restores the export into a fresh profile. Explicit
Nix preferences win conflicts. The isolated export was reviewed; no personal
profile was exported. It does not test interactive rendering, Bitwarden sign-in,
permission consent, or autofill. A separate isolated launch with networking
enabled confirmed the Bitwarden extension download.

See the [configuration notes](../../../docs/brave-configuration.md) and
[directory-mappings reference](../../../lib/directory-mappings/README.md).
