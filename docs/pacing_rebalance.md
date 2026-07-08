# Pacing Rebalance — Deliberate Combat Pass

**Date:** 2026-06-23 (pass 1), 2026-07-07 (pass 2)
**Goal:** Slow moment-to-moment combat so positioning matters and shots are
readable — **without** `Engine.time_scale` (animations stay crisp). This is a
pure data/tuning pass on the things that *move and fire*. Fire rate / attack
speed / combo cancel windows / animation fps are intentionally left alone
(slower movement already increases time-on-target; the combo layer's feel was
tuned at current tempo).

Pass 2 (Ben, 2026-07-06: "we can be even more methodical") turns the same
levers again by a further ~×0.8–0.85 on top of pass 1's values. Roster grew to
10 characters (Ravager, Whisper, Deadeye added since pass 1) — all 10 got the
same treatment, spread and ordering preserved.

This file is the shared reference for the follow-up pacing tasks (2.1 / 3.1 / 4.1).

> **Dash:** the Spacebar dash — the player's tool to reclaim mobility against the new
> slower bases — is documented in [dash.md](dash.md) (constants + the modifier-driven
> stat keys `dash_speed` / `dash_cooldown` / `dash_charges` for Task 3.1).

---

## The levers (where to tune from now on)

| System | Lever | File | Pass 1 | Pass 2 |
|--------|-------|------|-------:|-------:|
| Player base move speed | per-character `base_move_speed` | `data/characters.gd` | see table | see table |
| Player default move speed (safety) | `_base_stats.move_speed` | `scripts/entities/player.gd` | 66 (orig 120) | **54** |
| Enemy move speed | `MOVE_SPEED_SCALE` (one global ×) | `scripts/entities/enemy.gd` | 0.6 | **0.5** |
| Player projectile speed | `PLAYER_PROJECTILE_SPEED_SCALE` | `scripts/systems/projectile_manager.gd` | 0.65 | **0.55** |
| Enemy projectile speed | `ENEMY_PROJECTILE_SPEED_SCALE` | `scripts/systems/projectile_manager.gd` | 0.6 | **0.5** |
| Screen-fill rate | `base_spawn_interval` | `scripts/managers/enemy_spawn_manager.gd` | 4.5 (orig 3.5) | **5.25** |
| Fire Familiar cruise speed | `FLY_SPEED` | `scripts/entities/fire_familiar.gd` | 75 (unchanged pass 1) | **62** |
| Blood Elemental cruise speed | `WALK_SPEED` | `scripts/entities/blood_elemental.gd` | 55 (unchanged pass 1) | **45** |

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
- **Enemies are relatively faster than the player** (pass 1: enemy ×0.6 vs player
  ~×0.55, ratio ≈1.09; pass 2: enemy ×0.5 vs player ~×0.45 off the *original*
  bases, ratio ≈1.11 — same margin preserved). This is deliberate: it keeps
  closing pressure up so the longer spawn interval and slower absolute speeds
  don't make waves trivially kiteable. Reaction time scales with *absolute*
  speed (everything is slower → more time to read), while kite threat scales
  with the *ratio* (slightly higher → positioning matters more).
- **Dash is untouched on purpose (pass 2).** `DASH_DURATION`/`dash_speed` in
  `player.gd` and the ChainFactory/SkillFactory combo-lunge displacement
  distances are unchanged. At a slower base pace the dash becomes *relatively*
  more powerful — that's the intended payoff for the earned mobility tool, not
  a bug. Only revisit if playtesting shows dash now trivializes all threats.
- **Pets keep pace with the new bases.** Fire Familiar / Blood Elemental use
  their own constant-speed locomotion with a catch-up multiplier (the
  established pet standard — see CLAUDE.md). Their cruise speeds were rescaled
  ×~0.82/0.83 alongside the player so they don't visibly outrun their owner.

---

## Player — per-character base move speed

Pass 1 rescaled ~×0.55 off the original design values. Pass 2 (2026-07-07) turns
the same lever a further ~×0.8–0.85 off the pass-1 values, rounded clean, ordering
+ spread preserved (Shade fastest, Warden slowest). Ravager, Whisper, and Deadeye
were added to the roster after pass 1 and are folded into the same tiers here.

| Character | Orig | Pass 1 | Pass 2 | × (p1→p2) |
|-----------|----:|----:|----:|--:|
| The Warden    |  96 |  58 | **48** | 0.83 |
| The Ravager   |   — |  62 | **52** | 0.84 |
| The Drifter   | 120 |  66 | **54** | 0.82 |
| The Herald    | 120 |  66 | **54** | 0.82 |
| The Spark     | 126 |  70 | **58** | 0.83 |
| The Cursed    | 126 |  70 | **58** | 0.83 |
| The Deadeye   |   — |  70 | **58** | 0.83 |
| The Scavenger | 132 |  72 | **60** | 0.83 |
| The Whisper   |   — |  78 | **64** | 0.82 |
| The Shade     | 144 |  80 | **66** | 0.83 |

