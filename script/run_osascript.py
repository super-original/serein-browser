#!/usr/bin/env python3
"""Bound native input so a late helper cannot type into a later test scenario."""
import subprocess
import sys

deadline = float(sys.argv[1])
assert 0 < deadline <= 10
arguments = sys.argv[2:]
source = sys.stdin.buffer.read() if not arguments or arguments[0] == '-' else b''
try:
    result = subprocess.run(['/usr/bin/osascript', *arguments], input=source, timeout=deadline)
    raise SystemExit(result.returncode)
except subprocess.TimeoutExpired:
    print(f'Native input exceeded {deadline:g} seconds; owned osascript helper stopped.', file=sys.stderr)
    raise SystemExit(124)
