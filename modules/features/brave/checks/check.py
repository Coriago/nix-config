"""Check real Brave policies, sync, snapshots, and restore in offline profiles."""

import json
from contextlib import nullcontext
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
from urllib.request import urlopen

import websocket


review_home = os.environ.get("BRAVE_REVIEW_HOME")
with (nullcontext(review_home) if review_home else tempfile.TemporaryDirectory(prefix="brave check ")) as root_home:
    Path(root_home).mkdir(parents=True, exist_ok=True)
    for stage in range(3):
        home = root_home if stage < 2 else str(Path(root_home) / "restore")
        config_home = Path(home) / "config"
        data = config_home / "BraveSoftware/Brave-Browser"
        env = dict(os.environ, HOME=home, XDG_CONFIG_HOME=str(config_home),
                   XDG_CACHE_HOME=str(Path(home) / "cache"),
                   XDG_DATA_HOME=str(Path(home) / "data"),
                   XDG_STATE_HOME=str(Path(home) / "state"))
        if stage == 2:
            (Path(home) / "snapshot").mkdir(parents=True)
            (Path(home) / "snapshot/Preferences.json").write_bytes(
                (Path(root_home) / "snapshot/Preferences.json").read_bytes()
            )
        port_file = data / "DevToolsActivePort"
        port_file.unlink(missing_ok=True)
        with (Path(home) / "browser.log").open("w+") as log:
            process = subprocess.Popen(
                [sys.argv[3] if stage == 2 else sys.argv[1], "--headless=new", "--disable-gpu", "--no-first-run",
                 "--no-default-browser-check", "--disable-background-networking",
                 "--disable-component-update", "--disable-extensions",
                 "--remote-debugging-port=0", "--remote-allow-origins=http://localhost",
                 "about:blank"],
                env=env,
                stdout=log, stderr=log, start_new_session=True,
            )
            sock = None
            try:
                deadline = time.monotonic() + 30
                while not port_file.exists():
                    if process.poll() is not None or time.monotonic() > deadline:
                        log.seek(0)
                        raise AssertionError("Brave failed to start: " + log.read())
                    time.sleep(0.1)
                port = port_file.read_text().splitlines()[0]
                with urlopen(f"http://127.0.0.1:{port}/json", timeout=10) as response:
                    page = next(p for p in json.load(response) if p["type"] == "page")
                sock = websocket.create_connection(
                    page["webSocketDebuggerUrl"], origin="http://localhost", timeout=15,
                )
                request_id = 0

                def call(method, **params):
                    global request_id
                    request_id += 1
                    sock.send(json.dumps({"id": request_id, "method": method, "params": params}))
                    while True:
                        result = json.loads(sock.recv())
                        if result.get("id") == request_id:
                            assert "error" not in result, result
                            return result["result"]

                def evaluate(expression):
                    result = call("Runtime.evaluate", expression=expression,
                                  awaitPromise=True, returnByValue=True)
                    assert "exceptionDetails" not in result, result
                    return result["result"].get("value")

                call("Page.navigate", url="brave://settings/")
                deadline = time.monotonic() + 20
                while not evaluate("typeof chrome.settingsPrivate !== 'undefined'"):
                    assert time.monotonic() < deadline, "Settings WebUI did not load"
                    time.sleep(0.1)
                prefs = {p["key"]: p for p in evaluate(
                    "new Promise(resolve => chrome.settingsPrivate.getAllPrefs(resolve))"
                )}
                expected = {
                    "homepage": ["https://homepage.backyard-host.com/", "https://example.invalid/", "https://explicit.invalid/"][stage],
                    "homepage_is_newtabpage": False,
                    "browser.show_home_button": True,
                    "credentials_enable_service": False,
                    "credentials_enable_autosignin": False,
                }
                for key, value in expected.items():
                    assert prefs[key]["value"] == value, (key, prefs[key])
                    if key != "credentials_enable_autosignin":
                        assert prefs[key]["enforcement"] == "RECOMMENDED", (key, prefs[key])
                if stage > 0:
                    assert prefs["bookmark_bar.show_on_all_tabs"]["value"] is False
                engines = evaluate(
                    "import('chrome://resources/js/cr.js')"
                    ".then(m => m.sendWithPromise('getSearchEnginesList'))"
                )
                google = next(e for e in engines["defaults"] if e["default"])
                assert google["name"] == "Google", google
                assert google["url"] == "https://www.google.com/search?q=%s", google
                assert google["isRecommendedFromPolicy"], google
                edits = {"homepage": "https://example.invalid/", "bookmark_bar.show_on_all_tabs": False} if stage == 0 else {}
                if stage == 1:
                    edits = {
                        "homepage": "https://homepage.backyard-host.com/",
                        "homepage_is_newtabpage": False,
                        "browser.show_home_button": True,
                        "credentials_enable_service": False,
                    }
                for key, value in edits.items():
                    assert evaluate(
                        "new Promise(resolve => chrome.settingsPrivate.setPref("
                        f"{json.dumps(key)}, {json.dumps(value)}, '', resolve))"
                    ), "Preference was not editable: " + key
                # Ask the actual browser to flush preferences before restarting.
                sock.send(json.dumps({"id": 1000, "method": "Browser.close"}))
                process.wait(timeout=10)
            finally:
                if sock is not None:
                    sock.close()
                # Bound shutdown even if headless Brave or its shell helper hangs.
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait()
                time.sleep(0.1)

        if stage == 1:
            assert os.access(config_home / "syncbrave/brave-policies/recommended/wrapper.json", os.W_OK)
            manifest = config_home / "syncbrave/brave-extensions/nngceckbapebfimnlniiiahkandclblb.json"
            assert json.loads(manifest.read_text()) == {"external_update_url": "https://clients2.google.com/service/update2/crx"}
            assert os.access(manifest, os.W_OK)
            # Synthetic private/stateful data must not survive snapshot filtering.
            preference_file = data / "Default/Preferences"
            original = json.loads(preference_file.read_text())
            original.update({
                "account_info": [{"email": "private@example.invalid"}],
                "extensions": {"settings": {"example": {"token": "synthetic-private"}}},
                "session": {"startup_urls": ["https://private.invalid/"]},
                "unknown_future_state": {"credentials": ["synthetic-private"]},
            })
            original["browser"]["window_placement"] = {"machine_id": "synthetic-machine"}
            preference_file.write_text(json.dumps(original))
            subprocess.run([sys.argv[2]], env=env, check=True)
            exported = Path(home) / "snapshot/Preferences.json"
            captured = json.loads(exported.read_text())
            expected = {
                "homepage": "https://homepage.backyard-host.com/",
                "homepage_is_newtabpage": False,
                "browser": {"show_home_button": True},
                "bookmark_bar": {"show_on_all_tabs": False},
                "credentials_enable_service": False,
                "credentials_enable_autosignin": False,
            }
            assert captured == expected, "Snapshot retained unexpected fields or lost preferences"
            assert sorted(p.name for p in exported.parent.iterdir()) == ["Preferences.json"]
            # Reject malformed values and nonportable generated/local homepage paths.
            malformed = dict(original, homepage="file:///nix/store/synthetic-path",
                             credentials_enable_service={"secret": "synthetic-private"})
            preference_file.write_text(json.dumps(malformed))
            subprocess.run([sys.argv[2]], env=env, check=True)
            filtered = json.loads(exported.read_text())
            assert "homepage" not in filtered and "credentials_enable_service" not in filtered
            preference_file.write_text(json.dumps(original))
            subprocess.run([sys.argv[2]], env=env, check=True)

print("Real headless Brave: policy delivery, writable sync, edit persistence, snapshot pruning, fresh-profile restore, and explicit preference precedence passed.")
