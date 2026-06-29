# Pacing Rebalance — Deliberate Combat Pass

**Date:** 2026-06-23
**Goal:** Slow moment-to-moment combat by ~40–50% so positioning matters and shots
are readable — **without** `Engine.time_scale` (animations stay crisp). This is a
pure data/tuning pass on the things that *move and fire*. Fire rate / attack speed
were intentionally left alone (slower movement already increases time-on-target).

This file is the shared reference for the follow-up pacing tasks (2.1 / 3.1 / 4.1).

> **Dash:** the Spacebar dash — the player's tool to reclaim mobility against the new
> slower bases — is documented in [dash.md](dash.md) (constants + the modifier-driven
> stat keys `dash_speed` / `dash_cooldown` / `dash_charges` for Task 3.1).

---

## The levers (where to tune from now on)

| System | Lever | File | New value |
|--------|-------|------|-----------|
| Player base move speed | per-character `base_move_speed` | `data/characters.gd` | see table |
| Player default move speed (safety) | `_base_stats.move_speed` | `scripts/entities/player.gd` | 66 (was 120) |
| Enemy move speed | `MOVE_SPEED_SCALE` (one global ×) | `scripts/entities/enemy.gd` | **0.6** |
| Player projectile speed | `PLAYER_PROJECTILE_SPEED_SCALE` | `scripts/systems/projectile_manager.gd` | **0.65** |
| Enemy projectile speed | `ENEMY_PROJECTILE_SPEED_SCALE` | `scripts/systems/projectile_manager.gd` | **0.6** |
| Screen-fill rate | `base_spawn_interval` | `scripts/managers/enemy_spawn_manager.gd` | 4.5 (was 3.5) |

### Design choices worth knowing

- **Enemy speed is a single global scale**, applied once at `setup_from_enemy_def`
  (`base_move_speed = def.move_speed * MOVE_SPEED_SCALE`). The per-type design
  values in the `data/factories/enemies/*` factories are **unchanged** — the spread
  the designer authored is preserved; only the global multiplier moves. Tune the one
  constant to rescale every enemy at once.
- **Projectiles slow travel but keep range.** The scale is applied to velocity/speed
  at spawn only; `max_range` is untouched, so a shot still covers the same distance —
  it just takes longer to get there. No weapon lost its reach.
