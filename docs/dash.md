# Dash — Spacebar Mobility Tool

**Date:** 2026-06-23
**Context:** Companion to the [pacing rebalance](pacing_rebalance.md). The global pace
was slowed ~45%, so the dash is the player's primary tool to reclaim burst mobility —
snappy and fluid, balanced by charges + a per-charge cooldown.

---

## Input

| Action | Binding | File |
|--------|---------|------|
| `dash` | **Spacebar** (KEY_SPACE / keycode 32) + controller bottom face button (JoyButton 0) | `project.godot` `[input]` |

> The vestigial Spacebar binding on the `fire` action was removed — `fire` is never
> polled (weapons auto-fire via `BehaviorComponent`), so Space is now dash-only. Mouse
> left-click remains on `fire` for any future manual-fire use.

---

## Mechanic (`scripts/entities/player.gd`)

A short, high-speed **impulse** in the current movement direction (falls back to last
facing, then `Vector2.RIGHT`, when no input is held). Snappy = high speed, short
duration, gentle ease-out tail. Grants i-frames for the whole window, then snaps back to
normal movement with no floaty residual.

### Fixed feel constants (not modifier-driven)

| Constant | Value | Meaning |
|----------|------:|---------|
| `DASH_DURATION` | `0.16` s | Active dash window. |
| `DASH_EASE_OUT` | `0.25` | Tail deceleration (0 = constant speed, 1 = stops dead). Velocity = `dash_speed * (1 - 0.25 * p²)`, `p` 0→1 over the dash. |

At `dash_speed` 520 over 0.16 s with this ease curve the dash covers **~76–80 px** —
tuned against the new base move speeds (Warden 58 … Shade 80 px/s).

### Modifier-driven stats — exposed in `_base_stats`, read via `get_stat()`

**These are the keys Task 3.1 / the passive tree should target.** Each is a base "add"
modifier registered by `CharacterFactory.build_base_modifiers`, so a `ModifierDefinition`
(`add` for flat, `bonus` for percent) on these tags scales the dash with zero new code.

| Stat key | Base | Notes |
|----------|-----:|-------|
| `dash_speed` | `520.0` | Impulse speed (px/s) at dash start. Snapshotted per dash. A `+%` is a `bonus` modifier. |
| `dash_cooldown` | `1.6` s | Per-charge refill time. A "-20% cooldown" upgrade = a `bonus` modifier of `-0.2`. |
| `dash_charges` | `1.0` | Max charges. Clamped to `int >= 1` at read (`_max_dash_charges()`). A "+1 charge" = an `add` modifier of `1`. |

Example upgrades:
- **+1 charge:** `ModifierDefinition` → `target_tag="dash_charges"`, `operation="add"`, `value=1`.
- **-20% cooldown:** `target_tag="dash_cooldown"`, `operation="bonus"`, `value=-0.2`.
- **+15% distance:** `target_tag="dash_speed"`, `operation="bonus"`, `value=0.15`.

### Charges + cooldown

- N charges (default 1). A dash consumes one; at 0 charges, dashing is blocked.
- Charges refill **one at a time** on `dash_cooldown` (`_tick_dash_cooldown`, ticked in
  `_physics_process`). Consuming a charge starts the refill clock if it isn't already
  running — it is never reset mid-refill.

### Guards & safety

- **Crowd control:** dashing is blocked while `status_effect_component.is_disabled()` or
  `is_movement_disabled()` — the same `move_blocked` flag the movement block uses.
- **I-frames:** the dash sets `is_invulnerable = true` for its duration (the existing
  `take_damage` guard at the `is_invulnerable` check), cleared when the dash ends. This is
  separate from the hit `_iframes_timer` / `IFRAME_DURATION` path, so it doesn't disturb
  hit-flash logic.
- **Physical phase-through:** i-frames only block *damage* — the player body still
  physically collides with enemy bodies (player mask bit 2 ↔ enemy mask includes player
  layer 1), so without this a dash bumps to a halt on the first enemy. `_set_dash_phasing`
  toggles the player's enemy-collision mask bit (2) **and** its own player-layer bit (1)
  off for the dash window so the dash slips through the crowd, restored on dash end /
  `_reset_dash_state`. Walls are **not** on these bits, so phasing never lets the player
  clip through walls.
- **Forces respect i-frames:** `apply_knockback` now early-returns on `is_invulnerable`
  too, so a dash can't be pinballed by knockback mid-window.
- **No residual velocity:** on dash end, velocity snaps to the current input-driven target
  (or zero), so movement resumes cleanly without a floaty slide.

### Reset

`_reset_dash_state()` (full charges, timers cleared, `is_invulnerable=false`) runs on
spawn (`_ready`) and on run restart (`reset_stats()`).

---

## VFX cue (`scripts/systems/player_vfx_helper.gd::spawn_dash_cue`)

Lightweight, no pooling — a handful of transient self-freeing nodes per dash:
- 3 fading afterimage ghosts of the player's current frame, trailing the dash direction.
- A one-shot `CPUParticles2D` dust puff at the launch point.
- A small camera offset nudge in the dash direction (`player.gd::_spawn_dash_vfx`).

---

## VERIFY — playtest required (feel-critical, only observable rendered)

Ben to open Godot and test:
- **Snappiness** — does the dash read as a crisp burst, not a glide? Tail blends cleanly?
- **I-frame timing** — does the dash phase through enemy contact for its window, no hit/knockback?
- **Charge refill cadence** — does ~1.6 s per charge feel right? (multi-charge once an upgrade grants it)
- **CC block** — confirm dash does nothing while stunned / movement-disabled.
