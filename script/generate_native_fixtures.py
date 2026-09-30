"""Generate controlled CRX3 native-host fixtures; never write private keys."""
import hashlib
import io
import json
import pathlib
import struct
import zipfile
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec

def varint(value):
    result = bytearray()
    while value > 127:
        result.append((value & 127) | 128)
        value >>= 7
    result.append(value)
    return bytes(result)

def field(number, value):
    return varint(number * 8 + 2) + varint(len(value)) + value

for version in [2, 3]:
    manifest = {'manifest_version': version, 'name': f'Serein MV{version} native host fixture',
                'description': 'Controlled native host permission and lifecycle verification.',
                'version': '1.0', 'permissions': ['nativeMessaging'],
                'options_ui': {'page': 'native.html', 'open_in_tab': True}}
    output = io.BytesIO()
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name, contents in [('manifest.json', json.dumps(manifest)), ('native.html', '<!doctype html><title>Native host fixture</title><body>Controlled native-host verification</body>')]:
            info = zipfile.ZipInfo(name, (2026, 9, 30, 0, 0, 0)); info.compress_type = 8
            archive.writestr(info, contents)
    key = ec.generate_private_key(ec.SECP256R1())
    public = key.public_key().public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)
    signed = field(1, hashlib.sha256(public).digest()[:16])
    payload = output.getvalue()
    signature = key.sign(b'CRX3 SignedData\0' + struct.pack('<I', len(signed)) + signed + payload, ec.ECDSA(hashes.SHA256()))
    header = field(3, field(1, public) + field(2, signature)) + field(10000, signed)
    pathlib.Path(f'Fixtures/NativeHosts/mv{version}.crx').write_bytes(b'Cr24' + struct.pack('<II', 3, len(header)) + header + payload)
