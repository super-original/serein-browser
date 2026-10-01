"""The shared downloads conformance fixture in an actual Chrome MV3 worker."""
import hashlib
import json
import pathlib
import shutil
import subprocess
import time


def prepare_download_reference(temporary, out):
    source = pathlib.Path('Fixtures/DownloadAPI')
    extension = pathlib.Path(temporary) / 'downloads-extension'
    extension.mkdir()
    manifest = {'manifest_version': 3, 'name': 'Serein download API reference', 'version': '1.0',
                'permissions': ['downloads'], 'host_permissions': ['http://127.0.0.1/*'],
                'background': {'service_worker': 'background.js'},
                'content_scripts': [{'matches': ['http://127.0.0.1/*'], 'js': ['content.js'], 'run_at': 'document_idle'}]}
    (extension / 'manifest.json').write_text(json.dumps(manifest))
    hashes = {}
    for name in ['background.js', 'content.js']:
        shutil.copyfile(source / name, extension / name)
        hashes[name] = hashlib.sha256((source / name).read_bytes()).hexdigest()
    (out / 'downloads-fixture.json').write_text(json.dumps({'manifest': manifest, 'scriptSHA256': hashes}, indent=2))
    return extension


def run_download_reference(request, script, prefix, out, download_directory):
    report = {'browser': 'Chrome for Testing 154.0.8037.57', 'variant': 'mv3',
              'scope': 'Original controlled downloads fixture; not Serein API support. Four-second exists freshness is an observation window, not a documented Chrome deadline.',
              'scenarioExecuted': False}
    try:
        request(prefix + '/url', {'url': 'http://127.0.0.1:8765/index.html?downloads-reference=mv3'})
        for _ in range(450):
            value = script('return document.documentElement.dataset.downloadReference || null')
            if value:
                report['result'] = json.loads(value)
                break
            time.sleep(.1)
        if 'result' not in report:
            raise RuntimeError('Download fixture did not finish within 45 seconds')
        report['scenarioExecuted'] = not report['result'].get('error')
        removed = report['result'].get('observations', {}).get('removedFilename')
        if removed:
            path = pathlib.Path(removed).resolve()
            owned = path.is_relative_to(download_directory.resolve())
            report['result']['checks']['removeFileActuallyRemoved'] = owned and not path.exists()
            report['result']['observations']['removedPathIsOwned'] = owned
        checks = report['result'].get('checks', {})
        report['passingChecks'] = sum(value is True for value in checks.values())
        report['totalChecks'] = len(checks)
        subprocess.run(['screencapture', '-x', str(out / 'downloads-reference.png')], check=True, timeout=10)
    except Exception as error:
        report['error'] = str(error)
    finally:
        (out / 'downloads-results.json').write_text(json.dumps(report, indent=2))
    return report
