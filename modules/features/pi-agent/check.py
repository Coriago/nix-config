"""Check bundled extensions over Pi's RPC transport, without network or credentials."""

import json
import os
import selectors
import subprocess
import sys
import tempfile
import time


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
    subprocess.run([binary, "--version"], env=env, cwd=tmp, check=True, timeout=15)
    # Subcommands must not be mistaken for chat prompts by wrapper flags.
    subprocess.run([binary, "list"], env=env, cwd=tmp, check=True, timeout=15)
    with tempfile.TemporaryFile() as stderr:
        proc = subprocess.Popen(
            [binary, "--mode", "rpc", "--no-session", "--no-approve", "-e", probe],
            env=env, cwd=tmp, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=stderr,
        )
        events = []
        try:
            proc.stdin.write(b'{"id":"check","type":"get_commands"}\n')
            proc.stdin.write(b'{"id":"probe","type":"prompt","message":"/mypi-check"}\n')
            proc.stdin.flush()
            deadline = time.monotonic() + 45
            buffer = b""
            with selectors.DefaultSelector() as selector:
                selector.register(proc.stdout, selectors.EVENT_READ)
                while not (
                    any(event.get("id") == "check" for event in events)
                    and any(event.get("statusKey") == "mypi-check" for event in events)
                ):
                    assert time.monotonic() < deadline, "Pi startup timed out"
                    for key, _ in selector.select(timeout=1):
                        chunk = os.read(key.fd, 65536)
                        assert chunk, f"Pi exited during startup: {proc.poll()}"
                        buffer += chunk
                        while b"\n" in buffer:
                            line, buffer = buffer.split(b"\n", 1)
                            if line.strip():
                                events.append(json.loads(line))
        finally:
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
    print("Pi loaded plugins and connected to Chrome DevTools through built-in MCP.")
