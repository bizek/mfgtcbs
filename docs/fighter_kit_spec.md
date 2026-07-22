# Fighter Kit Spec — first worked combat-chain example

> **Status: SHIPPED, and the numbers here are stale.** The Fighter kit was built and all 11 other kits
> followed the same shape. Tuning constants below have been superseded by the live values in
> `data/factories/chain_factory.gd` (e.g. the light-chain cancel window widened 0.55 → **0.75** after
> the 2026-07-04 feel test). Read this for the *shape* of a kit; read `chain_factory.gd` for numbers.

**Original status:** Design locked 2026-06-24 (Ben + Claude). Numbers below are **provisional — tune after first
in-engine test.** This is the reference implementation for the manual combo-chain combat layer; every
other class's kit is authored the same way (see "How this composes").

**Character:** `The Drifter` → class **Fighter** (True Heroes III). Grounded sword-and-board bruiser,
crisp on-press melee, infinite flowing light chain, an RMB heavy branch, and two neutral specials.

**Built entirely on existing systems** — `AbilityDefinition` + `ChoreographyDefinition`/`Phase`/`Branch`
(Hans's pipeline), `EffectDispatcher`, `DisplacementEffect`, `CharacterSpriteFactory`,
`WeaponData`/`WeaponFactory`. The only new *engine* pieces are two typed condition Resources
(`ConditionInputBuffered`, `ConditionInputHeld`) and the player-side choreography executor (T1.1/T2.2).

---

## 1. Input scheme

| Input | From neutral (idle/move) | Mid-combo (cancel window open) |
|---|---|---|
| **LMB tap** | start chain → **Attack** | advance light chain (Attack→Swirl→Tempest→loop) |
| **LMB hold** | Attack, then flow into **Whirlwind** channel | from Attack/Swirl, hold → **Whirlwind** |
| **RMB tap** | **Uppercut** (launcher — flings mobs away) | — |
| **RMB hold** | **Taunt** (shield smack → shockwave AoE) | — |
| **RMB** (mid-combo) | — | **Cataclysm** finisher (gated: must be at Swirl or later) |

Entry is **always Attack first** on the initial LMB press, preserving the crisp on-press hit; holding
then flows into Whirlwind. A quick click is a clean single strike, a held click becomes the spin.

---

## 2. Combo graph

```
PRESS LMB ─→ Attack (crisp hit ~frame 1)
              │
              ├─ tap LMB ─→ Swirl ──┬─ tap LMB ─→ Tempest ─→ loops back to Attack ∞
              │                     └─ RMB ─────→ Cataclysm ─→ idle      (gate: depth ≥ Swirl)
              │
              └─ HOLD LMB ─→ Whirlwind (Swirl loops, ticks AoE while held) ─→ release → idle

NEUTRAL RMB tap  ─→ Uppercut (knockback launcher, i-frame-gated fling)
NEUTRAL RMB hold ─→ Taunt    (shield smack → expanding shockwave AoE)
```

Each non-terminal light node is a `ChoreographyPhase`: play anim → fire effects on `hit_frame` →
`exit_type="wait"` opens the cancel window → `branches` (first match wins) decide the next node →
`default_next=-1` (no input → return to idle).

---

## 3. Animation sheets (real dims, provisional timing)

All sheets are **32×32, 4 rows (facings) × N frame columns**; slice **row 0 (front)**, `flip_h` for
left/right (matches `docs/character_overhaul_design.md` §1). Filenames keep the pack's "Figther"
misspelling. `_Effect.png` overlays are frame-matched and render on top via the VFX-layer system.

| Canonical anim | Sheet (rel. to Fighter folder) | Frames | fps (prov.) | hit_frame (prov.) | cancel_open→close (frames) | Effect overlay |
|---|---|---|---|---|---|---|
| `light_1` (`attack`) | `General_Animations/Figther_Attack.png` | 4 | 20 | 1 | 2 → end+grace | `Figther_Attack_Effect.png` |
| `light_2` (`swirl`) | `Special_Animations/Swirl/Figther_Swirl.png` | 4 | 18 | 1 | 2 → end+grace | `Figther_Swirl_Effect.png` |
| `light_3` (`tempest`) | `Special_Animations/Tempest/Figther_Tempest.png` | 7 | 18 | 3 | 4 → end+grace | `Figther_Tempest_Effect.png` |
| `heavy_cataclysm` | `Special_Animations/Cataclysm/Figther_Cataclysm.png` | 12 | 18 | 7 | — (terminal) | `Cataclysm_Effect.png` |
| `skill_uppercut` | `Special_Animations/Uppercut/Figther_Uppercut.png` | 4 | 18 | 1 | — (terminal) | `Figther_Uppercut_Effect.png` |
| `skill_taunt` | `Special_Animations/Taunt/Figther_Taunt.png` | 9 | 16 | 5 | — (terminal) | (no `_Effect`; spawn shockwave VFX) |

**Whirlwind** reuses the `swirl` sheet looping (no new sheet).

> **Slicing-path note (feeds T0.2 / T2.1):** specials live in `Special_Animations/<Name>/` subfolders,
> not the `General_Animations/` `dir` the current `sprite` schema assumes. `CharacterSpriteFactory`
> joins `dir + file`; the convention must allow a per-anim **sub-path or absolute `res://` path** so
> specials slice without a separate `dir` per anim. Simplest: let an `anims` entry's sheet string be a
> path relative to the pack root (e.g. `Special_Animations/Swirl/Figther_Swirl.png`) and point `dir` at
> the Fighter root. Decide in T0.2; implement in T2.1.

---

## 4. Node-by-node spec

Damage values are **provisional**, expressed against the equipped weapon's `damage` (Fighter starts
`Arcane Blade`, base 42). All hits route through `EffectDispatcher` → `DamageCalculator` (8-step) like
every other ability — single hit per enemy per phase (engine default; do not multi-tick).

