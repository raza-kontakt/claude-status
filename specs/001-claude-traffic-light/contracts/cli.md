# Contracts
**claude-light-hook [event]**: stdin = Claude hook JSON. Writes session file. Exit code always 0. Silent.
**claude-light-install install|uninstall [--settings PATH] [--hook PATH]**: default settings `~/.claude/settings.json`. Exit 0 ok, 1 on invalid JSON (file untouched). Idempotent.
**Env**: `CLAUDE_LIGHT_DIR` overrides state directory.
