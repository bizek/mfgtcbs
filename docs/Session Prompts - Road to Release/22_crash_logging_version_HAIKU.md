# Task 22 — Crash logging + version display
**Tier**: 1 → Haiku | **Depends on**: 10 (menu exists to show version). Parallel-safe with 21/23.

---

Two small release-safety items from `docs/release_pipeline.md` ("Post-Release Safety"):

1. **Version string**: set `config/version="1.0.0"` in project.godot (if absent). Display it in the main menu corner and the settings panel footer, read via `ProjectSettings.get_setting("application/config/version")` — never hardcoded. (Main menu may already show it from task 10 — verify, don't duplicate.)

2. **Crash/error log**: a small autoload or GameManager addition that captures script errors and writes `user://crash.log` (timestamp, version, error text, current scene, selected character). Godot 4 has no `error_logged` tree signal — use what's actually available: a custom `Logger` via `OS` is not exposed in GDScript, so implement pragmatically: wrap risky lifecycle points (save/load, run start/end, scene transitions) in explicit try-style guards that log failures, plus log unclean shutdown (write a `session_open` marker on boot, clear on clean quit; on next boot, marker present → log "previous session ended uncleanly" with last-known state). Keep the log capped (rotate at ~200KB).

Constraints: typed GDScript per CLAUDE.md; no per-frame cost; works in release export (no debug-only APIs).

Output format: code + grouped conventional commit. Verify by forcing one logged failure and one unclean-shutdown detection; quote the resulting crash.log lines in the summary.
