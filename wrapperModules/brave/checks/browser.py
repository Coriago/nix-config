"""Shared headless Brave launch and DevTools helpers, without scenario-specific checks."""
import json
import os
import signal
import subprocess
import time
from urllib.request import urlopen
import websocket

class Browser:
    def __init__(self, exe, env, data, explicit_data=False, online=False, extra_args=()):
        self.data = data
        self.sock = None
        self.request_id = 0
        data.mkdir(parents=True, exist_ok=True)
        port_file = data / 'DevToolsActivePort'
        port_file.unlink(missing_ok=True)
        self.log = (data / 'test-browser.log').open('w+')
        args = ['--headless=new', '--disable-gpu', '--no-first-run',
                '--no-default-browser-check', '--disable-component-update',
                '--remote-debugging-port=0', '--remote-allow-origins=http://localhost',
                'about:blank']
        if explicit_data:
            args += [f"--user-data-dir={data}"]
        args += list(extra_args)
        if not online:
            args += ['--disable-background-networking']
        self.process = subprocess.Popen([exe, *args], env=env, stdout=self.log,
                                        stderr=self.log, start_new_session=True)
        try:
            deadline = time.monotonic() + 30
            while not port_file.exists():
                if self.process.poll() is not None or time.monotonic() > deadline:
                    self.log.seek(0)
                    raise AssertionError('No independent browser started: ' + self.log.read())
                time.sleep(.1)
            self.port = port_file.read_text().splitlines()[0]
            with urlopen(f'http://127.0.0.1:{self.port}/json', timeout=10) as response:
                page = next(p for p in json.load(response) if p['type'] == 'page')
            self.sock = websocket.create_connection(page['webSocketDebuggerUrl'],
                                                    origin='http://localhost', timeout=15)
        except BaseException:
            self.close()
            raise

    def call(self, method, **params):
        self.request_id += 1
        self.sock.send(json.dumps(dict(id=self.request_id, method=method, params=params)))
        while True:
            message = json.loads(self.sock.recv())
            if message.get('id') == self.request_id:
                assert 'error' not in message, message
                return message['result']

    def evaluate(self, expression):
        result = self.call('Runtime.evaluate', expression=expression,
                           awaitPromise=True, returnByValue=True, userGesture=True)
        assert 'exceptionDetails' not in result, result
        return result['result'].get('value')

    def navigate(self, url, ready):
        self.call('Page.navigate', url=url)
        deadline = time.monotonic() + 20
        while not self.evaluate(ready):
            assert time.monotonic() < deadline, f'{url} failed to load'
            time.sleep(.1)

    def settings(self):
        self.navigate('brave://settings/', "typeof chrome.settingsPrivate !== 'undefined'")
        return {p['key']: p for p in self.evaluate(
            'new Promise(resolve => chrome.settingsPrivate.getAllPrefs(resolve))')}

    def extensions(self, required):
        self.navigate('brave://extensions/', "typeof chrome.developerPrivate !== 'undefined'")
        deadline = time.monotonic() + 150
        while True:
            installed = {e['id']: e for e in self.evaluate(
                'chrome.developerPrivate.getExtensionsInfo({includeDisabled:true, includeTerminated:true})')}
            if set(required) <= installed.keys():
                return installed
            assert time.monotonic() < deadline, ('Extension download timed out', list(installed))
            time.sleep(1)

    def close(self):
        if self.sock:
            try:
                self.sock.send(json.dumps(dict(id=99999, method='Browser.close')))
                self.process.wait(timeout=10)
            except (OSError, websocket.WebSocketException, subprocess.TimeoutExpired):
                pass
            self.sock.close()
        try:
            os.killpg(self.process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        self.process.wait()
        self.log.close()

