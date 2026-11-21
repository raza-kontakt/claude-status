#!/bin/bash
# One-step setup: build the app, connect Claude Code (edits ~/.claude/settings.json), launch the widget.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build-app.sh
APP="$PWD/build/ClaudeLight.app"
"$APP/Contents/MacOS/claude-light-install" install --hook "$APP/Contents/MacOS/claude-light-hook"
open "$APP"
echo "Done. Restart running Claude Code sessions so they load the hooks."
