#!/bin/bash
# Regenerates Resources/AppIcon.icns from scripts/make-icon.swift
set -euo pipefail
cd "$(dirname "$0")/.."
T=$(mktemp -d)
swift scripts/make-icon.swift "$T/base.png"
mkdir "$T/AppIcon.iconset"
for sz in 16 32 128 256 512; do
  sips -z $sz $sz "$T/base.png" --out "$T/AppIcon.iconset/icon_${sz}x${sz}.png" >/dev/null
  sips -z $((sz*2)) $((sz*2)) "$T/base.png" --out "$T/AppIcon.iconset/icon_${sz}x${sz}@2x.png" >/dev/null
done
iconutil -c icns "$T/AppIcon.iconset" -o Resources/AppIcon.icns
cp "$T/base.png" Resources/AppIcon-preview.png
rm -rf "$T"
echo "Wrote Resources/AppIcon.icns"
