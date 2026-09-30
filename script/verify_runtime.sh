#!/bin/bash
set -euo pipefail
ROOT="$PWD/evidence/runtime"
mkdir -p "$ROOT"
# Compile embedded UI automation before launching the app. Shell syntax checks do
# not detect AppleScript reserved words or grammar errors.
python3 - <<'PYTHON'
from pathlib import Path
import re, subprocess, tempfile
source = Path("script/verify_runtime.sh").read_text()
blocks = re.findall(r"^[ \t]*(?:if )?osascript[^\n]*<<'APPLESCRIPT'[^\n]*\n(.*?)^APPLESCRIPT$", source, re.M | re.S)
assert blocks and all(block.startswith("on run arguments") for block in blocks), "No valid AppleScript blocks found"
with tempfile.TemporaryDirectory(prefix="serein-applescript-") as temporary:
    for index, block in enumerate(blocks):
        script = Path(temporary) / f"input-{index}.applescript"
        script.write_text(block)
        subprocess.run(["osacompile", "-o", str(script.with_suffix(".scpt")), str(script)], check=True)
print(f"Compiled {len(blocks)} embedded AppleScript input scenarios")
PYTHON
xcrun swiftc -parse-as-library -target arm64-apple-macos27.0 script/ScreenCapture.swift -o /tmp/serein-capture
xcrun swiftc -target arm64-apple-macos27.0 script/PointerInput.swift -o /tmp/serein-pointer
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
  with timeout of 5 seconds
  tell application "System Events" to tell process "Serein"
    keystroke "g" using {command down, shift down}
    delay 0.5
    keystroke item 1 of arguments
    key code 36
    delay 0.7
    keystroke "a" using command down
    keystroke "native-save-result.txt"
  end tell
  end timeout
end run
APPLESCRIPT
        ;;
      save-download) osascript -e 'tell application "System Events" to tell process "Serein" to key code 36' ;;
      suggestion-query)
        osascript -e 'tell application "System Events" to tell process "Serein"' -e 'keystroke "l" using command down' -e 'keystroke "a" using command down' -e 'keystroke "serein keyboard suggestion"' -e 'end tell'
        ;;
      suggestion-down) osascript -e 'tell application "System Events" to tell process "Serein" to key code 125' ;;
      suggestion-up) osascript -e 'tell application "System Events" to tell process "Serein" to key code 126' ;;
      suggestion-escape) osascript -e 'tell application "System Events" to tell process "Serein" to key code 53' ;;
      suggestion-return) osascript -e 'tell application "System Events" to tell process "Serein" to key code 36' ;;
      split-divider-drag)
        read -r SPLIT_X SPLIT_Y SPLIT_END_X SPLIT_END_Y < "$ROOT/split-drag-points"
        /tmp/serein-pointer "$SPLIT_X" "$SPLIT_Y" "$SPLIT_END_X" "$SPLIT_END_Y" > "$ROOT/split-divider-pointer.log" 2>&1
        ;;
      glance-option-click)
        read -r GLANCE_X GLANCE_Y < "$ROOT/glance-click-point"
        /tmp/serein-pointer "$GLANCE_X" "$GLANCE_Y" > "$ROOT/glance-pointer-input.log" 2>&1
        ;;
      glance-external-link)
        read -r GLANCE_X GLANCE_Y < "$ROOT/glance-click-point"
        /tmp/serein-pointer "$GLANCE_X" "$GLANCE_Y" plain > "$ROOT/glance-external-pointer-input.log" 2>&1
        ;;
      folder-name)
        osascript -e 'tell application "System Events" to tell process "Serein"' -e 'delay 0.3' -e 'keystroke "a" using command down' -e 'keystroke "Research notes"' -e 'key code 36' -e 'end tell'
        ;;
      folder-toggle|folder-context)
        FOLDER_IDENTIFIER=$(cat "$ROOT/folder-control-identifier")
        if osascript - "$KEYBOARD_NAME" "$FOLDER_IDENTIFIER" > "$ROOT/$KEYBOARD_NAME-point" 2> "$ROOT/$KEYBOARD_NAME-input.log" <<'APPLESCRIPT'
