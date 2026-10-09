"""Check the wrapped CLI and exercise its Playwright browser over MCP, offline."""

import json
import os
from pathlib import Path
import queue
import subprocess
import sys
import threading
import time


package = Path(sys.argv[1])
binary = package / "bin/opencode"
baseline = json.loads((package / "opencode-config.json").read_text())
config_path = Path(os.environ["XDG_CONFIG_HOME"]) / "syncopencode/opencode-config.json"
tui_path = config_path.with_name("opencode-tui-config.json")

version = subprocess.check_output([binary, "--version"], text=True, timeout=30)
assert "v2." in version, version
print(version.strip(), flush=True)
config = json.loads(config_path.read_text())
assert config == baseline, "Synced config differs from the personalized baseline"
assert json.loads(tui_path.read_text()) == json.loads((package / "opencode-tui-config.json").read_text())
assert not config_path.is_symlink() and not tui_path.is_symlink()
assert os.access(config_path, os.W_OK) and os.access(tui_path, os.W_OK)
# Reapply declared values while preserving a valid runtime-only preference.
config_path.write_text(json.dumps({**config, "autoupdate": True, "logLevel": "WARN"}))

sources = subprocess.run(
    [binary, "debug", "config"], text=True, capture_output=True, timeout=60
)
assert sources.returncode == 0, sources.stdout + sources.stderr
assert str(config_path) in sources.stdout, sources.stdout + sources.stderr
synced = json.loads(config_path.read_text())
assert synced["autoupdate"] is False
assert synced["logLevel"] == "WARN"
assert {key: synced[key] for key in baseline} == baseline
print("Writable configuration discovered; declared defaults restored and runtime preference retained", flush=True)

for _ in range(10):
    status = subprocess.run(
        [binary, "mcp", "list"], text=True, capture_output=True, timeout=60
    )
    assert status.returncode == 0, status.stdout + status.stderr
    if "playwright" in status.stdout and "connected" in status.stdout.lower():
        break
    time.sleep(1)
else:
    raise AssertionError(status.stdout + status.stderr + sources.stdout + sources.stderr)
print("OpenCode connected to Playwright MCP", flush=True)

server = subprocess.Popen(
    config["mcp"]["servers"]["playwright"]["command"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    bufsize=1,
)
messages = queue.Queue()
errors = []


def read_messages():
    for line in server.stdout:
        try:
            messages.put(json.loads(line))
        except json.JSONDecodeError:
            errors.append(line)
    messages.put(None)


def read_errors():
    errors.extend(server.stderr)


threading.Thread(target=read_messages, daemon=True).start()
threading.Thread(target=read_errors, daemon=True).start()
request_id = 0


def send(message):
    server.stdin.write(json.dumps({"jsonrpc": "2.0", **message}) + "\n")
    server.stdin.flush()


def request(method, params):
    global request_id
    request_id += 1
    send({"id": request_id, "method": method, "params": params})
    while True:
        try:
            message = messages.get(timeout=60)
        except queue.Empty:
            raise AssertionError(f"MCP timeout: {method}\n{''.join(errors)}")
        assert message is not None, "MCP exited:\n" + "".join(errors)
        if message.get("method") == "roots/list":
            send({"id": message["id"], "result": {"roots": [{"uri": Path.cwd().as_uri(), "name": "test"}]}})
        elif message.get("id") == request_id and "method" not in message:
            assert "error" not in message, message
            result = message["result"]
            assert not result.get("isError"), result
            return result


try:
    request("initialize", {
        "protocolVersion": "2024-11-05",
        "capabilities": {"roots": {}},
        "clientInfo": {"name": "myopencode-check", "version": "1"},
    })
    send({"method": "notifications/initialized"})
    tools = request("tools/list", {})["tools"]
    assert {"browser_navigate", "browser_evaluate", "browser_snapshot"} <= {tool["name"] for tool in tools}
    request("tools/call", {"name": "browser_navigate", "arguments": {"url": "about:blank"}})
    request("tools/call", {
        "name": "browser_evaluate",
        "arguments": {"function": "() => { document.body.innerHTML = '<h1>myopencode-browser-test</h1>'; return document.body.innerText; }"},
    })
    snapshot = request("tools/call", {"name": "browser_snapshot", "arguments": {}})
    assert "myopencode-browser-test" in json.dumps(snapshot), snapshot
    request("tools/call", {"name": "browser_close", "arguments": {}})
    print("Playwright MCP: browser launched, JavaScript executed, snapshot verified", flush=True)
finally:
    server.terminate()
    try:
        server.wait(timeout=10)
    except subprocess.TimeoutExpired:
        server.kill()
        server.wait()
