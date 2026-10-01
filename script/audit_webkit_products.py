"""Read-only evidence for owned WebKit build products; never repairs or launches code."""
import hashlib
import json
import pathlib
import plistlib
import subprocess
import time


def audit_products(products, root, evidence, environment):
    root = pathlib.Path(root).resolve()
    release = pathlib.Path(products) / 'Release'
    deadline = time.monotonic() + 600
    records = []
    report = {'scope': 'Read-only development product audit. No signing repair, entitlement grant, execution, distribution or production approval.',
              'complete': False, 'records': records}
    destination = pathlib.Path(evidence) / 'product-security-audit.json'

    def save():
        destination.write_text(json.dumps(report, indent=2) + '\n')

    def command(args):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError('Product audit exceeded ten-minute budget')
        result = subprocess.run(args, env=environment, capture_output=True, text=True,
                                timeout=min(30, remaining))
        return {'returncode': result.returncode, 'stdout': result.stdout[-65536:],
                'stderr': result.stderr[-65536:],
                'truncated': len(result.stdout) > 65536 or len(result.stderr) > 65536}

    try:
        candidates = sorted({p.resolve() for p in release.rglob('*')
                             if p.suffix in {'.framework', '.xpc', '.app'} and p.is_dir()})
        if len(candidates) > 128:
            raise RuntimeError('Unexpected product count exceeds audit bound')
        for bundle in candidates:
            if not bundle.is_relative_to(root):
                raise RuntimeError('Product resolves outside owned build root')
            record = {'path': str(bundle.relative_to(root))}
            records.append(record)
            record['signature'] = command(['codesign', '--display', '--verbose=4', '--entitlements', ':-', str(bundle)])
            record['verification'] = command(['codesign', '--verify', '--deep', '--strict', '--verbose=4', str(bundle)])
            info = next((p for p in [bundle / 'Contents/Info.plist', bundle / 'Resources/Info.plist'] if p.is_file()), None)
            if info:
                if not info.resolve().is_relative_to(root):
                    raise RuntimeError('Product metadata resolves outside owned root')
                metadata = plistlib.loads(info.read_bytes())
                record['bundle_identifier'] = metadata.get('CFBundleIdentifier')
                name = metadata.get('CFBundleExecutable')
                if isinstance(name, str) and name == pathlib.Path(name).name:
                    binary = (bundle / ('Contents/MacOS' if bundle.suffix != '.framework' else '') / name).resolve()
                    if binary.is_file() and binary.is_relative_to(root):
                        digest = hashlib.sha256()
                        with binary.open('rb') as stream:
                            for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                                digest.update(chunk)
                        record['binary_sha256'] = digest.hexdigest()
                        record['binary_bytes'] = binary.stat().st_size
                        record['architecture'] = command(['xcrun', 'lipo', '-archs', str(binary)])
                        record['deployment'] = command(['xcrun', 'vtool', '-show-build', str(binary)])
                        record['dependencies'] = command(['otool', '-L', str(binary)])
            save()
        report['complete'] = bool(records)
        report['all_signatures_verify'] = bool(records) and all(r['verification']['returncode'] == 0 for r in records)
        report['production_approved'] = False
    except Exception as error:
        report['error'] = str(error)
    finally:
        save()
    return report
