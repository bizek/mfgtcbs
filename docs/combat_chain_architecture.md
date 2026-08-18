# Combat Chain Architecture (T1.1)

> **Status: SHIPPED.** Written as a design doc 2026-06-24; the design was built and all 12 class kits
> ship on it. The architecture below is **current and authoritative** — it is how the combat layer
> actually works, and it remains the rule for any new kit or chain work.
>
> Two things in §0 are now **history, not present tense**, and are kept because the reasoning still
> explains the design:
> - §0 describes the executor as living on `enemy.gd`. Decision 5 was carried out — the shared
>   `ChoreographyRunner` (`scripts/components/choreography_runner.gd`) exists and is what the
>   **player** runs. `enemy.gd` still holds its own in-place copy; that migration is deferred.
>   Line numbers cited in §0 are from the June 2026 `enemy.gd` and have drifted.
> - "Choreography has zero content today" was true when written. It is emphatically not true now:
>   four bosses plus every player kit's light/heavy/channel graph and Q/E skills run on it. Refactors
>   in this area are **no longer low-risk**.
>
> Reconciled 2026-07-21. Implementation entry points: `data/factories/chain_factory.gd`,
> `data/factories/skill_factory.gd`, `scripts/systems/combat_input_buffer.gd`,
> `data/resources/conditions/condition_input_{buffered,held}.gd`.

**Original status:** Design, 2026-06-24 (Claude, architecture hat). The keystone design for the manual combo-chain
combat layer. Implements the model in `docs/fighter_kit_spec.md` on top of the existing engine. Build
tasks T2.2–T2.6 follow this; if any of them tempts you toward a new FSM / `AttackData` / `Hitbox`, stop —
it's wrong per this doc.

**Grounded on the real executor**, not the docs: `scripts/entities/enemy.gd` lines 96–101 (state),
285–311 (`_process` branch/timer loop), 536–556 (`_on_frame_changed` hit-frame firing), 558–565
(`_on_animation_finished`), 582–743 (`_start_choreography` … `_end_choreography`).

---

## Decisions at a glance

| # | Decision | Why |
|---|---|---|
| 1 | Combo graph = **one `AbilityDefinition` with a multi-branch `ChoreographyDefinition`** (one phase per node) | It's exactly what `ChoreographyBranch` arrays already do; zero new sequence machinery |
| 2 | **Two new condition Resources** — `ConditionInputBuffered`, `ConditionInputHeld` — evaluated by the host, ordered held-before-buffered | Mirrors existing `ConditionHpThreshold`/`ConditionEntityCount`; the only branch-vocabulary the combo needs |
| 3 | Held channel (Whirlwind) = a `"wait"` phase whose `ConditionInputHeld` branch points **at itself**; release falls through to `default_next=-1` | Re-entry replays anim + re-fires `hit_frame` → ticking, using machinery that already exists |
| 4 | **Crisp on-press is free** — set an early `hit_frame` (0–1). Effects fire on `frame_changed` during playback; the player runs the executor, NOT its `_fire_pending_shot` swing-end path | The executor already fires on `sprite.frame == hit_frame` |
| 5 | Executor location = **extract a shared `ChoreographyRunner`** consumed by both `enemy.gd` and `player.gd`, delegating condition-eval + target-resolution + effect-firing to a tiny host interface | De-dupes ~150 lines; choreography has **zero content today**, so refactoring `enemy.gd` is low-risk |
| 6 | Input layer = buffer (`was_buffered`) **+ held-duration tracker** (`held_for`); conditions read it | Tap-vs-hold needs both; pure data, no FSM |
| 7 | A character carries its graph as data — `CharacterData.sprite` anims + a `chain_factory`-built ability; no new top-level type | Reuse `CharacterData.ALL` |

---

## 0. What already exists (ground truth — do not redesign)

The choreography executor on `enemy.gd` is complete and behavior-correct:

