# Task 29 — Pacing second pass: even more methodical
**Tier**: 2 → Sonnet | **Depends on**: none. Run BEFORE task 18 (balance tuning) and ideally before the class mod/level-up rework playtests (31–33).

---

<goal>
A second deliberate-pacing pass on top of the 2026-06-23 rebalance: slow the moment-to-moment
game a further **~15–20%** so combat reads as methodical — positioning, combo commitment, and
dodge decisions all deliberate. Ben's direction (2026-07-06): "we can be even more methodical."
</goal>

<context>
- `docs/pacing_rebalance.md` is the lever map and the shared reference — this pass turns the SAME
  levers again and updates that doc. Do not invent new levers or use `Engine.time_scale`.
- **Scope decision (locked with Ben):** movement, projectile travel, and spawn cadence only.
  Attack speed, combo cancel windows, and animation fps are UNTOUCHED — the combo layer's feel
  was tuned at current tempo and slower movement already increases time-on-target.
- Roster is now 10 characters (`data/characters.gd`) — the original 7 plus Ravager (62),
  Whisper (78), Deadeye (70). All get the same treatment, spread and ordering preserved
  (Shade fastest → Warden slowest).
</context>

<requirements>
Turn each lever ~×0.8–0.85, rounded to clean values, and record old → new in pacing_rebalance.md:
- Per-character `base_move_speed` (all 10) + the `_base_stats.move_speed` safety default in player.gd.
- `MOVE_SPEED_SCALE` (enemy.gd): 0.6 → ~0.5. Keep the enemy:player ratio slightly above 1 as
  before — closing pressure must survive the slowdown (re-derive the ratio in the doc).
- `PLAYER_PROJECTILE_SPEED_SCALE`: 0.65 → ~0.55 and `ENEMY_PROJECTILE_SPEED_SCALE`: 0.6 → ~0.5
  (projectile_manager.gd). Travel speed only; ranges stay decoupled, verify weapons still reach
  the 340px spawn ring comfortably.
- `base_spawn_interval` (enemy_spawn_manager.gd): 4.5 → ~5.25.

Systems that must be checked against the new bases (they have their own absolute speeds):
- **Dash** (`docs/dash.md`, player.gd constants): deliberately LEAVE dash speed/distance unchanged
  — at a slower base pace the dash becomes relatively more powerful, which is the design intent
  (dash is the earned mobility tool). State this explicitly in the doc. Only flag it for Ben if
  playtest shows dash now trivializes all threats.
- **Pets** (fire_familiar.gd / blood_elemental.gd): they use own constant-speed locomotion with
  player catch-up (CLAUDE.md pet standard). Rescale their cruise/catch-up speeds proportionally
  (~×0.8–0.85) so they don't visibly outrun their owner.
- **Class dashes / combo displacement phases** (teleport blink, deadly dash, combo lunges in
  ChainFactory): displacement distances are position-based, not speed-based — verify none now
  overshoot relative to enemy spacing; adjust only if something is clearly broken.
- Percent modifiers (statuses, passives, level-up upgrades) are untouched — they scale off bases.

Update `docs/pacing_rebalance.md` in place: new values in every table (all 10 characters, all
enemies at the new scale, projectile tables), a short "Second pass (2026-07-XX)" changelog
section, and a refreshed VERIFY playtest checklist for Ben (kite feel at the extremes,
swarm pressure, projectile readability, screen-fill, pet keep-up, dash power level).
</requirements>

<output_format>
Data/constant changes + updated pacing_rebalance.md, grouped conventional commit. Summary: the
old → new lever table and the playtest checklist. This is feel-critical — Ben playtests in Godot
before it's called done.
</output_format>
