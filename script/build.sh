#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode_27.1.app/Contents/Developer
export MACOSX_DEPLOYMENT_TARGET=27.0
mkdir -p evidence/build dist
{
  sw_vers
  uname -m
  xcodebuild -version
  xcrun swift --version
  xcrun --sdk macosx --show-sdk-version
  ls -d /Applications/Xcode*.app
  readlink /Applications/Xcode_27.1.app || true
  df -h .
  sysctl hw.memsize
  echo "MACOSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET"
} | tee evidence/build/toolchain.txt
test "$(sw_vers -productVersion | cut -d. -f1)" = 27
test "$(xcrun --sdk macosx --show-sdk-version | cut -d. -f1)" = 27
python3 script/check_signed_fixtures.py
xcrun swift test --parallel --xunit-output evidence/build/unit-tests.xml 2>&1 | tee evidence/build/tests.log
xcrun swift build -c release --arch arm64 2>&1 | tee evidence/build/build.log
APP=dist/Serein.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
BIN=$(xcrun swift build -c release --arch arm64 --show-bin-path)
cp "$BIN/Serein" "$APP/Contents/MacOS/Serein"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Fixtures "$APP/Contents/Resources/Fixtures"
xcrun swiftc -target arm64-apple-macos27.0 script/NativeHostFixture.swift -o "$APP/Contents/Resources/Fixtures/NativeHosts/NativeEcho"
codesign --force --sign - --options runtime "$APP/Contents/Resources/Fixtures/NativeHosts/NativeEcho"
xcrun vtool -show-build "$APP/Contents/Resources/Fixtures/NativeHosts/NativeEcho" > evidence/build/native-host-macho.txt
codesign --force --sign - --options runtime "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
xcrun vtool -show-build "$APP/Contents/MacOS/Serein" | tee evidence/build/macho.txt
python3 - <<'PY'
import pathlib,plistlib
p=plistlib.loads(pathlib.Path('dist/Serein.app/Contents/Info.plist').read_bytes())
assert p['LSMinimumSystemVersion']=='27.0'
s=pathlib.Path('evidence/build/macho.txt').read_text()
assert 'minos 27.0' in s and 'sdk 27.0' in s
h=pathlib.Path('evidence/build/native-host-macho.txt').read_text()
assert 'minos 27.0' in h and 'sdk 27.0' in h
PY
ditto -c -k --sequesterRsrc --keepParent "$APP" dist/Serein-macOS27-arm64.zip
shasum -a 256 dist/Serein-macOS27-arm64.zip > dist/SHA256SUMS
