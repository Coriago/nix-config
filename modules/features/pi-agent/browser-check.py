"""Exercise the packaged Chrome DevTools server and browser, entirely offline."""

import json
import os
import queue
import re
import signal
import subprocess
import sys
import tempfile
import threading


with tempfile.TemporaryDirectory() as home:
    server = subprocess.Popen(
        [sys.argv[1]],
        env=dict(os.environ, HOME=home, XDG_CONFIG_HOME=home, XDG_CACHE_HOME=home),
        cwd=home, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, bufsize=1, start_new_session=True,
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
            if message.get("id") == request_id and "method" not in message:
                assert "error" not in message, message
                result = message["result"]
                assert not result.get("isError"), (result, "".join(errors))
                return result

    def call(name, **arguments):
        return request("tools/call", {"name": name, "arguments": arguments})

    try:
        request("initialize", {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "mypi-browser-check", "version": "1"},
        })
        send({"method": "notifications/initialized"})
        tools = {tool["name"] for tool in request("tools/list", {})["tools"]}
        assert {"list_pages", "evaluate_script", "take_snapshot", "take_screenshot"} <= tools, tools
        pages = call("new_page", url="about:blank")
        text = "\n".join(part.get("text", "") for part in pages["content"])
        ids = re.findall(r"^(\d+): about:blank", text, re.MULTILINE)
        assert ids, pages
        page = int(ids[-1])
        call("evaluate_script", pageId=page, function="""() => {
          document.body.innerHTML = '<h1>mypi-browser-test</h1>';
          return document.body.innerText;
        }""")
        snapshot = call("take_snapshot", pageId=page)
        assert "mypi-browser-test" in json.dumps(snapshot), snapshot
        screenshot = call("take_screenshot", pageId=page)
        assert any(part.get("type") == "image" and part.get("data") for part in screenshot["content"]), screenshot
        print("Chromium launched; JavaScript, snapshot, and screenshot checks passed.", flush=True)
    finally:
        os.killpg(server.pid, signal.SIGTERM)
        try:
            server.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(server.pid, signal.SIGKILL)
            server.wait()
