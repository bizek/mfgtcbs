# Engine Reference

Component-based combat engine. All content = Resource definitions routed through EffectDispatcher. New enemies, abilities, statuses, weapons = data factories, zero code changes.

## Architecture at a Glance

```
Autoloads:  EventBus, GameManager, ProgressionManager, UpgradeManager, EnemySpawnManager, ExtractionManager
Scene-owned: CombatOrchestrator (child of MainArena)
  Children:  ProjectileManager, VfxManager, DisplacementSystem, CombatFeedbackManager, DebugDraw
```

Every entity (player, enemy, summon) owns 6 components created in `_init()` or `_ready()`:
- `health: HealthComponent` — HP, shield, death prevention
- `modifier_component: ModifierComponent` — flat modifier list + cached query
- `ability_component: AbilityComponent` — skill bar, cooldowns, conditions
- `behavior_component: BehaviorComponent` — AI loop / auto-attack timer, target resolution
- `status_effect_component: StatusEffectComponent` — active statuses, modifier sync, aura ticks
- `trigger_component: TriggerComponent` — EventBus listeners, condition evaluation, effect dispatch

Entity contract: see `scripts/entities/entity_interface.gd` for required properties/methods.

Orchestrator tick order per frame: SpatialGrid rebuild → StatusEffect.tick → AbilityComponent.tick_cooldowns → BehaviorComponent.tick (enemies only; player ticks own behavior in _physics_process).

## The Effect Pipeline

All game effects route through `EffectDispatcher.execute_effects(effects, source, targets, ability, combat_manager)`. This is THE dispatch hub. Never execute effects manually — always go through EffectDispatcher.

`BehaviorComponent` resolves targets via `_resolve_targets_internal(TargetingRule, entity)` using SpatialGrid, then emits `ability_requested` or `auto_attack_requested`. The entity handler calls `EffectDispatcher.execute_effects()`.

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

---

## Unused / Underleveraged Systems

Everything below is fully wired and functional but has zero or minimal content using it. These are the systems where new content can be created purely through data.

### Trigger System

`TriggerComponent` connects to EventBus signals and dispatches effects when conditions pass. Content attaches triggers via `StatusEffectDefinition.trigger_listeners` or `TalentDefinition.trigger_listeners`.

```gdscript
var listener := TriggerListenerDefinition.new()
listener.event = "on_kill"          # any EventBus signal name
listener.target_self = true         # effects target the trigger bearer
listener.conditions = [TriggerConditionSourceIsSelf.new()]  # only my kills
listener.effects = [heal_effect]    # what happens
```

**Available events**: `on_hit_dealt`, `on_hit_received`, `on_kill`, `on_crit`, `on_block`, `on_dodge`, `on_heal`, `on_death`, `on_status_applied`, `on_status_expired`, `on_absorb`, `on_displacement_resisted`, `on_overkill`, `on_revive`, `on_status_resisted`, `on_summon`, `on_summon_death`, `on_ability_used`

**Trigger conditions** (filter when effects fire):
- `TriggerConditionSourceIsSelf` / `TriggerConditionTargetIsSelf` — event participant is trigger bearer
- `TriggerConditionEventEntityFaction` — source/target is enemy/ally relative to bearer
- `TriggerConditionAbilityId` — specific ability caused the event
- `TriggerConditionStatusId` — specific status involved
- `TriggerConditionHpThreshold` — bearer HP above/below threshold
- `TriggerConditionTargetHitByTag` — target was recently hit by ability with tag
- `TriggerConditionNotCrit` — hit was NOT a crit

**Current usage**: Zero content uses triggers. TriggerComponent is fully wired — statuses register/unregister listeners automatically on apply/expire.

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

**Current usage**: All 8 enemy types only have auto_attack. No enemy uses skills.

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

Executor lives on `enemy.gd` (`_start_choreography()` through `_end_choreography()`). Stun interrupts choreography. Player currently lacks choreography execution but the pattern is identical.

**Current usage**: Zero content. Fully ported and functional.

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

**Current usage**: Zero content uses ability conditions.

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

**Current usage**: Only Void Mortar weapon (single-tick detonation pattern).

### Aura System

StatusEffectDefinitions with `aura_radius > 0` and `aura_tick_effects` automatically pulse effects to nearby entities each tick via `StatusEffectComponent._execute_aura_tick()`.

```gdscript
aura_status.aura_radius = 100.0
aura_status.aura_target_faction = "ally"  # or "enemy"
aura_status.aura_tick_effects = [ApplyStatusEffectData]  # buff/debuff per tick
```

Uses SpatialGrid. Applied to bearer at spawn via `EnemyDefinition.on_spawn_statuses`.

**Current usage**: Herald enemy only.

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

**Current usage**: No content has VFX configured. System is fully wired.

### Talent Tree System

Fully wired data model. `TalentDefinition` carries modifiers, trigger listeners, ability modifications, and apply_statuses. `TalentTreeDefinition` validates pick order (intro → branch tier progression → capstone). `AbilityModification` adds effects to existing abilities or modifies cooldowns.

`CharacterDefinition.talent_tree` holds the tree. Entity setup reads `talent_picks` and registers all talent effects.

**Current usage**: Resource types exist. No character has a talent tree defined.

### Summon System

`SummonEffect` resource type exists. `EffectDispatcher` routes to `CombatOrchestrator.spawn_summon()` which is currently a stub (`push_warning`). To implement: create summon entity from template, register with orchestrator, track in `source._active_summons`.

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

## Debug Tools

**DebugDraw** (`CombatOrchestrator.debug_draw`): Toggle with debug panel button. Visualizes targeting areas and ability hitboxes on `on_ability_used`. Set `debug_draw.enabled = true`, optionally filter with `debug_draw.ability_filter = ["ability_id"]`.

**Entity Inspector** (F5): Click-to-inspect overlay. Shows all entity state: HP, stats, behavior, abilities with cooldowns, active statuses with stacks/duration, modifiers, trigger listeners. Mouse wheel scrolls. ESC deselects.

**Debug Panel** (F1): God mode, level-up, spawn enemies, give weapons/mods/resources, kill all, skip extraction, activate all extractions, spawn keystone, debug draw toggle.

## EventBus Signal Vocabulary

Combat: `on_hit_dealt`, `on_hit_received`, `on_kill`, `on_death`, `on_heal`, `on_crit`, `on_block`, `on_dodge`, `on_overkill`, `on_reflect`, `on_absorb`
Status: `on_status_applied`, `on_status_expired`, `on_status_consumed`, `on_status_resisted`, `on_cleanse`
Movement: `on_displacement_resisted`
Ability: `on_ability_used`
Entity: `on_summon`, `on_summon_death`, `on_revive`
System: `on_chain_threshold`, `on_conversion`, `on_doom_trigger`

All signals flow through `EventBus` (autoload). TriggerComponent connects lazily via refcount. CombatFeedbackManager and VfxManager also listen directly.

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
| Game data | `data/characters.gd`, `data/weapons.gd`, `data/mods.gd` |
