#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Universal binary (Apple Silicon + Intel): build each arch in its own scratch dir, then merge with lipo.
# (Separate per-arch builds are more portable across toolchains than one multi-arch build.)
UNI=build/universal
rm -rf "$UNI"; mkdir -p "$UNI"
build_arch() { swift build -c release --triple "$1-apple-macosx13.0" --scratch-path ".build/$1" "${@:2}"; }
for arch in arm64 x86_64; do build_arch "$arch"; done
for bin in claude-light-app claude-light-hook claude-light-install; do
  lipo -create -output "$UNI/$bin" \
    "$(build_arch arm64 --show-bin-path)/$bin" \
    "$(build_arch x86_64 --show-bin-path)/$bin"
done
BIN="$UNI"
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
