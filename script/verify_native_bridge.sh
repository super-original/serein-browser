#!/bin/bash
set -euo pipefail
ROOT="$PWD/evidence/native-bridge"
mkdir -p "$ROOT"
python3 script/fixture_server.py --directory Fixtures > "$ROOT/server.log" 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
open -n dist/Serein.app --stdout "$ROOT/application.log" --stderr "$ROOT/application-error.log" --args --test-root "$ROOT" --native-bridge-test
sleep 2
APP_PID=$(pgrep -x Serein | head -1 || true)
for i in $(seq 1 900); do
  if test -s "$ROOT/results.json"; then break; fi
  if ! kill -0 "$APP_PID" 2>/dev/null; then break; fi
  sleep 0.1
done
cat "$ROOT/application.log"
cat "$ROOT/application-error.log"
python3 - "$ROOT" <<'PY'
import json,pathlib,sys
root=pathlib.Path(sys.argv[1])
for f in root.glob('*.json'): print(f.name, f.read_text())
p=root/'results.json'
assert p.exists(), 'Native-message probe did not finish; normal runtime results are separate'
results=json.loads(p.read_text())
assert results and all(r['passed'] for r in results), 'Native-message probe failed'
PY
