# Tasks: Claude Traffic Light

## Phase 1: Setup
- [x] T001 Create Package.swift with ClaudeLightCore, claude-light-app, claude-light-hook, claude-light-install, test target
- [x] T002 [P] Create scripts/build-app.sh producing build/ClaudeLight.app

## Phase 2: Foundational
- [x] T003 [P] Signal parsing in Sources/ClaudeLightCore/Signal.swift
- [x] T004 [P] SessionTracker state machine in Sources/ClaudeLightCore/SessionTracker.swift
- [x] T005 StateStore (atomic per-session files, prune) in Sources/ClaudeLightCore/StateStore.swift

## Phase 3: US1 - See Claude's state (P1)
- [x] T006 [P] [US1] Tests for Signal, SessionTracker, StateStore in Tests/ClaudeLightCoreTests/CoreTests.swift
- [x] T007 [US1] Hook executable in Sources/claude-light-hook/main.swift
- [x] T008 [US1] Traffic light view + polling in Sources/claude-light-app/TrafficLightView.swift

## Phase 4: US2 - Install (P2)
- [x] T009 [P] [US2] SettingsInstaller in Sources/ClaudeLightCore/SettingsInstaller.swift
- [x] T010 [P] [US2] Installer tests in Tests/ClaudeLightCoreTests/InstallerTests.swift
- [x] T011 [US2] Installer CLI in Sources/claude-light-install/main.swift

## Phase 5: US3 - Widget polish (P3)
- [x] T012 [US3] Floating panel, drag, persisted position, accessory policy, Quit menu in Sources/claude-light-app/main.swift

## Phase 6: Polish
- [x] T013 Smoke tests: hook latency (<100 ms), render pixels (scripts/verify-render.sh), installer CLI

## Phase 7: Analyze follow-ups
- [x] T014 Map Notification event to idle; update spec edge cases (analyze F1/U1)
- [x] T015 PositionStore + tests in Sources/ClaudeLightCore/PositionStore.swift (analyze C2)
- [x] T016 scripts/verify-render.sh pixel check for FR-012 (analyze C4)

## Phase 8: Convergence
- [x] T017 Hooks installed into real ~/.claude/settings.json (user approved, backup at settings.json.bak-claudelight); a live session wrote state=working and the app was running (US1/AC1); real Stop event observed: working -> idle (green) at 21:32:04, then back to working on the next prompt
- [x] T018 Add scripts/setup.sh that builds, installs hooks and opens the app so setup takes two commands per SC-005 (partial)
- [x] T019 Right-click Quit verified via `ClaudeLight --selftest-quit` (native menu fetched as a right-click does, Quit item activated, app exits 0); caught and fixed NSHostingView returning no menu
- [x] T020 Document the --snapshot mode and CLAUDE_LIGHT_DEBUG log in plan.md as verification aids (unrequested)
