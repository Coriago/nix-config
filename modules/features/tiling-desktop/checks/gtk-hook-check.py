"""Run the actual GTK templates/hooks with a fresh home and private D-Bus."""
import os
from pathlib import Path
import subprocess
import sys
import tomllib
import tomli_w

noctalia, assets, dconf = sys.argv[1:]
assets = Path(assets)
catalog = tomllib.loads((assets / "builtin.toml").read_text())
Path("gtk").symlink_to(assets / "gtk", target_is_directory=True)
config = Path("templates.toml").absolute()
config.write_text(tomli_w.dumps({
    "templates": {name: catalog["templates"][name] for name in ("gtk3", "gtk4")}
}))
# Start without generated colors, but retain a user-authored CSS rule.
for version in (3, 4):
    directory = Path(os.environ["XDG_CONFIG_HOME"]) / f"gtk-{version}.0"
    directory.mkdir()
    (directory / "gtk.css").write_text("/* keep user CSS */\n")

env = {key: os.environ[key] for key in (
    "HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_RUNTIME_DIR", "DBUS_SESSION_BUS_ADDRESS"
)}
# Only the wrapper supplies hook programs, schemas, theme assets and GIO modules.
env.update(PATH="", XDG_DATA_DIRS=str(Path("empty-data").absolute()))
wallpaper = assets.parent / "noctalia-wallpaper.png"
for mode, theme in (("dark", "adw-gtk3-dark"), ("light", "adw-gtk3")):
    subprocess.run([
        noctalia, "theme", str(wallpaper),
        "--default-mode", mode, "-c", str(config), "-o", "palette.json",
    ], env=env, check=True)
    for key, value in (("gtk-theme", theme), ("color-scheme", f"prefer-{mode}")):
        result = subprocess.check_output([
            dconf, "read", f"/org/gnome/desktop/interface/{key}"
        ], env=env, text=True).strip()
        assert result == repr(value), (key, result)
    for version in (3, 4):
        directory = Path(env["XDG_CONFIG_HOME"]) / f"gtk-{version}.0"
        css = (directory / "gtk.css").read_text()
        assert "/* keep user CSS */" in css
        assert css.count('@import url("noctalia.css");') == 1
        assert "@define-color" in (directory / "noctalia.css").read_text()
