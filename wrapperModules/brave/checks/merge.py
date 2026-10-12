"""Merge into an existing profile; guard live browsers and stale/remote locks."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

from browser import Browser

with tempfile.TemporaryDirectory(prefix="brave merge ") as home:
    env = dict(os.environ, HOME=home, XDG_CONFIG_HOME=home + "/config",
               XDG_STATE_HOME=home + "/state", XDG_DATA_HOME=home + "/data",
               XDG_CACHE_HOME=home + "/cache")
    data = Path(home) / "config/wrapper-test/user-data"
    prefs = data / "Default/Preferences"
    state = data / "Local State"
    prefs.parent.mkdir(parents=True)
    prefs.write_text(json.dumps({"bookmark_bar": {"show_on_all_tabs": False},
                                "runtime_only": {"keep": True}}))
    state.write_text(json.dumps({"brave": {"p3a": {"enabled": True}},
                                "runtime_only": {"keep": True}}))

    def sync(*args):
        return subprocess.run([sys.argv[2], *args], env=env, capture_output=True)

    assert sync().returncode == 0
    assert json.loads(prefs.read_text())["bookmark_bar"]["show_on_all_tabs"] is True
    assert json.loads(prefs.read_text())["runtime_only"] == {"keep": True}
    assert json.loads(state.read_text())["brave"]["p3a"]["enabled"] is False
    assert json.loads(state.read_text())["runtime_only"] == {"keep": True}

    browser = Browser(sys.argv[1], env, data)
    try:
        settings = browser.settings()
        assert settings["bookmark_bar.show_on_all_tabs"]["value"] is True
        assert settings["extensions.theme.system_theme"]["value"] == 1
        assert settings["brave.brave_ads.sponsored.enabled"]["value"] is False
        blocked = sync()
        assert blocked.returncode != 0 and b"profile is in use" in blocked.stderr
    finally:
        browser.close()

    # Same boot preserves edits; manual sync reapplies the baseline.
    saved = json.loads(prefs.read_text())
    saved["bookmark_bar"]["show_on_all_tabs"] = False
    prefs.write_text(json.dumps(saved))
    assert sync("--startup").returncode == 0
    assert json.loads(prefs.read_text())["bookmark_bar"]["show_on_all_tabs"] is False
    assert sync().returncode == 0
    assert json.loads(prefs.read_text())["bookmark_bar"]["show_on_all_tabs"] is True

    lock = data / "SingletonLock"
    lock.unlink(missing_ok=True)
    lock.symlink_to("foreign-host-fixture-123")
    assert sync().returncode != 0
    lock.unlink()
    lock.symlink_to(Path("/proc/sys/kernel/hostname").read_text().strip() + "-999999999")
    assert sync().returncode == 0
    assert lock.is_symlink(), "Only Brave may clean up its singleton lock"

print("Existing-profile merge, retained runtime keys, same-boot edits, manual sync, live-browser guard and stale/remote locks passed.")
