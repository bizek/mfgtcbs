# Boss Authoring Reference

## Overview

A **biome boss** is a single named encounter that gates extraction at the end of a run. It differs from a miniboss (which guards an extraction point mid-run) in scope and contract:

| | Miniboss (e.g., Warped Colossus) | Biome Boss (e.g., Heart of the Deep) |
|---|---|---|
| Phase | 3 (any mid-run phase) | 5 (final, run-ending) |
| HP | 400–600 | 1200–2000 |
| Skills | 2–3 scripted patterns | 3–5 + phase-branching stance machine |
| Extraction gate | No | **Yes — `is_extraction_allowed()` = false while alive** |
| `is_boss` | `true` | `true` |
| Tags | `["bosses"]` | `["bosses", "final_boss"]` |
| XP | ~60 | ~200 |

Each biome gets exactly one boss, placed in its Level 0 arena. The boss is the mechanical punctuation on the biome's identity — its move set should remix or escalate what the biome's regular enemies have been doing all run.

---

## Anatomy of a Boss

### Data Definition

One factory file per boss: `data/factories/enemies/<name>_data.gd`. See the [New Enemy pattern](engine_reference.md) for the base wiring. Boss-specific fields:

```gdscript
def.is_boss = true
def.boss_bar_color = Color(...)     # shown in the dedicated boss HP bar
def.groups = ["bosses", "final_boss"]
def.tags = ["Boss", "Final"]
def.knockback_multiplier = 0.0      # bosses ignore knockback by default
def.sprite_scale = Vector2(3.2, 3.2)  # large silhouette
def.base_stats = {"max_hp": 1600.0}
def.xp_value = 200.0
def.health_drop_chance = 1.0        # always drops health on kill
```

Register in `EnemyRegistry.build_all()` and wire a spawn call in `EnemySpawnManager` using `_spawn_boss_bypass_cap()` (bypasses the enemy cap).

Bosses **reuse** the `brute.tscn` scene (CharacterBody2D, AnimatedSprite2D, Hurtbox Area2D, `enemy.gd` script). No dedicated scene file is required unless the boss needs custom node structure (e.g., attachments).

### Skills and Phases

Bosses express attack patterns as `AbilityDefinition` objects wired to `ChoreographyDefinition`. Every attack follows the **wind-up → hit** two-phase minimum:

```gdscript
## Phase 0: telegraph + wait
var tel := SpawnTelegraphEffect.new()
tel.shape = "circle"        # "circle", "ring", "line", "cone"
tel.anchor = "target_position"  # or "source_position", "source_forward_line"
tel.radius = 80.0
tel.duration = 0.75
tel.color = Color(...)
tel.telegraph_id = "unique_id"

var windup := ChoreographyPhase.new()
windup.animation = "attack"
windup.effects = [tel]
windup.exit_type = "wait"
windup.wait_duration = 0.75   # must match tel.duration
windup.default_next = 1

## Phase 1: damage
var hit := ChoreographyPhase.new()
hit.effects = [damage_effect]
hit.exit_type = "wait"
hit.wait_duration = 0.4
hit.default_next = -1         # -1 ends choreography, ability goes on cooldown
```

Available damage effects — see `engine_reference.md` §EffectDispatcher:

| Effect | Use case |
|--------|---------|
| `AreaDamageEffect` | Circle AoE centered on a point |
| `DealDamageEffect` | Direct hit (inside projectile `on_hit_effects`) |
| `SpawnProjectilesEffect` | Radial bursts, aimed spreads, single shots |
| `GroundZoneEffect` | Persistent floor hazard that ticks |
| `DisplacementEffect` | Boss charges; `displaced = "self"`, `destination = "to_target"` |

### Phase Transitions Within a Boss Fight

Branching uses `ChoreographyBranch` on a selector phase with `exit_type = "wait"` and a very short `wait_duration` (0.02 s). Each branch has a `ConditionHpThreshold` and a `next_phase` index. **First passing branch wins**, so test lower thresholds first:

