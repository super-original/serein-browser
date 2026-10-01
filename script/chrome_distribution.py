"""Verify the preinstalled test browser against its exact upstream distribution.

Chrome for Testing's official macOS archive is unsealed. This compares complete
file contents, links and executable bits; it never modifies the installed app.
"""
import hashlib
import json
import os
import pathlib
import stat
import time
import urllib.request
import zipfile

URL = 'https://storage.googleapis.com/chrome-for-testing-public/154.0.8037.57/mac-arm64/chrome-mac-arm64.zip'
SIZE = 191429663
SHA256 = '0e6b3439469c1b8b95b2e89c72ea29f7af00fb2c28a8878358a0b6002b6d3a64'
DRIVER_SHA256 = 'ad8c4613ef867bd4ee803fd4ac39ee865fa2e53db78170331cc92d64dc3db0f0'


def verify_application_files(app, source):
    prefix = 'chrome-mac-arm64/Google Chrome for Testing.app/'
    expected = set()
    regular = links = 0
    for entry in source.infolist():
        if not entry.filename.startswith(prefix) or entry.is_dir():
            continue
        relative = pathlib.PurePosixPath(entry.filename[len(prefix):])
        assert not relative.is_absolute() and '..' not in relative.parts
        name = str(relative)
        assert name not in expected, 'Duplicate archive path'
        expected.add(name)
        target = app.joinpath(*relative.parts)
        mode = entry.external_attr >> 16
        if stat.S_ISLNK(mode):
            assert target.is_symlink() and os.readlink(target) == source.read(entry).decode(), 'Link mismatch: ' + name
            assert target.resolve().is_relative_to(app.resolve()), 'Link escapes application'
            links += 1
        else:
            assert target.is_file() and not target.is_symlink(), 'Missing regular file: ' + name
            assert bool(target.stat().st_mode & 0o111) == bool(mode & 0o111), 'Executable mode mismatch: ' + name
            with target.open('rb') as actual, source.open(entry) as original:
                assert hashlib.file_digest(actual, 'sha256').digest() == hashlib.file_digest(original, 'sha256').digest(), 'File mismatch: ' + name
            regular += 1
    actual = set()
    for directory, directories, files in os.walk(app, followlinks=False):
        for name in files + [name for name in directories if (pathlib.Path(directory) / name).is_symlink()]:
            actual.add(str((pathlib.Path(directory) / name).relative_to(app)))
    assert regular > 0, 'Archive has no application files'
    assert actual == expected, 'Unexpected or missing application files: ' + str(sorted(actual.symmetric_difference(expected))[:10])
    assert not any(name.endswith('/_CodeSignature/CodeResources') for name in expected), 'Upstream sealing changed; review preflight'
    return regular, links


def verify_distribution(app, temporary, out):
    started = time.monotonic()
    report = {'url': URL, 'expectedSHA256': SHA256, 'expectedBytes': SIZE, 'verified': False}
    archive = pathlib.Path(temporary) / 'official-chrome.zip'
    try:
        digest = hashlib.sha256()
        count = 0
        with urllib.request.urlopen(URL, timeout=30) as response, archive.open('wb') as file:
            while chunk := response.read(1024 * 1024):
                count += len(chunk)
                assert count <= SIZE, 'Official archive exceeded pinned size'
                assert time.monotonic() - started < 180, 'Official archive transfer deadline'
                digest.update(chunk)
                file.write(chunk)
        report.update(bytes=count, sha256=digest.hexdigest())
        assert count == SIZE and digest.hexdigest() == SHA256, 'Official archive identity mismatch'
        assert app.is_dir() and not app.is_symlink(), 'Expected installed application directory'
        with zipfile.ZipFile(archive) as source:
            regular, links = verify_application_files(app, source)
        report.update(verified=True, regularFiles=regular, symlinks=links,
                      signatureScope='Upstream testing distribution has no CodeResources seals; exact archive/file provenance verified, not Developer ID or notarization.')
    except Exception as error:
        report['error'] = str(error)
        raise
    finally:
        report['seconds'] = time.monotonic() - started
        (out / 'distribution-verification.json').write_text(json.dumps(report, indent=2))
        archive.unlink(missing_ok=True)
    return report
