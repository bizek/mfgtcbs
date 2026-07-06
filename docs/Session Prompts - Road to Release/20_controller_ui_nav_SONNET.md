# Task 20 — Controller UI navigation, hot-swap glyphs
**Tier**: 2 → Sonnet | **Depends on**: 19

---

<goal>
Make every menu and hub panel fully navigable on controller — required for the Steam controller badge and Deck Verified. Spec: `docs/release_pipeline.md` → "Controller Support Audit" (UI + hot-swap sections).
</goal>

<context>
- Surfaces: main menu (task 10), settings (09/12), pause menu, all hub panels (Armory, Workshop, Research, Roster, Records, Launch, and the Passive Tree panel from task 28 — its scrollable node grid needs focus-follows-scroll care), level-up screen, merchant shop, insurance panel, game-over and extraction-success screens.
- Godot focus system does most of the work: ensure every interactive Control has sensible `focus_neighbor_*`/focus mode, an initial focus is grabbed when each panel opens, and ScrollContainers follow focus (`ensure_control_visible`).
- Scene changes via MCP tools; many panels build rows dynamically in script — set focus config in code where rows are generated.
- Glyph hint: a small bottom-bar label per screen ("Ⓐ Confirm Ⓑ Back" / "Enter Confirm, Esc Back") that switches based on the last input device (track keyboard-vs-joypad from `_input`; switch on `Input.joy_connection_changed` too).
</context>

<requirements>
- D-pad + left stick navigate every listed surface; confirm/back buttons activate/close; no focus traps (test: can you always reach every control and always back out?).
- Level-up screen: upgrade cards focusable, selection obvious (focus stylebox), confirm picks.
- Hub: panel switching on shoulder buttons or an equivalent discoverable scheme.
- Hot-swap: unplugging mid-run doesn't crash; glyph labels switch within a second of device change.
- Verify the release-doc acceptance criteria: full run + full hub + settings, controller only. If no physical controller available, list Ben's manual verification checklist.
</requirements>

<output_format>
Focus wiring + glyph bar, grouped conventional commits. Summary: per-surface checklist with pass/fail.
</output_format>
