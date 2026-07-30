# Engine Reference

> **Status:** Reconciled with code 2026-07-21. Where this doc and the source disagree, the source wins — verify against `project.godot [autoload]`, `scripts/systems/combat_orchestrator.gd`, and `scripts/autoloads/event_bus.gd`.

Component-based combat engine. All content = Resource definitions routed through EffectDispatcher. New enemies, abilities, statuses, weapons = data factories, zero code changes.

## Architecture at a Glance

```
Autoloads (game):   EventBus, GameManager, ProgressionManager, UpgradeManager,
                    EnemySpawnManager, ExtractionManager, CodexManager, LootTables,
                    Settings, AudioManager, InputGlyphs, AchievementManager, Logger
Autoloads (editor): MCPScreenshot, MCPInputService, MCPGameInspector  (godot_mcp addon — not game systems)

Scene-owned: CombatOrchestrator (child of MainArena)
  Children:  ProjectileManager, VfxManager, TelegraphManager, DisplacementSystem,
             CombatFeedbackManager, ComboEffectResolver, DebugDraw, FlowField
  Owned (not a node): SpatialGrid, ground-zone list, corpse list, run RNG
```

Every entity (player, enemy, summon) owns 6 components created in `_init()` or `_ready()`:
- `health: HealthComponent` — HP, shield, death prevention
- `modifier_component: ModifierComponent` — flat modifier list + cached query
- `ability_component: AbilityComponent` — skill bar, cooldowns, conditions
- `behavior_component: BehaviorComponent` — AI loop / auto-attack timer, target resolution
- `status_effect_component: StatusEffectComponent` — active statuses, modifier sync, aura ticks
- `trigger_component: TriggerComponent` — EventBus listeners, condition evaluation, effect dispatch

The **player** owns a 7th: `skill_component: SkillComponent` — the Q/E skill slots, populated per kit by `SkillFactory.build_kit_skills()`.

Entity contract: see `scripts/entities/entity_interface.gd` for required properties/methods.

Orchestrator tick order per frame: SpatialGrid rebuild → StatusEffect.tick → AbilityComponent.tick_cooldowns → BehaviorComponent.tick (enemies only; player ticks own behavior in _physics_process) → ground-zone ticks.

## Run Modes

`GameManager` carries three switches that change what MainArena builds:

| Flag | Effect |
|------|--------|
| `use_ldtk_level_1` | Load `Level_0` from the LDtk project instead of the procedural `ArenaGenerator`. |
| `use_descent_mode` | Block-based vertical descent (`BlockManager` + `DepthTracker` + `LdtkLevelDirector`) instead of one monolithic level. This is the live path. |
| `training_mode` | Flat sandbox: no waves, no phase clock, no extraction. Dummies + `training_panel.gd`. See `docs/dev_tools.md`. |

In descent mode `phase_number` still advances on the wall clock (other systems depend on `phase_started` firing), but **combat and loot scaling must read `GameManager.get_effective_phase()`**, which derives the 1–5 tier from spatial depth. Never scale off `phase_number` directly.

## Level Loading

Levels are authored in LDtk, one `.ldtkl` file per biome. See `docs/ldtk_schema.md` for the full entity/enum/IntGrid contract and `docs/ldtk_workflow.md` for authoring steps.

`LdtkLoader` (`scripts/systems/ldtk_loader.gd`) parses the active level's `.ldtkl` file at arena start and instantiates: spawn zones (IntGrid regions fed to `EnemySpawnManager`), boss spawn markers, level exit triggers, and environmental decoration layers. Biome-level metadata — wave compositions, music track ID, extraction type pool — lives in `data/factories/level_data.gd` and is read by `GameManager` during phase setup.

In descent mode this is only half the story — the arena is streamed from blocks rather than loaded whole. See "Descent & Level Streaming" below.

> Cross-references: `docs/ldtk_schema.md` (entity defs, layer stack) · `docs/ldtk_workflow.md` (add a biome, add a level)

## The Effect Pipeline

All game effects route through `EffectDispatcher.execute_effects(effects, source, targets, ability, combat_manager)`. This is THE dispatch hub. Never execute effects manually — always go through EffectDispatcher.

`BehaviorComponent` resolves targets via `_resolve_targets_internal(TargetingRule, entity)` using SpatialGrid, then emits `ability_requested` or `auto_attack_requested`. The entity handler calls `EffectDispatcher.execute_effects()`.

---

## Combo-Chain Combat Layer

**This is the game's identity system** — the manual, input-driven melee/caster chain layer that sits on top of the effect pipeline. Full design: `docs/combat_chain_architecture.md`. Read it before touching any kit.

The load-bearing idea: **a combo graph is not a new construct.** It is one `AbilityDefinition` whose `ChoreographyDefinition` has one phase per combo node, with `ChoreographyBranch` arrays conditioned on input. No FSM, no `AttackData`, no `Hitbox` type. If a task tempts you toward one, it's the wrong solution.

### The pieces

| Piece | File | Role |
|-------|------|------|
| `ChoreographyRunner` | `scripts/components/choreography_runner.gd` | Host-agnostic executor. Walks phases, fires effects on hit frames, evaluates branches each frame during `"wait"` phases. Duck-typed `choreo_*` host interface. |
| `ChainFactory` | `data/factories/chain_factory.gd` | Builds the `light` / `heavy` / `channel` graphs per `melee_kit`. Base radii, tick cadences, cancel windows. |
| `SkillFactory` | `data/factories/skill_factory.gd` | Builds the `skill_q` / `skill_e` abilities per kit. Populates `SkillComponent`. |
| `CombatInputBuffer` | `scripts/systems/combat_input_buffer.gd` | Press timestamps + hold durations. Pure input state — no FSM, no anim, no damage. |
| `ConditionInputBuffered` / `ConditionInputHeld` | `data/resources/conditions/` | The branch vocabulary. Evaluated by the host, **held before buffered**. |
| `ComboRegistry` / `ComboDetector` / `ComboEffectResolver` | `scripts/data/`, `scripts/systems/` | Mod-combo discovery and resolution (see Codex System below). |

### How a press becomes a hit