**The Cursed** carries a Blood Pact +20% move-speed `bonus`: effective speed
**58 × 1.2 = 70** (pass 1: 84, orig: 151). Still the fastest character by
effective speed — expert-tier, not sluggish (70 > Shade's base 66).

---

## Enemies — global ×0.5 (design values unchanged in the factories)

Effective `base_move_speed` after the global scale (before per-spawn difficulty
scaling, which still adds its small +10%/difficulty on top):

| Enemy | Design | Effective ×0.6 (pass 1) | Effective ×0.5 (pass 2) |
|-------|------:|------:|------:|
| fodder           |  25 | 15.0 | 12.5 |
| swarmer          |  72 | 43.2 | 36.0 |
| brute            |  36 | 21.6 | 18.0 |
| caster           |  24 | 14.4 | 12.0 |
| stalker          |  72 | 43.2 | 36.0 |
| guardian         |  25 | 15.0 | 12.5 |
| herald           |  42 | 25.2 | 21.0 |
| carrier          | 108 | 64.8 | 54.0 |
| warped_fodder    |  33 | 19.8 | 16.5 |
| warped_swarmer   |  84 | 50.4 | 42.0 |
| warped_brute     |  36 | 21.6 | 18.0 |
| warped_caster    |  24 | 14.4 | 12.0 |
| cave_fodder      |  80 | 48.0 | 40.0 |
| cave_swarmer     | 110 | 66.0 | 55.0 |
| cave_brute       |  38 | 22.8 | 19.0 |
| cave_bat         | 145 | 87.0 | 72.5 |
| cave_raider      |  95 | 57.0 | 47.5 |
| cave_skirmisher  | 130 | 78.0 | 65.0 |
| warped_colossus (miniboss) | 18 | 10.8 | 9.0 |
| heart_of_the_deep (final boss) | 13 | 7.8 | 6.5 |

The fastest swarm units (cave_bat 72.5, cave_skirmisher 65, cave_swarmer 55) still
out-pace or match a mid-tier player, so kiting them remains a real choice.

---

## Projectiles — travel speed only (range unchanged)

### Player weapons (×0.55, was ×0.65) — `data/weapons.gd` values are unchanged; scale is at spawn

| Weapon | `projectile_speed` | Effective (×0.65) | Effective (×0.55) | Notes |
|--------|------:|------:|------:|-------|
| Hurled Steel      | 400 | 260 | 220 | range still 1200px |
| Frost Scattergun  | 340 | 221 | 187 | short-range shotgun reach preserved (~231px) |
| Warden's Repeater | 380 | 247 | 209 | range still ~1330px |
| Spark's Pistol    | 440 | 286 | 242 | range still ~1320px |
| Herald's Call     | 360 | 234 | 198 | range still ~1080px |

All still clear the 340px spawn ring comfortably (slowest, Frost Scattergun at
187px/s, closes that gap in under 2s).

*Ember Beam (instant raycast), Void Mortar (artillery marker) and Lightning Orb
(orbit) don't use ProjectileManager travel speed and are unaffected.*

### Enemy projectiles (×0.5, was ×0.6)

| Source | `speed` | Effective (×0.6) | Effective (×0.5) |
|--------|------:|------:|------:|
| Caster bolt              |  90 |  54 |  45 |
| Warped Caster void burst |  80 |  48 |  40 |
| Colossus shockwave ring  | 140 |  84 |  70 |
| Heart nova burst         | 160 |  96 |  80 |
| Heart void spit          | 210 | 126 | 105 |

---

## Spawn cadence

`base_spawn_interval` 3.5 → 4.5 (pass 1) → **5.25** (pass 2, ~+17% more between
waves, ~+50% total off the original 3.5). The effective interval still divides
by `difficulty × channel_pressure`, and per-phase `PHASE_SPAWN_MULT` still
multiplies wave counts — only the base period stretched. `enemies_per_spawn`
(2), `max_enemies` (90) and all phase multipliers are unchanged.

---

## Pets — cruise speed rescaled to keep pace

Own constant-speed locomotion with catch-up (the established pet standard),
not lerp-glued to the player — see CLAUDE.md. Rescaled ×~0.82/0.83 alongside
the player bases:

| Pet | Lever | Pass 1 | Pass 2 |
|-----|-------|-------:|-------:|
| Fire Familiar    | `FLY_SPEED`  (`fire_familiar.gd`)   | 75 | **62** |
| Blood Elemental  | `WALK_SPEED` (`blood_elemental.gd`) | 55 | **45** |

`CATCHUP_MULT` (1.8 / 1.6) is a multiplier on top of these, so the catch-up
boost scales proportionally without a separate edit.

## Dash and combo displacement — intentionally unchanged

`dash_speed` (520 px/s), `DASH_DURATION` (0.16s), and the ChainFactory/
SkillFactory combo-lunge/blink displacement distances (Spark's teleport blink,
Ravager's deadly dash, etc.) are **not** touched by this pass. These are
absolute, not derived from the move-speed bases, so slowing the bases makes
dash and lunges *relatively* more powerful — that's the intended payoff for
the earned mobility tool, not an oversight. Displacement distances are
position-based (not speed-based) so they don't interact with the travel-speed
scales at all. Revisit only if Ben's playtest shows dash now trivializes
threats it shouldn't (e.g. dashing clean through swarm pressure that used to
require positioning).

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
  not sluggish? Check Warden (slowest, 48) and Shade (fastest, 66) at the extremes.
- **Enemy closing speed** — do swarms still apply pressure and punish standing still,
  or has the slowdown made them trivially kiteable? Watch cave_bat / skirmisher / swarmer
  at their new effective speeds (72.5 / 65 / 55).
- **Projectile readability** — can enemy bolts (caster, warped burst, boss nova/spit)
  now be seen and dodged on reaction at ×0.5? Are player shots still satisfying to
  land at ×0.55, or do they now feel floaty?
- **Screen-fill rate** — does the arena populate at a readable pace at the 5.25s base
  interval, or too empty / too full?
- **Pet keep-up** — do Fire Familiar (62) and Blood Elemental (45) still visibly
  keep pace with their slower owners, or do they now lag noticeably even with
  catch-up boost?
- **Dash power level** — with dash speed/distance unchanged against a further-slowed
  base, does the dash now trivialize threats it shouldn't (e.g. dashing clean
  through swarms that used to require real positioning)? If so, flag it — dash
  was deliberately left untouched this pass, not an oversight.

If any axis is off, turn the matching lever in the table above and re-test.
