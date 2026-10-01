#!/usr/bin/env python3
"""Reject stale packaged scripts without regenerating signing keys during CI."""
import ast
import io
import pathlib
import struct
import zipfile

source = ast.parse(pathlib.Path('script/generate_signed_fixtures.py').read_text())
expected = {}
for statement in source.body:
    if isinstance(statement, ast.Assign):
        for target in statement.targets:
            if isinstance(target, ast.Name) and target.id in ('script', 'options_script'):
                expected[target.id] = ast.literal_eval(statement.value)
assert set(expected) == {'script', 'options_script'}
for name in ('signed-fixture.crx', 'signed-update.crx', 'signed-update-disabled.crx', 'signed-update-unsupported.crx', 'wrong-developer.crx'):
    data = pathlib.Path('Fixtures/Packages', name).read_bytes()
    assert data[:8] == b'Cr24\x03\x00\x00\x00', name
    offset = 12 + struct.unpack('<I', data[8:12])[0]
    with zipfile.ZipFile(io.BytesIO(data[offset:])) as archive:
        assert archive.read('identity.js').decode() == expected['script'], f'{name}: regenerate signed fixtures'
        assert archive.read('options.js').decode() == expected['options_script'], f'{name}: regenerate signed fixtures'
print('All five signed fixture archives contain current instrumentation; CRX signature tests run separately.')
