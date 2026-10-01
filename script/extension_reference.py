"""Compare original port JS in a fresh pinned Gecko browser; never alter Serein gates."""
import hashlib
import json
import pathlib
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
import zipfile
from download_reference import run_download_reference
from formatter_reference import run_formatter_reference

out = pathlib.Path('evidence/extension-reference')
results = []
prefix = None

def request(path, data=None, method=None):
    req = urllib.request.Request('http://127.0.0.1:4444' + path,
        data=None if data is None else json.dumps(data).encode(),
        headers={'Content-Type': 'application/json'}, method=method)
    try:
        with urllib.request.urlopen(req, timeout=40) as response:
            result = json.load(response)['value']
    except urllib.error.HTTPError as error:
        raise RuntimeError(error.read().decode()) from error
    if isinstance(result, dict) and 'error' in result:
        raise RuntimeError(result)
    return result

def script(code, args=None, asynchronous=False):
    return request(prefix + ('/execute/async' if asynchronous else '/execute/sync'), {'script': code, 'args': args or []})

def page_probe():
    return script('return {url:location.href,ready:document.readyState,...document.documentElement.dataset};')

for _ in range(60):
    try:
        request('/status')
        break
    except Exception:
        time.sleep(0.2)
else:
    raise RuntimeError('Owned geckodriver did not become ready')
download_directory=tempfile.TemporaryDirectory(prefix='serein-reference-downloads-')
try:
    session = request('/session', {'capabilities': {'alwaysMatch': {'browserName': 'firefox', 'moz:firefoxOptions': {
        'binary': '/tmp/SereinPortReference.app/Contents/MacOS/zen',
        'prefs': {'zen.welcome-screen.seen': True, 'browser.shell.checkDefaultBrowser': False,
                  'browser.startup.homepage_override.mstone': 'ignore',
                  'devtools.jsonview.enabled':False,
                  'browser.download.folderList':2,'browser.download.useDownloadDir':True,
                  'browser.download.dir':download_directory.name}}}}})
    prefix = '/session/' + session['sessionId']
    (out / 'capabilities.json').write_text(json.dumps(session['capabilities'], indent=2))
    request(prefix + '/timeouts', {'script': 15000, 'pageLoad': 15000})
    request(prefix + '/window/rect', {'width': 1000, 'height': 677, 'x': 10, 'y': 30})
    # Local-network discovery is unnecessary for the loopback-only fixture.
    subprocess.run(['osascript', '-e', 'tell application "System Events" to tell process "UserNotificationCenter" to click button "Don’t Allow" of window 1'], capture_output=True, text=True, timeout=8)
    with tempfile.TemporaryDirectory(prefix='serein-port-reference-') as temporary:
        for version in [2, 3]:
            name = f'mv{version}'
            entry = {'variant': name, 'browser': 'Zen 1.22.2b (Gecko)', 'fixtureVersion': '1.0'}
            results.append(entry)
            addon_id = f'serein-port-reference-mv{version}@serein.invalid'
            try:
                source = pathlib.Path('Fixtures/PortMessaging') / name
                manifest = json.loads((source / 'manifest.json').read_text())
                manifest['browser_specific_settings'] = {'gecko': {'id': addon_id}}
                if version == 3:
                    manifest['background'] = {'scripts': ['background.js'], 'persistent': False}
                entry['manifestAdaptation'] = 'Declared Gecko ID; MV3 uses nonpersistent background scripts instead of Chrome service_worker.' if version == 3 else 'Declared Gecko ID only.'
                entry['scriptSHA256'] = {p: hashlib.sha256((source / p).read_bytes()).hexdigest() for p in ['content.js', 'background.js']}
                package = pathlib.Path(temporary) / (name + '.xpi')
                with zipfile.ZipFile(package, 'w') as archive:
                    archive.writestr('manifest.json', json.dumps(manifest))
                    for p in ['content.js', 'background.js']:
                        archive.write(source / p, p)
                (out / (name + '-manifest.json')).write_text(json.dumps(manifest, indent=2))
                installed = request(prefix + '/moz/addon/install', {'path': str(package), 'temporary': True})
                assert installed == addon_id, installed
                url = 'http://127.0.0.1:8765/index.html?port-lifecycle=' + name + '-disable'
                request(prefix + '/url', {'url': url})
                before = {}
                for _ in range(100):
                    before = page_probe()
                    if before.get('portEchoCount') == '3' and before.get('url') == url and before.get('ready') == 'complete':
                        break
                    time.sleep(0.05)
                entry['beforeDisable'] = before
                assert before.get('portEchoCount') == '3', 'Port did not establish three ordered echoes'
                # This privileged automation acts on the pinned reference's actual
                # add-on manager, like its settings toggle. It is not browser code
                # copied into Serein and does not alter extension content scripts.
                request(prefix + '/moz/context', {'context': 'chrome'})
                disabled = script('''const done=arguments[arguments.length-1];
                    const {AddonManager}=ChromeUtils.importESModule("resource://gre/modules/AddonManager.sys.mjs");
                    AddonManager.getAddonByID(arguments[0]).then(async addon=>{
                        if(!addon) throw new Error("Reference add-on absent");
                        await addon.disable();done({disabled:addon.userDisabled,active:addon.isActive});
                    }).catch(error=>done({error:String(error)}));''', [addon_id], asynchronous=True)
                entry['disabled'] = disabled
                request(prefix + '/moz/context', {'context': 'content'})
                for _ in range(100):
                    after = page_probe()
                    if after.get('portDisconnected') == 'true':
                        break
                    time.sleep(0.05)
                script("window.dispatchEvent(new Event('serein-port-after-disable'))")
                time.sleep(0.25)
                entry['afterDisable'] = page_probe()
                entry['scenarioExecuted'] = disabled.get('disabled') is True and disabled.get('active') is False
                subprocess.run(['screencapture', '-x', str(out / (name + '-disabled.png'))], check=True, timeout=8)
            except Exception as error:
                entry['error'] = str(error)
                entry['scenarioExecuted'] = False
            finally:
                try:
                    request(prefix + '/moz/context', {'context': 'content'})
                    request(prefix + '/moz/addon/uninstall', {'id': addon_id})
                except Exception as error:
                    entry['cleanupError'] = str(error)
                (out / 'results.json').write_text(json.dumps(results, indent=2))
        download_results=[run_download_reference(request,script,prefix,out,temporary,version,download_directory.name) for version in [2,3]]
        formatter_result=run_formatter_reference(request,script,prefix,out,temporary)
    assert all(item['scenarioExecuted'] for item in results), results
    assert all(item['scenarioExecuted'] for item in download_results), download_results
    assert all(item['result'].get('checks') and all(item['result']['checks'].values()) for item in download_results), download_results
    assert formatter_result['scenarioExecuted'] and all(formatter_result['checks'].values()), formatter_result
finally:
    try:
        if prefix:
            request(prefix, method='DELETE')
    finally:
        download_directory.cleanup()