- **Percentages stay percentages.** Every move-speed buff/slow is a `bonus`/`percent`
  modifier (`overdrive`, `adrenaline_rush`, `velocity`, `assassin`, `fortress`, the
  Herald aura, `chilled`, Cursed's +20%). Only the *bases* moved, so all of those
  still scale correctly off the new bases.
- **Enemies are relatively faster than the player** (enemy ×0.6 vs player ~×0.55).
  This is deliberate: it keeps closing pressure up so the longer spawn interval and
  slower absolute speeds don't make waves trivially kiteable. Reaction time scales
  with *absolute* speed (everything is slower → more time to read), while kite
  threat scales with the *ratio* (slightly higher → positioning matters more).

---

## Player — per-character base move speed

Rescaled ~×0.55, rounded clean, ordering + spread preserved (Shade fastest, Warden
slowest). Warden kept a touch above ×0.55 so the tank doesn't feel sluggish.

| Character | Old | New | × |
|-----------|----:|----:|--:|
| The Warden    |  96 | **58** | 0.60 |
| The Drifter   | 120 | **66** | 0.55 |
| The Herald    | 120 | **66** | 0.55 |
| The Spark     | 126 | **70** | 0.56 |
| The Cursed    | 126 | **70** | 0.56 |
| The Scavenger | 132 | **72** | 0.55 |
| The Shade     | 144 | **80** | 0.56 |

**The Cursed** carries a Blood Pact +20% move-speed `bonus`: effective speed
**70 × 1.2 = 84** (was 151). Still the fastest non-Shade by effective speed —
expert-tier, not sluggish.

---

## Enemies — global ×0.6 (design values unchanged in the factories)

Effective `base_move_speed` after the global scale (before per-spawn difficulty
scaling, which still adds its small +10%/difficulty on top):

| Enemy | Design | Effective ×0.6 |
|-------|------:|------:|
| fodder           |  25 | 15.0 |
| swarmer          |  72 | 43.2 |
| brute            |  36 | 21.6 |
| caster           |  24 | 14.4 |
| stalker          |  72 | 43.2 |
| guardian         |  25 | 15.0 |
| herald           |  42 | 25.2 |
| carrier          | 108 | 64.8 |
| warped_fodder    |  33 | 19.8 |
| warped_swarmer   |  84 | 50.4 |
| warped_brute     |  36 | 21.6 |
| warped_caster    |  24 | 14.4 |
| cave_fodder      |  80 | 48.0 |
| cave_swarmer     | 110 | 66.0 |
| cave_brute       |  38 | 22.8 |
| cave_bat         | 145 | 87.0 |
| cave_raider      |  95 | 57.0 |
| cave_skirmisher  | 130 | 78.0 |
| warped_colossus (miniboss) | 18 | 10.8 |
| heart_of_the_deep (final boss) | 13 | 7.8 |

The fastest swarm units (cave_bat 87, cave_skirmisher 78, cave_swarmer 66) still
out-pace or match a mid-tier player, so kiting them remains a real choice.

---

## Projectiles — travel speed only (range unchanged)

### Player weapons (×0.65) — `data/weapons.gd` values are unchanged; scale is at spawn

| Weapon | `projectile_speed` | Effective | Notes |
|--------|------:|------:|-------|
| Hurled Steel      | 400 | 260 | range still 1200px |
| Frost Scattergun  | 340 | 221 | short-range shotgun reach preserved (~231px) |
| Warden's Repeater | 380 | 247 | range still ~1330px |
| Spark's Pistol    | 440 | 286 | range still ~1320px |
| Herald's Call     | 360 | 234 | range still ~1080px |

*Ember Beam (instant raycast), Void Mortar (artillery marker) and Lightning Orb
(orbit) don't use ProjectileManager travel speed and are unaffected.*

### Enemy projectiles (×0.6)

| Source | `speed` | Effective |
|--------|------:|------:|
| Caster bolt              |  90 |  54 |
| Warped Caster void burst |  80 |  48 |
| Colossus shockwave ring  | 140 |  84 |
| Heart nova burst         | 160 |  96 |
| Heart void spit          | 210 | 126 |

---

## Spawn cadence

`base_spawn_interval` 3.5 → **4.5** (~+29% between waves). The effective interval
still divides by `difficulty × channel_pressure`, and per-phase `PHASE_SPAWN_MULT`
still multiplies wave counts — only the base period stretched. `enemies_per_spawn`
(2), `max_enemies` (90) and all phase multipliers are unchanged.

---

## Arena sanity

Arena bounds are ±800 × ±600; enemies spawn on a 340px radius around the player.
All player weapons retain their pre-rebalance range (range was decoupled from the
speed scale), so every weapon can still reach the spawn ring. No coordinate or
bounds logic changed.

---

## VERIFY — playtest required (feel-critical, only observable when rendered)

These are numeric changes; whether they *feel* right can only be judged in-engine.
Ben to open Godot and playtest, watching specifically:

- **Player kite speed** — does repositioning feel deliberate but still responsive,
  not sluggish? Check Warden (slowest, 58) and Shade (fastest, 80) at the extremes.
- **Enemy closing speed** — do swarms still apply pressure and punish standing still,
  or has the slowdown made them trivially kiteable? Watch cave_bat / skirmisher / swarmer.
- **Projectile readability** — can enemy bolts (caster, warped burst, boss nova/spit)
  now be seen and dodged on reaction? Are player shots still satisfying to land?
- **Screen-fill rate** — does the arena populate at a readable pace, or too empty / too full?

If any axis is off, turn the matching lever in the table above and re-test.
