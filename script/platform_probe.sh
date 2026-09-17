#!/bin/bash
set -xeuo pipefail
mkdir -p evidence/platform
exec > >(tee evidence/platform/probe.log) 2>&1
export DEVELOPER_DIR=/Applications/Xcode_27.0.app/Contents/Developer
export MACOSX_DEPLOYMENT_TARGET=27.0
sw_vers
uname -m
xcodebuild -version
xcrun swift --version
xcrun --sdk macosx --show-sdk-version
df -h .
sysctl hw.memsize
test "$(sw_vers -productVersion | cut -d. -f1)" = 27
test "$(xcrun --sdk macosx --show-sdk-version | cut -d. -f1)" = 27
SDK=$(xcrun --sdk macosx --show-sdk-path)
mkdir -p evidence/platform/headers
cp "$SDK"/System/Library/Frameworks/WebKit.framework/Headers/WKWebExtension*.h evidence/platform/headers/
cp "$SDK"/System/Library/Frameworks/AppKit.framework/Headers/NSWindow.h evidence/platform/headers/
cp "$SDK"/System/Library/Frameworks/AppKit.framework/Headers/NSGlassEffect*.h evidence/platform/headers/ || true
grep -n -B 3 -A 8 -E 'windowToolbar|windowChrome|window.*[Rr]eveal|titlebar|Titlebar|bordered|TabsPickerStyle' "$SDK"/System/Library/Frameworks/SwiftUI.framework/Modules/SwiftUI.swiftmodule/arm64e-apple-macos.swiftinterface > evidence/platform/swiftui-interfaces.txt || true
mkdir -p /tmp/SereinProbe.app/Contents/MacOS
xcrun swiftc -parse-as-library -swift-version 6 -target arm64-apple-macos27.0 script/PlatformProbe.swift -o /tmp/SereinProbe.app/Contents/MacOS/SereinProbe
cat > /tmp/SereinProbe.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>dev.serein.probe</string><key>CFBundleExecutable</key><string>SereinProbe</string><key>CFBundlePackageType</key><string>APPL</string><key>LSMinimumSystemVersion</key><string>27.0</string><key>NSPrincipalClass</key><string>NSApplication</string></dict></plist>
PLIST
codesign --force --sign - /tmp/SereinProbe.app
open -n /tmp/SereinProbe.app
sleep 3
pgrep -x SereinProbe
screencapture -x evidence/platform/desktop.png
test -s evidence/platform/desktop.png
killall SereinProbe

python3 - <<'PYEOF'
import base64,pathlib
p=pathlib.Path('evidence/platform/desktop.png')
print('SEREIN_FILE_BEGIN desktop.png')
print(base64.b64encode(p.read_bytes()).decode())
print('SEREIN_FILE_END')
PYEOF
