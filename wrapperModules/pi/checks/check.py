"""Real offline Pi CLI/RPC; synthetic settings and private data only."""
import json
import os
from pathlib import Path
import selectors
import subprocess
import sys
import tempfile

binary, snapshot, restore, browser, browser_snapshot = sys.argv[1:]
with tempfile.TemporaryDirectory(prefix="pi wrapper ") as tmp:
    root = Path(tmp)
    env = dict(os.environ, HOME=tmp, XDG_CONFIG_HOME=f"{tmp}/config",
               XDG_STATE_HOME=f"{tmp}/state", XDG_CACHE_HOME=f"{tmp}/cache",
               PI_OFFLINE="1", PI_CODING_AGENT_DIR=f"{tmp}/wrong")
    agent = root / "agent with spaces"

    def run(exe, *args):
        return subprocess.run([exe, *args], env=env, cwd=tmp, check=True,
                              capture_output=True, text=True, timeout=30)

    def rpc(exe):
        proc = subprocess.Popen([exe, "--mode", "rpc", "--no-session", "--no-mcp",
                                 "--no-approve", "--no-extensions"],
                                env=env, cwd=tmp, stdin=subprocess.PIPE,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            proc.stdin.write(b'{"id":"state","type":"get_state"}\n'
                             b'{"id":"commands","type":"get_commands"}\n')
            proc.stdin.flush()
            records = {}
            buffer = b""
            with selectors.DefaultSelector() as selector:
                selector.register(proc.stdout, selectors.EVENT_READ)
                while len(records) < 2:
                    assert selector.select(30), "RPC response timed out"
                    chunk = os.read(proc.stdout.fileno(), 65536)
                    assert chunk, "Pi exited before replying"
                    buffer += chunk
                    while b"\n" in buffer:
                        line, buffer = buffer.split(b"\n", 1)
                        record = json.loads(line)
                        if record.get("id") in ("state", "commands"):
                            assert record["success"], record
                            records[record["id"]] = record["data"]
            assert records["state"]["autoCompactionEnabled"] is False
            assert "wrapper-probe" in {c["name"] for c in records["commands"]["commands"]}
        finally:
            proc.stdin.close()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
            errors = proc.stderr.read().decode().splitlines()
            assert not [line for line in errors
                        if not (line.startswith("sync-snap: pi:") and line.endswith("failed=0"))], errors

    run(binary, "--version")
    assert not (root / "wrong").exists()
    settings = agent / "settings.json"
    assert json.loads(settings.read_text()) == {
        "theme": "dark", "compaction": {"enabled": False}, "editorPaddingX": 2}
    assert json.loads((agent / "keybindings.json").read_text()) == {
        "app.session.new": "ctrl+shift+n"}
    rpc(binary)
    # Pi's native subcommands must remain first in argv.
    run(binary, "list")
    data = json.loads(settings.read_text())
    data.update(theme="light", quietStartup=True, compaction={"enabled": True},
                trackingId="fixture-private-id", deviceId="fixture-device",
                lastChangelogVersion="0.0.0", sessionDir="/private/sessions",
                httpProxy="https://user:synthetic-secret@proxy.invalid",
                extensions=["/nix/store/fixture/extension.ts", "./local.ts"],
                packages=["npm:fixture"], defaultTools=["read", "bash"],
                shellPath="/nix/store/fixture/bin/bash")
    settings.write_text(json.dumps(data))
    # Snapshot must capture edits without first syncing declared settings.
    run(snapshot)
    captured = json.loads((root / "captured/settings.json").read_text())
    assert captured == {"theme": "light", "quietStartup": True,
                        "compaction": {"enabled": True}, "editorPaddingX": 2,
                        "defaultTools": ["read", "bash"]}, captured
    assert {p.name for p in (root / "captured").iterdir()} == {
        "settings.json", "keybindings.json"}
    run(restore, "--version")
    restored = json.loads((root / "restored/settings.json").read_text())
    assert restored == captured | {"compaction": {"enabled": False}}
    rpc(restore)
    # Declared values reapply on launch; runtime-only preferences survive.
    run(binary, "--version")
    assert json.loads(settings.read_text())["quietStartup"] is True
    assert json.loads(settings.read_text())["compaction"]["enabled"] is False
    run(browser, "--version")
    browser_config = agent / "chrome-devtools.json"
    browser_config.write_text(json.dumps({
        "headless": False, "isolated": True, "viewport": "1280x720",
        "wsHeaders": '{"Authorization":"synthetic-secret"}',
        "user-data-dir": "/private/browser", "chromeArg": ["--private-fixture"],
        "executablePath": "/nix/store/fixture/chromium"}))
    run(browser_snapshot)
    assert json.loads((root / "captured/chrome-devtools.json").read_text()) == {
        "headless": False, "isolated": True, "viewport": "1280x720"}
    print("Pi config discovery, explicit extensions, subcommands, sync, pruning, and restored baseline passed.")
