# Research
- **Decision**: Hooks `UserPromptSubmit`, `PreToolUse`, `PostToolUse` => working; `Stop`, `Notification` (waiting on user), `SessionEnd` => idle. Rationale: PostToolUse keeps freshness for the stale timer. Hook stdin JSON contains `session_id` and `hook_event_name`.
- **Decision**: Per-session files, atomic write (temp + rename). Rationale: no daemon/port, no write races between sessions, survives app not running. Alternative: localhost HTTP — rejected (blocks when app down, port conflicts).
- **Decision**: App polls directory every 250 ms. Rationale: simplest, robust vs DispatchSource edge cases; negligible cost.
- **Decision**: Stale = working file with timestamp older than 600 s => idle; idle files older than 1 day are pruned.
- **Decision**: Installer tags its hook commands with the binary name `claude-light-hook` so uninstall can identify its own entries; hook entries use matcher-group format `{"matcher":"","hooks":[{"type":"command","command":"<path> <event>"}]}`.
- **Decision**: Event name also passed as argv[1] as fallback if stdin lacks `hook_event_name`.
- **Decision**: App bundle via script (Info.plist with LSUIElement=true) plus NSApp `.accessory` policy.
