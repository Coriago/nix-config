# Reviewing an application's snapshot

A snapshot is a reusable preference baseline, not a backup of the application's
entire profile. Decide what to retain from the actual output and the application's
schema. Record app-specific decisions beside its wrapper module; use this guide
when adding a wrapper whose feature enables snapshots.

## What belongs in the baseline?

| Data | Default decision |
| --- | --- |
| Theme, keybindings, editor/UI preferences, intentional plugin settings | Keep when they express a useful preference. |
| Session state, history, recent files, counters, timestamps, caches | Prune unless there is an explicit preference use case. |
| Passwords, tokens, cookies, credential material, private account/project data | Prune; keep authentication in the application's runtime storage. |
| Monitor/device IDs, temporary paths, machine-specific discovery results | Usually prune; retain only when intentionally part of this feature's baseline. |
| Generated `/nix/store/` paths, packaged executable/plugin wiring | Prune captured values; regenerate from the feature or adapter. |
| Upstream defaults serialized by the app | Review; retaining them pins behavior that might otherwise follow upstream. |
| Lists and objects inside lists | Review as a whole, preserving order and required references. Do not infer element identity. |

A field name alone does not establish meaning: a password-manager preference is
not necessarily a password. Prefer narrowly scoped, schema-informed rules over
broad matching that discards useful settings. Likewise, an innocuous name does not
prove that its value is safe to retain.

## Review workflow

1. Identify the preference files and known state/credential fields from the pinned
   app's documentation. Put generally useful pruning defaults in the adapter's
   `snapshot.files.<entry>` options. Keep export opt-in in the feature and put
   personal exceptions there.
2. Launch with isolated HOME/XDG directories first. Exercise representative
   settings and plugin configuration; use synthetic private values to check
   exclusions. Let the app finish saving before capture.
3. At the end of implementation, run `nix run path:.#snapshot-<package-name>` with
   the same runtime environment. Override `snapshot.defaultDir` in a test package
   for disposable exports. Snapshot commands do not launch or sync the app first.
   If representative real runtime data is available, review that output too;
   otherwise state that only fixtures or CLI behavior were tested.
4. Inspect each exported file locally and compare it with the intended preferences.
   Do not dump raw credentials or private values into tool output, reports, or
   commits. Describe findings by field path and category. Preserve preexisting
   snapshots while investigating, and never stage or commit automatically.
5. Refine pruning and rerun the command. Verify both that unwanted fields disappear
   and that intended settings remain. Record decisions, especially ambiguous
   fields or intentionally retained machine-specific values.
6. Test a fresh runtime directory using the resulting baseline. Confirm that the
   app accepts it, retained preferences work, and explicit Nix settings still win
   conflicts. A successful JSON parse alone does not prove the app accepts a config.

Use `pruneKeyContains`/`pruneValueContains` for simple patterns and `transform` for
precise structural edits. These names accept regexes and jq filters respectively;
see [engine filtering semantics](../packages/sync-snap/README.md#snapshot-filtering)
before writing rules. In particular, pruning inside an array removes the whole
containing array. Use an explicit, tested transform when only part should be
removed. There is no built-in keep/select option yet.

A failed export can leave the previous snapshot in place. Check the command's exit
status and error sidecars before treating a file as a fresh result. Files are
captured separately, so close the app or otherwise ensure stable inputs when
cross-file consistency matters. Detailed failure behavior belongs in the
[engine reference](../packages/sync-snap/README.md).

## Record the outcome

Keep a short note beside the app adapter: files reviewed, retained categories,
pruned field paths and reasons, array handling, and validation performed. Add
focused fixtures beside the module when pruning has meaningful edge cases; never
use real credentials as fixtures. Revisit the rules when an app changes its schema.
