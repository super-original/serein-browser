#!/usr/bin/env python3
"""Deterministic local browser fixtures, including a resumable slow download."""
import argparse
import functools
import http.server
import re
import time

PAYLOAD = bytes(range(256)) * 32768

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
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
