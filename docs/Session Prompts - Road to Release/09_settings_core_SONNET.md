# Task 09 — Settings system core
**Tier**: 2 → Sonnet | **Depends on**: none (M3 entry point)

---

<goal>
Build the settings system from scratch — none exists (verified in `docs/release_pipeline.md` → "Settings Menu"). This is a blocking v1 item and a dependency for the main menu (task 10) and audio system (task 14).
</goal>

<context>
- Read `docs/release_pipeline.md` "Settings Menu" section — it is the spec.
- This pass covers: Audio (master/music/SFX sliders + mute), Display (fullscreen, vsync, screen-shake intensity 0–100%), and persistence. Rebinding + accessibility are task 12 — design the panel so those tabs/sections can be added without rework.
- No audio buses exist yet. Create Master/Music/SFX buses now (Godot audio bus layout) so sliders control real buses; task 14's audio system will play into them.
- Persistence: `ConfigFile` at `user://settings.cfg`, fully separate from the progression save. Apply on startup before the first scene needs them.
- Screen-shake intensity needs a consumer: expose a multiplier (e.g. on a small `Settings` autoload) that the juice pass (task 17) and any existing camera shake will read.
- UI: match hub panel aesthetic (`scripts/ui/hub_panel_base.gd`, C_CARD/C_AMBER/C_BORDER palette). Accessible from the pause menu (`scripts/ui/pause_menu.gd`) and later from the main menu.
- CLAUDE.md rules: MCP tools for scenes, 3× viewport text sizing, ScrollContainer SHOW_AS_NEEDED.
</context>

<requirements>
- New `Settings` autoload (registered in project.godot): load/save/apply, typed getters, `setting_changed` signal.
- Sliders move bus volumes in real time (use `linear_to_db`; slider 0 = mute, not -∞ jump glitches).
- Fullscreen + vsync apply immediately and persist.
- Defaults: sensible out-of-box values; missing/corrupt cfg falls back to defaults without crashing.
- Verify: change every setting, restart the game, confirm persistence; delete settings.cfg, confirm clean defaults.
</requirements>

<output_format>
Autoload + settings UI scene + pause-menu hook, grouped conventional commits. Note in the summary which bus names tasks 14/15 should target.
</output_format>
