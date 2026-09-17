#!/bin/bash
set -euo pipefail
ROOT="$PWD/evidence/runtime"
mkdir -p "$ROOT"
python3 -m http.server 8765 --bind 127.0.0.1 --directory Fixtures > "$ROOT/server.log" 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
open -n dist/Serein.app --stdout "$ROOT/application.log" --stderr "$ROOT/application-error.log" --args --test-root "$ROOT" --integration-test
sleep 2
osascript -e 'tell application "System Events" to tell process "UserNotificationCenter" to click button "Don’t Allow" of window 1' || true
for i in $(seq 1 2400); do
  if test -s "$ROOT/results.json"; then break; fi
  if test -f "$ROOT/capture-request"; then
    CAPTURE_NAME=$(cat "$ROOT/capture-request")
    if [[ "$CAPTURE_NAME" =~ ^[a-z0-9-]+$ ]]; then
      screencapture -x "$ROOT/$CAPTURE_NAME.png"
    fi
    rm "$ROOT/capture-request"
  fi
  if (( i % 20 == 0 )); then ps -axo pid,ppid,rss,%cpu,comm > "$ROOT/process-$i.txt"; fi
  sleep 0.1
done
cat "$ROOT/application.log"
cat "$ROOT/application-error.log"
python3 - <<'PY'
import json,pathlib
p=pathlib.Path('evidence/runtime/results.json')
assert p.exists(), 'Application did not finish runtime verification'
results=json.loads(p.read_text())
for r in results: print(('PASS' if r['passed'] else 'FAIL'),r['name'],r['detail'])
assert all(r['passed'] for r in results), 'Runtime scenario failures'
PY
