"""Original Formatter in the runner's pinned Chrome for Testing; never Serein."""
import functools
import hashlib
import http.server
import json
import os
import pathlib
import platform
import plistlib
import signal
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
from chrome_download_reference import prepare_download_reference, run_download_reference
from chrome_distribution import DRIVER_SHA256, verify_distribution

VERSION = '154.0.8037.57'
OUT = pathlib.Path('evidence/chrome-formatter-reference')
APP = pathlib.Path('/Applications/Google Chrome for Testing.app')
BINARY = APP / 'Contents/MacOS/Google Chrome for Testing'
DRIVER = pathlib.Path('/usr/local/share/chromedriver-mac-arm64/chromedriver')
OUT.mkdir(parents=True, exist_ok=True)
report = {'browser': 'Chrome for Testing', 'expectedVersion': VERSION,
          'extension': 'JSON Formatter 0.8.0', 'manifestAdaptation': 'None',
          'scope': 'Unmodified source build; three document checks, not store installation or universal compatibility.',
          'checks': {}, 'scenarioExecuted': False}
prefix = None
driver = server = server_thread = None


def request(path, data=None, method=None):
    req = urllib.request.Request('http://127.0.0.1:9515' + path,
        data=None if data is None else json.dumps(data).encode(),
        headers={'Content-Type': 'application/json'}, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.load(response)['value']
    except urllib.error.HTTPError as error:
        raise RuntimeError(error.read().decode()) from error


def script(code):
    return request(prefix + '/execute/sync', {'script': code, 'args': []})


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


with tempfile.TemporaryDirectory(prefix='serein-chrome-reference-') as temporary:
    try:
        assert platform.system() == 'Darwin' and platform.machine() == 'arm64'
        assert platform.mac_ver()[0].split('.')[0] == '27'
        report['os'] = platform.mac_ver()[0]
        info = plistlib.loads((APP / 'Contents/Info.plist').read_bytes())
        report['bundleVersion'] = info['CFBundleShortVersionString']
        report['driverSHA256'] = digest(DRIVER)
        assert report['driverSHA256'] == DRIVER_SHA256, 'Driver differs from pinned official distribution'
        report['driverVersion'] = subprocess.check_output([str(DRIVER), '--version'], text=True, timeout=10).strip()
        assert report['bundleVersion'] == VERSION, 'Runner browser changed; review and repin'
        assert report['driverVersion'].split()[1] == VERSION, 'Runner driver changed; review and repin'
        report['binarySHA256'] = digest(BINARY)
        report['driverSHA256'] = digest(DRIVER)
        signature = subprocess.run(['codesign', '--verify', '--deep', '--strict', str(APP)], capture_output=True, text=True, timeout=30)
        report['signatureVerification'] = {'exitCode': signature.returncode, 'diagnostic': signature.stderr}
        report['distribution'] = verify_distribution(APP, temporary, OUT)
        if signature.returncode != 0:
            assert signature.returncode == 1 and signature.stderr.strip() == str(APP) + ': code has no resources but signature indicates they must be present', 'Unexpected signature failure'
        build = pathlib.Path(temporary) / 'formatter'
        subprocess.run([sys.executable, 'script/build_json_formatter_fixture.py', str(build),
                        str(OUT / 'formatter-build.json')], check=True, timeout=240)
        extension = build / 'extension'
        report['originalManifestSHA256'] = hashlib.sha256((extension / 'manifest.json').read_bytes()).hexdigest()
        downloads_extension = prepare_download_reference(temporary, OUT)
        download_directory = pathlib.Path(temporary) / 'downloads'
        download_directory.mkdir()
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 8765),
            functools.partial(http.server.SimpleHTTPRequestHandler, directory='Fixtures'))
        server_thread = threading.Thread(target=server.serve_forever, daemon=True)
        server_thread.start()
        with (OUT / 'chromedriver.log').open('w') as log:
            driver = subprocess.Popen([str(DRIVER), '--port=9515', '--allowed-ips=127.0.0.1'],
                                      stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        for _ in range(60):
            try:
                request('/status')
                break
            except Exception:
                if driver.poll() is not None:
                    raise RuntimeError('Owned ChromeDriver exited before readiness')
                time.sleep(.1)
        else:
            raise RuntimeError('Owned ChromeDriver readiness timeout')
        session = request('/session', {'capabilities': {'alwaysMatch': {
            'browserName': 'chrome', 'goog:chromeOptions': {'binary': str(BINARY),
                'prefs': {'download.default_directory': str(download_directory), 'download.prompt_for_download': False}, 'args': [
                '--user-data-dir=' + str(pathlib.Path(temporary) / 'profile'),
                '--load-extension=' + str(extension.resolve()) + ',' + str(downloads_extension.resolve()), '--no-first-run', '--no-default-browser-check']}}}})
        prefix = '/session/' + session['sessionId']
        report['capabilities'] = session['capabilities']
        assert report['capabilities']['browserVersion'] == VERSION
        request(prefix + '/timeouts', {'script': 15000, 'pageLoad': 15000})
        report['window'] = request(prefix + '/window/rect', {'width': 1000, 'height': 677, 'x': 10, 'y': 30})
        request(prefix + '/url', {'url': 'http://127.0.0.1:8765/formatter.json'})
        value = {}
        for _ in range(100):
            value = script('''const pre=document.querySelector('#jsonFormatterRaw pre');
                let parsed=false,rawParseError=null;
                try {parsed=JSON.parse(pre?.innerText).project==='Serein'} catch(e){rawParseError=String(e)}
                return {formatted:!!document.querySelector('#jsonFormatterParsed .entry'),
                    project:window.json?.project || null,items:window.json?.nested?.items?.length ?? null,
                    globalType:typeof window.json,rawPresent:!!pre,parsed,rawParseError};''')
            if value.get('formatted') and value.get('project') == 'Serein':
                break
            time.sleep(.1)
        report['observation'] = value
        report['checks'] = {'isolatedFormatsJSON': value.get('formatted') is True,
                            'rawInnerTextParses': value.get('parsed') is True,
                            'mainWorldGlobal': value.get('project') == 'Serein' and value.get('items') == 4}
        report['scenarioExecuted'] = True
        # This fresh runner's fixture server needs only loopback. Deny the
        # optional local-network request; do not grant or edit privacy databases.
        consent = subprocess.run(['osascript', '-e', 'tell application "System Events" to tell process "UserNotificationCenter" to click button "Don’t Allow" of window 1'], capture_output=True, text=True, timeout=8)
        (OUT / 'local-network-denial.txt').write_text(str(consent.returncode) + '\n' + consent.stdout + consent.stderr)
        subprocess.run(['osascript', '-e', 'tell application "Google Chrome for Testing" to activate'], check=True, timeout=8)
        time.sleep(0.5)
        subprocess.run(['screencapture', '-x', str(OUT / 'formatter-reference.png')], check=True, timeout=10)
        report['downloads'] = run_download_reference(request, script, prefix, OUT, download_directory)
    except Exception as error:
        report['error'] = str(error)
    finally:
        if prefix:
            try:
                request(prefix, method='DELETE')
            except Exception as error:
                report['sessionCleanupError'] = str(error)
        if driver and driver.poll() is None:
            try:
                os.killpg(driver.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                driver.wait(timeout=10)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(driver.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                driver.wait(timeout=5)
        if server:
            server.shutdown()
            server.server_close()
        if server_thread:
            server_thread.join(timeout=5)
        (OUT / 'results.json').write_text(json.dumps(report, indent=2))

assert report['scenarioExecuted'] and len(report['checks']) == 3 and all(report['checks'].values()), 'Chrome reference failed; diagnostics retained'
assert report.get('downloads', {}).get('scenarioExecuted') and report['downloads']['passingChecks'] == report['downloads']['totalChecks'] == 16, 'Downloads reference failures retained'
