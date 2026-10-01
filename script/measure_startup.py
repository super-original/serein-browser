#!/usr/bin/env python3
"""Ten independent actual app launches; OS/WebKit caches deliberately stay warm."""
import json
import pathlib
import platform
import statistics
import subprocess
import sys
import time
import urllib.request
import uuid


def stop(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def main():
    root = pathlib.Path('evidence/startup', str(uuid.uuid4())).resolve()
    root.mkdir(parents=True)
    app = pathlib.Path('dist/Serein.app/Contents/MacOS/Serein').resolve()
    samples = []
    report = {'architecture': platform.machine(), 'platform': platform.platform(),
              'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
              'note': 'Direct executable launches, five fresh application profiles and five one-tab URL-only session restores, interleaved. Untimed seed launch first. OS and WebKit caches remain warm; no installed extensions. Parent timer includes process spawn and readiness-file publication/polling (10 ms); app timer starts at Swift main entry and ends at native readiness plus restored-document identity. Neither measures pixels, LaunchServices, cold boot, energy, or a physical Mac.',
              'samples': samples}

    def launch(mode, ordinal, seed=None):
        profile = root / f'{mode}-{ordinal}'
        profile.mkdir(mode=0o700)
        if seed is not None:
            (profile / 'session.json').write_bytes(seed)
        marker = profile / 'startup-ready.json'
        with (profile / 'stdout.log').open('w') as stdout, (profile / 'stderr.log').open('w') as stderr:
            started = time.monotonic_ns()
            process = subprocess.Popen([str(app), '--test-root', str(profile), '--startup-benchmark', mode,
                                        '-restoreTabHistory', 'NO'], stdout=stdout, stderr=stderr)
            try:
                deadline = time.monotonic() + 25
                while not marker.exists() and time.monotonic() < deadline:
                    assert process.poll() is None, f'{mode} process exited before readiness'
                    time.sleep(.01)
                observed = time.monotonic_ns()
                assert marker.exists(), f'{mode} timed out'
                value = json.loads(marker.read_text())
                value.update(ordinal=ordinal, spawnToObservedReadinessMilliseconds=(observed-started)/1e6)
                if mode != 'seed':
                    samples.append(value)
                assert value['mode'] == mode and value['passed'], value
                assert value['entryToReadinessMilliseconds'] > 0, value
                assert process.wait(timeout=10) == 0, 'App failed to quit through ordinary termination'
            finally:
                stop(process)
        return profile

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
                raise AssertionError('Fixture server did not start')
            seeded = launch('seed', 0)
            seed = (seeded / 'session.json').read_bytes()
            for ordinal in range(5):
                launch('fresh', ordinal)
                launch('restore', ordinal, seed)
            report['summary'] = {}
            for mode in ['fresh', 'restore']:
                report['summary'][mode] = {}
                for metric in ['entryToReadinessMilliseconds', 'spawnToObservedReadinessMilliseconds']:
                    values = [sample[metric] for sample in samples if sample['mode'] == mode]
                    report['summary'][mode][metric] = {'count': len(values), 'minimum': min(values),
                                                       'median': statistics.median(values), 'maximum': max(values)}
            print(json.dumps(report['summary'], indent=2), flush=True)
        except Exception as error:
            report['error'] = str(error)
            raise
        finally:
            (root.parent / 'startup-performance.json').write_text(json.dumps(report, indent=2))
            stop(server)


if __name__ == '__main__':
    main()
