# Directory mappings

Import `locallib.directory-mappings` into a wrapper, independently of sync-snap.
The `locallib` flake-parts argument is defined in `modules/flake-parts.nix`; capture
it in the outer module just like `locallib.sync-snap`.

```nix
{locallib, ...}: {
  flake.wrappers.myapp = {wlib, ...}: {
    imports = [wlib.wrapperModules.myapp locallib.directory-mappings];
    directoryMappings = [
      {
        source = "\${HOME}/.config/my-custom-config";
        target = "\${HOME}/.config/myapp";
      }
    ];
  };
}
```

`source` is the real writable directory; `target` is the directory the app sees.
The list defaults to `[]`, which leaves the normal launch untouched. Entries
apply in list order. Paths must expand to absolute paths. Runtime shell variable
expansion is supported, including `${XDG_CONFIG_HOME:-$HOME/.config}`. These are
trusted Nix expressions, not strings received from the application.

The addon uses the upstream `argv0type` function hook to run the final command
through Bubblewrap. It preserves the host filesystem with `--dev-bind / /`, then
applies writable `--bind` mappings. No additional helper executable is generated.
Startup hooks (including sync-snap) run outside the mapping first. Arguments,
working directory, environment, network and terminal remain available; child
processes inherit the mappings. Existing external services do not inherit them.
This is filesystem redirection, not a security sandbox.

Missing source directories are created. Bubblewrap may also create missing target
directories. Existing target contents are hidden only in this process tree; they
are not copied or deleted. A bind failure stops launch, so the app cannot silently
write to the original location. Linux user namespaces must be available. The
addon requires `wrapperImplementation = "nix"` and owns its `argv0type` hook;
wrappers with another custom launch function require explicit composition.

For a missing target beneath a root-owned directory, bind mounts alone cannot
create the target. Set `directoryMappingParentDirs` to recreate the necessary
parents in temporary filesystems, in parent-before-child order. For example,
Brave uses `["/etc" "/etc/brave" "/etc/brave/policies"]` before mapping its
recommended policy directory. Existing immediate children of each parent are
bound back from the host; child paths listed as another parent or a mapping
target are replaced instead. Symlinks, including dangling ones, are preserved.
Unrelated `/etc` entries and mandatory Brave policies remain visible. New entries
in these temporary parents disappear when the process tree exits; writes inside
bound children still reach the host. Do not use this for application data that
needs persistent creation/renaming of entries in the parent itself. Paths must
be absolute, cannot be `/`, and support the same environment expansion as mappings.
The default empty list preserves the ordinary bind-only launch.

Map directories rather than individual writable files: atomic temporary-file
renames work inside the mapped directory. Writes persist in the source after
exit, and external edits reach the same files. Actual hot reload still depends
on the application's watcher. Avoid overlapping mappings unless their ordering
is intentional; a mapping hides all target contents, including plugins/themes.

## OpenCode

The OpenCode wrapper maps `sync.defaultDir` onto `$XDG_CONFIG_HOME/opencode`
when the configured paths differ. All generated config files, including CLI
preferences, use the shared sync destination defaults. The `myopencode` feature
only chooses `$XDG_CONFIG_HOME/syncopencode` and personal settings; app-specific
path behavior lives in `wrapperModules/opencode.nix`.
OpenCode sees its native `cli.json` path and saves into `syncopencode/cli.json`.
Other files in the original `opencode/` directory are not carried over.

Run without installing or rebuilding NixOS:

```sh
nix run path:.#myopencode
```

Check the addon with `nix build path:.#checks.x86_64-linux.directory-mappings`.
The adjacent `check.nix` exercises actual bind mounts, atomic writeback, child
process inheritance, spaces in paths/arguments, exit status, and preservation of
the host target. It also checks missing targets under `/etc`, temporary parents,
hidden files, dangling symlinks, sibling directories, and absence of host writes.
The separate `myopencode` check exercises the real wrapped CLI
and Playwright MCP. These checks do not assert interactive theme rendering.

References: [Bubblewrap](https://github.com/containers/bubblewrap/tree/v0.12.0)
and its [manual](https://github.com/containers/bubblewrap/blob/v0.12.0/bwrap.xml);
[wrapper launch hook](https://github.com/nix-community/nix-wrapper-modules/blob/1db3c116a6aa61823f8d8f3c47c306846428fc54/modules/makeWrapper/module.nix).
