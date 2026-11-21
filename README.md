# Claude Light

A tiny floating traffic light for macOS: **red** while Claude Code is working, **green** when it's finished.

One step: `scripts/setup.sh` (builds, connects Claude Code, opens the widget). Or manually:

```bash
scripts/build-app.sh                                   # builds build/ClaudeLight.app
open build/ClaudeLight.app                             # shows the widget (drag it anywhere; right-click to quit)
build/ClaudeLight.app/Contents/MacOS/claude-light-install install     # connect Claude Code (edits ~/.claude/settings.json)
build/ClaudeLight.app/Contents/MacOS/claude-light-install uninstall   # remove only our hooks
swift test
```
Restart running Claude Code sessions after installing so they pick up the hooks. Built with Spec Kit; see `specs/001-claude-traffic-light/`.
