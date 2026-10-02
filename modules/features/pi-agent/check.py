"""Check bundled extensions over Pi's RPC transport, without network or credentials."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import selectors
import subprocess
import sys
import tempfile
import time
import threading


# Simulate only the model response; Pi executes the actual sandbox and tools.
CODE = """
const results = await Promise.all([
  tools.bash({command: "printf codemode-bash-ok"}),
  tools.mcp__chrome_devtools__list_pages({}),
]);
if (results[0].exit_code !== 0 || results[0].output !== "codemode-bash-ok")
  throw new Error("Nested bash failed");
if (results[1].isError || !results[1].content.length)
  throw new Error("Nested MCP failed");
text("codemode-worker-ok");
"""


class ModelStub(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_POST(self):
        request = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        done = any(message["role"] == "tool" for message in request["messages"])
        delta = {"role": "assistant", "content": "Done"} if done else {
            "role": "assistant", "tool_calls": [{
                "index": 0, "id": "codemode-check", "type": "function",
                "function": {"name": "codemode", "arguments": json.dumps({"code": CODE})},
            }],
        }
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        for content, reason in [(delta, None), ({}, "stop" if done else "tool_calls")]:
            chunk = {"id": "check", "object": "chat.completion.chunk", "created": 0,
                     "model": "check", "choices": [{"index": 0, "delta": content,
                                                     "finish_reason": reason}]}
            self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode())
        self.wfile.write(b"data: [DONE]\n\n")
        self.wfile.flush()


binary, probe = sys.argv[1:]
with tempfile.TemporaryDirectory() as tmp:
    env = dict(
        os.environ,
        HOME=tmp,
        XDG_CONFIG_HOME=f"{tmp}/.config",
        XDG_CACHE_HOME=f"{tmp}/.cache",
        PI_CODING_AGENT_DIR=f"{tmp}/.pi/agent",
        PI_OFFLINE="1",
    )
    # Disable only the remote connection; extension registration is tested separately.
    agent_dir = os.path.join(tmp, ".pi", "agent")
    os.makedirs(agent_dir)
    with open(os.path.join(agent_dir, "mcp.json"), "w") as f:
        json.dump({"mcpServers": {"context7": {
            "url": "https://mcp.context7.com/mcp", "enabled": False,
        }}}, f)
    server = ThreadingHTTPServer(("127.0.0.1", 0), ModelStub)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    with open(os.path.join(agent_dir, "models.json"), "w") as f:
        json.dump({"providers": {"smoke": {
            "baseUrl": f"http://127.0.0.1:{server.server_port}/v1",
            "api": "openai-completions", "apiKey": "test-only",
            "models": [{"id": "check", "contextWindow": 200000, "maxTokens": 1024}],
        }}}, f)
    subprocess.run([binary, "--version"], env=env, cwd=tmp, check=True, timeout=15)
    # Subcommands must not be mistaken for chat prompts by wrapper flags.
    subprocess.run([binary, "list"], env=env, cwd=tmp, check=True, timeout=15)
    with tempfile.TemporaryFile() as stderr:
        proc = subprocess.Popen(
            [binary, "--mode", "rpc", "--no-session", "--no-approve", "-e", probe,
             "--provider", "smoke", "--model", "check", "--thinking", "off"],
            env=env, cwd=tmp, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=stderr,
        )
        events = []
        try:
            proc.stdin.write(b'{"id":"check","type":"get_commands"}\n')
            proc.stdin.write(b'{"id":"probe","type":"prompt","message":"/mypi-check"}\n')
            proc.stdin.flush()
            deadline = time.monotonic() + 60
            buffer = b""
            codemode_sent = False
            with selectors.DefaultSelector() as selector:
                selector.register(proc.stdout, selectors.EVENT_READ)
                while not any(event.get("type") == "agent_settled" for event in events):
                    if not codemode_sent and any(
                        event.get("statusKey") == "mypi-check" for event in events
                    ):
                        proc.stdin.write(b'{"id":"codemode","type":"prompt","message":"Run the sandbox check"}\n')
                        proc.stdin.flush()
                        codemode_sent = True
                    assert time.monotonic() < deadline, f"Pi check timed out: {events}"
                    for key, _ in selector.select(timeout=1):
                        chunk = os.read(key.fd, 65536)
                        assert chunk, f"Pi exited during startup: {proc.poll()}"
                        buffer += chunk
                        while b"\n" in buffer:
                            line, buffer = buffer.split(b"\n", 1)
                            if line.strip():
                                events.append(json.loads(line))
        finally:
            server.shutdown()
            server.server_close()
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
            stderr.seek(0)
            errors = stderr.read().decode()
            if errors:
                print(errors, file=sys.stderr)

    assert not errors, errors
    response = next(event for event in events if event.get("id") == "check")
    assert response["success"], response
    commands = {cmd["name"] for cmd in response["data"]["commands"]}
    assert "websearch" in commands, commands
    statuses = {
        event["statusKey"]: event.get("statusText")
        for event in events if event.get("method") == "setStatus"
    }
    state = json.loads(statuses["mypi-check"])
    tools = set(state["tools"])
    assert {"web_search", "fetch_content", "ask_user_question"} <= tools, tools
    assert {"mcp__chrome-devtools__list_pages", "mcp__chrome-devtools__evaluate_script", "codemode"} <= tools, tools
    sandbox = next(event for event in events
                   if event.get("type") == "tool_execution_end"
                   and event.get("toolName") == "codemode")
    assert not sandbox["isError"], sandbox
    assert "codemode-worker-ok" in json.dumps(sandbox["result"]), sandbox
    nested = {call["name"]: call["status"] for call in sandbox["result"]["details"]["calls"]}
    assert nested == {"bash": "ok", "mcp__chrome-devtools__list_pages": "ok"}, nested
    print("Pi loaded plugins and executed codemode with nested bash and Chrome DevTools calls.")
