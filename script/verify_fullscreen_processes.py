#!/usr/bin/env python3
"""Keep baseline/WebGPU/WebGL in separate app processes; retain failing checks."""
import json
import pathlib
import subprocess
import time
import urllib.request

root = pathlib.Path('evidence/fullscreen-processes').resolve()
root.mkdir(parents=True, exist_ok=True)
app = pathlib.Path('dist/Serein.app/Contents/MacOS/Serein').resolve()
combined = []
# This scenario must also run when the main browser harness fails before setup.
pointer = root / 'pointer-input'
subprocess.run(['xcrun', 'swiftc', '-target', 'arm64-apple-macos27.0',
                'script/PointerInput.swift', '-o', str(pointer)], check=True)

def stop(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()

with (root / 'server.log').open('w') as server_log:
    server = subprocess.Popen(['python3', 'script/fixture_server.py', '--directory', 'Fixtures'], stdout=server_log, stderr=server_log)
    try:
        for _ in range(50):
            assert server.poll() is None, 'Owned fixture server exited'
            try:
                with urllib.request.urlopen('http://127.0.0.1:8765/fullscreen.html', timeout=1) as response:
                    assert response.status == 200
                break
            except OSError:
                time.sleep(0.1)
        else:
            raise AssertionError('Fixture server not ready')
        for mode in ['none', 'webgpu', 'webgl']:
            subprocess.run(['python3', 'script/collect_fixture_crashes.py'], check=True)
            directory = root / mode
            directory.mkdir(exist_ok=True)
            with (directory / 'application.log').open('w') as stdout, (directory / 'application-error.log').open('w') as stderr:
                process = subprocess.Popen([str(app), '--test-root', str(directory), '--fullscreen-probe', mode], stdout=stdout, stderr=stderr)
                try:
                    deadline = time.monotonic() + 90
                    while process.poll() is None and time.monotonic() < deadline:
                        request = directory / 'keyboard-request'
                        if request.exists():
                            name = request.read_text().strip()
                            request.unlink()
                            if name == 'fullscreen-enter':
                                coordinates = (directory / 'fullscreen-click-point').read_text().split()
                                assert len(coordinates) == 2
                                subprocess.run([str(pointer), *coordinates, 'plain'], check=True)
                            elif name == 'fullscreen-exit':
                                subprocess.run(['osascript', '-e', 'tell application "System Events" to tell process "Serein" to key code 53'], check=True)
                            else:
                                raise AssertionError(f'Unexpected input request {name}')
                            (directory / (name + '.keyboard-finished')).touch()
                        request = directory / 'capture-request'
                        if request.exists():
                            name = request.read_text().strip()
                            assert name and all(c in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in name)
                            request.unlink()
                            subprocess.run(['screencapture', '-x', str(directory / (name + '.png'))], check=True)
                            (directory / (name + '.processes.txt')).write_bytes(subprocess.check_output(['ps', '-axo', 'pid,ppid,rss,%cpu,comm']))
                            (directory / (name + '.capture-finished')).touch()
                        time.sleep(0.1)
                    assert process.poll() == 0, f'{mode} failed to exit normally'
                    results = json.loads((directory / 'results.json').read_text())
                    assert len(results) == 4
                    for result in results:
                        result['name'] = mode + '-fresh-process-' + result['name']
                    combined.extend(results)
                    (root / 'results.json').write_text(json.dumps(combined, indent=2))
                    print(json.dumps(results, indent=2), flush=True)
                finally:
                    stop(process)
    finally:
        stop(server)
assert len(combined) == 12 and all(result['passed'] for result in combined), 'Fullscreen failures retained; screenshots require separate inspection'
