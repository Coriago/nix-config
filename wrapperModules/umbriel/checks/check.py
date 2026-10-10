"""Native config validation and sync/snapshot; probe compositor launch arguments."""
import os
from pathlib import Path
import subprocess
import sys
import tomllib
import tomli_w

app, probe, restore = map(Path, sys.argv[1:])
home = Path(os.environ['HOME'])
config = Path(os.environ['XDG_CONFIG_HOME']) / 'fixture compositor/config.toml'
snapshot = home / 'snapshot/config.toml'

def run(exe, *args, good=True):
    result = subprocess.run([exe, *args], text=True, capture_output=True)
    assert (result.returncode == 0) == good, (result.args, result.stdout, result.stderr)
    return result.stdout

def read(path):
    return tomllib.loads(path.read_text())

def write(path, data):
    path.write_text(tomli_w.dumps(data))

def helper(exe, suffix):
    return exe.parent / ('umbriel-' + suffix)

assert run(probe, 'msg', 'outputs').splitlines() == ['msg', 'outputs']
assert not config.exists()
assert run(probe, '-s', 'argument with spaces').splitlines() == ['-c', str(config), '-s', 'argument with spaces']
run(app, 'config', 'validate')
assert read(config)['layout']['mode'] == 'scrolling'
assert run(probe, 'config', 'validate').splitlines() == ['config', 'validate', '-c', str(config)]

# Manual file edits persist until startup sync. IPC and validation are read-only.
changed = read(config)
changed['layout']['scrolling']['default_extent_fraction'] = 0.7
changed['appearance'] = {'blur': {'radius': 4}}
changed['keybinds']['Mod+F'] = 'window-toggle-fullscreen'
write(config, changed)
run(app, 'config', 'validate')
run(probe, 'msg', 'outputs')
assert read(config) == changed
run(helper(app, 'snapshot'))
assert read(snapshot) == changed
run(helper(restore, 'sync'))
run(restore, 'config', 'validate')
restored = read(home / 'restored/config.toml')
assert restored['layout']['scrolling']['default_extent_fraction'] == 0.5
assert restored['appearance']['blur']['radius'] == 4
assert restored['keybinds']['Mod+F'] == 'window-toggle-fullscreen'
run(probe)
assert read(config) == restored

# Prune generated wiring, credentials and machine-specific output/device choices.
private = read(config)
private.update(environment={'SECRET_TOKEN': 'synthetic-secret', 'GTK_DATA_PREFIX': '/nix/store/theme'},
               include={'files': ['/home/private/layout.toml']},
               output={'DP-1': {'scale': 1.5}},
               drm={'ignored_pci_addresses': ['0000:01:00.0']})
private['general'] = {'autostart': ['portable-command', '/nix/store/app/bin/app']}
private['input'] = {'touch': {'map_to_output': 'DP-1'}, 'device': {'local-device': {'enabled': True}}}
private['keybinds']['Mod+G'] = 'spawn:/nix/store/app/bin/app'
write(config, private)
run(helper(app, 'snapshot'))
assert read(snapshot) == restored
previous = snapshot.read_bytes()
config.write_text('[broken')
run(helper(app, 'snapshot'), good=False)
assert snapshot.read_bytes() == previous
run(app, 'config', 'validate', good=False)
assert config.read_text() == '[broken', 'Validation must not sync away broken edits'
write(config, restored)
run(app, 'config', 'validate')
run(helper(app, 'snapshot'))
assert read(snapshot) == restored
# Explicit validator paths remain supported and do not mutate the managed file.
other = home / 'another config.toml'
other.write_text('[broken')
run(app, 'config', 'validate', '-c', str(other), good=False)
assert read(config) == restored
print('Umbriel: native validation, launch arguments, merge, snapshot pruning/restore and IPC isolation passed.')