```gdscript
var cond_desperate := ConditionHpThreshold.new()
cond_desperate.target = "self"
cond_desperate.threshold = 0.25
cond_desperate.direction = "below"

var branch_desperate := ChoreographyBranch.new()
branch_desperate.condition = cond_desperate
branch_desperate.next_phase = 5    # jumps to desperate-phase wind-up

## selector phase — index 0 in choreo.phases
var selector := ChoreographyPhase.new()
selector.hit_frame = -1
selector.exit_type = "wait"
selector.wait_duration = 0.02
selector.default_next = 1          # normal phase if no branch passes
selector.branches = [branch_desperate, branch_enraged]  # desperate first!
```

The auto-attack ability runs the stance machine in a loop: `ability.cooldown_base` sets how often the selector re-evaluates. Separate skill abilities run on their own independent cooldowns and fire when `BehaviorComponent` resolves a target.

### Telegraph and Counterplay

Every boss skill that deals > 15 damage **must** have a telegraph. Rules of thumb:

| Pattern | Telegraph shape | Duration target | Notes |
|---------|----------------|-----------------|-------|
| Point-targeted AoE | `circle` at `target_position` | 0.7–1.0 s | Fill build-up visualizes remaining time |
| Boss self-centered burst | `ring` at `source_position` | 0.9–1.2 s | Larger radius = longer telegraph |
| Directional sweep | `cone` at `source_forward_line` | 0.8–1.0 s | Player must move to the side |
| Charge | `line` at `source_forward_line` | 0.5–0.7 s | Shorter OK — charge is visually obvious |

Telegraph duration must equal `ChoreographyPhase.wait_duration`. Set `telegraph_speed_scale` to match (0.5 = half animation speed during wind-up, which reads as slow/threatening).

Player movement speed is ~200 px/s. A 100 px radius circle telegraph at 0.75 s gives the player ~150 px of escape margin — enough for one roll but not a leisurely stroll. The design target: **avoidable with correct read, unavoidable if ignored**.

Damage relative to player HP at wave-phase 5 (expected ~200 HP with two upgrade tiers): a single boss hit should be 15–20% of player HP (30–40 dmg) at most. Stacked hits that overlap (e.g., a nova burst + ground zone) should not instant-kill a healthy player.

---

## The Heart of the Deep Walkthrough

Source: [`data/factories/enemies/heart_of_the_deep_data.gd`](../data/factories/enemies/heart_of_the_deep_data.gd)

### Base Stats

| Stat | Value | Why |
|------|-------|-----|
| `max_hp` | 1600 | Roughly 4× a Phase 5 Brute. Long enough for phase transitions to feel earned, short enough to die in ~45 s with a good build. |
| `contact_damage` | 18 | High — being cornered is punished. |
| `move_speed` | 13 px/s | Very slow. It is a presence, not a chaser. Positioning mistakes matter more than reaction time. |
| `base_armor` | 10 | Modest damage reduction. Does not invalidate burst builds. |
| `knockback_multiplier` | 0.0 | Immune. Preventing knockback means players can't kite it with hit-and-run physics. |
| `sprite_scale` | 3.2× | Imposing silhouette that makes the fight arena feel smaller. |

### Ability 1: Abyssal Slam (auto-attack stance machine, cooldown 4 s)

The auto-attack is a 7-phase stance machine. Each cycle begins at phase 0 — a 0.02 s selector that reads current HP and branches:

| HP | Branch | Stance |
|----|--------|--------|
| > 50% | Default | **Abyssal Slam** (phases 1–2) |
| ≤ 50% | `branch_enraged` | **Tidal Sweep** (phases 3–4) |
| ≤ 25% | `branch_desperate` (tested first) | **Collapse Nova** (phases 5–6) |

**Abyssal Slam** (phases 1–2): Circle telegraph at target position, radius 100, 1.0 s wind-up. On hit: `AreaDamageEffect`, 33 Void dmg, 100 px radius. *Design intent*: Standard point-and-dodge. Teaches the telegraph pattern before it escalates.