on run arguments
  with timeout of 5 seconds
  tell application "System Events" to tell process "Serein"
    set controls to entire contents of window 1
    repeat with uiElement in controls
      try
        if value of attribute "AXIdentifier" of uiElement is item 2 of arguments then
          if item 1 of arguments is "folder-context" then
            set origin to position of uiElement
            set extent to size of uiElement
            set centerX to (item 1 of origin) + (item 1 of extent) / 2
            set centerY to (item 2 of origin) + (item 2 of extent) / 2
            return (centerX as text) & " " & (centerY as text)
          end if
          perform action "AXPress" of uiElement
          return
        end if
      end try
    end repeat
    error "Research notes folder button was not found"
  end tell
  end timeout
end run
APPLESCRIPT
        then
          if [[ "$KEYBOARD_NAME" == 'folder-context' ]]; then
            read -r FOLDER_X FOLDER_Y < "$ROOT/folder-context-point"
            /tmp/serein-pointer "$FOLDER_X" "$FOLDER_Y" right > "$ROOT/folder-context-pointer.log" 2>&1
            sleep 0.5
            screencapture -x "$ROOT/47-folder-context.png"
            osascript -e 'tell application "System Events" to tell process "Serein" to key code 53'
          fi
        else
          touch "$ROOT/$KEYBOARD_NAME.keyboard-failed"
        fi
        ;;
      native-host-registration-file)
        NATIVE_MANIFEST=$(cat "$ROOT/native-host-manifest-path")
        osascript - "$NATIVE_MANIFEST" > "$ROOT/native-host-picker-input.log" 2>&1 <<'APPLESCRIPT' || touch "$ROOT/native-host-registration-file.keyboard-failed"
on run arguments
  with timeout of 5 seconds
  tell application "System Events" to tell process "Serein"
    delay 0.4
    keystroke "g" using {command down, shift down}
    delay 0.4
    keystroke "a" using command down
    keystroke item 1 of arguments
    delay 1.2
    key code 36
    delay 1.2
    key code 36
    repeat 8 times
      repeat with candidateWindow in windows
        if my openFileIfPresent(candidateWindow) then return
        repeat with childSheet in sheets of candidateWindow
          if my openFileIfPresent(childSheet) then return
          repeat with nestedSheet in sheets of childSheet
            if my openFileIfPresent(nestedSheet) then return
          end repeat
        end repeat
      end repeat
      delay 0.2
    end repeat
    error "Native Open button or consent was not found"
  end tell
  end timeout
end run
on openFileIfPresent(containerElement)
  try
  tell application "System Events"
    if exists button "Open" of containerElement then
      if enabled of button "Open" of containerElement then
        perform action "AXPress" of button "Open" of containerElement
        return true
      end if
    end if
    if exists button "Allow" of containerElement then return true
  end tell
  end try
  return false
end openFileIfPresent
APPLESCRIPT
        ;;
      fullscreen-enter)
        read -r FULLSCREEN_X FULLSCREEN_Y < "$ROOT/fullscreen-click-point"
        /tmp/serein-pointer "$FULLSCREEN_X" "$FULLSCREEN_Y" plain > "$ROOT/fullscreen-pointer-input.log" 2>&1
        ;;
      fullscreen-exit) osascript -e 'tell application "System Events" to tell process "Serein" to key code 53' ;;
      glance-next-tab) osascript -e 'tell application "System Events" to tell process "Serein" to key code 48 using control down' ;;
      glance-previous-tab) osascript -e 'tell application "System Events" to tell process "Serein" to key code 48 using {control down, shift down}' ;;
      glance-escape) osascript -e 'tell application "System Events" to tell process "Serein" to key code 53' ;;
      find-query) osascript -e 'tell application "System Events" to tell process "Serein"' -e 'keystroke "f" using command down' -e 'delay 0.3' -e 'keystroke "a" using command down' -e 'keystroke "Workspaces"' -e 'end tell' ;;
      find-escape) osascript -e 'tell application "System Events" to tell process "Serein" to key code 53' ;;
      find-page-key) osascript -e 'tell application "System Events" to tell process "Serein" to keystroke "k"' ;;
      extension-command) osascript -e 'tell application "System Events" to tell process "Serein" to keystroke "y" using {option down, shift down}' ;;
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
if ! test -s "$ROOT/results.json"; then
  screencapture -x "$ROOT/diagnostic-timeout.png" || true
  sample "$APP_PID" 3 -file "$ROOT/diagnostic-timeout-stack.txt" || true
fi
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
