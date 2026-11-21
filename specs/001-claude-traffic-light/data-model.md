# Data Model
- **Signal**: `event: working|idle`, `sessionID: String`, `timestamp: Date`. Parsed from hook JSON (`hook_event_name`, `session_id`).
- **Session file** `<dir>/<sessionID>.json`: `{"state":"working"|"idle","updated":<unix seconds>}`.
- **SessionTracker**: `[sessionID: (state, updated)]`; `light(now:)` -> `.red` if any working and `now - updated < 600`, else `.green`.
- Transitions: working events -> working; Stop/SessionEnd -> idle (SessionEnd removes the file).