- **State**: `_choreography`, `_choreography_ability`, `_choreography_phase_index`, `_choreography_timer`,
  `_choreography_targets`, plus `_current_attack_anim` / `_hit_frame_fired`. `set_process` is **off**
  except during `"wait"` / `"displacement_complete"` phases.
- **Phase entry** (`_enter_choreography_phase`, enemy.gd:603): sets `is_untargetable`/`is_invulnerable`
  from the phase, optional `retarget`, optional `displacement`, **fires effects immediately if
  `hit_frame < 0`**, plays `phase.animation` (with `telegraph_speed_scale`), then arms the exit:
  `"wait"` → `_choreography_timer = wait_duration` + `set_process(true)`; `"anim_finished"` → waits for
  the animation_finished signal.
- **Per-frame** (`_process`, enemy.gd:296–311): during a `"wait"` phase, decrements the timer and **every
  frame evaluates each `branch` — first passing branch wins → `_enter_choreography_phase(branch.next_phase)`**;
  on timeout → `_on_choreography_phase_exit()` → enters `phase.default_next`.
- **Hit firing** (`_on_frame_changed`, enemy.gd:540–549): when `sprite.frame == phase.hit_frame` (guarded
  by `_hit_frame_fired`), calls `_execute_choreography_phase_effects` → `EffectDispatcher.execute_effects`.
- **Branch eval** (`_evaluate_choreography_branch`, enemy.gd:709): currently type-switches
  `ConditionEntityCount` / `ConditionHpThreshold`, returns `false` for anything else. **This is the
  extension seam.**
- **Interrupt**: stun/freeze calls `_end_choreography()` (enemy.gd:327–330). Cleanup resets all flags and
  plays `idle`.

**Three facts this hands us for free:**
1. Branch evaluation already lives exactly where the cancel window is (`"wait"` phases). Our combo nodes
   are `"wait"` phases; their `wait_duration` *is* the cancel window.
2. Early-`hit_frame` firing already exists — crisp on-press needs no new mechanism.
3. Re-entering the same phase index resets `_hit_frame_fired` and replays — that's a tick. Channels fall
   out of the existing machinery.

---

## 1. Combo-graph-as-choreography

A character's light combo is **one `AbilityDefinition`** (`mode = "Manual"`) whose `choreography.phases`
is the graph — one `ChoreographyPhase` per node. Non-terminal nodes use `exit_type = "wait"` with
`wait_duration` = the cancel window, and carry their branches. Terminal nodes use `default_next = -1`
(end → idle) or point back to an earlier index (loop).

### The Fighter graph as a concrete phase array

Phase indices: `0 Attack · 1 Swirl · 2 Tempest · 3 Whirlwind · 4 Cataclysm`.

```
phase[0] Attack       anim="light_1"  hit_frame=1  exit="wait" wait=<cancelwin>
  branches (held before buffered):
    ConditionInputHeld(light_attack, 0.18)      -> 3   # hold → Whirlwind
    ConditionInputBuffered(light_attack, win)   -> 1   # tap  → Swirl
  default_next = -1                                     # nothing → idle
  # note: NO heavy branch here — Cataclysm gate (depth ≥ Swirl)

phase[1] Swirl        anim="swirl"    hit_frame=1  exit="wait" wait=<cancelwin>
  branches:
    ConditionInputHeld(light_attack, 0.18)      -> 3   # hold → Whirlwind
    ConditionInputBuffered(light_attack, win)   -> 2   # tap  → Tempest
    ConditionInputBuffered(heavy_attack, win)   -> 4   # RMB  → Cataclysm  (gate met)
  default_next = -1

phase[2] Tempest      anim="tempest"  hit_frame=3  exit="wait" wait=<cancelwin>
  branches:
    ConditionInputBuffered(heavy_attack, win)   -> 4   # RMB  → Cataclysm
    ConditionInputBuffered(light_attack, win)   -> 0   # tap  → loop to Attack ∞
  default_next = 0                                      # auto-loop to Attack on whiff? (see note)

phase[3] Whirlwind    anim="swirl"(loop) hit_frame=1 exit="wait" wait=<one rotation>
  branches:
    ConditionInputHeld(light_attack, 0.0)       -> 3   # still held → re-enter (tick again)
  default_next = -1                                     # released → idle

phase[4] Cataclysm    anim="heavy_cataclysm" hit_frame=7 exit="anim_finished"
  default_next = -1                                     # terminal → idle
```

