"""Remove settings.toml fields that are defined in config.toml."""
import argparse
import os
from pathlib import Path
import tempfile
import tomllib

import tomli_w


def remove_configured(settings, config):
    remaining = {}
    for key, value in settings.items():
        if key not in config:
            remaining[key] = value
        elif isinstance(value, dict) and isinstance(config[key], dict):
            nested = remove_configured(value, config[key])
            if nested:
                remaining[key] = nested
        # Scalars and arrays are whole fields. A configured field is removed
        # regardless of its value, type, or portability.
    return remaining


def reset(settings_file, config_file):
    config = tomllib.loads(config_file.read_text())
    if settings_file.is_symlink():
        raise RuntimeError("settings.toml must be a regular file, not a symlink")
    if not settings_file.exists():
        return
    settings = tomllib.loads(settings_file.read_text())
    remaining = remove_configured(settings, config)
    if remaining == settings:
        return
    fd, temporary = tempfile.mkstemp(prefix=".settings-reset-", dir=settings_file.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(tomli_w.dumps(remaining))
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, settings_file)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("settings", type=Path)
    parser.add_argument("config", type=Path)
    args = parser.parse_args()
    try:
        reset(args.settings, args.config)
    except (OSError, ValueError, RuntimeError) as error:
        parser.exit(1, f"noctalia-reset-overrides: {error}\n")
