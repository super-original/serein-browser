#!/usr/bin/env python3
"""Read-only CI ownership evidence before any future process-failure injection.

launchctl procinfo is a diagnostic interface, not a production browser API.
No signals are sent; absent/ambiguous ownership must block subsequent injection.
"""
import concurrent.futures
import json
import pathlib
import re
import subprocess
import sys

app_pid = int(sys.argv[1])
root = pathlib.Path(sys.argv[2])
assert app_pid > 1 and root.is_dir()
rows = subprocess.check_output(['ps', '-axo', 'pid=,comm='], text=True).splitlines()
candidates = []
for row in rows:
    parts = row.strip().split(None, 1)
    if len(parts) != 2:
        continue
    pid, command = int(parts[0]), parts[1]
    if pid == app_pid or command.endswith('/com.apple.WebKit.WebContent'):
        candidates.append((pid, command))

def inspect(candidate):
    pid, command = candidate
    try:
        result = subprocess.run(['sudo', '-n', 'launchctl', 'procinfo', str(pid)],
                                text=True, capture_output=True, timeout=5)
        # Preserve only ownership fields; never publish environment/arguments.
        fields = [line.strip() for line in result.stdout.splitlines()
                  if re.match(r'^\s*(responsible|coalition|program path)', line, re.I)]
        return {'pid': pid, 'command': command, 'exit_code': result.returncode,
                'ownership_fields': fields}
    except (OSError, subprocess.TimeoutExpired) as error:
        return {'pid': pid, 'command': command, 'error': type(error).__name__}

with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    evidence = list(pool.map(inspect, candidates[:16]))
(root / 'web-process-ownership.json').write_text(json.dumps(
    {'app_pid': app_pid, 'read_only': True, 'candidates': evidence}, indent=2))
