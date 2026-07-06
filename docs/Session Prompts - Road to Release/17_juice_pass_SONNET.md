# Task 17 — Juice pass: hit-stop, shake, boss intro, extraction fanfare
**Tier**: 2 → Sonnet | **Depends on**: 09 (screen-shake intensity setting exists). Parallel-safe with 16.

---

<goal>
A focused game-feel pass on the moments that sell the game. Audit what exists first (VFXManager, CombatFeedbackManager, player_vfx_helper already provide damage numbers and some feedback), then add the missing layer of impact.
</goal>

<context>
- Read `docs/engine_reference.md` VFX/feedback sections; inspect `scripts/systems/vfx_manager.gd`, `combat_feedback_manager.gd`, `player_vfx_helper.gd` and the camera setup in the player/arena scenes before adding anything — extend existing systems, never parallel-build.
- All shake routes through one camera-shake utility that multiplies by the settings intensity (task 09's `Settings` multiplier; 0% must mean literally zero motion).
- CLAUDE.md gameplay rule applies: knockback/forces gated on i-frames (no pinball).
</context>

<requirements>
Implement, each individually toggleable in code for tuning:
- **Hit-stop**: 2–4 frame freeze on player crits and on elite/boss kills (Engine.time_scale dip or per-entity pause — pick the approach that can't soft-lock if interrupted; restore via timer that survives scene pause). **P1, non-negotiable (design-audit D6): combo FINISHER impacts get the strongest hit-stop + shake in the game — the finisher landing in a crowd is the game's pitch moment. Wire it off the per-kit finisher markers (see passive_tree_spec.md §6.2), not hardcoded phase names.**
- **Screen shake**: small on player damage taken, medium on AoE/explosive kills, large on boss telegraph impacts — capped so chained explosions don't compound past the max.
- **Boss intro**: on `boss_should_spawn`, a short beat — camera nudge toward spawn, name banner ("Heart of the Deep" style, 3× scaled font), brief enemy-spawn suppression window if trivially available (skip if it needs new spawn-manager surgery).
- **Extraction fanfare**: portal extraction complete gets a distinct flash/zoom beat before the success screen.
- **Kill pop**: enemies flash white + slight scale pop on death frame if not already present (check enemy.gd first).
- Everything respects the screen-shake/flash settings; nothing triggers during pause; 60fps held at horde scale (verify with the performance monitor).
</requirements>

<output_format>
Code changes in existing systems, grouped conventional commits. Summary: list each effect, its trigger, and its tuning constants (file:line) so Ben can adjust by feel.
</output_format>
