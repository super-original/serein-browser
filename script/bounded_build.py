"""Bound a CI-owned process group; report sampled resource limits, not feasibility claims."""
import collections
import json
import os
import pathlib
import re
import shutil
import signal
import subprocess
import threading
import time

GIB = 1024 ** 3


def parse_processes(text):
    rows = []
    for line in text.splitlines():
        fields = line.split(None, 3)
        if len(fields) == 4:
            try:
                rows.append(dict(pid=int(fields[0]), ppid=int(fields[1]), rss_bytes=int(fields[2])*1024,
                                 executable=fields[3]))
            except ValueError:
                continue
    return rows


def descendants(rows, root_pid):
    owned = {root_pid}
    while True:
        expanded = owned | {row['pid'] for row in rows if row['ppid'] in owned}
        if expanded == owned:
            return [row for row in rows if row['pid'] in owned]
        owned = expanded


def limit_reason(sample, elapsed, seconds):
    if elapsed >= seconds:
        return 'elapsed-time-limit'
    if sample['disk_free_bytes'] < 8*GIB:
        return 'disk-reserve-limit'
    if sample['descendant_rss_bytes'] > 5*GIB:
        return 'sampled-process-rss-limit'
    pressure = sample.get('system_free_memory_percent')
    if pressure is not None and pressure < 8:
        return 'system-memory-pressure-limit'
    return None


def snapshot(directory, pid):
    rows = parse_processes(subprocess.check_output(['ps', '-axo', 'pid=,ppid=,rss=,comm='], text=True, timeout=5))
    owned = descendants(rows, pid)
    pressure = None
    if os.uname().sysname == 'Darwin':
        try:
            result = subprocess.run(['memory_pressure', '-Q'], capture_output=True, text=True, timeout=3)
            match = re.search(r'System-wide memory free percentage:\s*(\d+)%', result.stdout)
            if result.returncode == 0 and match:
                pressure = int(match[1])
        except (OSError, subprocess.TimeoutExpired):
            pass
    return dict(disk_free_bytes=shutil.disk_usage(directory).free,
                descendant_rss_bytes=sum(row['rss_bytes'] for row in owned),
                descendant_count=len(owned), system_free_memory_percent=pressure)


def run_bounded(command, *, cwd, evidence, name, seconds, env=None, sample_fn=snapshot, interval=2):
    """Only signal the new session/process group created here; never match global names."""
    evidence = pathlib.Path(evidence)
    evidence.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    process = subprocess.Popen(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, start_new_session=True)
    tail = collections.deque(maxlen=16)
    written = 0
    stop_reader = threading.Event()
    reader_errors = []
    os.set_blocking(process.stdout.fileno(), False)

    def drain():
        nonlocal written
        try:
            with (evidence/(name+'.log')).open('wb') as output:
                while True:
                    try:
                        data = os.read(process.stdout.fileno(), 65536)
                    except BlockingIOError:
                        if stop_reader.wait(0.02):
                            break
                        continue
                    if not data:
                        break
                    tail.append(data)
                    chunk = data[:max(0, 20*1024*1024-written)]
                    output.write(chunk)
                    written += len(chunk)
        except OSError as error:
            reader_errors.append(str(error))

    reader = threading.Thread(target=drain, daemon=True)
    reader.start()
    samples = []
    reason = None
    try:
        with (evidence/(name+'-resources.jsonl')).open('w') as output:
            while process.poll() is None:
                sample = sample_fn(cwd, process.pid)
                sample['elapsed_seconds'] = time.monotonic()-started
                samples.append(sample)
                output.write(json.dumps(sample)+'\n'); output.flush()
                reason = limit_reason(sample, sample['elapsed_seconds'], seconds)
                if reason:
                    break
                if len(samples) % 15 == 0:
                    print(json.dumps(dict(stage=name, **sample)), flush=True)
                time.sleep(interval)
    except BaseException:
        reason = 'supervisor-error'
        raise
    finally:
        if process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=20)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait(timeout=5)
        stop_reader.set()
        reader.join(timeout=5)
        if reader_errors:
            reason = reason or "log-capture-error"
        process.stdout.close()
        (evidence/(name+'-tail.log')).write_bytes(b''.join(tail))
        result = dict(command=command, returncode=process.returncode, stop_reason=reason,
                      elapsed_seconds=time.monotonic()-started, samples=len(samples),
                      sampled_peak_descendant_rss_bytes=max((s['descendant_rss_bytes'] for s in samples),default=0),
                      minimum_sampled_disk_free_bytes=min((s['disk_free_bytes'] for s in samples),default=None),
                      retained_initial_log_bytes=written,
                      memory_scope='Sampled process descendants only; XPC services and transient peaks may be omitted. RSS may double-count shared memory. System memory pressure is a separate global guard.')
        (evidence/(name+'-summary.json')).write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result),flush=True)
    if reason or process.returncode:
        print(b''.join(tail).decode(errors='replace')[-12000:],flush=True)
    return result
