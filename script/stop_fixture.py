#!/usr/bin/env python3
"""Record/stop only the exact integration app launched for this evidence root."""
import json
import os
import pathlib
import shlex
import signal
import subprocess
import sys
import time

mode, root_text, executable = sys.argv[1:4]
root = pathlib.Path(root_text).resolve()
identity_file = root / 'main-process-identity.json'

def identify(pid):
    if pid <= 1:
        raise ValueError('Invalid fixture PID')
    try:
        state = subprocess.check_output(['ps', '-p', str(pid), '-o', 'stat='], text=True).strip()
        if state.startswith('Z'):
            return None
        started = subprocess.check_output(['ps', '-p', str(pid), '-o', 'lstart='], text=True).strip()
        command = subprocess.check_output(['ps', '-ww', '-p', str(pid), '-o', 'command='], text=True).strip()
    except subprocess.CalledProcessError:
        return None
    args = shlex.split(command)
    if not args or args[0] != executable or '--integration-test' not in args:
        raise ValueError('PID does not identify the exact integration executable')
    if '--test-root' not in args or args.index('--test-root') + 1 >= len(args):
        raise ValueError('Missing fixture root')
    index = args.index('--test-root')
    if pathlib.Path(args[index + 1]).resolve() != root:
        raise ValueError('PID belongs to another evidence root')
    return {'pid': pid, 'started': started, 'executable': executable, 'root': str(root)}

if mode == 'record':
    pid = int((root / 'app-pid').read_text())
    identity = identify(pid)
    if identity is None:
        raise SystemExit('Integration app exited before identity was recorded')
    identity_file.write_text(json.dumps(identity, indent=2))
    print(pid)
elif mode == 'stop':
    if not identity_file.exists():
        raise SystemExit('No recorded integration app; no process was signaled')
    identity = json.loads(identity_file.read_text())
    pid = identity['pid']
    result = {'pid': pid, 'term_sent': False, 'kill_sent': False, 'already_exited': False}
    current = identify(pid)
    if current is None:
        result['already_exited'] = True
    else:
        if current != identity:
            raise SystemExit('Process identity changed; no process was signaled')
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        result['term_sent'] = True
        for _ in range(50):
            try:
                current = identify(pid)
            except ValueError:
                current = None  # The original process no longer owns this PID.
            if current != identity:
                break
            time.sleep(0.1)
        else:
            if identify(pid) != identity:
                raise SystemExit('Process identity changed before escalation')
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            result['kill_sent'] = True
    (root / 'main-process-cleanup.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result))
else:
    raise SystemExit('Expected record or stop')
