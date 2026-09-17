#!/bin/bash
set -euo pipefail
mkdir -p evidence/zen
exec > >(tee evidence/zen/capture.log) 2>&1
sw_vers
xcodebuild -version
curl --fail --location --retry 2 https://github.com/zen-browser/desktop/releases/download/1.22.2b/zen.macos-universal.dmg -o /tmp/zen.dmg
echo '2332673353551bfe4607aa6edd3c3ee3149652651a7698acabad935612c93943  /tmp/zen.dmg' | shasum -a 256 -c -
hdiutil attach /tmp/zen.dmg -nobrowse -mountpoint /tmp/zen-mount
ditto /tmp/zen-mount/Zen.app /tmp/Zen.app
hdiutil detach /tmp/zen-mount
python3 -m http.server 8765 --bind 127.0.0.1 --directory Fixtures > /tmp/fixture-server.log 2>&1 &
geckodriver --allow-system-access --port 4444 > evidence/zen/geckodriver.log 2>&1 &
python3 script/zen_reference.py
