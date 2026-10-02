"""Test wrapper configuration and atomic saves without launching a GUI."""
import json
import os
from pathlib import Path
import subprocess
import sys


def read_config(directory):
    return {name: json.loads((directory / f"{name}.json").read_text())
            for name in ("settings", "colors")}


if sys.argv[1] == "--app":
    directory = Path(os.environ["NOCTALIA_CONFIG_DIR"])
    assert not os.environ.get("NOCTALIA_SETTINGS_FILE")
    configuration = read_config(directory)
    if "--save" in sys.argv[2:]:
        for name, data in configuration.items():
            data["testGuiEdit"] = True
            temporary = directory / f"{name}.tmp"
            temporary.write_text(json.dumps(data))
            temporary.replace(directory / f"{name}.json")
    print(json.dumps({"directory": str(directory), "configuration": configuration,
                      "args": sys.argv[2:]}))
    sys.exit(0)

portable, live, frozen, source, live_path = sys.argv[1:]
committed = read_config(Path(source))


def run(exe, *args, env):
    return json.loads(subprocess.check_output([exe, *args], env=env, text=True))


def check_edits(exe, directory, env):
    # Test-only preInstalledPlugins supplies the registry, source and settings.
    registry_path = directory / "plugins.json"
    registry = json.loads(registry_path.read_text())
    assert registry["states"]["test-plugin"]["enabled"]
    assert (directory / "plugins/test-plugin/main.qml").is_file()
    plugin_settings = directory / "plugins/test-plugin/settings.json"
    assert json.loads(plugin_settings.read_text()) == {"fromNix": True}
    # GUI changes are allowed and upstream copying must not revert them.
    registry["states"]["test-plugin"]["enabled"] = False
    registry_path.write_text(json.dumps(registry))
    plugin_settings.write_text('{"fromGui": true}')
    for name in ("settings", "colors"):
        path = directory / f"{name}.json"
        assert not path.is_symlink() and os.access(path, os.W_OK)
    run(exe, "--save", env=env)
    result = run(exe, env=env)
    assert all(data["testGuiEdit"] for data in result["configuration"].values())
    assert not json.loads(registry_path.read_text())["states"]["test-plugin"]["enabled"]
    assert json.loads(plugin_settings.read_text()) == {"fromGui": True}


for xdg in (False, True):
    env = os.environ.copy()
    env["PATH"] = ""  # Copy tools must come from the wrapper, not the host.
    env.pop("XDG_CONFIG_HOME", None)
    root = Path(env["HOME"]) / ".config"
    if xdg:
        root = Path(env["HOME"]) / "custom config"
        env["XDG_CONFIG_HOME"] = str(root)
    env["NOCTALIA_SETTINGS_FILE"] = "/nonexistent/inherited.json"
    directory = root / "mynoctalia"
    initial = run(portable, "argument with spaces", env=env)
    assert initial["directory"] == str(directory)
    assert initial["configuration"] == committed
    assert initial["args"] == ["argument with spaces"]
    check_edits(portable, directory, env)

# A checkout already has settings/colors; never overwrite them with store defaults.
directory = Path(live_path)
directory.mkdir(parents=True, exist_ok=True)
for name in ("settings", "colors"):
    (directory / f"{name}.json").write_text('{"fromCheckout": true}')
env = os.environ.copy()
initial = run(live, env=env)
assert initial["directory"] == live_path
assert all(data == {"fromCheckout": True} for data in initial["configuration"].values())
check_edits(live, directory, env)
assert all(data["testGuiEdit"] for data in read_config(directory).values())

# NixOS without liveConfig keeps both files in the store.
initial = run(frozen, env=env)
assert initial["directory"].startswith("/nix/store/")
assert initial["configuration"] == committed
assert read_config(Path(source)) == committed
print("Passed: settings/colors, HOME/XDG, atomic saves, persistence, live/store modes, preinstalled plugins and GUI edits.")
