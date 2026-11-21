#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ARCHS="--arch arm64 --arch x86_64"   # universal: Apple Silicon + Intel
swift build -c release $ARCHS
BIN=$(swift build -c release $ARCHS --show-bin-path)
APP=build/ClaudeLight.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp "$BIN/claude-light-app" "$APP/Contents/MacOS/ClaudeLight"
cp "$BIN/claude-light-hook" "$BIN/claude-light-install" "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>ClaudeLight</string>
<key>CFBundleIdentifier</key><string>dev.claudelight.app</string>
<key>CFBundleExecutable</key><string>ClaudeLight</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
# Ad-hoc sign the helper binaries first, then the bundle (helpers live in Contents/MacOS).
codesign --force --sign - "$APP/Contents/MacOS/claude-light-hook" "$APP/Contents/MacOS/claude-light-install"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"
