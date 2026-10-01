#!/usr/bin/env python3
"""Deterministic local browser fixtures, including a resumable slow download."""
import argparse
import functools
import http.server
import io
import math
import struct
import wave
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

    def do_HEAD(self):
        if self.path.split('?', 1)[0] == '/serein-tone.wav':
            return self.tone()
        return super().do_HEAD()

    def do_GET(self):
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
