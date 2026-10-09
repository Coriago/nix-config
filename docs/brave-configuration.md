# Brave configuration notes

The intended defaults are Bitwarden for password management, Google for search,
and preferences that remain editable in Brave's UI.

## Preferences and policies

Brave has both per-profile preferences and browser policies. Recommended policies
provide defaults that users can override; mandatory policies enforce values.
Policies can cause Brave to display “Managed by your organization”.

On Linux, Brave reads policy JSON from `/etc/brave/policies/recommended` and
`/etc/brave/policies/managed`. Inspect effective values and select **Reload
policies** at `brave://policy`. Some policies require a restart.

Initial preferences apply when a profile is first created. They are not a reliable
way to change an existing profile. Directly editing a running browser's
`Preferences` file is also unreliable: Brave may overwrite changes, and it does
not reliably reload external edits. Close Brave normally before reading or
changing saved preferences.

References: [Brave policies](https://support.brave.app/hc/en-us/articles/360039248271-Group-Policy),
[Chromium preferences](https://www.chromium.org/administrators/configuring-other-preferences/).

## Bitwarden

Bitwarden's Chrome Web Store extension ID is
`nngceckbapebfimnlniiiahkandclblb`. External extension installation metadata can
request installation from the store; downloading requires network access, and
Brave manages subsequent updates. Removing an externally installed extension in
the UI may require manually reinstalling it later.

Installing Bitwarden does not automatically grant its default-password-manager
permission. Sign in, choose **Make Bitwarden your default password manager**, and
accept **Allow**. The option is also available in Bitwarden's autofill settings.

The native preferences `credentials_enable_service = false` and
`credentials_enable_autosignin = false` disable built-in password saving and
automatic sign-in. `PasswordManagerEnabled = false` can also be expressed as a
policy. These settings do not log into Bitwarden or grant extension permissions.
`ExtensionSettings` supports `toolbar_pin = "default_pinned"` for toolbar visibility;
pinning and installation are separate choices.

References: [Bitwarden browser deployment](https://bitwarden.com/help/browserext-deploy/),
[default password manager](https://bitwarden.com/help/disable-browser-autofill/),
[external extensions](https://developer.chrome.com/docs/extensions/how-to/distribute/install-extensions),
[extension policies](https://support.google.com/chrome/a/answer/9867568).

## Google search

The tested recommended policy values were:

| Policy | Value |
| --- | --- |
| `DefaultSearchProviderEnabled` | `true` |
| `DefaultSearchProviderName` | `Google` |
| `DefaultSearchProviderKeyword` | `google.com` |
| `DefaultSearchProviderSearchURL` | `https://www.google.com/search?q={searchTerms}` |

An explicit search-engine choice in Brave's UI can override these recommendations.
Search settings include protected preference data; copying raw search preferences
or their integrity hashes is not a dependable way to restore the search engine.

## Lessons for retaining personal preferences

- Keep deliberate preferences separate from browser state. `Preferences` can
  contain account information, identifiers, paths, extension data, and browsing
  activity as well as useful settings.
- A filtered preference export is not a profile backup. Cookies, history, login
  databases, extension storage, `Local State`, and `Secure Preferences` should not
  become a portable configuration baseline.
- Review every export. Exclusion lists need adjustment as Brave evolves; they do
  not guarantee removal of all sensitive or machine-specific values.
- Lists may contain stateful objects. Treat them cautiously rather than merging
  items by index or assuming their ordering is stable.
- Reapplying declared preferences at startup resets those declared values after
  GUI edits. Preserve desired edits before restarting if they should become defaults.
- Distinguish the browser data directory from its selected profile. Multiple
  profiles have different preferences; a second launch may reuse a running browser.
- A running-browser lock is a useful signal, not proof that external writes are
  safe. Never remove a lock while the browser is running.

Earlier headless testing confirmed Google defaults, Bitwarden installation,
writable preferences, and persistence across restart. Interactive Bitwarden
login/autofill and normal GUI shutdown were not validated. Headless shutdown did
not reliably complete, so it should not be treated as evidence about GUI shutdown.
