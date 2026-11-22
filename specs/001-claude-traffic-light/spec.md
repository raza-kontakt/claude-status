# Feature Specification: Claude Traffic Light

**Feature Branch**: `001-claude-traffic-light`
**Created**: 2026-11-21
**Status**: Draft
**Input**: A tiny Mac app styled as a traffic light with a red and a green light. Red is on while Claude Code is working; green is on once Claude Code has finished.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See at a glance whether Claude is busy (Priority: P1)

A developer runs Claude Code in the background while doing other things. A small always-on-top traffic-light widget on their desktop shows a lit red light while Claude is working and a lit green light when Claude has finished and is waiting.

**Why this priority**: This is the entire purpose of the product.

**Independent Test**: Start the widget, send a "working" signal then a "finished" signal, and observe red then green.

**Acceptance Scenarios**:

1. **Given** the widget is running, **When** Claude starts working on a prompt, **Then** the red light is lit and green is dim within 1 second.
2. **Given** red is lit, **When** Claude finishes its response, **Then** green is lit and red is dim within 1 second.
3. **Given** Claude uses tools repeatedly during one task, **When** each tool call starts, **Then** red stays lit with no flicker to green.
4. **Given** the widget has just launched with no signal received yet, **When** it appears, **Then** green is lit (idle = Claude not working).

---

### User Story 2 - One-step connection to Claude (Priority: P2)

The user runs a single install command that connects Claude Code to the widget, and a matching uninstall command that removes only what it added.

**Why this priority**: Without connection nothing updates, but the widget is still demonstrable without it.

**Independent Test**: Run install against a sample settings file with pre-existing content; verify the connection entries appear and existing content is unchanged; run uninstall and verify the original content is restored.

**Acceptance Scenarios**:

1. **Given** a Claude settings file with other hooks and options, **When** install runs, **Then** those are preserved and the new connection entries are added.
2. **Given** install already ran, **When** it runs again, **Then** no duplicate entries are created.
3. **Given** no settings file exists, **When** install runs, **Then** one is created.
4. **Given** the connection is installed, **When** uninstall runs, **Then** only entries added by this product are removed.
5. **Given** the settings file is not valid JSON, **When** install runs, **Then** it stops with a clear error and leaves the file untouched.

---

### User Story 3 - Unobtrusive, traffic-light-like widget (Priority: P3)

The widget looks like a small vertical traffic-light housing with two round lights, floats above other windows, can be dragged anywhere, stays out of the Dock, and can be quit from a right-click menu.

**Why this priority**: Polish that makes the widget pleasant to live with.

**Independent Test**: Launch the app, verify its appearance, drag it, quit via menu.

**Acceptance Scenarios**:

1. **Given** the widget is running, **When** the user drags it, **Then** it moves and remembers its position on next launch.
2. **Given** the widget is running, **When** the user right-clicks it, **Then** a menu offers Quit.
3. **Given** the widget is running, **Then** it does not appear in the Dock and stays above other windows.

### Edge Cases

- Session ends normally: a session-end signal returns the widget to green. If Claude is interrupted (e.g. Esc) no signal is sent, so the 10-minute stale timeout applies.
- Claude pauses to ask for permission or input: a notification signal turns the light green ("needs you").
- Multiple Claude sessions at once: red stays lit while at least one session is working; green only when none are.
- A session working for a very long time with no signals (crash): a working state older than 10 minutes with no new signal is treated as stale and reverts to green.
- Signals arrive before the widget is running: they are not lost fatally; the widget reads the latest state at launch.
- Malformed or empty signal data is ignored without crashing.
- Signal sender must never block or slow Claude, even if the widget is not running.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The widget MUST show exactly three lights, red, yellow and green, with exactly one lit at a time. (Amended: yellow added for background agents; originally two lights.)
- **FR-002**: Red MUST be lit while any Claude session is working (whether or not a background agent is also running); yellow MUST be lit when no session is working but a background agent is still running; green MUST be lit otherwise.
- **FR-003**: A prompt submission or tool-start signal MUST mark a session as working; a finish, stop or session-end signal MUST mark it not working.
- **FR-004**: The widget MUST track sessions independently and aggregate them per the edge case above.
- **FR-005**: A working session with no signal for 10 minutes MUST be treated as not working.
- **FR-006**: The widget MUST update within 1 second of a signal.
- **FR-007**: The signal sender MUST complete in well under 100 ms, never fail Claude's flow, and work whether or not the widget is running.
- **FR-008**: An install command MUST add the connection to the user's Claude settings non-destructively and idempotently; an uninstall command MUST remove only its own entries.
- **FR-009**: Install MUST refuse to modify an unparseable settings file.
- **FR-010**: The widget MUST float above other windows, be draggable, persist its position, hide from the Dock, and offer Quit.
- **FR-011**: Ignore malformed signals.
- **FR-012**: Lit lights MUST glow visibly distinct from dim lights (not colour alone: lit lights are also noticeably brighter).
- **FR-013**: A background agent (subagent) MUST count as running from its start signal until its stop signal. Tool calls made by a subagent MUST NOT mark the main Claude as working.
- **FR-014**: A background agent with no signal for 10 minutes MUST be treated as stopped, so a lost stop signal can't leave the light yellow.

### Key Entities

- **Session**: one Claude conversation, identified by an id, with a working/not-working state and a last-signal time.
- **Signal**: an event (working-started, tool-started, finished, session-ended) tied to a session.
- **Light State**: red or green, derived from all sessions.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The correct light is shown within 1 second of a state change in 100% of test cases.
- **SC-002**: Install followed by uninstall leaves a user's settings file byte-for-byte semantically identical to the original.
- **SC-003**: Running install twice yields the same result as once.
- **SC-004**: The signal sender adds under 100 ms to any Claude action.
- **SC-005**: A user can go from download to a working indicator with two commands.

## Assumptions

- macOS 13 or later; the app is built and run from the command line without an IDE project.
- The user uses Claude Code, which supports lifecycle hooks.
- The widget and Claude run on the same machine as the same user; no network exposure is needed.
- Single-user, personal tool; no accounts, telemetry or sounds in v1.
