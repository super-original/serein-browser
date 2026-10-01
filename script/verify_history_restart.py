#!/usr/bin/env python3
"""Exercise production history persistence and fallback in separate app processes."""
import json
import pathlib
import stat
import subprocess
import sys
import time
import urllib.request
import uuid

root = pathlib.Path('evidence/history-restart', str(uuid.uuid4())).resolve()
root.mkdir(parents=True)
app = pathlib.Path('dist/Serein.app/Contents/MacOS/Serein').resolve()

def stop(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()

results = []
with (root / 'server.log').open('w') as log:
    server = subprocess.Popen([sys.executable, 'script/fixture_server.py', '--directory', 'Fixtures'], stdout=log, stderr=log)
    try:
        for _ in range(100):
            assert server.poll() is None, 'Owned fixture server exited'
            try:
                with urllib.request.urlopen('http://127.0.0.1:8765/index.html', timeout=1) as response:
                    assert response.status == 200
                break
            except OSError:
                time.sleep(.1)
        else:
            raise AssertionError('Fixture server did not become ready')
        prepared = None
        for stage, expected in [('prepare', 3), ('resume', 5), ('disabled', 2), ('mismatched-engine', 2), ('corrupt-state', 2)]:
            fallback = stage not in ['prepare', 'resume']
            app_stage = 'fallback' if fallback else stage
            ready = root / f'{app_stage}-results.json'
            ready.unlink(missing_ok=True)
            if fallback:
                session = json.loads(prepared)
                if stage == 'mismatched-engine':
                    session['navigationHistory'][0]['engine'] = 'different-WebKit-build'
                elif stage == 'corrupt-state':
                    session['navigationHistory'][0]['checksum'] = 'corrupt'
                (root / 'session.json').write_text(json.dumps(session))

            with (root / f'{stage}.log').open('w') as stdout, (root / f'{stage}-error.log').open('w') as stderr:
                process = subprocess.Popen([str(app), '--test-root', str(root), f'--history-restart-{app_stage}', '-restoreTabHistory', 'NO' if stage == 'disabled' else 'YES'], stdout=stdout, stderr=stderr)
                try:
                    deadline = time.monotonic() + 70
                    while not ready.exists() and time.monotonic() < deadline:
                        assert process.poll() is None, f'{stage} exited before publishing readiness'
                        time.sleep(0.1)
                    assert ready.exists(), f'{stage} did not reach quit readiness'
                    # User-facing quit runs outside the fixture's Swift task, as
                    # it does from the application menu. Target only our child PID.
                    quit_input = subprocess.run(['osascript', '-e', 'on run arguments',
                        '-e', 'tell application "System Events"',
                        '-e', 'set targetProcess to first application process whose unix id is (item 1 of arguments as integer)',
                        '-e', 'tell targetProcess', '-e', 'set frontmost to true',
                        '-e', 'keystroke "q" using command down', '-e', 'end tell',
                        '-e', 'end tell', '-e', 'end run', str(process.pid)],
                        text=True, capture_output=True, timeout=10)
                    (root / f'{stage}-quit-input.log').write_text(quit_input.stdout + quit_input.stderr)
                    assert quit_input.returncode == 0, quit_input.stderr
                    try:
                        code = process.wait(timeout=15)
                    except subprocess.TimeoutExpired:
                        subprocess.run(['screencapture', '-x', str(root / f'{stage}-quit-timeout.png')], timeout=10)
                        subprocess.run(['sample', str(process.pid), '3', '-file', str(root / f'{stage}-quit-timeout-stack.txt')], timeout=10)
                        raise
                finally:
                    stop(process)
            assert code == 0, f'{stage} app exited with {code}'
            stage_results = json.loads(ready.read_text())
            if stage == 'prepare':
                prepared = (root / 'session.json').read_text()
            for item in stage_results:
                item['name'] = stage + ':' + item['name']
            if fallback:
                (root / f'{stage}-results.json').write_text(json.dumps(stage_results, indent=2))
            results.extend(stage_results)
            if stage == 'disabled':
                saved = json.loads((root / 'session.json').read_text())
                results.append({'name':'disabled-removes-persisted-navigation-state',
                                'passed': not saved.get('navigationHistory'),
                                'detail':'Ordinary quit rewrites URL-only session while preference is off.'})
            modes = {name: stat.S_IMODE((root / name).stat().st_mode) for name in ['.', 'session.json']}
            protected = modes == {'.': 0o700, 'session.json': 0o600}
            results.append({'name': f'{stage}-private-storage-permissions', 'passed': protected, 'detail': str(modes)})
            (root.parent / 'results.json').write_text(json.dumps(results, indent=2))
            print(json.dumps(stage_results, indent=2), flush=True)
            assert len(stage_results) == expected, stage_results
            assert protected, modes
        results.append({'name':'history-independent-process-exits','passed':True,'detail':'Five independent launches exited with status 0; history and fallback semantics are reported separately.'})
        (root.parent / 'results.json').write_text(json.dumps(results, indent=2))
        assert all(item['passed'] for item in results), 'History restoration failures retained'
    finally:
        stop(server)
