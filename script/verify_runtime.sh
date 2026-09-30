#!/bin/bash
set -euo pipefail
ROOT="$PWD/evidence/runtime"
mkdir -p "$ROOT"
xcrun swiftc -parse-as-library -target arm64-apple-macos27.0 script/ScreenCapture.swift -o /tmp/serein-capture
system_profiler SPDisplaysDataType > "$ROOT/display.txt"
python3 script/fixture_server.py --directory Fixtures > "$ROOT/server.log" 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
python3 script/fetch_extension_fixtures.py /tmp/serein-extension-audit
ps -axo pid,ppid,rss,%cpu,comm > "$ROOT/process-baseline.txt"
open -n dist/Serein.app --stdout "$ROOT/application.log" --stderr "$ROOT/application-error.log" --args --test-root "$ROOT" --integration-test --real-extension-catalog /tmp/serein-extension-audit/catalog.json
sleep 2
APP_PID=$(pgrep -x Serein | head -1 || true)
osascript -e 'tell application "System Events" to tell process "UserNotificationCenter" to click button "Don’t Allow" of window 1' || true
for i in $(seq 1 2400); do
  if test -s "$ROOT/results.json"; then break; fi
  if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo "Serein exited before writing final results"
    break
  fi
  if test -f "$ROOT/keyboard-request"; then
    KEYBOARD_NAME=$(cat "$ROOT/keyboard-request")
    rm "$ROOT/keyboard-request"
    case "$KEYBOARD_NAME" in
      prepare-save-download)
        osascript - "$ROOT" <<'APPLESCRIPT'
on run arguments
  tell application "System Events" to tell process "Serein"
    keystroke "g" using {command down, shift down}
    delay 0.5
    keystroke item 1 of arguments
    key code 36
    delay 0.7
    keystroke "a" using command down
    keystroke "native-save-result.txt"
  end tell
end run
APPLESCRIPT
        ;;
      save-download) osascript -e 'tell application "System Events" to tell process "Serein" to key code 36' ;;
      address) osascript -e 'tell application "System Events" to tell process "Serein" to keystroke "l" using command down' ;;
      new-tab) osascript -e 'tell application "System Events" to tell process "Serein" to keystroke "t" using command down' ;;
      close-tab) osascript -e 'tell application "System Events" to tell process "Serein" to keystroke "w" using command down' ;;
      *) exit 2 ;;
    esac
    touch "$ROOT/$KEYBOARD_NAME.keyboard-finished"
  fi
  if test -f "$ROOT/capture-request"; then
    CAPTURE_NAME=$(cat "$ROOT/capture-request")
    rm "$ROOT/capture-request"
    if [[ "$CAPTURE_NAME" =~ ^[a-z0-9-]+$ ]]; then
      screencapture -x "$ROOT/$CAPTURE_NAME.png"
      if [[ "$CAPTURE_NAME" == '01-light-expanded' || "$CAPTURE_NAME" == 'diagnostic-direct-appkit' ]]; then
        /tmp/serein-capture "$ROOT/$CAPTURE_NAME-screen-capture-kit.png" || true
      fi
    fi
    touch "$ROOT/$CAPTURE_NAME.capture-finished"
  fi
  if (( i % 20 == 0 )); then
    ps -axo pid,ppid,rss,%cpu,comm > "$ROOT/process-$i.txt"
    if test -f "$ROOT/idle-start" && ! test -f "$ROOT/idle-end"; then
      ps -axo pid,ppid,rss,time,comm > "$ROOT/idle-$(date +%s).txt"
    fi
  fi
  sleep 0.1
done
python3 - "$ROOT" <<'PYCRASH'
import pathlib,shutil,sys,time
root=pathlib.Path(sys.argv[1])
for p in (pathlib.Path.home()/'Library/Logs/DiagnosticReports').glob('Serein*'):
    if p.is_file() and time.time()-p.stat().st_mtime < 1800:
        shutil.copy2(p,root/p.name)
PYCRASH
cat "$ROOT/application.log"
cat "$ROOT/application-error.log"
log show --last 3m --style compact --predicate '(process CONTAINS "WebKit" OR subsystem BEGINSWITH "com.apple.WebKit") AND (messageType == error OR messageType == fault)' > "$ROOT/webkit-system.log" 2>&1 || true
tail -80 "$ROOT/webkit-system.log"
head -80 "$ROOT/webkit-system.log"
cat "$ROOT/display.txt"
python3 script/summarize_performance.py "$ROOT"
python3 - <<'PY'
import json,pathlib
p=pathlib.Path('evidence/runtime/results.json')
assert p.exists(), 'Application did not finish runtime verification'
results=json.loads(p.read_text())
for r in results: print(('PASS' if r['passed'] else 'FAIL'),r['name'],r['detail'])
assert all(r['passed'] for r in results), 'Runtime scenario failures'
PY
