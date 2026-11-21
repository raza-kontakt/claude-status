#!/bin/bash
# Renders the widget offscreen in both states and checks lamp pixel colours.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build >/dev/null
D=$(mktemp -d)
for s in red green; do .build/debug/claude-light-app --snapshot "$D/$s.png" $s; done
swiftc -o "$D/check" scripts/check-pixels.swift
"$D/check" "$D"
