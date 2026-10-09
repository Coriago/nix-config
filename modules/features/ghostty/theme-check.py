"""Check config merging and real Noctalia templates/hooks without a GUI session."""
import os
from pathlib import Path
import subprocess
import sys
import tomllib
import tomli_w

ghostty, generated, noctalia, assets = sys.argv[1:]
assets = Path(assets)
launcher = Path(ghostty).read_text()
assert "--config-default-files=true" in launcher
assert "--config-default-files=false" not in launcher
assert f"--config-file={generated}" in launcher
directory = Path(os.environ["XDG_CONFIG_HOME"]) / "ghostty"
config = directory / "config.ghostty"
# Action commands intentionally bypass the wrapper's launch flags. Reproduce
# normal user-config + packaged-config loading explicitly for these checks.
config.write_text(f"font-size = 17\nkeybind = ctrl+shift+t=new_tab\nkeybind = ctrl+alt+f=increase_font_size:2\nconfig-file = {generated}\n")

def output(action):
    return subprocess.check_output([ghostty, action], text=True)

subprocess.run([ghostty, "+validate-config"], check=True)
bindings = output("+list-keybinds")
assert "ctrl+alt+f=increase_font_size:2" in bindings, bindings
assert "escape=end_search" in bindings, bindings
# CLI listings omit flags. Preserve upstream conditional search/selection
# handling by ensuring the packaged policy only removes selected bindings.
policy = Path(generated).read_text().splitlines()
assert "keybind = clear" not in policy
assert all(line.endswith("=unbind") for line in policy if line.startswith("keybind = "))
for action in (
    "new_tab", "previous_tab", "next_tab", "goto_tab", "last_tab", "move_tab",
    "close_tab", "new_split", "goto_split", "resize_split", "toggle_split_zoom",
):
    assert f"={action}" not in bindings, (action, bindings)
for action in ("copy_to_clipboard", "paste_from_clipboard", "reload_config"):
    assert f"={action}" in bindings, (action, bindings)

catalog = tomllib.loads((assets / "builtin.toml").read_text())
Path("ghostty").symlink_to(assets / "ghostty", target_is_directory=True)
templates = Path("templates.toml").absolute()
templates.write_text(tomli_w.dumps({"templates": {"ghostty": catalog["templates"]["ghostty"]}}))
colors = []
for mode in ("dark", "light"):
    subprocess.run([
        noctalia, "theme", str(assets.parent / "noctalia-wallpaper.png"),
        "--default-mode", mode, "-c", str(templates), "-o", "palette.json",
    ], check=True)
    assert config.read_text().count("theme = noctalia") == 1
    assert "font-size = 17" in config.read_text()
    theme = directory / "themes/noctalia"
    assert theme.is_file() and not theme.is_symlink()
    subprocess.run([ghostty, "+validate-config"], check=True)
    effective = output("+show-config")
    background = next(line for line in theme.read_text().splitlines() if line.startswith("background"))
    expected = background.split("=", 1)[1].strip().lstrip("#")
    assert f"background = #{expected}" in effective, (background, effective)
    assert "font-size = 17" in effective
    assert output("+list-keybinds") == bindings
    colors.append(expected)
assert colors[0] != colors[1], colors

# D-Bus activation and systemd must enter the wrapper too.
package = Path(ghostty).parent.parent
for relative in (
    "share/dbus-1/services/com.mitchellh.ghostty.service",
    "share/systemd/user/app-com.mitchellh.ghostty.service",
):
    assert ghostty in (package / relative).read_text(), relative
