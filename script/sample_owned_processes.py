#!/usr/bin/env python3
"""Read-only CI process attribution. Never publishes process arguments/environment."""
import concurrent.futures
import json
import pathlib
import re
import subprocess
import sys
import time


def parse_rows(text):
    rows = []
    for line in text.splitlines():
        parts = line.split(None, 10)
        if len(parts) != 11:
            continue
        try:
            cpu = sum(float(n) * 60 ** i for i, n in enumerate(reversed(parts[4].split(':'))))
            rows.append(dict(pid=int(parts[0]), rss_kib=int(parts[2]), cpu_seconds=cpu,
                             started=' '.join(parts[5:10]), executable=parts[10]))
        except ValueError:
            continue
    return rows


def identity(row):
    return row['pid'], row['started'], row['executable']


def interval_cpu(first, last):
    elapsed = last['monotonic_seconds'] - first['monotonic_seconds']
    if elapsed <= 0:
        return None
    before = {identity(row): row for row in first['processes'] if row['ownership'] == 'confirmed'}
    after = {identity(row): row for row in last['processes'] if row['ownership'] == 'confirmed'}
    common = before.keys() & after.keys()
    valid = [key for key in common if after[key]['cpu_seconds'] >= before[key]['cpu_seconds']]
    return dict(elapsed_seconds=elapsed, common_process_count=len(valid),
                cpu_interval_percent=sum(after[key]['cpu_seconds']-before[key]['cpu_seconds'] for key in valid)/elapsed*100 if valid else None)


def classify(output, returncode, app):
    if returncode:
        return 'unresolved'
    pid = re.search(r'^\s*responsible pid\s*=\s*(\d+)\s*$', output, re.M)
    path = re.search(r'^\s*responsible path\s*=\s*(.+?)\s*$', output, re.M)
    if not pid or not path:
        return 'unresolved'
    return 'confirmed' if int(pid[1]) == app['pid'] and path[1] == app['executable'] else 'foreign'


def inspect(row, app):
    try:
        result = subprocess.run(['sudo', '-n', 'launchctl', 'procinfo', str(row['pid'])],
                                capture_output=True, text=True, timeout=3)
        return identity(row), classify(result.stdout, result.returncode, app)
    except (OSError, subprocess.TimeoutExpired):
        return identity(row), 'unresolved'


def sample(root):
    app = json.loads((root / 'main-process-identity.json').read_text())
    app['started'] = ' '.join(app['started'].split())
    cache = {}
    with (root / 'owned-process-samples.jsonl').open('w') as output, concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        while not (root / 'results.json').exists():
            started = time.monotonic()
            idle = (root/'idle-start').exists() and not (root/'idle-end').exists()
            rows = parse_rows(subprocess.check_output(['ps', '-axo', 'pid=,ppid=,rss=,%cpu=,time=,lstart=,comm='], text=True))
            if not any(identity(row) == identity(app) for row in rows):
                break
            candidates = [row for row in rows if identity(row) == identity(app) or pathlib.Path(row['executable']).name.startswith('com.apple.WebKit.')]
            pending = [row for row in candidates if identity(row) != identity(app) and
                       (identity(row) not in cache or started - cache[identity(row)][0] > 10)]
            # Bound diagnostic overhead; excess candidates remain unresolved.
            for key, ownership in pool.map(lambda row: inspect(row, app), pending[:16]):
                cache[key] = started, ownership
            current = {identity(row) for row in parse_rows(subprocess.check_output(['ps', '-axo', 'pid=,ppid=,rss=,%cpu=,time=,lstart=,comm='], text=True))}
            for row in candidates:
                row['ownership'] = 'confirmed' if identity(row) == identity(app) else (cache[identity(row)][1] if identity(row) in cache and started-cache[identity(row)][0] <= 10 else 'unresolved')
                if identity(row) not in current:
                    row['ownership'] = 'unresolved'
            output.write(json.dumps(dict(monotonic_seconds=started, diagnostic_seconds=time.monotonic()-started,
                                         idle=idle, processes=candidates))+'\n')
            output.flush()
            time.sleep(max(0, 2-(time.monotonic()-started)))


if __name__ == '__main__':
    sample(pathlib.Path(sys.argv[1]))
