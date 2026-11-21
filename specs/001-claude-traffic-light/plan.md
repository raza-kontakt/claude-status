# Implementation Plan: Claude Traffic Light

**Branch**: `001-claude-traffic-light` | **Date**: 2026-11-21 | **Spec**: [spec.md](spec.md)

## Summary
A SwiftPM package with a testable core library and three executables: the floating traffic-light app, a hook binary that Claude Code invokes, and an installer that edits `~/.claude/settings.json`. Hooks write one file per session into `~/.claude-light/sessions/`; the app watches that directory and derives red/green.

## Technical Context
**Language/Version**: Swift 6 (toolchain 6.4), language mode 5 where needed for AppKit concurrency
**Primary Dependencies**: Foundation, SwiftUI, AppKit only (no third-party)
**Storage**: Per-session files in `~/.claude-light/sessions/<session_id>.json` (override via `CLAUDE_LIGHT_DIR`); window position in UserDefaults
**Testing**: XCTest via `swift test`
**Target Platform**: macOS 13+
**Project Type**: desktop-app + CLI
**Performance Goals**: hook < 100 ms; UI update < 1 s (poll 0.25 s)
**Constraints**: hook always exits 0, no network
**Scale/Scope**: ~600 LOC

## Constitution Check
Constitution is the unfilled template: no gates. Self-imposed: core logic is library-first and unit tested; hook never fails Claude. PASS (pre and post design).

## Project Structure
```text
Package.swift
Sources/ClaudeLightCore/   Signal.swift SessionTracker.swift StateStore.swift SettingsInstaller.swift
Sources/claude-light-app/  main.swift TrafficLightView.swift
Sources/claude-light-hook/ main.swift
Sources/claude-light-install/ main.swift
Tests/ClaudeLightCoreTests/
scripts/build-app.sh
```
**Structure Decision**: single package, core library + 3 thin executables.

## Verification aids (not user features)
- `claude-light-app --snapshot out.png red|green` renders the widget offscreen; `scripts/verify-render.sh` checks the lamp pixel colours.
- `CLAUDE_LIGHT_DEBUG=1` makes the app log each light change to stderr.