1. Player polls `CombatInputBuffer.tick()` every physics frame.
2. An entry input (`light_attack` / `heavy_attack` tap or hold) starts the matching graph at its phase 0 via `ChoreographyRunner`.
3. Each node is a `"wait"` phase. Its `wait_duration` **is** the cancel/buffer window — there is no separate window timer.
4. During that window the runner evaluates the phase's branches every frame; first passing branch wins and enters the next node. Timeout falls through to `default_next` (`-1` = chain ends → `choreo_on_chain_timeout`).
5. Effects fire when `sprite.frame == phase.hit_frame`. An early hit frame (0–1) is how "crisp on press" is achieved — no extra mechanism.
6. A held channel is a phase whose `ConditionInputHeld` branch points **at itself**: re-entry replays the animation and re-fires the hit frame, which is the tick. Release falls through to `default_next`.

### Input contract

Actions: `light_attack` (LMB / RT), `heavy_attack` (RMB / LT), `skill_q`, `skill_e`, `dash`. `fire` is a legacy alias sharing LMB's bindings. Aim is cursor-based (`aim_left/right/up/down` provide the right-stick equivalent).

Dash is host-side on `player.gd`, not a choreography: `DASH_DURATION` is a fixed feel constant; distance, cooldown and charge count are modifier-driven (`dash_speed`, `dash_cooldown`, `dash_charges`). `_dash_style` selects the per-class variant (e.g. the Spark's teleport blink).

**`player.gd::_get_aim_world_position()` is the single aim seam.** Facing, swing arcs, beam corridors, projectile headings, ground-zone placement, the Guard block arc and every Q/E skill read it — nothing reads the mouse directly. Three modes resolve in order:

| Mode | Aim point |
|------|-----------|
| **Auto-aim** (`Settings.auto_aim`) | The locked enemy's position (see below). |
| **Controller stick** | `global_position + _controller_aim_dir * CONTROLLER_AIM_DISTANCE`; the stick holds its last direction when released. |
| **Mouse** (default) | `get_global_mouse_position()`. |

### Auto-aim

Opt-in setting (Settings → Controls → "Auto Aim"), off by default, read live so the pause-menu toggle applies mid-run. With it on the player never steers a crosshair: attack + skills + movement is the whole control surface. Because it changes only what the aim seam returns, no combat code knows it exists.

`_update_auto_target()` runs once per physics frame, before facing:

- **Candidates** — `spatial_grid.get_nearby_in_range(..., faction 1, AUTO_AIM_ACQUIRE_RANGE=300)`, roughly on-screen. Alive, targetable enemies only.
- **Score** (lower wins) — distance, discounted by alignment with `_last_move_dir` (`AUTO_AIM_STEER_BIAS=0.30`). Movement is the player's remaining steering input: run at the enemy you want.
- **Hysteresis** — the held target is scored at `AUTO_AIM_SWAP_MARGIN=0.72` and kept out to `AUTO_AIM_RETAIN_RANGE=400`, so a rival must be clearly better to take the lock. Without this two equidistant enemies strobe the lock (and the swing direction) every frame.
- **Min reach** — a chasing mob standing *on* the player would yield a zero-length aim vector, so the aim point is pushed out to `AUTO_AIM_MIN_REACH=16` px along the same bearing.
- **No target** — face `_last_move_dir` (holding the last facing when still), deliberately *not* the stale cursor.

`auto_aim_reticle.gd` draws amber corner brackets over the lock (top-level child, `z_index=90` so the arena's y-sort can't bury it). Built lazily; a player with auto-aim off never gets the node. Cleared in `_on_health_died` — `_physics_process` early-returns once dead, which would otherwise freeze the reticle on-screen.

The bracket is sized off the target's **sprite**, not its hurtbox: enemy size lives in `EnemyDefinition.sprite_scale` (Brute 1.8×, Ancient Troll 2.4×, Heart of the Deep 3.2×), which `enemy.gd::_apply_def_visuals()` applies to the sprite while the authored collision shape stays small — a hurtbox-sized bracket sits inside a boss's feet. Size is `frame_size * sprite.global_scale * SPRITE_FILL(0.5) + BOX_PAD(3)`, clamped to 7–56 px; the fill factor approximates the drawn silhouette inside a padded sheet cell (a 32px fodder cell holds a ~16px zombie). Measured live each frame so the kill-pop scale tween and any runtime scaling are picked up. Measured results: swarmer/fodder 22px, Brute 35px, Ancient Troll 44px, Goblin King 54px.

Aim points at the target's *current* position — there is no lead prediction. Enemies mostly close on the player, so lateral error is small, and seeking projectiles (`ProjectileConfig.seek_radius`) correct for the rest.

### Cadence feedback

`EventBus` carries three combo-specific signals consumed by audio/HUD: `on_combo_step(entity, depth, is_finisher)`, `on_finisher_hit(entity)`, and `on_combo_dropped(entity, depth)` (a chain at depth ≥ 2 that lapsed rather than being interrupted or finished — the "exhale"). Spec: `docs/combo_feedback_spec.md`.

### Kit coverage

All 12 classes ship `light` / `heavy` / `channel` graphs from `ChainFactory.build_kit()` plus Q/E skills from `SkillFactory.build_kit_skills()`. A character selects its graphs with the `melee_kit` key in `CharacterData.ALL` — `"fighter"`, `"rogue"`, `"paladin"`, `"wizard"`, `"blood_mage"`, `"ranger"`, `"bard"`, `"barbarian"`, `"ninja"`, `"gunslinger"`, `"druid"`, `"cleric"`.

Animations for these phases are sliced/retimed through the Animation Lab (F10) and persist to `data/anim_overrides.json`, which **exported builds read**. See `docs/dev_tools.md`.

---

## Content Creation Patterns

### New Enemy

1. Create `data/factories/enemies/<name>_data.gd`:
```gdscript
class_name FooData extends RefCounted
static func create() -> EnemyDefinition:
    var def := EnemyDefinition.new()
    def.enemy_id = "foo"
    def.enemy_name = "Foo"
    def.tags = ["Melee", "Heavy"]
    def.base_stats = {"max_hp": 80.0}
    def.combat_role = "MELEE"  # or "RANGED"
    def.move_speed = 60.0
    def.contact_damage = 15.0
    def.behavior_type = "chase"  # "chase", "ranged", "flee"
    # Optional: def.auto_attack = _create_ability()
    # Optional: def.skills = [SkillDefinition]
    # Optional: def.on_spawn_statuses = [StatusEffectDefinition]
    return def
```
2. Register in `EnemyRegistry.build_all()`: `_definitions["foo"] = FooData.create()`
3. Add scene reference in `EnemySpawnManager` + wire spawn logic
4. Scene needs: CharacterBody2D with Sprite (AnimatedSprite2D) + Hurtbox (Area2D) child nodes, script = `enemy.gd`

`setup_from_enemy_def(def)` handles all stat/component/behavior wiring automatically.

### Enemy with Ranged Attack

Set `def.auto_attack` to an AbilityDefinition containing a SpawnProjectilesEffect:
```gdscript
static func _create_bolt() -> AbilityDefinition:
    var config := ProjectileConfig.new()
    config.speed = 90.0
    config.max_range = 315.0
    config.hit_radius = 8.0
    config.fallback_color = Color(1.0, 0.5, 0.1)  # procedural circle when no sprite
    var dmg := DealDamageEffect.new()
    dmg.damage_type = "Physical"
    dmg.base_damage = 12.0
    config.on_hit_effects = [dmg]
    var spawn := SpawnProjectilesEffect.new()
    spawn.projectile = config
    spawn.spawn_pattern = "aimed_single"  # "radial", "spread", "at_targets"
    var aa := AbilityDefinition.new()
    aa.ability_id = "foo_bolt"
    aa.cooldown_base = 2.0
    aa.mode = "Auto"
    aa.targeting = TargetingRule.new()
    aa.targeting.type = "nearest_enemy"
    aa.targeting.max_range = 200.0
    aa.effects = [spawn]
    return aa
```

Set `def.behavior_type = "ranged"` and `def.preferred_range = 175.0` so the enemy stops advancing at range.

### Projectile Steering (seek + turn cap)

`motion_type = "homing"` re-points a projectile straight at its target every frame — unmissable, and
the shape every Gravity mod combo was built against. Three `ProjectileConfig` fields express the
softer "slight homing" instead, and they work on `"directional"` motion too:

| Field | Meaning |
|---|---|
| `homing_turn_rate` | Degrees/sec cap on heading change. `0.0` = uncapped (the legacy snap). A finite rate makes the projectile *curve*, so it can be out-turned. |
| `seek_radius` | `> 0` lets a projectile with no target acquire one. Until it acquires it flies dead straight, so an unaimed shot stays unaimed. |
| `seek_cone` | Half-angle (deg) of the forward cone it may acquire within — stops a shot whipping around onto something behind the shooter. |

Turn radius is `speed / radians_per_sec`, and player projectiles fly at
`speed * PLAYER_PROJECTILE_SPEED_SCALE` (0.55) — so a nominal `speed = 300` travels at 165 px/s and
`homing_turn_rate = 120` gives a ~79px turn radius. The Scavenger's arrows use
`ChainFactory.ARROW_SEEK / ARROW_CONE / ARROW_TURN`; leave all three at their defaults and behaviour
is exactly as before.

Note `"aimed_single"` honours `count > 1` (the `projectile_count` stat) by fanning the extras
`AIMED_EXTRA_FAN` degrees to alternating sides — shot #0 always stays on the aim line.

### New Weapon

Add entry to `WeaponData.ALL` dict, then `WeaponFactory.build_weapon_ability()` generates the AbilityDefinition. Behavior types map to engine patterns:
- `"projectile"` / `"spread"` → SpawnProjectilesEffect + ProjectileConfig
- `"beam"` → DealDamageEffect (direct hit, no projectile)
- `"melee"` → AreaDamageEffect via `all_enemies_in_range` targeting
- `"artillery"` → GroundZoneEffect (delayed detonation)
- `"orbit"` → persistent OrbitOrb entities (special case)

### New Status Effect

Create a StatusEffectDefinition in a factory (StatusFactory or inline):
```gdscript
var def := StatusEffectDefinition.new()
def.status_id = "my_status"
def.tags = ["Fire", "DoT"]         # for immunity checks (Negate modifier)
def.is_positive = false             # buff vs debuff (cleanse targeting)
def.max_stacks = 3
def.base_duration = 5.0            # -1 = permanent
def.duration_refresh_mode = "overwrite"  # or "max"
def.tick_interval = 1.0            # 0 = no ticking
def.tick_effects = [DealDamageEffect]
def.modifiers = [ModifierDefinition]  # active while status is on
```

Apply via: `entity.status_effect_component.apply_status(def, source, stacks, duration)`

### New Modifier

`ModifierDefinition` is the universal stat modification shape. Used by everything: upgrades, statuses, talents, equipment, zone buffs.

```gdscript
var mod := ModifierDefinition.new()
mod.target_tag = "Physical"   # what it modifies
mod.operation = "resist"       # how
mod.value = 5.0
mod.source_name = "my_source"  # for removal/debug
entity.modifier_component.add_modifier(mod)
```

**Operations**: `"add"` (flat), `"bonus"` (multiplicative), `"resist"` (damage reduction), `"negate"` (immunity), `"pierce"` (ignore resist), `"cooldown_reduce"`, `"vulnerability"`, `"damage_taken"`, `"received_bonus"`

**Query**: `modifier_component.sum_modifiers(tag, operation)` — O(1) cached lookup.

**Stat read pattern**: `base = sum("stat", "add")`, then `final = base * (1.0 + sum("stat", "bonus"))`.

### Codex System

`CodexManager` (autoload, `scripts/systems/codex_manager.gd`) tracks per-combo discovery state across runs. Each `ModCombo` in `ComboRegistry` gets a `CodexEntry` with three progressive states: **discovered** (slotted in armory), **revealed** (triggered in a run), and **mastered** (triggered ≥ 50 times lifetime). The codex state serializes through `CodexManager.save_data()` / `load_data()` and is persisted by `ProgressionManager`. The viewer ships as `CodexGridPanel` (`scripts/ui/codex_grid_panel.gd`), embedded in the Armory hub panel rather than as its own station. In-run discoveries surface through `combo_discovery_popup.gd`.

### Mastery Bonuses

When a combo reaches mastered state, `MasteryApplicator.get_active_mastery_bonuses(active_combos)` returns a bonus dictionary (`bonus_type → accumulated_value`) for all currently active mastered combos. Bonus types and values are keyed per `ModCombo.combo_type` (e.g., ELEMENTAL_ELEMENTAL → +25% proc radius). `ComboRegistry` wires the `ModCombo.mastery_bonus: MasteryBonus` resource; `combo_effect_resolver.gd` calls `MasteryApplicator` during effect calculation to fold the bonuses in.

---

## Enemy Role Taxonomy

Every enemy falls into one of six roles. Role is expressed via `def.tags` on the EnemyDefinition and drives spawn composition per phase.

| Role | Speed | HP | Damage | Typical Count | Purpose |
|------|-------|----|--------|--------------|---------|
| Fodder | Slow | Very Low | Low | Massive packs | XP economy. The horde layer. Satisfying to mow down. |
| Swarmer | Fast | Low | Low–Med | Large packs | Positioning pressure. Dangerous in volume. |
| Brute | Slow | High | High | Few | Priority threat. Blocks paths. Demands focused attention. |
| Ranged/Caster | Stationary/Slow | Medium | Medium | Moderate | Forces movement. Creates danger zones. |
| Elite | Varies | Boosted | Boosted | Rare | Any base role with 1–2 modifiers applied. Mini-challenge. |
| Miniboss | Slow | Very High | Very High | 1–2 per phase | Guards extraction points. Unique attack patterns. Scales at phase × 1.5. |

### Elite Modifiers

Elites apply 1–2 modifiers on top of any base role:

| Modifier | Effect |
|----------|--------|
| Shielded | Shield must be broken before HP damage applies. |
| Splitting | On death, splits into 2–3 smaller copies of itself. |
| Exploding | On death, detonates in an AoE. Punishes melee/close builds. |
| Vampiric | Heals on hit — must be burst down. |
| Hasting | Periodically surges to double speed for a few seconds. |
| Reflecting | Returns a fraction of incoming damage to the attacker. |
| Summoning | Periodically spawns Fodder enemies. |

Modifiers are data flags on the EnemyDefinition. Any number can be added post-launch as pure content.

### Special Enemy Types

Beyond base roles, these behavioral variants appear at specific phase thresholds:

| Type | Phase | Behavior |
|------|-------|---------|
| Stalker | 3+ | Invisible until close range. Low HP, high burst damage. Distinct audio sting on reveal. |
| Mimic | 2+ | Disguised as a loot pickup. Reveals and attacks when player enters pickup radius. Replaces roughly 1-in-20 non-resource drops. |
| Herald | 3+ | No direct attack. Emits an aura buffing nearby enemies (damage, speed, or armor). Fragile but high priority — killing it weakens the surrounding group. |
| Anchor | 2+ | Plants itself and creates a persistent damage/slow zone. Must be killed to remove the zone. Denies kiting paths. |
| Carrier | 2+ | Holds guaranteed valuable loot but flees the player. Fast and evasive. Chasing it pulls the player out of position. |
| Phase-Warped | 5 only | Visually alien; unusual movement and attack patterns. Signals the player has crossed into somewhere they don't belong. |

### Phase Spawn Composition

| Phase | Composition | Elite Chance |
|-------|------------|-------------|
| Phase 1 | 80% Fodder, 20% Swarmer | None |
| Phase 2 | 50% Fodder, 25% Swarmer, 15% Brute, 10% Ranged | ~5% |
| Phase 3 | 30% Fodder, 25% Swarmer, 20% Brute, 15% Ranged, 10% Elite | ~15% |
| Phase 4 | 20% Fodder, 20% Swarmer, 25% Brute, 20% Ranged, 15% Elite | ~25% |
| Phase 5 | All types active, Phase-Warped dominant | ~40% |

---

## Extraction System

`ExtractionManager` (autoload) tracks channeling state and extraction outcomes. Four extraction types exist, each with distinct activation requirements and risk/reward profiles. Types are placed in levels via LDtk `Extraction` entities (see `docs/ldtk_schema.md` §6).

### Timed Extraction

The baseline option — appears at the end of each phase. A 10-second warning plays, then a portal materializes at the designated arena location and remains active for 18 seconds before the next phase begins. Activation requires a 4-second channel; taking damage during the channel does not interrupt it, but the player must survive.

### Guarded Extraction

Present from Phase 1 — always visible. A miniboss-tier guardian occupies the extraction point from run start. Killing the guardian opens a 25-second window requiring the same 4-second channel. After the window closes, a harder guardian respawns after 45 seconds.

### Locked Extraction

Appears Phase 3+. The point is visible but sealed. A Keystone item (~5% drop from Elites, guaranteed from the first Miniboss kill per phase) unlocks it. Using a Keystone activates a 2-second channel. Successful extraction grants a loot value bonus: +25% in Phase 3, +50% in Phase 4, +100% in Phase 5.

### Sacrifice Extraction

Available Phase 2+. Always visible and always available — no window, no guardian. The player selects one carried loot item to permanently destroy; the sacrifice triggers immediate extraction with no channel time.

### Death Penalty

On death: all extractable loot is lost. Meta XP is granted at 25% of what a successful extraction would have awarded. The insured item (if any) is saved.

---

## Save / Load

`ProgressionManager` owns all persistence. Save file: `user://progression.json` (JSON, written via `FileAccess`). Loaded on `_ready()`.

**Serialized state**: currency (`resources`), hub upgrade IDs (`hub_upgrades`), unlocked and selected weapons, equipped mod loadout per weapon (`weapon_mods`), owned mod inventory, selected and unlocked characters, and career statistics (runs, extractions, deaths, kills, deepest phase, loot records). `CodexManager.save_data()` / `load_data()` extends this with per-combo discovery/mastery state — `ProgressionManager` calls both.

**Save triggers**: after successful extraction (`GameManager.on_extraction_complete`), on player death (`GameManager` run-end flow), after every hub action that mutates state (buy upgrade, equip mod, select character — each mutation method calls `save_data()` inline). Armory equip changes also save via `hub_armory_panel.gd`. No mid-run save — intentional; runs are atomic.

## Engine Capabilities & Content Coverage

Everything below is fully wired and functional. The **Coverage** line on each says how much content actually uses it today — a low-coverage system is where new content can be created purely through data, and a stub is a genuine gap.

> Coverage claims were re-verified against `data/` on 2026-07-21. Before relying on a "no content" line, re-grep — this section drifts faster than any other.

### Trigger System

`TriggerComponent` connects to EventBus signals and dispatches effects when conditions pass. Content attaches triggers via `StatusEffectDefinition.trigger_listeners` or `TalentDefinition.trigger_listeners`.

```gdscript
var listener := TriggerListenerDefinition.new()
listener.event = "on_kill"          # any EventBus signal name
listener.target_self = true         # effects target the trigger bearer
listener.conditions = [TriggerConditionSourceIsSelf.new()]  # only my kills
listener.effects = [heal_effect]    # what happens
```

**Available events**: any signal on `EventBus` — see the full vocabulary near the end of this doc.

**Trigger conditions** (filter when effects fire):
- `TriggerConditionSourceIsSelf` / `TriggerConditionTargetIsSelf` — event participant is trigger bearer
- `TriggerConditionEventEntityFaction` — source/target is enemy/ally relative to bearer
- `TriggerConditionAbilityId` — specific ability caused the event
- `TriggerConditionStatusId` — specific status involved
- `TriggerConditionHpThreshold` — bearer HP above/below threshold
- `TriggerConditionTargetHitByTag` — target was recently hit by ability with tag
- `TriggerConditionNotCrit` — hit was NOT a crit

**Coverage**: Heavy. Used by `status_factory.gd`, `mod_combo_factory.gd`, `passive_tree_factory.gd`, `gear_unique_factory.gd`, and `warped_enemy_data.gd`. Statuses register/unregister listeners automatically on apply/expire, so a trigger attached to a `StatusEffectDefinition` needs no wiring.

### Enemy Skills (Cooldown Abilities)

`EnemyDefinition.skills: Array[SkillDefinition]` — enemies can have cooldown-based abilities beyond auto-attack. BehaviorComponent checks abilities by priority before falling back to auto-attack.

```gdscript
var skill := SkillDefinition.new()
skill.skill_name = "War Cry"
skill.unlock_level = 1
skill.ability = war_cry_ability  # AbilityDefinition with effects, targeting, cooldown
def.skills = [skill]
```

AbilityComponent evaluates conditions (HP thresholds, stack counts, entity counts, etc.) and BehaviorComponent only fires if targets resolve and conditions pass.

**Coverage**: Used by `ancient_troll`, `caster`, `goblin_king`, `heart_of_the_deep`, `stalker`, `warped_colossus`, `warped_enemy`. Basic roles (fodder, swarmer, brute, carrier, guardian, herald) still run auto-attack only.

### Choreography System (Boss Abilities)

Multi-phase ability sequences: wind-up → hit frame → displacement → branch → recovery. Defined as data on `AbilityDefinition.choreography: ChoreographyDefinition`.

```gdscript
var choreo := ChoreographyDefinition.new()
var phase0 := ChoreographyPhase.new()
phase0.animation = "wind_up"
phase0.exit_type = "anim_finished"      # "anim_finished", "wait", "displacement_complete"
phase0.default_next = 1

var phase1 := ChoreographyPhase.new()
phase1.effects = [area_damage]
phase1.hit_frame = 3                    # fire on this animation frame (-1 = immediate)
phase1.set_invulnerable = true
phase1.exit_type = "wait"
phase1.wait_duration = 0.5
phase1.default_next = -1                # -1 = end choreography

choreo.phases = [phase0, phase1]
ability.choreography = choreo
```

Each phase can: play animation, fire effects on hit frame, execute displacement, retarget, set untargetable/invulnerable, branch conditionally, wait for duration.

**Branching**: Phases with `exit_type = "wait"` evaluate `branches: Array[ChoreographyBranch]` each frame. Each branch has a condition Resource and a `next_phase` index. First passing branch wins. Timeout falls through to `default_next`.

**One executor.** `ChoreographyRunner` (`scripts/components/choreography_runner.gd`) is host-agnostic and runs choreography for **both** the player (combo graphs) and `enemy.gd` (boss/elite sequences). enemy.gd's private duplicate was retired 2026-07-21, so a behavior change now lands in exactly one place.

Hosts implement the duck-typed `choreo_*` contract listed at the top of the runner. Enemies additionally implement `choreo_displacement_active()`, backing the `"displacement_complete"` exit type: charge/leap phases hold until the DisplacementSystem clears `is_channeling`, with a `duration + 1.5s` watchdog so a displacement that never ran can't hard-lock the boss in an invulnerable state.

Stun/freeze interrupts choreography — genuinely, as of that migration. Before it, enemy.gd's choreography early-return preceded its stun check, making the interrupt branch unreachable; a stunned boss kept executing its attack.

**Coverage**: Heavy on both sides. Bosses/elites: `goblin_king`, `heart_of_the_deep`, `warped_colossus`, `ancient_troll`. Player: every one of the 12 kits' light/heavy/channel graphs plus Q/E skills, via `ChainFactory` and `SkillFactory`. See "Combo-Chain Combat Layer" above and `docs/boss_authoring_reference.md`.

### Displacement System

`DisplacementSystem` handles throws, knockbacks, pulls, charges, teleports with on-arrival effects. Currently only basic knockback (via `apply_knockback()`) is used.

```gdscript
var disp := DisplacementEffect.new()
disp.displaced = "target"              # "target" or "self" (charge)
disp.destination = "away_from_source"  # "to_target", "toward_source", "random_away"
disp.motion = "arc"                    # "arc", "linear", "instant"
disp.duration = 0.5
disp.arc_height = 40.0
disp.distance = 80.0
disp.on_arrival_displaced_effects = [stun_effect]  # fire on landing
```

Displacement cancels projectile tracking on the displaced entity, suppresses movement during flight, plays optional `displacement_animation`, and supports `bounce_distance` on arrival.

`modifier_component.has_negation("Displacement")` = entity immune to displacement (Anchored).

### Ability Conditions

Gates on ability firing. Evaluated by AbilityComponent before BehaviorComponent can request the ability.

- `ConditionHpThreshold` — self/any_ally/any_enemy HP above/below %
- `ConditionStackCount` — self/any_enemy has N+ stacks of status
- `ConditionEntityCount` — N+ enemies/allies exist (optionally within range)
- `ConditionNoActiveSummon` — no living summon with given ID
- `ConditionCorpseExists` — allied/enemy corpse available
- `ConditionTakingDamage` — entity hit within N seconds (optionally by ability tag)

**Coverage**: Used across `chain_factory.gd`, `skill_factory.gd`, `status_factory.gd`, `mod_combo_factory.gd`, `passive_tree_factory.gd`, `gear_unique_factory.gd`, and the boss data factories. The two input conditions (`ConditionInputBuffered`, `ConditionInputHeld`) are the combo layer's branch vocabulary and are evaluated by the host, not by AbilityComponent.

### Ground Zones

Persistent AoE areas that tick effects on entities within radius. Spawned via `GroundZoneEffect` through EffectDispatcher → `CombatOrchestrator.spawn_ground_zone()`.

```gdscript
var zone := GroundZoneEffect.new()
zone.radius = 40.0
zone.duration = 4.0
zone.tick_interval = 0.5
zone.target_faction = "enemy"  # or "ally"
zone.tick_effects = [DealDamageEffect, ApplyStatusEffectData]
```

Zone ticks run in `CombatOrchestrator._tick_ground_zones()`. Uses SpatialGrid for proximity.

**Coverage**: Heavy. Weapons (`weapon_factory.gd`), player kits (`chain_factory.gd`, `skill_factory.gd`), class mods, mod combos, gear uniques, and enemy factories (`caster`, `guardian`, `herald`, `goblin_king`, `heart_of_the_deep`, `warped_colossus`, `warped_enemy`).

### Aura System

StatusEffectDefinitions with `aura_radius > 0` and `aura_tick_effects` automatically pulse effects to nearby entities each tick via `StatusEffectComponent._execute_aura_tick()`.

```gdscript
aura_status.aura_radius = 100.0
aura_status.aura_target_faction = "ally"  # or "enemy"
aura_status.aura_tick_effects = [ApplyStatusEffectData]  # buff/debuff per tick
```

Uses SpatialGrid. Applied to bearer at spawn via `EnemyDefinition.on_spawn_statuses`.

**Coverage**: Herald enemy only (`herald_data.gd`). Still the cheapest untapped lever for enemy design.

### VFX System

`VfxManager` auto-handles ability and status VFX via EventBus. Zero manual wiring needed.

- **Ability VFX**: Set `AbilityDefinition.vfx_layers: Array[VfxLayerConfig]`. One-shot on ability use.
- **Status VFX**: Set `StatusEffectDefinition.vfx_layers` (looping while active) and/or `on_stack_vfx_layers` (one-shot per application).

```gdscript
var layer := VfxLayerConfig.new()
layer.sprite_frames = my_frames
layer.animation = "loop"
layer.start_animation = "intro"   # optional intro before loop
layer.end_animation = "outro"     # optional outro on removal
layer.offset = Vector2(0, -10)
layer.scale = Vector2(1.5, 1.5)
```

**Two different mechanisms own visuals — don't confuse them:**

| Visual | Owner | Why |
|---|---|---|
| **Ability / combo VFX** | the player's **ComboFx overlay** (`player.gd`), NOT `vfx_layers` | The packs' `_Effect` sheets are declared as `<node>_fx` entries in `CharacterData.sprite.anims` and played on an overlay sprite that is **frame-locked to the choreography phase** and **facing-aware**. `AbilityDefinition.vfx_layers` fires once on `on_ability_used` with only offset/scale — strictly weaker. Treat `vfx_layers` on abilities as **dormant by choice**; wiring it there would duplicate working code. |
| **Status VFX** | `StatusEffectDefinition.vfx_layers` → `VfxManager` | This is what `vfx_layers` is genuinely for: a looping overlay that lives as long as the status, with intro/loop/outro phases. |

**Status coverage**: `burning`, `chilled`, `frozen` (`StatusFactory._attach_aura()` → `StatusVfxFactory`, added 2026-07-21). Before that, statuses had **no** visual at all — an afflicted enemy looked identical to a healthy one.

Adding one to another status is a single line in its `_build_*`:

```gdscript
_attach_aura(def, "fire")               # or "ice" / "poison"
_attach_aura(def, "ice", Vector2(0.8, 0.8))   # lighter states read smaller
```

`StatusVfxFactory` slices the Minifantasy Spell Effects **Aura** sheets, whose three rows map 1:1 onto `VfxLayerConfig` (row 0 → `start_animation`, row 1 → `animation` loop, row 2 → `end_animation`; 32px, 8 frames/row, 10fps). Missing sheets degrade to "no overlay", never to a broken status. Only fire/ice/poison sheets are wired — shock/void statuses have no aura yet.

### Talent Tree System

Fully wired data model. `TalentDefinition` carries modifiers, trigger listeners, ability modifications, and apply_statuses. `TalentTreeDefinition` validates pick order (intro → branch tier progression → capstone). `AbilityModification` adds effects to existing abilities or modifies cooldowns.

`CharacterDefinition.talent_tree` holds the tree. Entity setup reads `talent_picks` and registers all talent effects.

**Coverage**: None — no character defines a `talent_tree`. **Superseded in practice** by the account-wide passive tree (`data/passive_tree.gd`, 59 nodes, `PassiveTreeFactory`, `ProgressionManager` allocation API) plus the per-run level-up ability upgrades (`data/ability_upgrades.gd`). Treat `TalentDefinition` / `TalentTreeDefinition` as dormant engine surface, not as the progression plan. See `docs/passive_tree.md`.

### Summon System

Two distinct paths, and picking the wrong one is a common mistake:

- **Enemy-side** — implemented. `SummonEffect.summon_id` is an `EnemyRegistry` id; `CombatOrchestrator.spawn_summon()` refills the summoner's retinue up to `max_active` live adds, tagging each with a `summoned_by` meta. Used by `goblin_king_data.gd`.
- **Player-side** — deliberately *not* routed through `SummonEffect`. Pets are autonomous entities with their own scripts (`fire_familiar.gd`, `blood_elemental.gd`, `spirit_guardian.gd`, `holy_hammer.gd`, `orbit_orb.gd`, `summon_altar.gd`). Calling `spawn_summon()` from player content emits a `push_warning` and does nothing. Per project rule, pets own their locomotion — never lerp-glue them to the player.

### Death Prevention

`StatusEffectDefinition.prevents_death = true` — HP clamped to 1 on lethal damage. Fires `on_death_prevented_effects`, then the status self-removes. Wired in HealthComponent + StatusEffectComponent.

### Thorns

`StatusEffectDefinition.thorns_percent > 0` — reflects that fraction of incoming damage back to attacker. Fires reflected HitData. Wired in `StatusEffectComponent.notify_hit_received()`.

### Taunt

`StatusEffectDefinition.grants_taunt = true` + `taunt_radius` — enemies within radius prioritize targeting this entity. Tracked by StatusEffectComponent. BehaviorComponent doesn't currently read taunt state for targeting (would need wiring in target resolution).

### Targeting Count Threshold

`StatusEffectDefinition.targeting_count_threshold` + `targeting_count_status` — when N+ enemies are targeting the bearer, auto-apply a status. Checked each status tick. Wired in StatusEffectComponent.

### Damage Type Conversion

`ConversionDefinition` on ModifierComponent. DamageCalculator Step 2 checks `source.modifier_component.get_first_conversion(damage_type)`. First matching conversion wins. True damage immune.

### Shield from Damage Reduction

`StatusEffectDefinition.shield_on_hit_absorbed_percent` — accumulates shield from DR-mitigated damage. `shield_cap_percent_max_hp` caps the total. Shield applies on status expiry.

### Overflow Chain

`OverflowChainEffect` — overkill damage chains to nearest unhit enemy. If that also overkills, keeps chaining up to `max_chains`. Optional `heal_percent` heals source for total damage dealt.

### Resurrection

`ResurrectEffect` dispatches to `CombatOrchestrator.revive_entity()`, which is **still a stub** (`push_warning`, no behavior). `get_nearest_corpse()` and the orchestrator's `corpses` list are real; only the revival itself is unimplemented. `ConditionCorpseExists` will evaluate correctly against that list.

---

## Two-Layer Mod System

Mods split into two families that never mix. Full reference: `docs/class_mod_system.md`.

| Layer | Data | Applies to | Count |
|-------|------|-----------|-------|
| **Generic mods** | `data/mods.gd` | Any weapon whose capability tags match. Resolved by `data/mod_applicability.gd`. | 18 |
| **Class mods** | `data/class_mods.gd` → `ClassModFactory` | One class's kit — modifies that kit's chain/skill primitives. | 48 (4 per class × 12) |

Generic mods carry applicability tags; kits carry capability tags; the resolver decides what can slot where, including the switch-character edge case. Generic-mod pair/triple interactions are catalogued in `docs/mod_interaction_matrix.md` and resolved at runtime by `ComboRegistry` → `ComboDetector` → `ComboEffectResolver`, with discovery state in `CodexManager`.

## Descent & Level Streaming

In `use_descent_mode` the arena is assembled from **blocks** rather than one authored level:

| Piece | File | Role |
|-------|------|------|
| `BlockManager` | `scripts/systems/block_manager.gd` | Selects and streams blocks. |
| `DepthTracker` | `scripts/systems/depth_tracker.gd` | Spatial depth 0.0–1.0, pushed to `GameManager.set_descent_depth()` once per frame by MainArena. |
| `LdtkLevelDirector` | `scripts/systems/ldtk_level_director.gd` | Level/biome sequencing. |
| `LdtkLoader` | `scripts/systems/ldtk_loader.gd` | Parses `.ldtkl`, builds collision, spawn zones, exits, decoration. |
| `LdtkExitZone` | `scripts/systems/ldtk_exit_zone.gd` | Block-to-block transitions. |
| `FlowField` | `scripts/systems/flow_field.gd` | 8px navigation grid with amortized flood fill — enemy pathing through block geometry. Orchestrator-owned. |

Blocks live in `blocks/{caves,crypt,nmrealm}/` as `.block` text sketches, compiled by `tools/block_compiler.py` into `.ldtkl` + PNG previews in `blocks/previews/`. **Authoring path: `docs/block_sketch_workflow.md` and the `/blockgen` skill — do not hand-paint.**

## Audio

`AudioManager` (autoload) routes SFX and music; `data/factories/sound_table.gd` maps ~54 sound ids to assets. Weapon fire is wired through `on_ability_used`. Tooling and per-sound status: `docs/audio_pipeline.md`, `docs/audio_asset_manifest.md`.

---

## Damage Pipeline

8-step in `DamageCalculator.calculate_damage()`:
1. Base damage (+ attribute scaling)
2. Damage type conversion
3. Offensive modifiers (source "bonus" for type + "All")
4. Dodge check (target "dodge_chance")
5. Block check (target "block_chance" + "block_mitigation")
6. Resistance (`resist / (resist + 100)` reduction, reduced by source "pierce")
6.5. Damage taken modifiers (target "damage_taken")
7. Vulnerability (target "vulnerability" per-type + "All")
8. Crit (source "crit_chance" + "crit_multiplier")

Healing pipeline in `calculate_healing()`: base → healing bonus → healing received → crit.

Curse inversion: `StatusEffectDefinition.curse_damage_type != ""` — healing on cursed target converts to damage of that type. Runs through resist + vulnerability only.

## Targeting Types

BehaviorComponent `_resolve_targets_internal()` supports:
`nearest_enemy`, `nearest_enemies`, `furthest_enemy`, `highest_hp_enemy`, `self_centered_burst`, `all_enemies_in_range`, `all_allies`, `lowest_hp_ally`, `lowest_stacks_enemy`, `frontal_rectangle`, `nearest_enemy_targeting_owner`, `most_recently_healed_enemy`, `grab_nearest_throw_furthest`, `self`

TargetingRule also supports: `max_range`, `max_targets`, `height` (for frontal_rectangle), `min_nearby` + `nearby_radius` (cluster filter), `target_status_id` (for lowest_stacks).

## Effect Types

All in `data/resources/effects/`. Each is a Resource with @export fields, zero behavior. EffectDispatcher handles execution.

| Effect | What it does |
|--------|-------------|
| `DealDamageEffect` | Full damage pipeline hit. Leech auto-applied if source has "leech" modifier. |
| `HealEffect` | Healing pipeline. Curse-aware. `percent_max_hp` for %-based heals. |
| `ApplyStatusEffectData` | Apply status. `apply_to_self` for self-buffs. |
| `ApplyShieldEffect` | Add shield HP with attribute scaling. |
| `ApplyModifierEffectData` | Add modifier directly (bypasses status system). |
| `AreaDamageEffect` | AOE damage around target position via SpatialGrid. |
| `DisplacementEffect` | Throw/knockback/pull/charge with on-arrival effects. |
| `SpawnProjectilesEffect` | Spawn projectiles via ProjectileManager. Patterns: radial, aimed_single, spread, at_targets. |
| `CleanseEffect` | Remove statuses by polarity or specific ID. |
| `ConsumeStacksEffect` | Consume stacks, fire `per_stack_effects` per stack consumed. |
| `GroundZoneEffect` | Persistent AoE zone with tick effects. |
| `SetMaxStacksEffect` | Set status to max stacks (optionally gated by talent_id). |
| `OverflowChainEffect` | Overkill chains to nearby enemies. |
| `ResurrectEffect` | Revive nearest same-faction corpse (stub). |
| `SummonEffect` | Spawn summon entity (stub). |
| `SpawnTelegraphEffect` | Spawn a telegraph indicator via `TelegraphManager`; used for boss wind-ups and area warnings before hit-frame. |

## Debug Tools

**DebugDraw** (`CombatOrchestrator.debug_draw`): Toggle with debug panel button. Visualizes targeting areas and ability hitboxes on `on_ability_used`. Set `debug_draw.enabled = true`, optionally filter with `debug_draw.ability_filter = ["ability_id"]`.

**Entity Inspector** (F5): Click-to-inspect overlay. Shows all entity state: HP, stats, behavior, abilities with cooldowns, active statuses with stacks/duration, modifiers, trigger listeners. Mouse wheel scrolls. ESC deselects. Click-select is gated behind the debug toggle.

**Debug Panel** (F1): God mode, level-up, spawn enemies, give weapons/mods/resources, kill all, skip extraction, activate all extractions, spawn keystone, debug draw toggle.

**Hotkeys** (all require `GameManager.debug_mode`):

| Key | Action |
|-----|--------|
| F1 | Toggle debug panel |
| F2 | God mode |
| F3 | Level up once |
| F4 | Skip extraction |
| F5 | Spawn test telegraph / entity-inspector toggle |
| F6 | Spawn miniboss |
| F7 | Spawn final boss |
| F10 | Animation Lab |
| F11 | Training Room panel show/hide |

F8/F9 are Godot's built-in Stop/Pause — never bind them.

**Training Room** (main menu → TRAINING ROOM): flat sandbox with dummies, live class swap, hit-back toggle, live fodder pack, slow-mo, and a DPS meter. **Animation Lab** (F10): re-slice and retime any kit animation, re-pin hit frames, author intro/loop/outro staging for held abilities; writes `data/anim_overrides.json`, which exported builds read. Full guide: `docs/dev_tools.md`.

## EventBus Signal Vocabulary

Source of truth: `scripts/autoloads/event_bus.gd`.

| Group | Signals |
|-------|---------|
| Combat | `on_hit_dealt`, `on_hit_received`, `on_kill`, `on_death`, `on_heal`, `on_crit`, `on_block`, `on_dodge`, `on_overkill`, `on_consecutive_hit`, `on_first_hit`, `on_interrupt`, `on_reflect`, `on_absorb`, `on_friendly_fire` |
| Combo cadence | `on_finisher_hit`, `on_combo_step`, `on_combo_dropped` |
| Status | `on_status_applied`, `on_status_expired`, `on_status_consumed`, `on_status_resisted`, `on_cleanse` |
| Movement | `on_displacement_resisted` |
| Ability | `on_ability_used` |
| Entity | `on_ally_death`, `on_ally_hit_received`, `on_summon`, `on_summon_death`, `on_revive`, `on_transform` |
| System | `on_chain_threshold`, `on_chain_break`, `on_threshold_cross`, `on_echo`, `on_conversion`, `on_idle`, `on_pickup`, `on_doom_trigger`, `on_proximity_enter`, `on_proximity_exit` |

All signals flow through `EventBus` (autoload). TriggerComponent connects lazily via refcount. CombatFeedbackManager, VfxManager, AudioManager, and AchievementManager also listen directly.

## Key File Locations

| System | Files |
|--------|-------|
| Entity contract | `scripts/entities/entity_interface.gd` |
| Player | `scripts/entities/player.gd` |
| Enemy (all types) | `scripts/entities/enemy.gd` |
| Enemy data factories | `data/factories/enemies/*.gd` |
| Enemy registry | `data/factories/enemies/enemy_registry.gd` |
| Status factory | `data/factories/status_factory.gd` |
| Weapon factory | `data/factories/weapon_factory.gd` |
| All Resource types | `data/resources/` (flat) + `data/resources/effects/` + `data/resources/conditions/` + `data/resources/triggers/` |
| Components | `scripts/components/*.gd` |
| Systems | `scripts/systems/*.gd` |
| Orchestrator | `scripts/systems/combat_orchestrator.gd` |
| Arena wiring | `scripts/main_arena.gd` |
| Combo chains / kits | `data/factories/chain_factory.gd`, `data/factories/skill_factory.gd`, `scripts/components/choreography_runner.gd`, `scripts/systems/combat_input_buffer.gd` |
| Game data | `data/characters.gd` (12), `data/weapons.gd` (42), `data/mods.gd` (18), `data/class_mods.gd` (48), `data/trinkets.gd` (9), `data/ability_upgrades.gd` (36), `data/passive_tree.gd` (59), `data/achievements.gd` (12) |
| Class mods | `data/class_mods.gd`, `data/factories/class_mod_factory.gd`, `data/mod_applicability.gd` |
| Progression | `data/passive_tree.gd`, `data/factories/passive_tree_factory.gd`, `data/ability_upgrades.gd`, `data/achievements.gd` |
| Gear | `data/trinkets.gd`, `data/factories/gear_unique_factory.gd` |
| Loot tables | `data/loot_tables.gd` (autoload) |
| Codex / mastery | `scripts/systems/codex_manager.gd`, `scripts/systems/mastery_applicator.gd`, `scripts/resources/codex_entry.gd`, `scripts/resources/mastery_bonus.gd`, `scripts/ui/codex_grid_panel.gd` |
| Level loading / descent | `scripts/systems/ldtk_loader.gd`, `scripts/systems/block_manager.gd`, `scripts/systems/depth_tracker.gd`, `scripts/systems/ldtk_level_director.gd`, `scripts/systems/flow_field.gd`, `data/factories/level_data.gd` |
| Audio | `scripts/managers/audio_manager.gd`, `data/factories/sound_table.gd` |
| Dev tools | `scripts/ui/anim_lab_panel.gd`, `scripts/ui/training_panel.gd`, `data/anim_overrides.json` |
| Save file | `user://progression.json` (written by `ProgressionManager`) |

## See Also

| Doc | Contents |
|-----|---------|
| `docs/combat_chain_architecture.md` | The combo-chain layer: combo-graph-as-choreography, input conditions, `ChoreographyRunner`, kit composition |
| `docs/mechanical_vocabulary.md` | Game grammar: damage types, status effects, weapon behaviors, mod effects, class-mod ops, trigger events |
| `docs/core_framework_decisions.md` | Math baselines: damage formula, XP curve, phase scaling, extraction timing, instability thresholds, economy |
| `docs/class_mod_system.md` | Two-layer mod model, applicability resolver, per-class mod rosters |
| `docs/mod_interaction_matrix.md` | Generic-mod pairs and triples with resolved effects |
| `docs/passive_tree.md` | Passive tree data contract, gate rules, render recipe |
| `docs/boss_authoring_reference.md` | Boss/miniboss choreography patterns and telegraphs |
| `docs/dev_tools.md` | Training Room and Animation Lab |
| `docs/weapon-scaling-reference.md` | Per-weapon base stats and mod synergies (v1 universal weapons only) |
| `docs/ldtk_schema.md` | LDtk contract: entity defs, enums, IntGrid values, layer stack |
| `docs/ldtk_workflow.md` | LDtk authoring: add a biome, add a level, biome asset map |
| `docs/block_sketch_workflow.md` | Descent block authoring via text sketches + `tools/block_compiler.py` |
| `docs/diagrams.md` | Mermaid views of the same systems |
