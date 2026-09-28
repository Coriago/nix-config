"""Check the wrapped CLI and exercise its memory server over MCP, offline."""

import json
from pathlib import Path
import queue
import subprocess
import sys
import threading
import time


package = Path(sys.argv[1])
binary = package / "bin/myopencode"
config_path = package / "myopencode-config.json"
config = json.loads(config_path.read_text())

version = subprocess.check_output([binary, "--version"], text=True, timeout=30)
assert "v2." in version, version
print(version.strip(), flush=True)

sources = subprocess.run(
    [binary, "debug", "config"], text=True, capture_output=True, timeout=60
)
assert sources.returncode == 0, sources.stdout + sources.stderr
assert str(config_path) in sources.stdout, sources.stdout + sources.stderr
print("Wrapped configuration discovered by OpenCode", flush=True)

for _ in range(10):
    status = subprocess.run(
        [binary, "mcp", "list"], text=True, capture_output=True, timeout=60
    )
    assert status.returncode == 0, status.stdout + status.stderr
    if "memory" in status.stdout and "connected" in status.stdout.lower():
        break
    time.sleep(1)
else:
    raise AssertionError(status.stdout + status.stderr + sources.stdout + sources.stderr)
print("OpenCode connected to memory MCP", flush=True)

server = subprocess.Popen(
    config["mcp"]["memory"]["command"],
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
    assert {"create_entities", "read_graph", "delete_entities"} <= {tool["name"] for tool in tools}
    request("tools/call", {
        "name": "create_entities",
        "arguments": {"entities": [{"name": "myopencode-test", "entityType": "test", "observations": ["MCP works"]}]},
    })
    graph = request("tools/call", {"name": "read_graph", "arguments": {}})
    assert "myopencode-test" in json.dumps(graph), graph
    request("tools/call", {"name": "delete_entities", "arguments": {"entityNames": ["myopencode-test"]}})
    print("Memory MCP: initialized, entity created, graph read, entity deleted", flush=True)
finally:
    server.terminate()
    try:
        server.wait(timeout=10)
    except subprocess.TimeoutExpired:
        server.kill()
        server.wait()
