"""Filter and real Noctalia CLI checks; no running desktop needed."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tomllib

script, executable, reset_script = sys.argv[1:]
spec = importlib.util.spec_from_file_location("snapshotter", script)
snapshotter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(snapshotter)

fixture = {
    "config_version": 14,
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
filtered = snapshotter.prune(fixture)
assert filtered == {
    "theme": {"mode": "dark"}, "audio": {"enable_overdrive": False},
    "bar": {"default": {"position": "top"}},
}

home = Path(os.environ["HOME"])
source = home / "settings.toml"
config_file = home / "config.toml"
destination = home / "snapshot.toml"
baseline = {
    "theme": {"mode": "light", "source": "builtin", "templates": {"builtin_ids": ["gtk3"]}},
    "shell": {"avatar_path": "/nix/store/example/avatar.png"},
    "hooks": {"started": "baseline-command"},
}
config_file.write_text(snapshotter.tomli_w.dumps(baseline))
source.write_text(snapshotter.tomli_w.dumps(fixture))
snapshotter.snapshot(config_file, source, destination)
combined = tomllib.loads(destination.read_text())
assert combined["theme"] == {"mode": "dark", "source": "builtin", "templates": {"builtin_ids": ["gtk3"]}}
assert "shell" not in combined
assert "wallpaper" not in combined
assert combined["hooks"] == baseline["hooks"]
assert combined["audio"] == {"enable_overdrive": False}
assert "monitor" not in combined["bar"]
assert "token" not in combined

# Arrays replace; rejected local overrides cannot erase baseline values.
source.write_text('[theme.templates]\nbuiltin_ids = ["gtk4"]\n')
snapshotter.snapshot(config_file, source, destination)
assert tomllib.loads(destination.read_text())["theme"]["templates"]["builtin_ids"] == ["gtk4"]

# The reported regression: reset leaves an empty or missing override file.
# Either must snapshot the baseline, never an empty override-only document.
for contents in ["", "config_version = 14\n"]:
    source.write_text(contents)
    snapshotter.snapshot(config_file, source, destination)
    assert tomllib.loads(destination.read_text()) == snapshotter.prune_store_paths(baseline)
source.unlink()
snapshotter.snapshot(config_file, source, destination)
assert tomllib.loads(destination.read_text()) == snapshotter.prune_store_paths(baseline)

# Changing build paths must not churn the snapshot or rewrite an identical file.
previous = destination.read_bytes()
previous_mtime = destination.stat().st_mtime_ns
baseline["shell"]["avatar_path"] = "/nix/store/next-build/avatar.png"
baseline["hooks"]["colors_changed"] = ["exec /nix/store/next-build/bin/snapshot"]
config_file.write_text(snapshotter.tomli_w.dumps(baseline))
source.write_text('[wallpaper]\ndefault = "file:///nix/store/gui/image.png"\n')
snapshotter.snapshot(config_file, source, destination)
assert destination.read_bytes() == previous
assert destination.stat().st_mtime_ns == previous_mtime
assert snapshotter.prune_store_paths({"only": ["plain", "/nix/store/build/bin/tool"]}) is snapshotter.DROP
assert snapshotter.prune_store_paths({"empty": [], "nested": {}, "enabled": False}) == {
    "empty": [], "nested": {}, "enabled": False,
}

# Invalid input must not replace the last good snapshot.
previous = destination.read_bytes()
source.write_text("[broken")
try:
    snapshotter.snapshot(config_file, source, destination)
    raise AssertionError("Invalid settings accepted")
except tomllib.TOMLDecodeError:
    assert destination.read_bytes() == previous
source.write_text("")
config_file.write_text("[broken")
try:
    snapshotter.snapshot(config_file, source, destination)
    raise AssertionError("Invalid baseline accepted")
except tomllib.TOMLDecodeError:
    assert destination.read_bytes() == previous
config_file.write_text(snapshotter.tomli_w.dumps(baseline))

# Nix sets light in this check; local GUI settings must still win.
env = os.environ | {"XDG_STATE_HOME": str(home / "state with spaces")}

def export():
    return tomllib.loads(subprocess.check_output([executable, "config", "export"], env=env, text=True))

snapshot_command = Path(executable).parent / "noctalia-snapshot-preferences"

def capture():
    subprocess.run([snapshot_command], env=env, check=True)
    return tomllib.loads((home / "snapshot.toml").read_text())

subprocess.run([executable, "config", "validate"], env=env, check=True)
assert export()["theme"]["mode"] == "light"
assert export()["shell"]["launch_apps_as_systemd_services"] is True
baseline_snapshot = capture()
assert baseline_snapshot["theme"]["mode"] == "light"
assert "/nix/store/" not in snapshotter.tomli_w.dumps(baseline_snapshot)
assert export()["wallpaper"]["default"]["path"].startswith("/nix/store/")
assert Path(export()["wallpaper"]["default"]["path"]).suffix == ".png", "Greeter sync needs a clean wallpaper extension"
state = Path(env["XDG_STATE_HOME"]) / "mynoctalia/noctalia"
state.mkdir(parents=True, exist_ok=True)
(state / "settings.toml").write_text('[theme]\nmode = "dark"\n')
assert export()["theme"]["mode"] == "dark"
assert capture() == snapshotter.merge(baseline_snapshot, {"theme": {"mode": "dark"}})
assert not (state / "settings.toml").is_symlink()
assert export()["hooks"]["shutting_down"]

# Reset matches field names recursively, without consulting the portability filter.
baseline = home / "reset-config.toml"
baseline.write_text(snapshotter.tomli_w.dumps({
    "theme": {"mode": "light"},
    "shell": {"avatar_path": "/baseline/avatar.png"},
    "monitors": ["HDMI-A-1"],
    "enabled": True,
}))
source.write_text(snapshotter.tomli_w.dumps({
    "theme": {"mode": "dark", "source": "builtin"},
    "shell": {"avatar_path": "/home/me/avatar.png", "polkit_agent": True},
    "monitors": ["DP-1"],
    "enabled": True,
    "local_only": {"device": "my-device"},
}))
subprocess.run([sys.executable, reset_script, source, baseline], check=True)
assert tomllib.loads(source.read_text()) == {
    "theme": {"source": "builtin"},
    "shell": {"polkit_agent": True},
    "local_only": {"device": "my-device"},
}
previous = source.read_bytes()
subprocess.run([sys.executable, reset_script, source, baseline], check=True)
assert source.read_bytes() == previous
baseline.write_text("[broken")
assert subprocess.run([sys.executable, reset_script, source, baseline], capture_output=True).returncode != 0
assert source.read_bytes() == previous

# The installed command uses its own generated config.toml. It does not write a snapshot.
snapshot = (home / "snapshot.toml").read_bytes()
(state / "settings.toml").write_text('[theme]\nmode = "dark"\n[shell]\navatar_path = "/home/me/avatar.png"\n')
subprocess.run([Path(executable).parent / "noctalia-reset-overrides"], env=env, check=True)
assert tomllib.loads((state / "settings.toml").read_text()) == {
    "shell": {"avatar_path": "/home/me/avatar.png"},
}
assert export()["theme"]["mode"] == "light"
assert (home / "snapshot.toml").read_bytes() == snapshot
# Snapshot after the actual reset command retains every baseline preference.
assert capture() == baseline_snapshot

# Simulate snapshot -> next generated config, with explicit Nix values winning.
next_config = home / "next-config.toml"
next_config.write_text(snapshotter.tomli_w.dumps(snapshotter.merge(
    capture(), {"theme": {"mode": "dark"}}
)))
snapshotter.snapshot(next_config, state / "settings.toml", destination)
roundtrip = tomllib.loads(destination.read_text())
assert roundtrip == snapshotter.merge(baseline_snapshot, {"theme": {"mode": "dark"}})

# Hooks use the running shell's baseline and state, not an unrelated default.
hook_root = home / "hook-config"
(hook_root / "noctalia").mkdir(parents=True)
(hook_root / "noctalia/config.toml").write_text(next_config.read_text())
hook_env = env | {
    "NOCTALIA_CONFIG_HOME": str(hook_root),
    "NOCTALIA_STATE_HOME": str(state.parent),
}
for hook in export()["hooks"]["colors_changed"]:
    subprocess.run(hook, shell=True, env=hook_env, check=True)
assert tomllib.loads(destination.read_text()) == roundtrip
print("Passed: prune-before-merge, empty/missing overrides, reset/snapshot roundtrip, hook roots, invalid input and real CLI precedence.")
