#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode_27.0.app/Contents/Developer
export MACOSX_DEPLOYMENT_TARGET=27.0
mkdir -p evidence/build dist
{
  sw_vers
  uname -m
  xcodebuild -version
  xcrun swift --version
  xcrun --sdk macosx --show-sdk-version
  readlink /Applications/Xcode_27.0.app || true
  df -h .
  sysctl hw.memsize
  echo "MACOSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET"
} | tee evidence/build/toolchain.txt
test "$(sw_vers -productVersion | cut -d. -f1)" = 27
test "$(xcrun --sdk macosx --show-sdk-version | cut -d. -f1)" = 27
xcrun swift test --build-system native --parallel 2>&1 | tee evidence/build/tests.log
xcrun swift build --build-system native -c release --arch arm64 2>&1 | tee evidence/build/build.log
APP=dist/Serein.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/arm64-apple-macosx/release/Serein "$APP/Contents/MacOS/Serein"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Fixtures "$APP/Contents/Resources/Fixtures"
codesign --force --sign - --options runtime "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
xcrun vtool -show-build "$APP/Contents/MacOS/Serein" | tee evidence/build/macho.txt
python3 - <<'PY'
import pathlib,plistlib
p=plistlib.loads(pathlib.Path('dist/Serein.app/Contents/Info.plist').read_bytes())
assert p['LSMinimumSystemVersion']=='27.0'
s=pathlib.Path('evidence/build/macho.txt').read_text()
assert 'minos 27.0' in s and 'sdk 27.0' in s
PY
ditto -c -k --sequesterRsrc --keepParent "$APP" dist/Serein-macOS27-arm64.zip
shasum -a 256 dist/Serein-macOS27-arm64.zip > dist/SHA256SUMS
