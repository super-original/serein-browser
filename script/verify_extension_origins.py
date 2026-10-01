#!/usr/bin/env python3
"""Isolate experimental Firefox origins; record real process exit and partial evidence."""
import json
import pathlib
import subprocess
import time
import urllib.request

root = pathlib.Path('evidence/extension-origins').resolve()
root.mkdir(parents=True, exist_ok=True)
app = pathlib.Path('dist/Serein.app/Contents/MacOS/Serein').resolve()
combined = []

def stop(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)

with (root / 'server.log').open('w') as log:
    server = subprocess.Popen(['python3', 'script/fixture_server.py', '--directory', 'Fixtures'], stdout=log, stderr=log)
    try:
        for _ in range(50):
            assert server.poll() is None, 'Owned fixture server exited'
            try:
                with urllib.request.urlopen('http://127.0.0.1:8765/index.html', timeout=1) as response:
                    assert response.status == 200
                break
            except OSError:
                time.sleep(0.1)
        else:
            raise AssertionError('Fixture server did not start')
        for mode in ['controlled', 'real']:
            directory = root / mode
            directory.mkdir(exist_ok=True)
            with (directory / 'application.log').open('w') as stdout, (directory / 'application-error.log').open('w') as stderr:
                process = subprocess.Popen([str(app), '--test-root', str(directory), '--extension-origin-probe', mode,
                    '--real-extension-catalog', '/tmp/serein-extension-audit/catalog.json'], stdout=stdout, stderr=stderr)
                try:
                    deadline = time.monotonic() + 80
                    while process.poll() is None and time.monotonic() < deadline:
                        request = directory / 'capture-request'
                        if request.exists():
                            assert request.read_text() == 'resource-page', 'Unexpected capture request'
                            request.unlink()
                            subprocess.run(['screencapture', '-x', str(directory / 'resource-page.png')], check=True)
                            (directory / 'resource-page.capture-finished').touch()
                        time.sleep(0.1)
                    exit_code = process.poll()
                    subprocess.run(['screencapture', '-x', str(directory / 'final-desktop.png')], check=False)
                    outcome = {'pid': process.pid, 'exit_code': exit_code, 'timed_out': exit_code is None}
                    (directory / 'process-outcome.json').write_text(json.dumps(outcome, indent=2))
                    combined.append({'name': mode + '-process-completes', 'passed': exit_code == 0, 'detail': json.dumps(outcome)})
                    results = directory / 'results.json'
                    if results.exists():
                        for result in json.loads(results.read_text()):
                            result['name'] = mode + '-' + result['name']
                            combined.append(result)
                    else:
                        combined.append({'name': mode + '-complete-results', 'passed': False, 'detail': 'No complete results; inspect partial evidence'})
                finally:
                    stop(process)
            (root / 'results.json').write_text(json.dumps(combined, indent=2))
    finally:
        stop(server)
print(json.dumps(combined, indent=2))
assert combined and all(result['passed'] for result in combined), 'Custom origins remain experimental; failed assertions retained'
