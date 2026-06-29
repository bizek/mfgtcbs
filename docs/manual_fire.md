# Manual Fire — Cursor-Aimed Shooting (default)

**Date:** 2026-06-24
**Context:** Companion to the [pacing rebalance](pacing_rebalance.md) / [dash](dash.md) work.
Manual cursor-aimed firing is now the **default** combat model — hold left-click and aim, so
you control *when* and *where* you shoot. Legacy auto-fire (aim at nearest enemy) remains as a
debug-panel toggle for A/B comparison. Pairs with a planned overall range nerf so aiming
matters.

---

## Default & toggle

**Manual fire is the default** (`player.gd::manual_fire_mode = true`) — the game now expects
you to hold left-click and aim. To compare against the old behavior, open the **F1 debug
panel** and click **"Auto Fire: OFF / ON"** (sits under God Mode); turning Auto Fire **ON**
restores legacy auto-fire (aim at nearest enemy). The button is green while auto-fire is on.

> A dedicated hotkey (e.g. F8) was avoided on purpose: **F8 is Godot's "Stop" shortcut** and
> would kill the running game. The toggle lives in the debug panel instead.

Wiring: the panel's `_cmd_toggle_auto_fire` calls `player.gd::toggle_manual_fire()` (which
flips `manual_fire_mode` and resets the shared attack timer so the first shot after a switch
is prompt) and labels the button by the *inverse* (auto = not manual). Because the debug
panel only exists when `GameManager.debug_mode` is true, **in normal play there is no way to
leave manual fire** — it is the shipped behavior, not a debug-only tool.

---

## Behaviour (`scripts/entities/player.gd`)

When `manual_fire_mode` is on, `_physics_process` calls `_tick_manual_fire` instead of
`behavior_component.tick`:

- **Hold** the `fire` action (**left mouse**, already bound in `project.godot`) to shoot.
  Release to stop — this is the point: you can stop firing while repositioning or dashing.
- Shots fire at the weapon's **normal cadence** — the manual path reuses
  `BehaviorComponent.auto_attack_timer` and `get_effective_attack_interval()`, so
  attack-speed / cooldown mods apply identically to auto-fire.
- Aim follows the **mouse cursor**, locked in at swing-start (`_pending_aim_dir`). How each
  weapon class resolves that aim (`_resolve_manual_targets`):

  | Class | Aim resolution | Damage |
  |-------|----------------|--------|
  | **Projectile / Spread** | Phantom marker (`_aim_marker`) parked at the cursor stands in as `attack_target`; the spawn pipeline fires the cone toward it. | Projectile collision along the cursor line. |
  | **Beam** | Real enemies inside a thin corridor along the aim ray (in front, within `BEAM_HALF_WIDTH≈20px`), nearest first, capped at the live `projectile_count`. Beam VFX draws straight down the cursor line to max range (reads even on a whiff). | `DealDamage` to the corridor enemies. |
  | **Melee** | Real enemies within `max_range` and inside the swing arc (`arc_degrees`, size-mod scaled) centred on the cursor direction. Arc VFX swings toward the cursor. | `DealDamage` to the arc enemies. |
  | **Artillery** | Phantom marker at the cursor; `GroundZoneEffect` detonates there. | AoE finds real enemies near the impact point. |

  The marker only ever stands in where the pipeline reads *position* (projectile direction,
  ground-zone placement) — never as a damage target (it has no health/faction). Beam/melee
  feed **real enemies** into `DealDamage`.
- **Whiffs render**: with no enemies in the line/arc, the beam/swing still plays toward the
  cursor (`_on_auto_attack` / `_fire_pending_shot` skip the auto re-aim when manual), it just
  deals no damage.
- **Suppressed during CC** (same `is_disabled()` gate as auto-fire).
- **Orbit weapons** (Lightning Orb) are skipped — they're passive; the orbs self-manage
  their hits and there's nothing to trigger manually.
- The aim marker is freed in `reset_stats()` and dies with the scene; no per-shot churn
  (one reused node).

---

## If this becomes permanent

The toggle is deliberately thin so it can graduate into a real feature:
- Promote the debug-panel toggle to a settings/option (or just make manual the default and
  delete the auto-fire branch).
- Full manual aiming already covers **all** weapon classes (projectile, spread, beam, melee,
  artillery) — directional resolution lives in `player.gd::_resolve_manual_targets`.
- Pairs naturally with an overall **range nerf** (shorter `max_range` on weapons) so aiming
  actually matters.

---

## VERIFY — playtest

Ben to open Godot and check (player.gd compiles clean via the live validator):
- **Toggle** — open F1 panel, click "Manual Fire"; the button turns green when ON.
- **Projectile** (Drifter / Hurled Steel) — shots fly toward the cursor, hit enemies in path.
- **Beam** (Ember Beam) — beam fires straight down the cursor line; enemies in the corridor
  take damage; firing into empty space still draws the beam.
- **Melee** (Arcane Blade) — swing arc points at the cursor; enemies in that arc get hit.
- **Artillery** (Void Mortar) — blast lands at the cursor, not the nearest enemy.
- **Tempo** — releasing left-click stops firing; holding resumes at the right cadence.
- **Dash interplay** — you can hold fire through a dash, or release to reposition silently.
