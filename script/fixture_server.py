#!/usr/bin/env python3
"""Deterministic local browser fixtures, including a resumable slow download."""
import argparse
import base64
import hashlib
import json
import pathlib
import functools
import http.server
import io
import math
import struct
import wave
import zlib
import urllib.parse
import re
import time

PAYLOAD = bytes(range(256)) * 32768

def tone_wave():
    output = io.BytesIO()
    with wave.open(output, 'wb') as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(8000)
        audio.writeframes(b''.join(struct.pack('<h', round(1000 * math.sin(2 * math.pi * 440 * index / 8000))) for index in range(8000)))
    return output.getvalue()

TONE = tone_wave()

def icon_png(width=16, height=16):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    pixels = b''.join(b'\x00' + b''.join(bytes((255, 255, 255, 255)) if 6 <= x < 10 or 6 <= y < 10 else bytes((22, 133, 130, 255)) for x in range(width)) for y in range(height))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(pixels)) + chunk(b'IEND', b'')

ICON = icon_png()
ICON_EXTERNAL_REQUESTS = 0

class Handler(http.server.SimpleHTTPRequestHandler):
    def tone(self):
        start, end = 0, len(TONE) - 1
        value = self.headers.get('Range')
        if value:
            match = re.fullmatch(r'bytes=(\d+)-(\d*)', value)
            if not match:
                self.send_error(416)
                return
            start = int(match[1])
            end = min(end, int(match[2])) if match[2] else end
            if start > end:
                self.send_error(416)
                return
        self.send_response(206 if value else 200)
        self.send_header('Content-Type', 'audio/wav')
        self.send_header('Content-Length', str(end - start + 1))
        self.send_header('Accept-Ranges', 'bytes')
        if value:
            self.send_header('Content-Range', f'bytes {start}-{end}/{len(TONE)}')
        self.end_headers()
        if self.command != 'HEAD':
            try:
                self.wfile.write(TONE[start:end + 1])
            except (BrokenPipeError, ConnectionResetError):
                pass

    def end_headers(self):
        if urllib.parse.urlsplit(self.path).path == '/icon.html' and 'headerdeny' in urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query):
            self.send_header('Content-Security-Policy', "connect-src 'none'")
        super().end_headers()

    def do_HEAD(self):
        if self.path.split('?', 1)[0] == '/serein-tone.wav':
            return self.tone()
        return super().do_HEAD()

    def do_GET(self):
        path = urllib.parse.urlsplit(self.path).path
        if path == '/icon-svg-external':
            global ICON_EXTERNAL_REQUESTS
            ICON_EXTERNAL_REQUESTS += 1
            self.send_response(200)
            self.send_header('Content-Type', 'image/png')
            self.send_header('Content-Length', str(len(ICON)))
            self.end_headers()
            self.wfile.write(ICON)
            return
        if path == '/icon-svg-audit':
            payload = json.dumps({'requests': ICON_EXTERNAL_REQUESTS}).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        if path == '/icon-svg':
            query = urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query)
            width = 1025 if 'wide' in query else 32 if 'rect' in query else 16
            payload = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="16" viewBox="0 0 16 16">'
                '<rect width="16" height="16" fill="#168582"/><path d="M6 0h4v16H6zM0 6h16v4H0z" fill="white"/>'
                + ('<script>fetch("http://127.0.0.1:8765/icon-svg-external?script=1")</script>'
                   '<image href="http://127.0.0.1:8765/icon-svg-external?image=1" width="1" height="1"/>' if 'unsafe' in query else '')
                + '</svg>').encode()
            self.send_response(200)
            self.send_header('Content-Type', 'image/svg+xml')
            self.send_header('Content-Length', str(len(payload)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(payload)
            return
        if path.startswith('/icon-format/'):
            name = path.rsplit('/', 1)[-1]
            entries = json.loads((pathlib.Path(self.directory) / 'IconFormats.json').read_text())
            if name not in entries:
                self.send_error(404)
                return
            entry = entries[name]
            payload = base64.b64decode(entry['base64'], validate=True)
            assert hashlib.sha256(payload).hexdigest() == entry['sha256']
            self.send_response(200)
            self.send_header('Content-Type', entry['mime'])
            self.send_header('Content-Length', str(len(payload)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(payload)
            return
        if path == '/icon-redirect':
            self.send_response(302)
            self.send_header('Location', '/icon-fixture.png')
            self.send_header('Content-Length', '0')
            self.end_headers()
            return
        if path in ['/icon-fixture.png', '/icon-cookie.png', '/icon-large', '/icon-stream-large', '/icon-wide.png', '/icon-slow']:
            if path == '/icon-cookie.png':
                expected = urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query).get('value', [''])[0]
                if not expected or ('sereinIcon=' + expected) not in self.headers.get('Cookie', '').split('; '):
                    self.send_error(403)
                    return
            if path == '/icon-slow':
                time.sleep(1.5)
            payload = icon_png(1025, 16) if path == '/icon-wide.png' else ICON
            if path in ['/icon-large', '/icon-stream-large']:
                payload += b'\x00' * 262145
            self.send_response(200)
            self.send_header('Content-Type', 'image/png')
            self.send_header('Cache-Control', 'no-store')
            if path != '/icon-stream-large':
                self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            try:
                self.wfile.write(payload)
            except (BrokenPipeError, ConnectionResetError):
                pass
            return
        if self.path.split('?', 1)[0] == '/redirect-download':
            self.send_response(302)
            self.send_header('Location', '/download.txt')
            self.send_header('Content-Length', '0')
            self.end_headers()
            return
        if self.path.split('?', 1)[0] == '/serein-tone.wav':
            return self.tone()
        if self.path.split('?', 1)[0] in ['/ads/!rotator/probe.js', '/serein-clean-probe.js']:
            payload = b'window.sereinBlockerLoads=(window.sereinBlockerLoads||0)+1;'
            self.send_response(200)
            self.send_header('Content-Type', 'application/javascript')
            self.send_header('Content-Length', str(len(payload)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(payload)
            return
        if self.path.split('?', 1)[0] == '/extension-network-redirect':
            self.send_response(302)
            self.send_header('Location', 'http://127.0.0.1:8765/extension-network.json?case=redirect')
            self.send_header('Content-Length', '0')
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            return
        if self.path.split('?', 1)[0] != '/slow-download.bin':
            return super().do_GET()
        start, end = 0, len(PAYLOAD) - 1
        value = self.headers.get('Range')
        if value:
            match = re.fullmatch(r'bytes=(\d+)-(\d*)', value)
            if not match:
                self.send_error(416)
                return
            start = int(match[1])
            end = min(end, int(match[2])) if match[2] else end
            if start > end:
                self.send_error(416)
                return
        self.send_response(206 if value else 200)
        self.send_header('Content-Type', 'application/octet-stream')
        self.send_header('Content-Disposition', 'attachment; filename="slow-download.bin"')
        self.send_header('Content-Length', str(end - start + 1))
        self.send_header('Accept-Ranges', 'bytes')
        self.send_header('ETag', '"serein-download-v1"')
        self.send_header('Last-Modified', 'Tue, 01 Sep 2026 00:00:00 GMT')
        if value:
            self.send_header('Content-Range', f'bytes {start}-{end}/{len(PAYLOAD)}')
        self.end_headers()
        print(f'SEREIN_DOWNLOAD_RANGE start={start} end={end}', flush=True)
        try:
            for offset in range(start, end + 1, 65536):
                self.wfile.write(PAYLOAD[offset:min(offset + 65536, end + 1)])
                self.wfile.flush()
                time.sleep(0.05)
        except (BrokenPipeError, ConnectionResetError):
            pass

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--directory', default='Fixtures')
    parser.add_argument('--port', type=int, default=8765)
    args = parser.parse_args()
    http.server.ThreadingHTTPServer(('127.0.0.1', args.port), functools.partial(Handler, directory=args.directory)).serve_forever()