> **Tempest `default_next` note (a feel decision, provisional):** `-1` ends the combo on whiff; `0` makes
> the light line truly auto-loop even without a press. `fighter_kit_spec.md` says "loops back to Attack" —
> implement as the **tap branch → 0** (player must keep pressing to loop), `default_next = -1`. An
> always-on auto-loop reads as a toggle, not a combo. Tune after test.

**The gate** (Cataclysm only from depth ≥ Swirl) is expressed purely by *which phases carry the heavy
branch* — Attack(0) omits it, Swirl(1)/Tempest(2) include it. No gate code.

Neutral specials (Uppercut, Taunt) are **separate `AbilityDefinition`s** on the skill component (§7, T2.5),
not nodes in this graph — they trigger from neutral, not mid-combo.

---

## 2. Two new condition Resources + the evaluator seam

Both mirror the existing typed-condition pattern (`ChoreographyBranch.condition: Resource`):

```gdscript
class_name ConditionInputBuffered extends Resource
@export var action: String = ""          ## InputMap action, e.g. "light_attack"
@export var within_window: float = 0.0   ## seconds; 0 = use the phase's cancel metadata

class_name ConditionInputHeld extends Resource
@export var action: String = ""
@export var min_duration: float = 0.0    ## action held continuously ≥ this → true
```

**Branch ordering rule (must document in the factory):** within a phase's `branches`, list
`ConditionInputHeld` **before** `ConditionInputBuffered` for the same action, because first-passing-branch
wins (enemy.gd:300–304). Otherwise a held LMB satisfies the buffered branch and advances instead of
channeling.

**Evaluator seam.** `_evaluate_choreography_branch` (enemy.gd:709) returns `false` for unknown conditions.
Rather than teach `enemy.gd` about input (it has none), the shared runner (§5) **delegates condition
evaluation to the host**:

```gdscript
# ChoreographyRunner asks the host; host evaluates only the conditions it understands.
func _evaluate_branch(branch) -> bool:
    if not branch.condition: return true
    return host.evaluate_choreography_condition(branch.condition)
```

