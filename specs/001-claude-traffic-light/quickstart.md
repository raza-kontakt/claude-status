# Quickstart
1. `swift build -c release && swift test`
2. `scripts/build-app.sh` -> `build/ClaudeLight.app`; `open build/ClaudeLight.app`
3. `.build/release/claude-light-install install`
4. Simulate: `echo '{"session_id":"x","hook_event_name":"UserPromptSubmit"}' | .build/release/claude-light-hook` -> red; with `Stop` -> green.