**Tidal Sweep** (phases 3–4): Cone telegraph forward-facing, 170 px long, 70° wide, 0.9 s wind-up. On hit: `AreaDamageEffect`, 27 Void dmg, 150 px radius. *Design intent*: The player learns to dodge laterally, not backwards. Activates at half HP — the fight changes gear. Note: the cone telegraph is visual; the hit box is a full 150 px radius (v1 approximation — true sector damage is a future engine feature).

**Collapse Nova** (phases 5–6): Ring telegraph at source, radius 260 px, 1.5 s wind-up. On hit: 18-projectile radial burst (pierce-all, 160 px/s, 380 px range, 18 Void dmg each) + 140 px ground zone under the boss for 8 s (ticks 4 Void dmg every 0.4 s). *Design intent*: Desperation move. Forces the player away from the boss with the projectile burst, then the void pool denies the center of the arena. Good builds need to burst the remaining ~400 HP through the coverage.

### Ability 2: Void Spit (skill, cooldown 6 s)

Line telegraph 260 px long, 28 px wide, 0.5 s wind-up. On hit: 5-projectile spread (60° arc, `aimed`, 210 px/s, pierce 1, 17 Void dmg each).

*Design intent*: Runs on an independent 6 s cooldown alongside the stance machine. When the slam cycle is in wind-up, Void Spit fires from a separate BehaviorComponent slot. This creates multi-threat overlap — the player is dodging both a floor telegraph and an incoming spray simultaneously. The pierce-1 on the projectiles means they cut through summons/orbs.

### Phase Transitions — the Moment-to-Moment

- **0–50% HP**: Abyssal Slam cycling every ~5.5 s (4 s CD + ~1.5 s execution), Void Spit interleaved every ~7 s. Readable, learnable, low lethality.
- **50% HP crossover**: Next stance-machine cycle lands in Tidal Sweep. Audio/visual cue opportunity — the phase colors shift (cone is pink vs purple slam). Damage stays similar but dodge direction changes.
- **25% HP crossover**: Collapse Nova. The ring telegraph telegraphs the explosion radius at 260 px — almost the full visible screen width. If the player is standing inside the ring, they have 1.5 s to move out. The subsequent void pool makes standing near the boss increasingly punishing. This phase is designed to feel chaotic but survivable with mobility.

### Why It Works at Phase 5 Difficulty

- Three mechanical demands (dodge point, dodge cone, dodge ring + burst) are introduced sequentially via phase transitions, not simultaneously.
- The void pool forces arena management without being instant-death — it's an area-denial that compounds over time.
- All three damage types (point AoE, projectile spread, ground zone) are mitigated by different build strategies (mobility, projectile resist, heal-on-hit), ensuring multiple playstyles remain viable.
- The slow movement speed means a mobile player is rarely cornered unless they make consecutive errors.

---

## Authoring a New Biome Boss

### 1. Concept

Write one paragraph: the boss's silhouette, its mechanical hook, and why it is not a Heart of the Deep reskin. The hook should relate to the biome's theme. *Example: a Fungal Cavern boss whose mechanic is spore clouds that reduce visibility — not just more Void damage.* If you can't write a distinct hook, the boss isn't ready for implementation.

### 2. Stat Baseline

Start from HotD's numbers and adjust:

| Stat | HotD | Earlier biome | Later biome |
|------|------|---------------|-------------|
| `max_hp` | 1600 | 800–1000 | 2000–2500 |
| `contact_damage` | 18 | 10–14 | 20–24 |
| `move_speed` | 13 | 18–22 | 10–14 |
| `base_armor` | 10 | 4–6 | 12–16 |

Earlier biome bosses should be faster and smaller to compensate for lower player build power.

### 3. Skill Set

Target 3–5 abilities (auto-attack stance machine + 1–3 independent skills):

