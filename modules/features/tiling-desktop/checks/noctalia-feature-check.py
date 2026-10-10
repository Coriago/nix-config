"""Validate selected personal preferences through Noctalia's real CLI."""
from pathlib import Path
import subprocess
import sys
import tomllib

settings = tomllib.loads(subprocess.check_output([sys.argv[1], 'config', 'export'], text=True))
assert settings['shell']['launch_apps_as_systemd_services'] is True
wallpaper = Path(settings['wallpaper']['default']['path'])
assert wallpaper.is_file() and wallpaper.suffix == '.png'
assert settings['theme']['builtin'] == 'Gruvbox'
assert {'gtk3', 'gtk4', 'kcolorscheme', 'umbriel'} <= set(settings['theme']['templates']['builtin_ids'])
assert not settings.get('hooks'), 'Old snapshot hooks must not be generated'
print('Noctalia accepts the assembled feature, wallpaper and selected theming preferences.')