- **Enemy host** keeps the current `ConditionEntityCount` / `ConditionHpThreshold` logic.
- **Player host** adds `ConditionInputBuffered` (reads the input buffer + the phase's cancel window) and
  `ConditionInputHeld` (reads `held_for`). It can also keep HP/entity conditions for free.

This keeps input-coupling out of `enemy.gd` and is the **only** new branch vocabulary the combo needs.

---

## 3. Held channel (Whirlwind) and looping

A channel is a `"wait"` phase that re-enters itself while held:

- `animation = "swirl"`, **`wait_duration ≈ the Swirl anim length`** so each re-entry visually continues
  the spin (a too-short wait restarts the anim mid-spin and looks choppy — tune to anim length).
- `hit_frame = 1` → each re-entry resets `_hit_frame_fired` and fires the tick `AreaDamageEffect` once.
- branch `ConditionInputHeld(light_attack, 0.0) → self`; `default_next = -1`.

Each rotation: enter → play Swirl → tick on frame 1 → wait_duration elapses → branch checks "still held?"
→ yes: re-enter self (tick again); no: `default_next = -1` → `_end_choreography` → idle.

This reuses the exact `GroundZoneEffect` cadence (tick-per-interval) without any multi-tick addition to the
executor. (The executor fires `hit_frame` once per phase entry; re-entry *is* the tick. Do **not** try to
make a single phase multi-fire — `AbilityDefinition.hit_frames` is not read by the choreography path.)

A light **loop** (Tempest → Attack) is just a branch/`default_next` pointing back to index 0. Re-entry
resets `_hit_frame_fired`, so the looped Attack hits again. No special-casing.

---

## 4. On-press timing — crisp, and already supported

The player today fires melee on the **last** frame: `_on_auto_attack` plays `"attack"` then schedules
`_fire_pending_shot` after `frame_count/fps` (player.gd:404–410). **The combo layer must not use that
path.** Instead:

- Pressing `light_attack` **starts the combo ability's choreography immediately** through the runner.
- Phase 0 plays `light_1` from frame 0 and fires its effects on `hit_frame = 1` via the runner's
  `frame_changed` handler — i.e. ~one frame (~50 ms at 20 fps) after the click. That *is* crisp on-press.
- For an instant hit, `hit_frame = -1` fires on phase entry (enemy.gd:628–630).

So crispness is a data choice (low `hit_frame`), not new code — provided the player drives the executor,
not `_fire_pending_shot`. **Ranged auto-fire weapons keep their existing `_on_auto_attack` path
unchanged**; only melee combo characters route through the executor.

---

## 5. Executor location — shared `ChoreographyRunner`

**Verdict: extract a shared `ChoreographyRunner` (a `Node` child, like the other components), consumed by
both entities.** Rationale:

- The executor is ~150 lines of non-trivial sequencing. Mirroring it onto `player.gd` doubles the
  maintenance surface and the two copies will drift.
- It already reads only a handful of host facts: `sprite`, target resolution, displacement system,
  combat_manager, and the branch evaluator. Those become a **host interface**.
- **Refactor risk is low**: `docs/engine_reference.md` records choreography as *"Zero content"* — no boss
  data drives it yet, so re-routing `enemy.gd` through the runner can't regress live content. (Verify by
  searching for any `AbilityDefinition` that sets `choreography` — expected: none in shipped data.)

  > ⚠️ **No longer true (2026-07-21).** That verification step now returns `goblin_king_data.gd`,
  > `heart_of_the_deep_data.gd`, `warped_colossus_data.gd`, and `ancient_troll_data.gd`, plus every
  > kit graph from `chain_factory.gd` / `skill_factory.gd`. `engine_reference.md` has been corrected.
  > The `enemy.gd` → runner migration is **still open**, but it is no longer a free refactor — it now
  > has live boss behavior to regress. Prove any such change against those four bosses.

### Host interface (what the runner needs from its owner)

```gdscript
# Implemented by both player.gd and enemy.gd
func choreo_sprite() -> AnimatedSprite2D
func choreo_resolve_targets(rule: TargetingRule) -> Array      # enemy: behavior_component; player: arc/cursor melee
func choreo_fire_effects(effects: Array, targets: Array, ability: AbilityDefinition) -> void
func evaluate_choreography_condition(c: Resource) -> bool      # enemy: hp/count; player: input + hp/count
func choreo_displacement_system() -> Object                    # may be null
```

The runner owns the phase index / timer / `_hit_frame_fired` state and the `_process` loop; the host
forwards `frame_changed` and `animation_finished` to it and exposes `is_untargetable`/`is_invulnerable`
for the runner to set. `enemy.gd`'s current methods map 1:1 — the refactor is mechanical.

### Player integration specifics

- **Targets**: `choreo_resolve_targets` for the player reuses the existing arc logic
  (`_resolve_melee_targets`, player.gd:642) toward the cursor/facing, and `choreo_fire_effects` routes
  through `EffectDispatcher` exactly like `_fire_pending_shot` does (player.gd:433).
- **Anim flags**: while a combo runs, set the player's `_attack_anim_active = true` so the walk/idle logic
  (player.gd:548) doesn't clobber the combo anim; clear on `_end_choreography`. Do not fight
  `_on_sprite_animation_finished` — route `animation_finished` to the runner first.