- **One telegraphed AoE** (circle or cone) — the "read-and-dodge" pattern
- **One projectile barrage** — forces movement, rewards positional awareness
- **One arena-control element** — ground zone, displacement, or summon
- Optional: displacement/charge, summon adds, self-buff at HP threshold

All abilities need a telegraph phase matching their damage radius and cooldown rhythm. The auto-attack stance machine should have at least 2 HP-threshold branches (one enrage at 50%, one desperation at 25%).

### 4. Phase Transitions

Minimum two branches in the selector. At each transition:
- Change at least one telegraph shape or color (visual signal to the player)
- Increase either damage or coverage radius, not both simultaneously
- The desperation phase should introduce a new threat type (e.g., ground zone, radial burst) that wasn't present in the normal phase

### 5. Arena

Check the boss region in the LDtk file (see [`ldtk_schema.md`](ldtk_schema.md) and [`ldtk_workflow.md`](ldtk_workflow.md)). Boss arenas should be:
- At least 600×600 px (HotD's nova radius is 260 px — the player needs room to escape it)
- Free of interior obstacles that would obscure the boss silhouette
- Have a clear spawn point for the boss (typically arena center, `Vector2.ZERO` relative to level origin)
- LevelExit entity placed at the arena edge — spawns after boss death, triggers `ExtractionManager`

### 6. Reward

Add a boss-tier loot table entry in `EnemySpawnManager` or the loot system. Boss kills should guarantee:
- 1 high-rarity mod drop
- 1 biome keystone (if the biome uses locked extraction)
- Full health orb

### 7. Test

Before declaring done:

- [ ] **Damage check**: Does the boss die to a Phase 5 build in ~45–90 seconds?
- [ ] **Lethality check**: Does the boss kill a player who stands still and ignores telegraphs within 15 seconds?
- [ ] **Build variety**: Test at least three build archetypes (melee, ranged, status). No build should be completely invalidated by a single mechanic.
- [ ] **Transition readability**: Phase transitions have distinct visual color shifts in telegraphs.
- [ ] **Death flow**: Boss death → `enemy_spawn_manager` clears gate → LevelExit becomes active → player can extract.

---

## Anti-Patterns

**No telegraph on heavy-damage skills.** If a skill deals > 20 damage, it needs a telegraph. Telegraphless hits feel unfair regardless of how much HP the player has.

**Phase transitions with no cue.** Changing stance silently makes phase transitions invisible. Minimum: change the telegraph color. Better: add an audio sting or brief animation.

**Single dominant strategy.** If kiting in a circle trivially beats the boss (or if melee is the only viable approach), the boss has failed its design. Each skill should incentivize a different positioning decision.

**Stat tank with no mechanical interest.** 2000 HP and nothing else is a slog, not a boss. At least two skills should create meaningful reads. The HP is the clock, not the challenge.

**Mechanics that only matter for one build.** Charm immunity, for example, only creates asymmetric difficulty if charm is a real option. Keep boss mechanics in the universally-relevant design space (dodgeable projectiles, avoidable AoEs, arena hazards) unless the biome is explicitly designed around a specific build archetype.

**Overlap with HotD's exact move set.** Every other boss should feel distinct. Using a radial nova + ground zone combo (HotD's desperate phase signature) on another boss should be a deliberate design choice, not a template copy.

---

## Acceptance Criteria

A biome boss is shippable when:

- [ ] Killable by a build that successfully extracted from wave-phase 5 of that biome
- [ ] NOT killable by an under-leveled build that skipped wave-phases
- [ ] Has at least one telegraphed AoE, one projectile pattern, one arena-control element
- [ ] Phase transitions are visually readable (color shift, animation, or audio cue)
- [ ] Death triggers level exit unlock and expected reward drop
- [ ] `is_extraction_allowed()` returns `false` while boss is alive, `true` after death
- [ ] Boss HP bar appears and tracks correctly (requires `is_boss = true` and `boss_bar_color`)
