# Task 08 — Character hub surfaces: portraits, roster, launch panel
**Tier**: 2 → Sonnet | **Depends on**: 06 + 07

---

<goal>
Surface the overhauled characters in the hub: portraits on the roster panel, animated/correct preview on character select and launch panel, updated unlock presentation. This is the marketing face of the overhaul — it should look deliberate, not retrofitted.
</goal>

<context>
- Design contract: `docs/character_overhaul_design.md` (portrait plan per character, §2).
- Portrait assets: `assets/minifantasy/Minifantasy_Portrait_Generator_Graphical_Assets_v1.0` — portraits may need to be composed from generator layers; if so, compose them once and save as textures under `assets/characters/portraits/`, don't build a runtime compositor.
- Panels: `scripts/ui/hub_roster_panel.gd`, `scripts/ui/hub_launch_panel.gd`, base class `scripts/ui/hub_panel_base.gd`. Hub player preview: `scripts/hub.gd` (currently colors a shared sprite per character — replace with the real per-character SpriteFrames from task 06).
- CLAUDE.md rules: scene changes via Godot MCP tools only; 3× viewport scaling for all text; wrap scrollable content in ScrollContainer with SHOW_AS_NEEDED; check overflow before declaring done.
</context>

<requirements>
- Roster panel: portrait + new name + class + passive copy + unlock cost per character; locked characters visually distinct (e.g. silhouette/desaturated portrait).
- Launch panel: selected character shown with name/class; hub preview character animates with its real Idle/Walk frames.
- All 7 portraits present, consistent dimensions and framing.
- Verify at full window and confirm no clipping/overflow with the longest name + longest passive description.
</requirements>

<output_format>
Assets + scene/script changes + grouped conventional commit. Include a screenshot (Godot MCP `get_editor_screenshot` or game screenshot) of the finished roster panel in your summary.
</output_format>
