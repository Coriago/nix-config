"""Filter and real Noctalia CLI checks; no running desktop needed."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tomllib

script, executable = sys.argv[1:]
spec = importlib.util.spec_from_file_location("sync", script)
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)

fixture = {
    "theme": {"mode": "dark"},
    "audio": {"enable_overdrive": False},
    "bar": {"default": {"position": "top"}, "monitor": {"DP-1": {"thickness": 30}}},
    "lockscreen_widgets": {"widget_order": ["login@DP-3"]},
    "shell": {"avatar_path": "/home/me/avatar.png"},
    "wallpaper": {"default": {"path": "/nix/store/example/image.png"}, "last": {"path": "~/last.jpg"}},
    "hooks": {"started": "host command"},
    "paths": ["relative/image.png"],
    "token": "private",
}
filtered = sync.prune(fixture)
assert filtered == {
    "theme": {"mode": "dark"}, "audio": {"enable_overdrive": False},
    "bar": {"default": {"position": "top"}},
    "wallpaper": {"default": {"path": "/nix/store/example/image.png"}},
}

home = Path(os.environ["HOME"])
source = home / "settings.toml"
destination = home / "filtered.toml"
source.write_text(sync.tomli_w.dumps(fixture))
sync.sync(source, destination)
assert tomllib.loads(destination.read_text()) == filtered
source.write_text('[theme]\nmode = "light"\n')
sync.sync(source, destination)
assert tomllib.loads(destination.read_text()) == {"theme": {"mode": "light"}}
previous = destination.read_bytes()
source.write_text("[broken")
try:
    sync.sync(source, destination)
    raise AssertionError("Invalid TOML accepted")
except tomllib.TOMLDecodeError:
    assert destination.read_bytes() == previous

# Nix sets light in this check; local GUI settings must still win.
env = os.environ | {"XDG_STATE_HOME": str(home / "state with spaces")}

def export():
    return tomllib.loads(subprocess.check_output([executable, "config", "export"], env=env, text=True))

subprocess.run([executable, "config", "validate"], env=env, check=True)
assert export()["theme"]["mode"] == "light"
state = Path(env["XDG_STATE_HOME"]) / "mynoctalia/noctalia"
state.mkdir(parents=True, exist_ok=True)
(state / "settings.toml").write_text('[theme]\nmode = "dark"\n')
assert export()["theme"]["mode"] == "dark"
subprocess.run([Path(executable).parent / "noctalia-sync-preferences"], env=env, check=True)
assert tomllib.loads((home / "synced.toml").read_text()) == {"theme": {"mode": "dark"}}
assert not (state / "settings.toml").is_symlink()
assert export()["hooks"]["shutting_down"]
print("Passed: filtering, replacement, invalid input, real config validation/precedence and sync command.")
