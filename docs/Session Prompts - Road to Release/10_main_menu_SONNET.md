# Task 10 — Main menu scene
**Tier**: 2 → Sonnet | **Depends on**: 09 (settings panel exists to link)

---

<goal>
Build the title screen. The game currently boots straight into the hub (verified). Required for any storefront release.
</goal>

<context>
- Spec: `docs/release_pipeline.md` → "Main Menu" section.
- Buttons: Continue (default focus when a save exists; disabled/hidden otherwise), New Game, Settings (opens task 09's panel), Credits (scene exists if task 04 ran; otherwise stub the button and note it), Quit.
- Save presence: ask `ProgressionManager` whether a save exists. New Game over an existing save requires a confirmation dialog before clearing.
- Aesthetic: hub panel style (C_CARD/C_AMBER/C_BORDER) + Minifantasy UI Overhaul pack (`assets/minifantasy/Minifantasy_UI _Overhaul_v1.0`); game title text — check `assets/fonts` for the display font.
- Boot flow: change the main scene in `project.godot` to the menu; Continue/New Game route to the hub scene. Trace how hub.tscn currently initializes so menu-first boot doesn't break autoload assumptions (managers may assume run-from-hub state).
- First-boot fast path (design-audit D4, `docs/design_audit_2026-07-06.md` §5.1): when NO save exists, New Game routes STRAIGHT into the first run (default character), skipping the hub — a new player should meet the hub after their first death/extraction, when its stations mean something. Returning players keep the normal menu → hub flow.
- Show the version string bottom-corner (read from project.godot config/version; add it if absent).
- CLAUDE.md rules: MCP tools for scenes; 3× viewport text sizing; keyboard focus navigation must work (groundwork for controller task 20).
</context>

<requirements>
- Boot → menu → hub flows clean with and without an existing save; New Game confirmation cannot be triggered accidentally.
- Quit works on desktop.
- No autoload errors in the output log when booting to menu instead of hub.
</requirements>

<output_format>
Menu scene + script + project.godot main-scene change, grouped conventional commit. Screenshot of the menu in the summary.
</output_format>
