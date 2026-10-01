#!/usr/bin/env python3
"""Crash only positively attributed WebContent children of this isolated test app."""
import json
import os
import pathlib
import re
import signal
import subprocess
import time
import urllib.request
import uuid

root = pathlib.Path('evidence/crash-recovery').resolve() / str(uuid.uuid4())
root.mkdir(parents=True)
bundle = pathlib.Path('dist/Serein.app').resolve()
app = bundle / 'Contents/MacOS/Serein'
app_pid = None

def stop(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()

def app_is_owned():
    if not app_pid:
        return False
    row = subprocess.run(['ps', '-p', str(app_pid), '-o', 'comm=', '-o', 'args='], text=True, capture_output=True).stdout
    return str(app) in row and str(root) in row and '--crash-recovery-test' in row

def targets():
    subprocess.run(['python3', 'script/inspect_web_processes.py', str(app_pid), str(root)], check=True, timeout=25)
    evidence = json.loads((root / 'web-process-ownership.json').read_text())
    assert evidence['app_pid'] == app_pid and app_is_owned(), 'Test app identity changed'
    return [item['pid'] for item in evidence['candidates']
            if item.get('exit_code') == 0
            and item['command'].endswith('/com.apple.WebKit.WebContent')
            and f'responsible pid = {app_pid}' in item['ownership_fields']
            and f'responsible path = {app}' in item['ownership_fields']]

reload_script = '''
on run arguments
with timeout of 5 seconds
 tell application "System Events"
  set targetProcess to first application process whose unix id is (item 1 of arguments as integer)
  tell targetProcess
  set controls to entire contents of window 1
  repeat with uiElement in controls
   try
    if value of attribute "AXIdentifier" of uiElement is "page-error-reload" then
     perform action "AXPress" of uiElement
     return "pressed"
    end if
   end try
  end repeat
  end tell
 end tell
end timeout
error "Error-page Reload control was not found"
end run
'''
with (root / 'server.log').open('w') as log:
    server = subprocess.Popen(['python3', 'script/fixture_server.py', '--directory', 'Fixtures'], stdout=log, stderr=log)
    launcher = None
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
            raise AssertionError('Fixture server not ready')
        launcher = subprocess.Popen(['open', '-W', '-n', str(bundle), '--stdout', str(root / 'application.log'),
                                     '--stderr', str(root / 'application-error.log'), '--args', '--test-root', str(root), '--crash-recovery-test'])
        injected = False
        deadline = time.monotonic() + 70
        while time.monotonic() < deadline and not (root / 'results.json').exists():
            if (root / 'ready.json').exists() and not injected:
                app_pid = int(json.loads((root / 'ready.json').read_text())['pid'])
                assert app_pid > 1 and app_is_owned(), 'Ready PID is not this test instance'
                owned = targets()
                assert 0 < len(owned) <= 4, f'Ambiguous WebContent ownership: {owned}'
                killed = []
                for pid in owned:
                    # Recheck responsibility immediately before each exact-PID signal.
                    if pid not in targets():
                        continue
                    (root / f'ownership-before-{pid}.json').write_bytes((root / 'web-process-ownership.json').read_bytes())
                    os.kill(pid, signal.SIGKILL)
                    killed.append(pid)
                assert killed, 'No positively attributed process remained'
                (root / 'injected-pids.json').write_text(json.dumps({'app_pid': app_pid, 'web_content_pids': killed}))
                (root / 'process-terminated').touch()
                injected = True
            request = root / 'capture-request'
            if request.exists():
                name = request.read_text().strip();request.unlink()
                assert re.fullmatch('[a-z0-9-]+', name)
                subprocess.run(['screencapture', '-x', str(root / (name + '.png'))], check=True)
                (root / (name + '.capture-finished')).touch()
            request = root / 'reload-request'
            if request.exists():
                request.unlink()
                result = subprocess.run(['osascript', '-e', reload_script, str(app_pid)], text=True, capture_output=True, timeout=10)
                (root / 'reload-input.log').write_text(result.stdout + result.stderr)
                (root / 'reload-input-finished').write_text('true' if result.returncode == 0 else 'false')
            time.sleep(0.1)
        assert (root / 'results.json').exists(), 'Crash-recovery app did not finish'
        results = json.loads((root / 'results.json').read_text())
        assert injected and len(results) == 7 and all(item['passed'] for item in results), results
        launcher.wait(timeout=10)
        print(json.dumps(results, indent=2))
    finally:
        if app_is_owned():
            os.kill(app_pid, signal.SIGTERM)
        if launcher is not None:
            stop(launcher)
        stop(server)
