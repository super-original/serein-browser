"""Index artifact evidence; inline bytes are an explicit troubleshooting fallback."""
import argparse
import base64
import hashlib
import json
import pathlib
import struct

parser = argparse.ArgumentParser()
parser.add_argument('root', type=pathlib.Path)
parser.add_argument('prefix', nargs='?', default='')
parser.add_argument('--inline', action='store_true')
args = parser.parse_args()
entries = []
for path in sorted(args.root.rglob('*')):
    if not path.is_file() or path.name == 'evidence-index.json':
        continue
    with path.open('rb') as source:
        digest = hashlib.file_digest(source, 'sha256').hexdigest()
    entry = {'path': args.prefix + str(path.relative_to(args.root)),
             'bytes': path.stat().st_size, 'sha256': digest}
    if path.suffix == '.png':
        with path.open('rb') as source:
            header = source.read(24)
        if len(header) == 24 and header[:8] == b'\x89PNG\r\n\x1a\n' and header[12:16] == b'IHDR':
            entry['width'], entry['height'] = struct.unpack('>II', header[16:24])
    entries.append(entry)
    print('EVIDENCE_FILE', json.dumps(entry), flush=True)
    if args.inline and (path.suffix in ('.png', '.json', '.h', '.ips', '.crash') or path.name == 'swiftui-interfaces.txt'):
        print('SEREIN_FILE_BEGIN ' + entry['path'], flush=True)
        encoded = base64.b64encode(path.read_bytes()).decode()
        for index in range(0, len(encoded), 2000):
            print('SEREIN_BYTES ' + encoded[index:index + 2000], flush=True)
        print('SEREIN_FILE_END', flush=True)
if args.root.is_dir():
    (args.root / 'evidence-index.json').write_text(json.dumps(entries, indent=2))
print(f'Evidence index: {len(entries)} files, {sum(item["bytes"] for item in entries)} bytes. Original files remain in the uploaded artifact.')
