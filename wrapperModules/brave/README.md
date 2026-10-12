# Brave adapter checks

The adapter is in [default.nix](default.nix). Its [checks](checks/check.nix)
instantiate `flake.wrappers.brave` directly with synthetic preferences and runtime
locations; they do not depend on `packages.mybrave` or personal feature settings.

```sh
nix build path:.#checks.x86_64-linux.brave-wrapper-preferences \
  path:.#checks.x86_64-linux.brave-wrapper-isolation --no-link -L
```

`brave-wrapper-preferences` checks policy delivery, edits across restarts, writable
sync files, snapshot pruning, restoration to a different profile, and explicit
preference precedence. Snapshot output is compared with the exact retained
baseline; synthetic private and future fields must be absent.

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
