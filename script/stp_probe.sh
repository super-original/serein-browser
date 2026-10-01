#!/bin/bash
set -euo pipefail
ROOT="$PWD/evidence/stp"
mkdir -p "$ROOT"
exec > >(tee "$ROOT/probe.log") 2>&1
sw_vers
uname -m
xcodebuild -version
xcrun --sdk macosx --show-sdk-version
test "$(sw_vers -productVersion | cut -d. -f1)" = 27
DMG=/tmp/serein-stp-253.dmg
MOUNT=/tmp/serein-stp-volume
SERVER_PID=''
cleanup() {
  if test -n "$SERVER_PID"; then kill "$SERVER_PID" 2>/dev/null || true; fi
  hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
  rm -f "$DMG"
}
trap cleanup EXIT
curl --fail --location --retry 2 --max-time 120 --max-filesize 209715200 -o "$DMG" 'https://secure-appldnld.apple.com/STP/142-27948-20260923-e61cf471-d516-4ac4-9b4c-f08e459272dc/SafariTechPreview253.dmg'
echo 'dbfcc270a845b9a7ac74b13b762808ef19a5652eabadc5b7719291754dc01c8e  /tmp/serein-stp-253.dmg' | shasum -a 256 --check
mkdir -p "$MOUNT"
hdiutil attach "$DMG" -readonly -nobrowse -mountpoint "$MOUNT"
PKG=$(python3 - "$MOUNT" <<'PYTHON'
import pathlib,sys
root=pathlib.Path(sys.argv[1])
packages=list(root.glob('*.pkg'))
assert len(packages)==1, f'Expected one signed installer; volume entries: {[p.name for p in root.iterdir()]}'
print(packages[0])
PYTHON
)
printf 'Installer: %s\n' "$PKG"
pkgutil --check-signature "$PKG" | tee "$ROOT/package-signature.txt"
spctl --assess --type install --verbose=2 "$PKG" 2>&1 | tee "$ROOT/package-assessment.txt"
sudo -n installer -pkg "$PKG" -target / > "$ROOT/install.log" 2>&1
APP='/Applications/Safari Technology Preview.app'
codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 | tee "$ROOT/app-signature.txt"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" | tee "$ROOT/version.txt"
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist" | tee -a "$ROOT/version.txt"
python3 -m http.server 8765 --bind 127.0.0.1 --directory Fixtures > "$ROOT/server.log" 2>&1 &
SERVER_PID=$!
sleep 1
for BROWSER in 'Safari' 'Safari Technology Preview'; do
  if [[ "$BROWSER" == 'Safari' ]]; then NAME=system-safari; else NAME=technology-preview; fi
  open -a "$BROWSER" http://127.0.0.1:8765/index.html
  sleep 3
  osascript - "$BROWSER" <<'APPLESCRIPT' > "$ROOT/$NAME-automation.txt" 2>&1
on run arguments
 with timeout of 15 seconds
  tell application "System Events"
   tell process (item 1 of arguments)
    set frontmost to true
    keystroke "l" using command down
    keystroke "http://127.0.0.1:8765/index.html"
    key code 36
    set position of front window to {10, 30}
    set size of front window to {1000, 677}
    repeat 40 times
     if name of front window contains "Field Notes" then exit repeat
     delay 0.25
    end repeat
    return name of front window
   end tell
  end tell
 end timeout
end run
APPLESCRIPT
  sleep 2
  screencapture -x "$ROOT/$NAME.png"
  xcrun swift script/VisualGate.swift "$ROOT/$NAME.png" "$ROOT/$NAME-glyphs.json" || true
  osascript - "$BROWSER" <<'APPLESCRIPT'
on run arguments
 tell application "System Events" to tell process (item 1 of arguments) to keystroke "q" using command down
end run
APPLESCRIPT
  sleep 1
done
log show --last 3m --style compact --predicate '(process CONTAINS "WebKit" OR subsystem BEGINSWITH "com.apple.WebKit") AND (messageType == error OR messageType == fault)' > "$ROOT/webkit-errors.log" 2>&1 || true
python3 - "$ROOT" <<'PY'
import json,pathlib,sys
root=pathlib.Path(sys.argv[1]);results=[]
for name in ['system-safari','technology-preview']:
 title=(root/(name+'-automation.txt')).read_text()
 gate=json.loads((root/(name+'-glyphs.json')).read_text())
 results.append({'browser':name,'loadedFixtureTitle':'Field Notes' in title,'desktopGlyphGate':gate['passed'],'scope':'Independent Apple browser diagnostic; never substitutes for the Serein rendering gate.'})
(root/'results.json').write_text(json.dumps(results,indent=2))
print(json.dumps(results,indent=2))
assert all(x['loadedFixtureTitle'] for x in results),'A browser did not expose the fixture title; inspect actual screenshots.'
PY
