#!/usr/bin/env python3
"""Regenerate original raster test bytes; optional development-only Pillow tool.

CI reads the checked-in JSON and needs only the standard library. No artwork or
third-party icon is copied. Generated with Pillow 12.3.0; encoders can differ.
"""
import base64
import hashlib
import io
import json
import pathlib
from PIL import Image

image = Image.new('RGB', (16, 16), (22, 133, 130))
for y in range(16):
    for x in range(16):
        if 6 <= x < 10 or 6 <= y < 10:
            image.putpixel((x, y), (255, 255, 255))
formats = {}
for name, format_name, mime, options in [
    ('jpeg', 'JPEG', 'image/jpeg', {'quality': 95}),
    ('gif', 'GIF', 'image/gif', {}),
    ('tiff', 'TIFF', 'image/tiff', {}),
    ('webp', 'WEBP', 'image/webp', {'lossless': True}),
    ('ico', 'ICO', 'image/x-icon', {'sizes': [(16, 16)]}),
]:
    buffer = io.BytesIO()
    image.save(buffer, format=format_name, **options)
    data = buffer.getvalue()
    formats[name] = dict(mime=mime, sha256=hashlib.sha256(data).hexdigest(),
                         base64=base64.b64encode(data).decode('ascii'))
path = pathlib.Path(__file__).resolve().parent.parent / 'Fixtures/IconFormats.json'
path.write_text(json.dumps(formats, indent=2, sort_keys=True)+'\n')
print('Wrote original 16x16 cross fixtures:', ', '.join(formats))
