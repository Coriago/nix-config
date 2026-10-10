"""Run distinct real profiles concurrently; optionally test Web Store lifecycle online."""
import json
import os
from pathlib import Path
import signal
import shutil
import subprocess
import sys
import tempfile
import time
from urllib.request import urlopen
import websocket

BITWARDEN = 'nngceckbapebfimnlniiiahkandclblb'
PREBUILT = 'pbfopnphnepmbmdpifenjcibgnknlbnj'
STYLUS = 'clngdbkpkpeebahjckkjfobafhncgmne'
ONLINE = os.environ.get('BRAVE_TEST_NETWORK') == '1'

class Browser:
    def __init__(self, exe, env, data, explicit_data=False):
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
        if not ONLINE:
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

with tempfile.TemporaryDirectory(prefix='brave isolation ') as temporary:
    home = Path(temporary)
    config = home / 'config'
    env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config),
               XDG_CACHE_HOME=str(home/'cache'), XDG_DATA_HOME=str(home/'data'),
               XDG_STATE_HOME=str(home/'state'))
    contrast_data = config/'contrast/user-data'
    # Native uninstall confirmation is unavailable headlessly. Simulate
    # its saved blocklist state in a real, disposable browser profile.
    bootstrap = Browser(sys.argv[3], env, contrast_data)
    try:
        bootstrap.settings()
    finally:
        bootstrap.close()
    for name in ['Preferences', 'Secure Preferences']:
        path = contrast_data/'Default'/name
        if path.exists():
            prefs = json.loads(path.read_text())
            extension_prefs = prefs.setdefault('extensions', {})
            extension_prefs.get('settings', {}).pop(BITWARDEN, None)
            if name == 'Preferences':
                extension_prefs['external_uninstalls'] = [BITWARDEN]
            path.write_text(json.dumps(prefs))
    shutil.rmtree(contrast_data/'Default/Extensions'/BITWARDEN, ignore_errors=True)
    bootstrap = Browser(sys.argv[3], env, contrast_data)
    try:
        bootstrap.navigate('brave://extensions/', "typeof chrome.developerPrivate !== 'undefined'")
        for _ in range(5):
            installed = bootstrap.evaluate('chrome.developerPrivate.getExtensionsInfo({includeDisabled:true})')
            assert BITWARDEN not in {e['id'] for e in installed}
            time.sleep(1)
    finally:
        bootstrap.close()
    print('Simulated saved UI-removal state respected by external installation on relaunch.', flush=True)
    ordinary = Browser(sys.argv[4], env, config/'BraveSoftware/Brave-Browser', explicit_data=True)
    main = contrast = None
    try:
        ordinary.settings()
        for key, value in [('homepage', 'https://ordinary.invalid/'), ('credentials_enable_service', True)]:
            assert ordinary.evaluate('new Promise(resolve => chrome.settingsPrivate.setPref('
                                     f'{json.dumps(key)}, {json.dumps(value)}, "", resolve))')
        main = Browser(sys.argv[1], env, config/'syncbrave/user-data')
        managed_file = contrast_data/'brave-policies/managed/nix-wrapper-extensions.json'
        managed_file.parent.mkdir(parents=True, exist_ok=True)
        managed_file.write_text(json.dumps({'ExtensionSettings': {'a'*32: {'installation_mode': 'blocked'}}}))
        contrast = Browser(sys.argv[2], env, contrast_data)
        assert len({ordinary.port, main.port, contrast.port}) == 3, 'The browsers shared a session'
        for browser, homepage, search in [(main, 'https://homepage.backyard-host.com/', 'Google'),
                                          (contrast, 'https://contrast.invalid/', 'Contrast Search')]:
            assert browser.settings()['homepage']['value'] == homepage
            engines = browser.evaluate("import('chrome://resources/js/cr.js').then(m => m.sendWithPromise('getSearchEnginesList'))")
            assert next(e for e in engines['defaults'] if e['default'])['name'] == search
            browser.navigate('brave://version/', "!!document.querySelector('#profile_path')?.textContent.trim()")
            profile_path = browser.evaluate("document.querySelector('#profile_path').textContent.trim()")
            assert profile_path == str(browser.data/'Default'), (profile_path, str(browser.data/'Default'))
        policy = json.loads((contrast_data/'brave-policies/managed/nix-wrapper-extensions.json').read_text())
        assert set(policy['ExtensionSettings']) == {BITWARDEN, STYLUS}
        local = contrast.extensions([PREBUILT])[PREBUILT]
        assert local['name'] == 'Wrapper prebuilt extension fixture' and local['version'] == '1.0.0', local['name']
        print('Prebuilt CRX installed by the actual browser from a local file.', flush=True)
        # The first browser must still have its original settings after the second starts.
        assert main.settings()['homepage']['value'] == 'https://homepage.backyard-host.com/'
        ordinary_prefs = ordinary.settings()
        assert ordinary_prefs['homepage']['value'] == 'https://ordinary.invalid/'
        assert ordinary_prefs['credentials_enable_service']['value'] is True
        print('Simultaneous ordinary Brave and two wrappers: distinct ports, profile paths, homepages, search engines and extension declarations passed.', flush=True)
        if ONLINE:
            installed = contrast.extensions([BITWARDEN, STYLUS])
            for extension in [BITWARDEN, STYLUS]:
                assert installed[extension]['mustRemainInstalled'], installed[extension]['name']
                assert not installed[extension]['userMayModify'], installed[extension]['name']
                assert installed[extension]['state'] == 'ENABLED', installed[extension]['name']
            main_installed = main.extensions([BITWARDEN])
            assert STYLUS not in main_installed and PREBUILT not in main_installed
            print('Previously removed Bitwarden restored; test-only Stylus installed; both enabled and required.', flush=True)
    finally:
        if contrast:
            contrast.close()
        if main:
            main.close()
        ordinary.close()
