# Task 12 — Settings phase 2: rebinding + accessibility
**Tier**: 2 → Sonnet | **Depends on**: 09. Best run after 19 (controller bindings) so rebinding covers joypad too — acceptable to defer to post-M6.

---

<goal>
Complete the settings menu with controls rebinding and accessibility options, per `docs/release_pipeline.md` → "Settings Menu".
</goal>

<context>
- Settings autoload + panel exist from task 09; add Controls and Accessibility sections in its established pattern.
- InputMap actions: enumerate from project.godot at runtime (`InputMap.get_actions()`, filter out `ui_*` built-ins unless deliberately rebindable).
- Accessibility consumers: damage numbers render via `CombatFeedbackManager` (`scripts/systems/combat_feedback_manager.gd`); screen flash effects — search `scripts/systems/vfx_manager.gd` and `player_vfx_helper.gd` for flash usage; status-effect colors for the color-blind palette live wherever statuses define display colors (check `data/factories/status_factory.gd` and HUD code).
</context>

<requirements>
- Controls: list every gameplay action with its current binding; click-to-rebind (capture next input, Esc cancels), conflict detection (warn + swap or reject), reset-to-defaults button. Persist overrides in settings.cfg and re-apply on boot. If task 19 has run, rebinding must handle joypad bindings too.
- Accessibility: damage numbers on/off; screen flash intensity 0–100%; text size Small/Normal/Large (scale factor applied to HUD/UI font sizes — verify legibility at 3× viewport on all three); deuteranopia-safe alternate palette for status-effect colors (swap the color table, not per-usage hacks).
- All options persist and apply without restart where feasible; note any that require restart in the UI.
- Verify each accessibility toggle visually in a debug run.
</requirements>

<output_format>
Settings panel + consumer changes, grouped conventional commits. Before/after screenshots for the color-blind palette in the summary.
</output_format>