### Light chain

- **Attack** (`light_1`) — frontal arc. `DealDamageEffect`/`AreaDamageEffect`, range ~55px, arc ~170°
  (reuse the existing melee arc resolution in `player.gd`/`weapon_factory.gd`). Damage ≈ weapon ×1.0.
  - `exit_type="wait"`, cancel window ~frames 2→end +grace.
  - `branches` (first match wins):
    1. `ConditionInputHeld(light_attack, min=0.18s)` → **Whirlwind**
    2. `ConditionInputBuffered(light_attack, window)` → **Swirl**
    3. `ConditionInputBuffered(heavy_attack, window)` → **Cataclysm** *(gate not yet met from Attack — see gate note)*
  - `default_next=-1` → idle.

- **Swirl** (`light_2`) — 360° spin. `AreaDamageEffect`, radius ~60px, damage ≈ weapon ×0.8.
  - cancel window, `branches`: held→Whirlwind, LMB→**Tempest**, RMB→**Cataclysm**; default→idle.

- **Tempest** (`light_3`) — wider spin finisher. `AreaDamageEffect`, radius ~80px, damage ≈ weapon ×1.2.
  - On end: **loop back to Attack** (`default_next` = Attack's phase index) so a held rhythm flows
    infinitely; RMB in its window → Cataclysm.

### Whirlwind (held channel)

- animation = `swirl` **looping**, `exit_type="wait"`, `wait_duration` ≈ 0.22s (one rotation = tick).
- `hit_frame` fires `AreaDamageEffect` radius ~60px, damage ≈ weapon ×0.35 **per tick**.
- `branches`: `ConditionInputHeld(light_attack)` → **itself** (keep spinning, tick again);
  `default_next=-1` on release → idle.
- This is the same tick-loop shape `GroundZoneEffect` already uses — proven pattern.

### Cataclysm (heavy finisher — gated)

- **Gate:** only reachable when combo depth ≥ Swirl (i.e. branch offered from Swirl/Tempest, not from
  Attack). Enforced by which phases carry the heavy branch.
- animation = `heavy_cataclysm` (12f), `hit_frame` ~7 (the slam). `AreaDamageEffect`, radius ~110px,
  damage ≈ weapon ×2.0. `Cataclysm_Effect` overlay = the shockwave VFX. Terminal → idle.

### Neutral specials (standalone `AbilityDefinition`s, `mode="Manual"`)

- **Uppercut** (`skill_uppercut`) — neutral RMB **tap**. `hit_frame` ~1: `DealDamageEffect`
  (≈ weapon ×0.6) **+ `DisplacementEffect`** knockback that **flings enemies away** from the player.
  - ⚠️ **Knockback MUST be i-frame-gated** (CLAUDE.md) or enemies pinball. Use the displacement system's
    existing gating; do not roll a new push.
  - Cooldown via `AbilityComponent` (provisional ~2.5s).
- **Taunt** (`skill_taunt`) — neutral RMB **hold**. `hit_frame` ~5 (the shield smack): expanding
  **shockwave** `AreaDamageEffect` (radius ~90px, damage ≈ weapon ×1.0). No `_Effect` sheet ships, so
  spawn a ring VFX via `PlayerVfxHelper` (reuse a shockwave/nova cue). Cooldown ~5s.

---

## 5. Two new typed conditions (engine — small, mirror existing pattern)

Both follow the `ChoreographyBranch.condition: Resource` typed-condition pattern (like boss
`ConditionHpThreshold`). Evaluated by the choreography executor during `exit_type="wait"`.

```gdscript
class_name ConditionInputBuffered extends Resource
@export var action: String = ""          ## InputMap action, e.g. "light_attack"
@export var within_window: float = 0.0   ## seconds; 0 = use phase cancel metadata

class_name ConditionInputHeld extends Resource
@export var action: String = ""
@export var min_duration: float = 0.0    ## action held continuously ≥ this → true
```

They read the input buffer / held-duration from the input layer (T2.3). **Order matters** in a phase's
`branches` array — list `ConditionInputHeld` before `ConditionInputBuffered` so a held LMB resolves to
Whirlwind, not a tap-advance.

---

## 6. How this composes (zero new core scripts)

1. **Sprites** — add the special anims to `CharacterData.ALL["The Drifter"].sprite.anims` using the
   extended entry shape from T0.2 (`[sheet, frames, fps, {hit_frame, cancel_open, cancel_close}]`), with
   the sub-path handling from §3. `CharacterSpriteFactory.build()` (extended in T2.1) slices them.
2. **Chain** — a `chain_factory` (T2.4) builds the light-chain `AbilityDefinition` whose `choreography`
   is the Attack→Swirl→Tempest(→loop) graph with the branches above, plus the Whirlwind and Cataclysm
   phases. Hits are `DealDamageEffect`/`AreaDamageEffect`.
3. **Specials** — `skill_factory` (T2.5) builds Uppercut and Taunt as `AbilityDefinition`s on the
   `SkillComponent`, bound to RMB tap / RMB hold.
4. **Weapon** — `Arcane Blade` in `WeaponData.ALL` declares this light/heavy chain (T2.6 additive keys);
   equipping it wires these chains as the player's melee. Default class chain falls back if unarmed.
5. **VFX** — each node lists its `_Effect` sheet in `AbilityDefinition.vfx_layers` (one-shot overlay on
   the caster); Taunt uses a `PlayerVfxHelper` shockwave since it has no `_Effect` sheet.

No edits to `EffectDispatcher`, `DamageCalculator`, the component classes, or the existing weapon
behaviors. New content is data + the two condition Resources + the shared executor.

---

## 7. Balance watch-list & future hooks

- **#1 watch: Whirlwind uptime.** Held spin + infinite tap-loop + forgiving windows = very high AoE
  uptime. Per-tick damage is deliberately low (×0.35); if still dominant, add a ramp, soft cap, or a
  light resource cost. Revisit after test.
- **Cancel windows are forgiving** for v1 (easy to chain). Tighten if combos feel mindless.
- **Cataclysm gate** (depth ≥ Swirl) is the intended early-game balance. **Future legendary mod —
  "Cataclysm Unbound":** removes the gate (RMB → Cataclysm from neutral/Attack) and **scales its radius**
  up. Authored later via `ModData` + `ModComboFactory`; logged here as a chase-item idea.
- **Mods enhance nodes**, not replace them: auras, extra swings, extra projectiles on Tempest, bleed on
  Whirlwind, bigger shockwave on Taunt — each hangs off a node's `effects` through the existing mod
  system. Build the graph first, mods second.

## 8. To confirm after first test (open)

- Real hit_frames per sheet (provisional above) — scrub each special in-editor and set the impact frame.
- Whether Uppercut should also grant a small **i-frame / hop on the player** (dodge-cancel feel) or stay
  a pure enemy-fling. Ben leaning: test fling-only first.
- Direction-row order (rows 1/3 side facings) if/when we go beyond row 0 + `flip_h`.
