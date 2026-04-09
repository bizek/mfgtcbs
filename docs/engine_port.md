# Engine Port — Session-by-Session Build Plan

This document is the master plan for porting the autobattler engine framework into Extraction Survivors. It replaces ad-hoc prototype patterns with a scalable, data-driven architecture where new abilities, status effects, enemies, weapons, and talents are created entirely as Resource definitions — zero code changes needed for new content.

**Source engine:** `M:\autobattler` (Hans's autobattler project)
**Target project:** This repo (Extraction Survivors / mfgtcbs)

**How to use this doc:** Each session, run `/implement` with the next unchecked task from the build order. Read this doc first to understand what you're building and why. Read the referenced source files from `M:\autobattler` to understand the pattern. Then implement in this project, adapting for top-down survivors gameplay where noted.

**Rule:** Never invent a pattern when the source engine has one. Read the source implementation, understand it, adapt it. The whole point is pattern consistency across both projects.

---

## Architecture Overview

The engine is built in layers. Each layer depends only on layers above it. Build in order — don't skip ahead.

```
Layer 0: Foundation ──── EventBus, HitData, ModifierDefinition
Layer 1: Core Math ───── ModifierComponent, DamageCalculator
Layer 2: Definitions ─── All Resource types (effects, statuses, abilities, triggers, conditions, choreography, VFX, projectiles)
Layer 3: Components ──── EffectDispatcher, HealthComponent, StatusEffectComponent, TriggerComponent, AbilityComponent, BehaviorComponent
Layer 4: Systems ─────── ProjectileManager, VfxManager, DisplacementSystem, CombatFeedbackManager
Layer 5: Orchestration ─ Entity, CombatManager, MovementSystem
Layer 6: Content ─────── Rebuild weapons/characters/enemies/mods as data definitions
Layer 7: Documentation ─ CLAUDE.md rewrite, pattern guides
```

---

## Build Order

### Layer 0: Foundation

These have zero dependencies. Build all three in one session.

#### 0A — EventBus
- [ ] **What:** Global autoload with 20+ signals for all combat events
- [ ] **Source:** `M:\autobattler\autoloads\event_bus.gd`
- [ ] **Target:** `scripts/autoloads/event_bus.gd` (register as autoload in project.godot)
- [ ] **Signals to port:**
  - Combat: `on_hit_dealt(source, target, hit_data)`, `on_hit_received(source, target, hit_data)`, `on_kill(killer, victim)`, `on_death(entity)`, `on_heal(source, target, amount)`, `on_crit(source, target, hit_data)`, `on_block(source, target, hit_data, mitigated)`, `on_dodge(source, target, hit_data)`, `on_overkill(killer, victim, overkill_amount)`, `on_reflect(source, target, hit_data)`, `on_absorb(entity, hit_data, absorbed)`
  - Status: `on_status_applied(source, target, status_id, stacks)`, `on_status_expired(entity, status_id)`, `on_status_consumed(entity, status_id, stacks)`, `on_cleanse(source, target, status_id)`
  - Movement: `on_displacement_resisted(resisted_by, attempted_by)`
  - Ability: `on_ability_used(source, ability)`
  - Summons: `on_summon(summoner, summon)`, `on_summon_death(summoner, summon)`
- [ ] **Adaptation:** Keep existing CombatManager.damage_dealt and entity_killed signals temporarily. They'll be replaced by EventBus signals in Layer 3. Don't break existing consumers yet.
- [ ] **Test:** EventBus autoloads without errors. Signals exist (connect/emit manually from debug panel to verify).

#### 0B — HitData
- [ ] **What:** RefCounted data carrier for damage events. Replaces passing raw floats through the damage pipeline.
- [ ] **Source:** `M:\autobattler\systems\hit_data.gd`
- [ ] **Target:** `scripts/systems/hit_data.gd`
- [ ] **Properties:** `amount`, `damage_type`, `original_damage_type`, `is_crit`, `is_blocked`, `is_dodged`, `block_mitigated`, `dr_mitigated`, `source`, `target`, `ability`, `is_reflected`
- [ ] **Factory:** `static func create(amount, damage_type, source, target, ability) -> HitData`
- [ ] **Test:** Can instantiate HitData, set properties, read them back.

#### 0C — ModifierDefinition
- [ ] **What:** Universal modifier Resource. The building block for ALL stat modification — equipment, talents, status effects, zone modifiers.
- [ ] **Source:** `M:\autobattler\data\modifier_definition.gd`
- [ ] **Target:** `data/resources/modifier_definition.gd`
- [ ] **Properties:**
  - `target_tag: String` — What it modifies: "damage", "Physical", "Fire", "armor", "crit_chance", "attack_speed", "move_speed", "All", etc.
  - `operation: String` — How: "add", "bonus", "multiply", "resist", "negate", "pierce", "cooldown_reduce", "duration_modify", "range_modify", "received_bonus", "vulnerability"
  - `value: float`
  - `min_stacks: int` — Only active at this+ stack count (for status-bound modifiers)
  - `decay: bool` — Scale linearly full→0 over status duration
  - `source_name: String` — For debug/UI display
- [ ] **Adaptation:** Tag names use this game's flat stat vocabulary ("damage", "armor", "max_hp", "attack_speed", "crit_chance", "crit_multiplier", "move_speed", "pickup_radius", "projectile_count", "pierce", "projectile_size") instead of the autobattler's attribute names ("Str", "Dex", "Stam"). The system is tag-agnostic — it doesn't care what the strings are.
- [ ] **Test:** Can create ModifierDefinition with various tag/operation combos.

---

### Layer 1: Core Math

Depends on Layer 0. Build both in one session.

#### 1A — ModifierComponent
- [ ] **What:** Flat list of active ModifierDefinitions with lazy-rebuild cache. Supports any number of modifiers from any source (upgrades, equipment, status effects, talents, zone buffs). Replaces the prototype's flat_mods/percent_mods dictionaries.
- [ ] **Source:** `M:\autobattler\entities\components\modifier_component.gd`
- [ ] **Target:** `scripts/components/modifier_component.gd`
- [ ] **Core API:**
  - `add_modifier(mod: ModifierDefinition, source_id: String = "")` — Add a modifier, mark cache dirty
  - `remove_modifiers_by_source(source_id: String)` — Remove all modifiers from a source
  - `sum_modifiers(tag: String, operation: String) -> float` — O(1) cached lookup
  - `has_negation(tag: String) -> bool` — Check if any "negate" modifier exists for tag
  - `get_first_conversion(damage_type: String) -> ConversionDefinition` — For damage type conversion
- [ ] **Cache:** Dictionary keyed by `"tag:operation"`. Rebuilt on first query after dirty flag set. All subsequent queries O(1) until next add/remove.
- [ ] **Stat read pattern:** `base_value + modifier_component.sum_modifiers(stat_name, "add")` then `* (1.0 + modifier_component.sum_modifiers(stat_name, "bonus"))`. This replaces the old `(base + flat) * (1 + pct)` formula with the same math but generic modifier sources.
- [ ] **Migration:** When wiring into player.gd, convert existing upgrade application to create ModifierDefinitions. Level-up upgrades with type="flat" become operation="add", type="percent" become operation="bonus". All consumers switch from `get_stat()` dict lookup to `modifier_component.sum_modifiers()`.
- [ ] **Test:** Add modifiers, verify sum_modifiers returns correct values. Verify cache invalidation on add/remove.

#### 1B — DamageCalculator
- [ ] **What:** Stateless 8-step damage pipeline. Replaces the inline `max(raw - armor, 1)` formula in CombatManager.
- [ ] **Source:** `M:\autobattler\systems\damage_calculator.gd`
- [ ] **Target:** `scripts/systems/damage_calculator.gd`
- [ ] **Pipeline:**
  1. **Base damage** = `base_damage * (1.0 + source.modifier_component.sum_modifiers(scaling_attribute, "add") * coefficient)`
  2. **Conversion** — Check source for damage type conversion modifiers
  3. **Offensive modifiers** — `1.0 + source.sum("bonus", damage_type) + source.sum("bonus", "All")`
  4. **Dodge** — Target dodge chance (from modifiers), RNG roll → HitData.is_dodged
  5. **Block** — Target block chance, block percent mitigation → HitData.is_blocked
  6. **Resistance** — `effective_resist = target_resist - source_pierce`, formula: `amount * (1.0 - effective_resist / (effective_resist + K))`
  7. **Damage taken modifiers** — Target's "received_bonus" modifiers (flat DR, percent DR)
  8. **Crit** — Source crit chance, crit multiplier from modifiers, RNG roll → HitData.is_crit
- [ ] **Returns:** HitData with all fields populated
- [ ] **Adaptation:** Step 1 simplified — this game doesn't have attribute scaling coefficients on most weapons. Base damage comes directly from weapon/ability. Steps 4-5 (dodge/block) — dodge exists (Shade passive), block doesn't yet but the pipeline slot exists for free. Step 6 (resistance) — armor becomes a resistance modifier on the target. Formula changes from `max(raw - armor, 1)` to `raw * (1.0 - armor / (armor + K))` — percentage-based, scales better at high values. Choose K=100 (100 armor = 50% reduction).
- [ ] **RNG:** Accept RNG parameter (or use randf()) for future deterministic replay support.
- [ ] **Test:** Calculate damage with known inputs. Verify each step produces expected output. Verify HitData fields are correct.

---

### Layer 2: Data Definitions

Depends on Layer 1. This is the largest layer — split across 2-3 sessions.

#### Session 2A — Effect Types
- [ ] **What:** All Resource subclasses that represent "things that happen" when abilities fire, statuses tick, triggers activate, etc.
- [ ] **Source:** `M:\autobattler\data\` — read each effect file
- [ ] **Target:** `data/resources/effects/` directory
- [ ] **Effect types to create:**
  - `DealDamageEffect` — damage_type, base_damage, scaling_attribute, scaling_coefficient
  - `HealEffect` — base_healing, scaling_attribute, scaling_coefficient, percent_max_hp
  - `ApplyStatusEffectData` — status (StatusEffectDefinition ref), stacks, duration, apply_to_self
  - `ApplyShieldEffect` — base_shield, scaling_attribute, scaling_coefficient
  - `ApplyModifierEffectData` — modifier (ModifierDefinition ref), duration
  - `AreaDamageEffect` — damage_type, base_damage, scaling_attribute, scaling_coefficient, aoe_radius
  - `DisplacementEffect` — displaced, destination, motion, duration, arc_height, distance, on_arrival effects
  - `SpawnProjectilesEffect` — projectile (ProjectileConfig ref), spawn_pattern, count, spawn_offset
  - `CleanseEffect` — count, target_type ("negative"/"positive"/"any"), target_status_id
  - `ConsumeStacksEffect` — status_id, stacks_to_consume, per_stack_effects
  - `OverflowChainEffect` — max_chains, heal_percent, damage_type, max_range
  - `ResurrectEffect` — hp_percent
  - `GroundZoneEffect` — zone_id, radius, duration, tick_interval, target_faction, tick_effects
  - `SetMaxStacksEffect` — status_id, status, required_talent_id
- [ ] **Pattern:** Each effect is a Resource with `@export` properties and zero behavior. Execution logic lives in EffectDispatcher (Layer 3). Effects are pure data.
- [ ] **Test:** Can instantiate each effect type, set properties.

#### Session 2B — StatusEffectDefinition + Conditions + Triggers
- [ ] **What:** Full status effect data model, ability conditions, trigger listeners with typed conditions
- [ ] **Source:** `M:\autobattler\data\status_effect_definition.gd`, `M:\autobattler\data\trigger_listener_definition.gd`, `M:\autobattler\data\condition_*.gd`, `M:\autobattler\data\trigger_condition_*.gd`
- [ ] **Target:** `data/resources/status_effect_definition.gd`, `data/resources/conditions/`, `data/resources/triggers/`
- [ ] **StatusEffectDefinition properties:**
  - Identity: `status_id`, `tags`, `is_positive`
  - Stacking: `max_stacks`, `duration_refresh_mode` ("overwrite"/"max")
  - Duration: `base_duration` (-1 = permanent)
  - Tick: `tick_interval`, `tick_effects: Array[Resource]`
  - Lifecycle effects: `on_apply_effects`, `on_expire_effects`, `on_consume_effects`
  - Reactive: `on_hit_received_effects`, `on_hit_received_damage_filter`, `on_hit_dealt_effects`
  - Modifiers: `modifiers: Array[ModifierDefinition]`
  - CC: `disables_actions`, `disables_movement`
  - Special: `prevents_death`, `curse_damage_type`, `grants_taunt`, `thorns_percent`
  - Aura: `aura_radius`, `aura_target_faction`, `aura_tick_effects`
  - Shield: `shield_on_hit_absorbed_percent`, `shield_cap_percent_max_hp`
  - VFX: `vfx_layers`, `on_stack_vfx_layers`
  - Triggers: `trigger_listeners: Array[TriggerListenerDefinition]`
- [ ] **Ability Condition types:** ConditionHpThreshold, ConditionStackCount, ConditionEntityCount, ConditionNoActiveSummon, ConditionCorpseExists, ConditionTakingDamage
- [ ] **TriggerListenerDefinition:** event, conditions, effects, target_self, target_event_source
- [ ] **Trigger Condition types:** TriggerConditionSourceIsSelf, TriggerConditionTargetIsSelf, TriggerConditionAbilityId, TriggerConditionStatusId, TriggerConditionHpThreshold, TriggerConditionEventEntityFaction, TriggerConditionTargetHitByTag, TriggerConditionNotCrit

#### Session 2C — AbilityDefinition + Choreography + Targeting + ProjectileConfig + VfxLayerConfig
- [ ] **What:** Ability data model, multi-phase choreography, targeting rules, projectile config, VFX layer config
- [ ] **Source:** `M:\autobattler\data\ability_definition.gd`, `M:\autobattler\data\choreography_definition.gd`, `M:\autobattler\data\choreography_phase.gd`, `M:\autobattler\data\choreography_branch.gd`, `M:\autobattler\data\targeting_rule.gd`, `M:\autobattler\data\projectile_config.gd`, `M:\autobattler\data\vfx_layer_config.gd`
- [ ] **Target:** `data/resources/` directory
- [ ] **AbilityDefinition:** ability_id, ability_name, tags, targeting, cooldown_base, mode, conditions, effects, priority, cast_range, hit_frames, vfx_frame, anim_override, hit_frame_override, vfx_layers, target_vfx_layers, hit_targeting, choreography
- [ ] **TargetingRule:** type, max_range, max_targets, height, min_nearby, nearby_radius, target_status_id
  - **Adaptation:** Targeting types adapted for top-down: "nearest_enemy", "nearest_enemies", "self", "all_enemies_in_range", "self_centered_burst", "lowest_hp_ally", "furthest_enemy", "all_allies"
- [ ] **ChoreographyDefinition:** phases: Array[ChoreographyPhase]
- [ ] **ChoreographyPhase:** animation, effects, hit_frame, displacement, retarget, set_untargetable, set_invulnerable, exit_type, wait_duration, default_next, branches
- [ ] **ChoreographyBranch:** condition, next_phase
- [ ] **ProjectileConfig:** motion_type, speed, max_range, arc_height, sprite_frames, animation, visual_scale, hit_radius, pierce_count, on_hit_effects, impact_sprite_frames, impact_animation, impact_aoe_radius, impact_aoe_effects
- [ ] **VfxLayerConfig:** sprite_frames, animation, z_index, offset, scale, start_animation, end_animation

---

### Layer 3: Runtime Components

Depends on Layer 2. Split across 2-3 sessions.

#### Session 3A — EffectDispatcher
- [ ] **What:** Stateless dispatcher that executes all effect types. THE central routing hub for all game effects.
- [ ] **Source:** `M:\autobattler\systems\effect_dispatcher.gd`
- [ ] **Target:** `scripts/systems/effect_dispatcher.gd`
- [ ] **Core function:** `static func execute_effects(effects: Array, source, targets: Array, ability, combat_manager, fallback_source)`
- [ ] **Pattern:** Type-switch on each effect Resource class → delegate to appropriate system (DamageCalculator for DealDamageEffect, StatusEffectComponent for ApplyStatusEffectData, ProjectileManager for SpawnProjectilesEffect, etc.)
- [ ] **Critical:** This replaces ALL inline effect execution. Weapon damage, mod effects, status DOTs, trigger reactions — everything routes through here.

#### Session 3B — StatusEffectComponent + TriggerComponent
- [ ] **What:** Full StatusEffectComponent driven by StatusEffectDefinition resources. TriggerComponent for EventBus-driven reactive effects.
- [ ] **Source:** `M:\autobattler\entities\components\status_effect_component.gd`, `M:\autobattler\entities\components\trigger_component.gd`
- [ ] **Target:** `scripts/components/status_effect_component.gd` (new, replaces prototype inline status code), `scripts/components/trigger_component.gd` (new)
- [ ] **StatusEffectComponent:**
  - Inner class: `ActiveStatus` — definition, stacks, duration_remaining, source, registered_modifier_ids, registered_trigger_ids
  - `apply_status(status_def: StatusEffectDefinition, source: Node2D, stacks: int = 1)` — handles stacking, duration refresh, modifier registration, trigger registration, on_apply_effects
  - `tick(delta)` — tick interval effects, duration countdown, modifier decay sync, aura dispatch
  - `consume_stacks(status_id, count)` — remove stacks, fire on_consume_effects per stack
  - `cleanse(count, polarity)` — remove statuses by type
  - `force_remove_status(status_id)` — cleanup modifiers, triggers, fire on_expire_effects
  - Track: disable_count, movement_disable_count, death_prevention_count
- [ ] **TriggerComponent:**
  - `register_listener(source_id, listener: TriggerListenerDefinition, source_entity)` — lazy EventBus signal connection via refcount
  - `unregister_listeners_for_source(source_id)` — decrement refcount, disconnect if 0
  - `_evaluate_and_dispatch(event, ...)` — check all conditions, fire effects via EffectDispatcher
  - Typed condition evaluation for all TriggerCondition subtypes

#### Session 3C — AbilityComponent + BehaviorComponent + HealthComponent
- [ ] **What:** Ability slot management, AI decision loop, health component integrated with HitData/EventBus
- [ ] **Source:** `M:\autobattler\entities\components\ability_component.gd`, `M:\autobattler\entities\components\behavior_component.gd`, `M:\autobattler\entities\components\health_component.gd`
- [ ] **Target:** `scripts/components/` (new files, replacing prototype components)
- [ ] **AbilityComponent:**
  - Inner class: `AbilitySlot` — definition, cooldown_remaining
  - `setup_abilities(skills: Array)` — populate slots from data
  - `get_highest_priority_ready() -> AbilityDefinition` — for AI ability selection
  - `start_cooldown(ability_id)` — with CDR modifier support
  - `register_ability_modification(target_id, effects, on_arrival, cdr)` — for talents
  - `tick_cooldowns(delta)` — decrement all cooldowns
  - `_check_conditions(ability) -> bool` — evaluate typed condition Resources
- [ ] **BehaviorComponent:**
  - **For enemies:** AI decision loop — get ready abilities, resolve targets, check conditions, fire ability_requested signal
  - **For player:** Input-driven ability trigger (auto-fire weapon = auto-attack ability, future active abilities = manual trigger)
  - Auto-attack timer with attack_speed modifier scaling
  - Targeting resolution via SpatialGrid
- [ ] **HealthComponent:**
  - `apply_damage(hit_data: HitData)` — takes HitData, not raw float. Emits through EventBus.
  - `apply_healing(amount, source)` — emits EventBus.on_heal
  - Shield tracking (absorb before HP)
  - Death prevention check (from status effects with prevents_death)
  - Replaces prototype HealthComponent entirely

---

### Layer 4: Systems

Depends on Layer 3. Split across 2 sessions.

#### Session 4A — ProjectileManager + VfxManager
- [ ] **What:** Pooled projectile system replacing per-node Area2D. Declarative VFX lifecycle.
- [ ] **Source:** `M:\autobattler\systems\projectile_manager.gd`, `M:\autobattler\systems\vfx_manager.gd`, `M:\autobattler\scenes\effects\vfx_effect.gd`
- [ ] **Target:** `scripts/systems/projectile_manager.gd` (rewrite from scratch), `scripts/systems/vfx_manager.gd` (new), `scripts/systems/vfx_effect.gd` (new)
- [ ] **ProjectileManager:** 512-slot parallel arrays. 3 motion types (directional, aimed, homing). Arc parabolic. Pierce tracking. On-hit effect execution via EffectDispatcher. Impact AOE. Single _draw() call.
- [ ] **VfxManager:** EventBus-driven. One-shot ability VFX on on_ability_used. Looping status VFX on on_status_applied, removed on on_status_expired. Three-phase lifecycle (start → loop → end). Deduplication for status VFX.
- [ ] **VfxEffect:** Lightweight AnimatedSprite2D. Factory creates instances. Auto-manages looping/one-shot. Phase sequencing (start → loop → end animation).
- [ ] **Adaptation:** Screen bounds adapted for 480x270 viewport. Projectile pool size may be smaller (256 instead of 512) since this game has fewer simultaneous projectiles than the autobattler.

#### Session 4B — DisplacementSystem + CombatFeedbackManager integration
- [ ] **What:** Knockback/throw/charge system with on-arrival effects. Combat feedback integrated with HitData/EventBus.
- [ ] **Source:** `M:\autobattler\systems\displacement_system.gd`, `M:\autobattler\scenes\run\combat_feedback_manager.gd`
- [ ] **Target:** `scripts/systems/displacement_system.gd` (new), `scripts/ui/combat_feedback_manager.gd` (rewrite)
- [ ] **DisplacementSystem:** Motion types (instant, linear, arc). Destination types (to_target, away_from_source, toward_source, random_away). On-arrival effects via EffectDispatcher.
- [ ] **CombatFeedbackManager:** Already pooled. Rewrite to consume HitData from EventBus.on_hit_dealt instead of CombatManager.damage_dealt. Add damage type coloring from HitData.damage_type. Add crit VFX enhancements.

---

### Layer 5: Orchestration

Depends on Layer 4. 2-3 sessions.

#### Session 5A — Entity rewrite
- [ ] **What:** Player and enemy scripts rewritten to own all components. Choreography execution. Animation state machine.
- [ ] **Source:** `M:\autobattler\entities\entity.gd`
- [ ] **Adaptation:** The autobattler has one Entity class for heroes and enemies. This game has separate player.gd (CharacterBody2D with input) and enemy.gd (CharacterBody2D with AI chase). Keep separate classes but ensure both implement the same component interface:
  - Both own: health (HealthComponent), modifier_component (ModifierComponent), ability_component (AbilityComponent), status_effect_component (StatusEffectComponent), trigger_component (TriggerComponent), behavior_component (BehaviorComponent)
  - Player BehaviorComponent: input-driven (auto-fire weapon ability, future manual abilities)
  - Enemy BehaviorComponent: AI-driven (chase + ability priority)
- [ ] **Choreography execution** lives on each entity (generic, not per-ability code). Both player and enemy can execute choreographed abilities.
- [ ] **CombatManager duck-typing API** (take_damage, get_armor, is_dead, heal, apply_status, apply_knockback) preserved as thin wrappers that delegate to components.

#### Session 5B — CombatManager rewrite
- [ ] **What:** Central orchestrator owning all subsystems. Defined tick order. Spawn/death lifecycle.
- [ ] **Source:** `M:\autobattler\scenes\run\combat_manager.gd`
- [ ] **Target:** Rewrite into scene-owned orchestrator (not autoload)
- [ ] **Tick order:** MovementSystem → StatusEffectComponent.tick() → AbilityComponent.tick_cooldowns() → BehaviorComponent.tick() — for each entity, in this order
- [ ] **Owns:** ProjectileManager, VfxManager, DisplacementSystem, SpatialGrid, CombatFeedbackManager
- [ ] **Adaptation:** Migrate from autoload to scene-owned node. Keep GameManager, ProgressionManager, UpgradeManager as autoloads (they persist across scenes). The existing main_arena.gd orchestration logic merges into the new CombatManager.

#### Session 5C — MovementSystem adaptation
- [ ] **What:** Entity positioning adapted for top-down survivors gameplay
- [ ] **Adaptation:**
  - Player: WASD input-driven movement (keep as-is)
  - Enemies: chase-player AI with per-type behavior overrides (keep as-is, integrate with BehaviorComponent)
  - Displacement: integrate existing knockback with DisplacementSystem for data-driven knockback/throw/charge
- [ ] **Don't port:** Formation positioning, engagement slots, scroll-based movement, hero auto-positioning. These are autobattler-specific.

---

### Layer 6: Content Rebuild

Depends on Layer 5. 3-4 sessions. Rebuild existing game content on top of the new framework.

#### Session 6A — Weapons as AbilityDefinitions
- [ ] **What:** Each weapon becomes an AbilityDefinition with appropriate effects
- [ ] **Mapping:**
  - Standard Sidearm → AbilityDefinition with SpawnProjectilesEffect (pattern: "aimed_single")
  - Frost Scattergun → AbilityDefinition with SpawnProjectilesEffect (pattern: "radial", count: 5, spread)
  - Ember Beam → AbilityDefinition with DealDamageEffect (direct, no projectile) + custom beam VFX
  - Lightning Orb → AbilityDefinition with summon-like persistent orbs (or custom effect type)
  - Void Mortar → AbilityDefinition with GroundZoneEffect (delayed detonation) or choreography (place marker → wait → detonate)
  - Plasma Blade → AbilityDefinition with AreaDamageEffect (arc-shaped) + melee VFX
- [ ] **Weapon mods as modifiers/triggers:**
  - Pierce → ModifierDefinition on projectile config (pierce_count)
  - Chain → TriggerListenerDefinition on on_hit_dealt → SpawnProjectilesEffect at hit target
  - Explosive → ProjectileConfig.impact_aoe_effects
  - Elemental → ApplyStatusEffectData in on_hit_effects
  - Lifesteal → TriggerListenerDefinition on on_hit_dealt → HealEffect (percent of damage)
  - Size → ModifierDefinition (projectile_size bonus)
  - Crit Amp → ModifierDefinition (crit_chance add, crit_multiplier add)
  - Accelerating → Custom ModifierDefinition with ramp logic (may need small code addition)
  - Split → Custom effect or on_expire trigger
  - Gravity → Homing motion_type on ProjectileConfig
  - Ricochet → Pierce + bounds reflection (may need projectile_manager extension)

#### Session 6B — Status effects as StatusEffectDefinitions
- [ ] **What:** Rebuild all 6 status effects as data definitions
- [ ] **Mapping:**
  - Fire/Burning → StatusEffectDefinition with tick_effects: [DealDamageEffect], vfx_layers: [burn particles]
  - Bleed → Same pattern as burning with different values/VFX
  - Cryo/Chilled → StatusEffectDefinition with modifiers: [move_speed bonus -0.3], stacking toward Frozen
  - Frozen → StatusEffectDefinition with disables_actions: true, disables_movement: true
  - Shock → StatusEffectDefinition with on_hit_received_effects: [chain damage] + consumed on first hit
  - Void-Touched → StatusEffectDefinition with on_expire_effects (death explosion) or custom death trigger

#### Session 6C — Characters + Enemies as data factories
- [ ] **What:** Characters become data factories producing entity definitions with abilities, modifiers, passives-as-statuses
- [ ] **Character passives as StatusEffectDefinitions:**
  - Scavenger: StatusEffect with modifiers [pickup_radius bonus +0.25] + loot_find modifier
  - Spark: StatusEffect with modifiers [crit_multiplier add +0.75]
  - Shade: StatusEffect with modifiers [dodge_chance add +0.15] + trigger on dodge → apply invisibility status
  - Warden: StatusEffect with trigger on_hit_received → conditional modifier (armor bonus when below 50% HP)
  - Herald: StatusEffect with modifiers [ability_damage bonus +0.30, ability_cooldown bonus -0.20]
  - Cursed: StatusEffect with modifiers [all stats bonus +0.20] + initial instability
- [ ] **Enemy factories:** Same pattern as autobattler's enemy data factories. Each enemy type gets an EnemyDefinition-style resource with auto-attack ability, optional skills, base stats.

#### Session 6D — Upgrades + Extraction integration
- [ ] **What:** Level-up upgrades become ModifierDefinitions. Evolution recipes use the same system. Extraction mechanics integrate with new EventBus signals.
- [ ] **Upgrades:** Each upgrade creates a ModifierDefinition (operation="add" for flat, operation="bonus" for percent). Evolutions remove prerequisite modifiers and apply evolution modifiers.
- [ ] **Extraction:** Wire extraction events through EventBus. Channel interruption via on_hit_received trigger.

---

### Layer 7: Documentation

After all layers are built and tested.

#### Session 7A — CLAUDE.md rewrite
- [ ] **What:** Full rewrite of project instructions for Claude Code sessions
- [ ] **Contents:**
  - Architecture overview with the layer diagram
  - "When to read what" table (adapted for this project)
  - Data-driven content creation patterns:
    - How to add a new weapon (create AbilityDefinition + ProjectileConfig)
    - How to add a new status effect (create StatusEffectDefinition)
    - How to add a new enemy (create factory with EnemyDefinition)
    - How to add a new character (create factory with passive StatusEffectDefinition)
    - How to add a new trigger (create TriggerListenerDefinition)
    - How to add a new mod (create ModifierDefinition + optional TriggerListener)
  - Performance constraints
  - System dependency map
  - Design pillar checkpoint (keep existing 5 pillars)

#### Session 7B — Pattern reference doc
- [ ] **What:** Detailed reference for each system showing the exact pattern for extending it
- [ ] **For each system:** "Here's how it works, here's a worked example of adding content, here are the files to touch"
- [ ] **Include:** The complete Resource subclass inventory with @export properties

---

## Session Checklist

Every session, before writing code:

1. **Read this doc** to know where you are in the build order
2. **Read the source files** from `M:\autobattler` listed in the current task
3. **Read the existing target files** in this project that will be modified or replaced
4. **Identify adaptation points** — what's different about top-down survivors vs side-scroll autobattle
5. **Build, test, commit**
6. **Update this doc** — check off completed tasks, note any deviations

---

## Adaptation Notes (Top-Down Survivors vs Side-Scroll Autobattle)

These differences affect implementation but not architecture:

| Aspect | Autobattler | Extraction Survivors | Adaptation |
|---|---|---|---|
| **Movement** | Formation-based auto-positioning | WASD player, chase-AI enemies | Keep separate movement systems |
| **Targeting** | Side-scroll: nearest in X direction | Top-down: nearest by distance | TargetingRule uses distance, not X |
| **Viewport** | 320x180 low-res | 480x270 low-res | Adjust screen bounds for projectiles |
| **Stats** | 5 attributes (Str/Dex/Stam/Int/Wis) → derived | Flat stats (damage, armor, etc.) | Use flat stat names as modifier tags |
| **Player control** | Auto-battle (AI controls heroes) | Player-controlled (WASD + auto-fire) | BehaviorComponent has input mode for player |
| **Party** | 4-5 heroes simultaneously | 1 player character | Simpler targeting, no formation |
| **Enemies** | Wave-based scroll encounters | Horde survival spawning | Keep EnemySpawnManager, integrate with new systems |
| **Progression** | Between-run base phase | Hub with workshop/armory | Keep existing hub, wire to new data model |
| **Weapons** | Auto-attack + 6 skill slots | Primary weapon + weapon mods | Weapon = auto-attack ability, mods = modifiers/triggers |
| **Scaling** | Level-based attribute growth | Per-run upgrades (reset each run) | Upgrades create temporary ModifierDefinitions |
