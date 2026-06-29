# Task 24 — Steam integration (GodotSteam, cloud saves, achievement sync)
**Tier**: 2 → Sonnet | **Depends on**: 21 (achievement_unlocked signal) + 23 (build pipeline). Requires Ben to have a Steamworks App ID first — confirm before starting; if no App ID yet, stop and say so.

---

<goal>
Integrate Steamworks via GodotSteam per `docs/release_pipeline.md` → "Distribution → Steam": init, achievement sync, cloud saves. Store-page assets and depot setup are Ben's side; this task is the code.
</goal>

<context>
- Use the GodotSteam GDExtension (not the custom-build editor) for Godot 4.6 — check godotsteam.com for the current 4.6-compatible release and install into `addons/`.
- The game must run PERFECTLY without Steam (itch build, dev runs): wrap everything in an `is_steam_available()` guard — init failure or missing DLL = silent feature-off, never a crash or error spam.
- Achievements: subscribe to `achievement_unlocked(id)` (task 21); map internal ids → Steam API names (table in the integration script); `Steam.set_achievement()` on unlock; `Steam.store_stats()` once at session end (quit + run-end), not per unlock.
- Cloud saves: Steam Auto-Cloud syncs `user://` via Steamworks config (dashboard side, Ben's) — code side only needs a doc note; do NOT implement manual Cloud API.
- `steam_appid.txt` with the App ID for local testing; gitignore it if Ben prefers the ID private (ask via a TODO note, default: commit it — App IDs aren't secret).
</context>

<requirements>
- Steam init on boot (after settings load), callbacks pumped (`Steam.run_callbacks()` per frame or timer), graceful no-Steam path verified by running without Steam running.
- Achievement sync verified in Steam's dev environment if the App ID + Steamworks achievement defs exist; otherwise verify the code path with logging and list the dashboard setup steps for Ben (achievement API names must match the id table).
- Update `docs/release_pipeline.md` Steam checklist: mark code items done, enumerate Ben's dashboard items (depots, Auto-Cloud paths, achievement defs, build upload via steamcmd).
</requirements>

<output_format>
Addon + integration script + doc updates, grouped conventional commits. Summary: what's verified vs what awaits Ben's dashboard work.
</output_format>
