"""Real Noctalia CLI roundtrip; a launch probe exercises startup without a desktop."""
import os
from pathlib import Path
import subprocess
import sys
import tomllib
import tomli_w

app, probe, restore = map(Path, sys.argv[1:])
home = Path(os.environ['HOME'])
config = Path(os.environ['XDG_CONFIG_HOME']) / 'fixture config/noctalia/config.toml'
settings = Path(os.environ['XDG_STATE_HOME']) / 'fixture state/noctalia/settings.toml'
snapshot = home / 'snapshot/noctalia/config.toml'

def run(exe, *args, good=True):
    result = subprocess.run([exe, *args], text=True, capture_output=True)
    assert (result.returncode == 0) == good, (result.args, result.stderr)
    return result.stdout

def read(path):
    return tomllib.loads(path.read_text())

def write(path, data):
    path.write_text(tomli_w.dumps(data))

def helper(exe, suffix):
    return exe.parent / ('noctalia-' + suffix)

# IPC/inspection must not create or reset files. The probe also verifies quoting.
assert run(probe, 'msg', 'status').splitlines()[-2:] == ['msg', 'status']
assert not config.exists() and not settings.exists()
assert run(probe).splitlines() == [str(config.parent.parent), str(settings.parent.parent)]
assert read(config) == read(settings)
assert read(config)['theme'] == {'mode': 'light', 'source': 'builtin'}
assert read(config)['bar']['default']['start'] == ['launcher', 'clock']
run(app, 'config', 'validate')

# Simulate GUI edits; the real CLI must observe the higher-priority state layer.
write(settings, {'theme': {'mode': 'dark'}, 'audio': {'enable_overdrive': True},
                 'bar': {'default': {'start': ['clock']}}})
export = tomllib.loads(run(app, 'config', 'export'))
assert export['theme']['mode'] == 'dark'
assert export['bar']['default']['start'] == ['clock']
run(probe, 'msg', 'status')
assert read(settings)['theme']['mode'] == 'dark'
run(helper(app, 'snapshot'))
assert read(snapshot)['theme'] == {'mode': 'dark', 'source': 'builtin'}
assert read(snapshot)['audio']['enable_overdrive'] is True
assert not (snapshot.parent / 'settings.toml').exists()

# Fresh runtime consumes the actual export, then explicit declarations win.
run(helper(restore, 'sync'))
run(restore, 'config', 'validate')
restored = tomllib.loads(run(restore, 'config', 'export'))
assert restored['theme']['mode'] == 'light'
assert restored['audio']['enable_overdrive'] is True
assert restored['bar']['default']['start'] == ['launcher', 'clock']

# Replace drops config-only fields; merge resets conflicts but keeps GUI-only keys.
write(config, {'theme': {'mode': 'dark'}, 'shell': {'offline_mode': True}})
run(probe, '--daemon')
assert 'shell' not in read(config)
assert read(settings)['theme']['mode'] == 'light'
assert read(settings)['audio']['enable_overdrive'] is True
assert read(settings)['bar']['default']['start'] == ['launcher', 'clock']

# Snapshot reads both files, prunes both layers and ignores private state.toml.
base = read(config)
base['hooks'] = {'started': ['/nix/store/fixture/bin/command']}
base['storage'] = {'key_file': '/home/private/key'}
base['theme']['mode'] = 'light'
write(config, base)
write(settings, {'config_version': 14, 'theme': {'mode': 'dark'},
                 'audio': {'enable_overdrive': True},
                 'shell': {'avatar_path': '/home/private/avatar.png'},
                 'calendar': {'accounts': [{'password': 'synthetic-secret'}]},
                 'accessibility': {'ui_scale': 1.5, 'high_contrast': True},
                 'wallpaper': {'monitors': {'DP-1': {'path': '/home/private/image.png'}}},
                 'desktop_widgets': {'widget_order': ['private@DP-1']}})
(settings.parent / 'state.toml').write_text('private = "synthetic-runtime-state"\n')
run(helper(app, 'snapshot'))
assert read(snapshot) == {
    'theme': {'mode': 'dark', 'source': 'builtin'},
    'bar': {'default': {'position': 'top', 'start': ['launcher', 'clock']}},
    'audio': {'enable_overdrive': True},
    'accessibility': {'high_contrast': True},
}
previous = snapshot.read_bytes()
run(helper(app, 'snapshot'))
assert snapshot.read_bytes() == previous
settings.write_text('[broken')
run(helper(app, 'snapshot'), good=False)
assert snapshot.read_bytes() == previous
# Malformed override prevents either sync file from being published.
before = config.read_bytes()
run(helper(app, 'sync'), good=False)
assert config.read_bytes() == before
settings.unlink()
run(helper(app, 'snapshot'))
assert read(snapshot)['theme']['mode'] == 'light'
settings.write_text('')
run(helper(app, 'snapshot'))
assert read(snapshot)['theme']['mode'] == 'light'
run(helper(app, 'sync'))
run(app, 'config', 'validate')
# Finish with a reviewed, native-validated retained baseline.
run(helper(app, 'snapshot'))
assert read(snapshot) == {'theme': {'mode': 'light', 'source': 'builtin'},
                         'bar': {'default': {'position': 'top', 'start': ['launcher', 'clock']}}}
# Unset XDG values use native defaults, including the state root.
env = {k: v for k, v in os.environ.items() if k not in ('XDG_CONFIG_HOME', 'XDG_STATE_HOME')}
subprocess.run([probe], env=env, check=True, stdout=subprocess.DEVNULL)
assert (home / '.config/fixture config/noctalia/config.toml').exists()
assert (home / '.local/state/fixture state/noctalia/settings.toml').exists()
print('Noctalia: native layer precedence, sync policies, snapshot pruning/restore and IPC isolation passed.')