- **Movement**: the player already keeps moving during attack anims (movement in `_physics_process` is not
  gated by `_attack_anim_active`; only the walk/idle *animation* is). Keep that — combos are mobile, and
  Whirlwind explicitly should let you reposition while spinning. (If a specific node should root the
  player, gate movement on a per-phase flag later; not needed for v1.)

---

## 6. Input contract (T2.3)

A small input layer the player host reads — **no FSM**:

```gdscript
# input buffer + held tracker (autoload or a player-owned helper)
func note_input(event)                              # called from _unhandled_input / polling
func was_buffered(action: String, within: float) -> bool
func held_for(action: String) -> float              # seconds the action has been continuously held; 0 if up
func consume(action: String)                        # clear buffered press after a branch consumes it
```

- `ConditionInputBuffered.evaluate` → `was_buffered(action, within_window>0 ? within_window : phase_cancel_window)`.
- `ConditionInputHeld.evaluate` → `held_for(action) >= min_duration`.
- Windows are data: `ChoreographyPhase.wait_duration` and the per-anim `{cancel_open, cancel_close}`
  metadata from T0.2 (`combat_convention.md`). No magic constants.
- Skill actions remain runtime-rebindable (T2.5).

Binding map for Fighter: `light_attack` = LMB (reuse/extend the existing `fire` action), `heavy_attack` =
RMB. Neutral RMB tap vs hold is disambiguated by `held_for("heavy_attack")` at the moment of a neutral
press (skill component, §7).

---

## 7. Data composition — how a character carries its kit

No new top-level type. A melee combo character composes from:

1. **`CharacterData.ALL[id].sprite.anims`** — the `light_1`/`swirl`/`tempest`/`heavy_cataclysm`/skill
   sheets with T0.2 timing metadata (`hit_frame`/`cancel_open`/`cancel_close`). `CharacterSpriteFactory`
   (extended in T2.1) slices them.
2. **`chain_factory`** (T2.4) — builds the light-combo `AbilityDefinition` (the §1 graph) from per-node
   params (anim name, hit_frame, damage, radius/arc, cancel window, branch targets). Fighter's numbers
   come from its `WeaponData`/`CharacterData`, not the factory body.
3. **`skill_factory`** (T2.5) — builds neutral specials (Uppercut, Taunt) as `AbilityDefinition`s on a
   `SkillComponent`, bound to RMB tap / RMB hold.
4. **`WeaponData`** (T2.6, additive) — a melee weapon declares the light/heavy chain it grants; equipping
   rewires which graph the runner reads; unequip restores the class default.

`player.gd` wiring: where it currently connects `behavior_component.auto_attack_requested` for ranged
auto-fire (player.gd:278), a melee-combo character instead binds `light_attack`/`heavy_attack` presses to
`runner.start(combo_ability)` and routes neutral RMB to the skill component.

---

## 8. Edge cases (all handled by phase/branch/runner — no new constructs)

