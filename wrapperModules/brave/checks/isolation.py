"""Run distinct real profiles concurrently; optionally test Web Store lifecycle online."""
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import time
from functools import partial
from browser import Browser

BITWARDEN = 'nngceckbapebfimnlniiiahkandclblb'
PREBUILT = 'pbfopnphnepmbmdpifenjcibgnknlbnj'
STYLUS = 'clngdbkpkpeebahjckkjfobafhncgmne'
ONLINE = os.environ.get('BRAVE_TEST_NETWORK') == '1'
Browser = partial(Browser, online=ONLINE)

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
        main = Browser(sys.argv[1], env, config/'wrapper-test/user-data')
        managed_file = contrast_data/'brave-policies/managed/nix-wrapper-extensions.json'
        managed_file.parent.mkdir(parents=True, exist_ok=True)
        managed_file.write_text(json.dumps({'ExtensionSettings': {'a'*32: {'installation_mode': 'blocked'}}}))
        contrast = Browser(sys.argv[2], env, contrast_data)
        assert len({ordinary.port, main.port, contrast.port}) == 3, 'The browsers shared a session'
        for browser, homepage, search in [(main, 'https://wrapper.invalid/', 'Fixture Search'),
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
        assert main.settings()['homepage']['value'] == 'https://wrapper.invalid/'
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
