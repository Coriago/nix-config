# Brave wrapper

Run `nix run path:.#mybrave`. Browser data lives in
`$XDG_CONFIG_HOME/syncbrave`, separate from ordinary Brave. Sync's
configuration directory alone does not isolate browser sessions; `userDataDir`
controls the actual profile, singleton lock, extension storage and snapshots.
The adapter derives `sync.defaultDir` from `userDataDir`; the feature only sets
`userDataDir` and, optionally, `profileDirectory`. Preferences is synced beneath
`<userDataDir>/<profileDirectory>/Preferences`, while generated policy and
extension manifests are stored in `brave-policies/` and `brave-extensions/` below
`userDataDir`. Changing the public directory option moves their destinations
together. Existing browser data is not automatically migrated between directories.
A second launch using the same user-data directory normally hands its request to
the already-running instance and exits. Changes to policies or extension wiring
require closing that wrapped instance and launching again.

The feature chooses Google, the Backyard homepage, and Bitwarden. The browser's
built-in password manager is disabled by an editable recommended policy.
Bitwarden's default-manager permission requires confirmation inside Bitwarden.
Bitwarden uses `force_installed`: it is downloaded automatically, including after
an earlier external installation was removed, and cannot be removed or disabled
in the browser UI. Edit the feature's extension list to change that requirement.
Brave can show a managed-browser indicator. The wrapper presents policy files
only to its process tree and retains other host mandatory policy files.

## Prebuilt extensions

The adapter follows the pinned Home Manager Chromium/Brave module's extension
interface and JSON manifest format, without evaluating Home Manager:

```nix
extensions = [
  "extension-id-from-the-store"
  {
    id = "actual-extension-id-from-the-crx";
    crxPath = ./extension.crx; # Or "${extensionPackage}/extension.crx".
    version = "1.2.3"; # Must match the CRX manifest.
  }
];
```

IDs must be 32 letters in the range a–p. `crxPath` defaults to null; `version`
defaults to null and is required for CRX installation. These entries default to
`installationMode = "external"`, which respects user removal in the browser UI.
The generated manifest uses `external_crx` and `external_version`. Initial local
installation requires no download. Future updating also depends on the packaged
extension's own update manifest; this option does not force a version downgrade.

URL-based entries use `updateUrl`, defaulting to the Chrome Web Store update
service, and may choose `normal_installed` (automatic, disabling allowed) or
`force_installed` (required, removal/disabling prevented). Those managed modes
require an update URL and cannot directly take `crxPath`. To require a locally
packaged extension, serve its CRX through the documented update-manifest protocol.

## Validation and snapshot review

The [feature check](checks/check.nix) launches the assembled `mybrave` package
headlessly and verifies it can render a page. Reusable extension, policy, profile
isolation, sync, snapshot and restoration checks live beside the
[Brave adapter](../../../wrapperModules/brave/README.md), using independent test
configurations. Neither suite exercises interactive Bitwarden sign-in or its
permission prompt.

Snapshot capture uses the actual selected profile's Preferences and retains only
six typed settings: homepage, whether it is the new-tab page, home-button and
bookmark-bar visibility, password saving and password auto sign-in. It drops all
other fields, including accounts, extensions/storage, sessions, history and
unknown future state; file URLs and store paths are also pruned. Checks capture
and inspect isolated runtime exports, inject synthetic private/stateful fields,
and verify the reviewed baseline in a fresh profile. Policies and extension
manifests remain declarative inputs and are excluded from snapshots.

## Runtime settings and capture

Homepage, startup pages, and the new-tab page are distinct; this feature sets the
Home button's destination and shows that button. Recommended settings remain
editable, and an existing explicit preference or mandatory host policy takes
precedence. Fresh profiles seed `credentials_enable_autosignin = false`.
After signing in to Bitwarden, accept **Make Bitwarden your default password
manager → Allow**, or choose it under **Settings → Autofill**. Installation cannot
grant that optional permission, and saved browser passwords can still autofill.
See [Bitwarden's instructions](https://bitwarden.com/help/disable-browser-autofill/).

Native Preferences uses sync's **seed** policy: a missing file is initialized from
the reviewed snapshot, then explicit Nix preferences. Existing files are never
rewritten externally, avoiding races with the browser and preserving edits.
Changing the baseline does not overwrite an existing profile. Policies/manifests
use synchronization on launch. Recommended policies merge; extension wiring
uses replacement so removed IDs and old CRX fields do not remain active. Only
declared external manifests are presented to Brave, even when older synced files
remain on disk. `sync.enable = false` retains
packaged policy/extension delivery but disables preference seeding; snapshot
export is independent.

Close the wrapped browser normally, then run `nix run path:.#snapshot-mybrave` to
capture into `snapshot/mybrave/Default/Preferences`. Capture does not launch/sync
Brave or stage/commit anything. Review URLs for private information before
retaining a baseline. No arrays, cookies, login databases, Local State, Secure
Preferences or protected search-engine/integrity fields are retained.

The adapter's `profileDirectory` selects a profile below `userDataDir` and defaults
to `Default`. Linux user namespaces must be available for directory mappings.
Inspect effective policies at `brave://policy`. The optional NixOS Brave feature
installs the wrapper; it has not been enabled on any host/profile here.