| Case | Handling |
|---|---|
| Tap buffered mid-anim | press recorded by buffer; `ConditionInputBuffered` true during the `"wait"` window → advance |
| Hold vs tap | `ConditionInputHeld` listed first; `held_for ≥ min` → channel, else buffered tap → advance |
| Cancel-window timeout (whiff) | `"wait"` timer expires, no branch passed → `default_next` (−1 = idle, or loop index) |
| **Post-swing pose (recovery release)** | A node's window is 2–4× its swing on purpose (`CANCEL_WIN` 0.75s over a 0.2s body), but a one-shot body freezes on its last frame — so the runner fires `choreo_on_phase_recovery()` once the body finishes drawing AND its hit has landed, and the player hands the sprite back to walk/idle. Window, phase flags and branches all stay live; the next node reclaims the body in `choreo_on_phase_anim()`. Channel beats (self-looping or `hold_anim_on_reentry`) are excluded — their recovery *is* the next beat. Added 2026-07-29 after an audit found 25 nodes across all 12 kits freezing 0.15–0.60s each. A phase may name a locomotion **set** to recover into via `recovery_locomotion` (e.g. `"carry"` → the player plays `carry_walk`/`carry_idle` instead of `walk`/`idle`) — the Ravager's Pile Driver hoist uses this to walk the six-second hold with the pile still overhead (2026-08-17). |
| Hurt-cancel mid-combo | `player.take_damage` calls `runner.interrupt()` (forgiving v1: only on hits above a small threshold, mirroring the channel-interrupt rule at player.gd:825); runner `_end_choreography` → idle, i-frames already applied |
| Dash interrupt | `_try_dash` calls `runner.interrupt()` before starting the dash; dash i-frames/phasing already exist |
| Stun / CC | same path as enemy (enemy.gd:327): `status_effect_component.is_disabled()` → `runner.interrupt()` |
| Channel release | `ConditionInputHeld(self)` fails → `default_next = -1` → idle |
| Gated heavy | Attack(0) carries no heavy branch; only Swirl/Tempest do → Cataclysm unreachable from depth < Swirl |
| Skill interrupts combo | skill component calls `runner.interrupt()` then runs the skill's own choreography |

---

## 9. Weapon hook (→ T2.6) and Mod seam (→ T4.1), in brief

- **Weapon**: `WeaponData` gains additive `light_chain`/`heavy_chain` keys consumed by `chain_factory`;
  `WeaponFactory` gets a melee-chain branch that returns the combo `AbilityDefinition`. Ranged behaviors
  (projectile/beam/etc.) are untouched. Equip/`switch_weapon` swaps which ability the runner starts.
- **Mods** hang off each node's `effects` via the existing `ModData`/`ModComboFactory` path (the same way
  `weapon_factory.gd` appends elemental/chain/explosive effects today) — e.g. bleed on the Whirlwind tick,
  a bigger `AreaDamageEffect` radius on Cataclysm ("Cataclysm Unbound" legendary). No new mod machinery.

---

## 10. Worked walkthrough — add a melee character, files only

Goal: a character with a looping 2-hit light combo, a held channel, a gated heavy, and one neutral skill —
**no engine edits.**

1. **Sprites** — add to `CharacterData.ALL["The X"].sprite.anims`: `light_1`, `light_2`, the channel anim,
   `heavy_1`, and the skill sheet, each `[sheet_path, frames, fps, {hit_frame, cancel_open, cancel_close}]`.
2. **Combo** — call `ChainFactory.build_light_combo({ nodes:[…], loop_to:0, channel_from:["light_1","light_2"],
   heavy_from_depth:1 })`. Returns the `AbilityDefinition` with the §1-shaped `choreography`.
3. **Skill** — `SkillFactory.build(...)` for the neutral special; register on the character's
   `SkillComponent` slot (RMB-tap or a `skill_N`).
4. **Weapon** (if melee) — add `light_chain`/`heavy_chain` to its `WeaponData.ALL` entry pointing at (2).
5. **Done.** The runner, conditions, input layer, `EffectDispatcher`, and `DamageCalculator` are all
   shared. Nothing in `scripts/` changes.

Acceptance: tap-chain advances and loops; hold enters the channel and ticks; RMB from depth ≥ N triggers
the heavy and is unavailable before; hurt/dash/stun cleanly cancel.

---

## 11. Provisional / tune-after-test (carried from `fighter_kit_spec.md`)

- All hit_frames, cancel windows, `wait_duration`s, and damages are provisional — first playable test, then
  tune. Whirlwind uptime is the #1 balance watch.
- Confirm zero shipped data sets `AbilityDefinition.choreography` before refactoring `enemy.gd` (expected:
  none; choreography is currently content-free).
- Channel `wait_duration` must be tuned to the Swirl anim length so re-entry reads as a continuous spin.
- Hurt-cancel threshold (does any hit cancel, or only big ones?) — start forgiving (only hits that would
  interrupt channeling, per the existing `amount > 10.0` rule at player.gd:825).
