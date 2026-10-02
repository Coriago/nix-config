"""Test wrapper settings selection and atomic saves without launching a GUI."""
import json
import os
from pathlib import Path
import subprocess
import sys

if sys.argv[1] == "--app":
    path = Path(os.environ["NOCTALIA_SETTINGS_FILE"])
    settings = json.loads(path.read_text())
    if "--save" in sys.argv[2:]:
        settings["testGuiEdit"] = True
        temporary = path.with_suffix(".tmp")
        temporary.write_text(json.dumps(settings))
        temporary.replace(path)
    print(json.dumps({"path": str(path), "settings": settings, "args": sys.argv[2:]}))
    sys.exit(0)

portable, live, source, live_path = sys.argv[1:]
committed = json.loads(Path(source).read_text())
original_source = Path(source).read_bytes()


def run(exe, *args, env):
    return json.loads(subprocess.check_output([exe, *args], env=env, text=True))


for xdg in (False, True):
    env = os.environ.copy()
    env.pop("XDG_CONFIG_HOME", None)
    root = Path(env["HOME"]) / ".config"
    if xdg:
        root = Path(env["HOME"]) / "custom config"
        env["XDG_CONFIG_HOME"] = str(root)
    # Inherited settings must not redirect this standalone package.
    env["NOCTALIA_SETTINGS_FILE"] = "/nonexistent/inherited.json"
    expected = root / "mynoctalia/settings.json"
    initial = run(portable, "argument with spaces", env=env)
    assert initial["path"] == str(expected)
    assert initial["settings"] == committed
    assert initial["args"] == ["argument with spaces"]
    assert expected.is_file() and not expected.is_symlink()
    assert os.access(expected, os.W_OK)
    assert run(portable, "--save", env=env)["settings"]["testGuiEdit"]
    assert run(portable, env=env)["settings"]["testGuiEdit"]

# Explicit live path simulates a checkout, including atomic GUI writes.
path = Path(live_path)
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps({"fromCheckout": True}))
env = os.environ.copy()
initial = run(live, env=env)
assert initial["path"] == live_path
assert initial["settings"] == {"fromCheckout": True}
run(live, "--save", env=env)
assert json.loads(path.read_text())["testGuiEdit"]
assert run(live, env=env)["settings"]["testGuiEdit"]
assert Path(source).read_bytes() == original_source
print("Passed: committed defaults, HOME/XDG paths, atomic saves, persistence, live checkout, arguments.")
