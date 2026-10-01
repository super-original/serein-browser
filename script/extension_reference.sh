#!/bin/bash
set -euo pipefail
mkdir -p evidence/extension-reference
exec > >(tee evidence/extension-reference/run.log) 2>&1
sw_vers
uname -m
xcodebuild -version
xcrun --sdk macosx --show-sdk-version
SERVER_PID=''
DRIVER_PID=''
cleanup() {
  if test -n "$DRIVER_PID"; then kill "$DRIVER_PID" 2>/dev/null || true; fi
  if test -n "$SERVER_PID"; then kill "$SERVER_PID" 2>/dev/null || true; fi
  hdiutil detach /tmp/serein-port-zen-volume -quiet 2>/dev/null || true
  rm -f /tmp/serein-port-zen.dmg
}
trap cleanup EXIT
curl --fail --location --retry 2 --max-time 120 https://github.com/zen-browser/desktop/releases/download/1.22.2b/zen.macos-universal.dmg -o /tmp/serein-port-zen.dmg
# Same exact upstream binary as the visual baseline.
echo '2332673353551bfe4607aa6edd3c3ee3149652651a7698acabad935612c93943  /tmp/serein-port-zen.dmg' | shasum -a 256 --check
hdiutil attach /tmp/serein-port-zen.dmg -readonly -nobrowse -mountpoint /tmp/serein-port-zen-volume
ditto /tmp/serein-port-zen-volume/Zen.app /tmp/SereinPortReference.app
hdiutil detach /tmp/serein-port-zen-volume
python3 -m http.server 8765 --bind 127.0.0.1 --directory Fixtures > evidence/extension-reference/server.log 2>&1 &
SERVER_PID=$!
geckodriver --allow-system-access --port 4444 > evidence/extension-reference/geckodriver.log 2>&1 &
DRIVER_PID=$!
python3 script/extension_reference.py
