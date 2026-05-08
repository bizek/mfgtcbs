# Architecture Blueprint
### Phase 7 Output | Plain English Code Structure

---

## What This Document Is

This defines HOW the game is built in code — what systems exist, what each is responsible for, how they communicate, and what the data looks like. Everything here is in plain English, not code. But it should be precise enough that translating it to Godot scripts is mechanical, not creative.

**Engine: Godot 4 (GDScript)**

---

## Architecture Principles

### 1. Data-Driven Everything
Anything we'll have 10+ of (weapons, mods, enemies, upgrades, arenas) is defined in DATA FILES, not in code. Adding a new weapon should mean creating a new data entry, not writing a new script. The code is the engine; the data is the fuel.

**Data format: Godot Resource files (.tres) or JSON.**
- Resource files integrate natively with Godot's editor and type system
- JSON works for simpler data (arena layouts, loot tables)
- Choose per system based on complexity

### 2. Scene Tree Architecture
Godot uses a scene tree — everything is a node in a hierarchy. Our architecture follows Godot's strengths:
- Each "system" is an autoloaded singleton (globally accessible manager)
- Game entities (player, enemies, projectiles) are scenes that instance into the world
- UI is a separate canvas layer that reads from game state

### 3. Signal-Based Communication
Systems talk to each other through Godot's signal system (observer pattern). Systems don't directly call each other — they emit signals that other systems listen to. This keeps systems decoupled and testable.

Example: When an enemy dies, the Enemy doesn't call the Loot system directly. Instead, it emits a signal "enemy_died(position, enemy_data)". The Loot system hears that signal and spawns drops. The XP system hears it and grants XP. The Stats system hears it and updates kill count. None of them know about each other.

### 4. Code vs Data Separation

| Code (Built Once) | Data (Added Repeatedly) |
|-------------------|------------------------|
| Stat system that reads/modifies stats | Stat definitions per character/enemy |
| Combat system that processes damage | Weapon definitions with stats/behavior |
| Upgrade system that presents choices | Individual upgrade definitions |
| Enemy spawner that places enemies | Enemy type definitions and spawn tables |
| Loot dropper that spawns pickups | Loot table definitions |
| Arena loader that builds levels | Arena layout data files |
| Audio manager that plays sounds | Sound file references per event |

---

## System Architecture Overview

```
AUTOLOADED SINGLETONS (always running, globally accessible)
├── EventBus            — Global combat signal bus (on_hit_dealt, on_kill, on_status_applied, etc.)
├── GameManager         — Game state machine, phase transitions, run lifecycle, instability
├── UpgradeManager      — Upgrade pool, level-up choices, evolution recipes
├── ExtractionManager   — Extraction channel state, speed multiplier
├── EnemySpawnManager   — Wave composition, spawn timing, difficulty scaling
└── ProgressionManager  — Meta-progression, currency, unlocks, save/load

SCENE-OWNED (child of MainArena, created per run)
└── CombatOrchestrator  — Owns all combat subsystems, manages tick order
    ├── ProjectileManager       — Pooled parallel-array projectiles, _draw() rendering
    ├── VfxManager              — Ability/status VFX lifecycle via EventBus
    ├── DisplacementSystem      — Throws, knockbacks, pulls, charges with on-arrival effects
    ├── CombatFeedbackManager   — Pooled floating damage numbers via _draw()
    └── DebugDraw               — Targeting/hitbox visualization

GAME WORLD (instanced per run — MainArena scene)
├── ArenaFloor (TextureRect)
├── Walls (StaticBody2D × 4)
├── ArenaGenerator (procedural layout: rocks, extraction markers)
├── Player (CharacterBody2D — component-based entity with 6 engine components)
│   ├── Camera2D
│   └── PickupCollector (Area2D — scaled by pickup_radius modifier)
├── CombatOrchestrator (owns all combat subsystems)
├── Enemies (spawned by EnemySpawnManager, registered with CombatOrchestrator)
│   └── All use enemy.gd + EnemyDefinition data factories
├── Extraction Zones (GuardedExtraction, LockedExtraction, SacrificeExtraction, TimedExtraction)
├── Pickups (XP gems, health orbs, loot drops, weapon/mod pickups, keystones)
└── HUD + LevelUpScreen + GameOverScreen + ExtractionSuccessScreen (CanvasLayers)

UI LAYER (separate CanvasLayer, always on top)
├── HUD (health, shield, XP bar, Instability meter, minimap)
├── LevelUpScreen (upgrade choice panel — pauses gameplay)
├── ExtractionUI (channel progress bar, extraction warnings)
├── DamageNumbers (floating text spawned on hits)
├── PhaseTransition (transition overlay between phases)
└── HubUI (hub menus — armory, research, roster, workshop, etc.)
```

---

## Detailed System Responsibilities

### GameManager (Autoload Singleton)

**Purpose:** Owns the game state machine. Knows what phase of play we're in and manages transitions.

**Responsible For:**
- Game state: MENU → HUB → RUN_STARTING → PHASE_ACTIVE → PHASE_TRANSITION → EXTRACTION → RUN_END → HUB
- Phase tracking: which phase (1-5) we're currently in
- Phase timer: how long the current phase has been running
- Run lifecycle: start a run, end a run (extract or death), return to hub
- Pause state: handles game pausing (during level-up, menus, extraction UI)

**Signals Emitted:**
- `run_started` — a new run begins
- `phase_started(phase_number)` — a new phase begins
- `phase_ending(phase_number)` — phase is about to end (triggers extraction windows)
- `phase_ended(phase_number)` — phase has ended, transition starting
- `extraction_successful(phase_number, loot_data)` — player extracted
- `player_died(phase_number, loot_data)` — player died
- `run_ended(result)` — run is over, returning to hub

**Listens To:**
- ExtractionManager: `extraction_complete`
- Player: `player_health_zero`
- Phase timer completion

**Does NOT Do:** Does not handle combat, loot, spawning, or any specific system logic. Only state transitions.

---

### Modifier System (Per-Entity Component)

**Purpose:** Every entity owns a `ModifierComponent` — a flat list of `ModifierDefinition` resources with a cached query layer.

**Responsible For:**
- Storing all active modifiers from any source (upgrades, weapon mods, status effects, talents, passives)
- O(1) cached stat queries via `sum_modifiers(tag, operation)`
- Immunity checks via `has_negation(tag)`
- Damage type conversion via `get_first_conversion(source_type)`

**Stat Read Pattern:**
```
base = modifier_component.sum_modifiers(stat_name, "add")
final = base * (1.0 + modifier_component.sum_modifiers(stat_name, "bonus"))
```

**Does NOT Do:** Does not decide WHEN modifiers change. Other systems (upgrades, statuses, talents) add/remove ModifierDefinitions; the component just stores and queries.

---

### Combat Pipeline (Stateless Systems)

**Purpose:** Resolves all damage and healing through a deterministic pipeline.

**DamageCalculator** — Stateless 8-step damage pipeline:
1. Base damage (+ attribute scaling)
2. Damage type conversion (via source's ModifierComponent)
3. Offensive modifiers (source "bonus" for damage type + "All")
4. Dodge check (target dodge_chance)
5. Block check (target block_chance + block_mitigation)
6. Resistance: `raw × (1 - resist / (resist + 100))`
7. Damage taken modifiers + vulnerability
8. Crit (source crit_chance + crit_multiplier)

Returns `HitData` (RefCounted) with amount, damage_type, is_crit, is_blocked, is_dodged, etc.

**EffectDispatcher** — Stateless type-switch dispatcher. All game effects route through `EffectDispatcher.execute_effects()`. 15 effect types: DealDamage, Heal, ApplyStatus, ApplyShield, SpawnProjectiles, Displacement, AreaDamage, Cleanse, ConsumeStacks, GroundZone, ApplyModifier, SetMaxStacks, OverflowChain, Resurrect, Summon.

**EventBus** — Global signal bus. Every combat event flows through here: `on_hit_dealt`, `on_hit_received`, `on_kill`, `on_death`, `on_heal`, `on_crit`, `on_block`, `on_dodge`, `on_status_applied`, `on_status_expired`, `on_ability_used`, etc. TriggerComponent listens lazily via refcount.

---

### UpgradeManager (Autoload Singleton)

**Purpose:** Manages the upgrade pool, presents level-up choices, tracks the player's current build, and handles evolution recipes.

**Responsible For:**
- Maintaining the pool of available upgrades (filtered by what's unlocked via meta-progression)
- Generating level-up choices: pick N upgrades from pool, weighted by rarity and Luck stat
- Tracking which upgrades the player has taken this run
- Applying upgrade effects to player stats via StatManager
- Handling rerolls (deduct in-run currency, generate new choices)
- Checking evolution recipes: after each upgrade taken, check if any evolution conditions are met
- Managing corruption upgrades: apply both the benefit and the penalty

**Data Structure — Upgrade Definition:**
```
UpgradeDefinition:
    id: unique string
    name: display name
    description: player-facing text
    rarity: Common / Uncommon / Rare / Epic / Legendary
    category: Weapon / Mod / Passive / ActiveAbility / Synergy / ExtractionPerk / Corruption
    effects: [{stat_or_trigger, modification_type, value}]
    corruption_penalty: (if Corruption category) [{stat_or_trigger, modification_type, value}]
    evolution_components: (if part of an evolution) [list of upgrade IDs needed]
    evolves_into: (if evolution target) upgrade ID of the evolved form
    icon: sprite reference
    max_level: how many times this can be taken (1 for unique, 3-5 for stackable)
    phase_requirement: minimum phase to appear (0 = always available)
```

**Signals Emitted:**
- `upgrade_chosen(upgrade_data)`
- `evolution_triggered(base_upgrades, evolved_upgrade)`
- `level_up_ready(choices)` — triggers UI to show choice panel

**Does NOT Do:** Does not handle XP accumulation (that's a stat tracked by StatManager). Does not apply stat changes directly (tells StatManager to apply them).

---

### LootManager (Autoload Singleton)

**Purpose:** Handles what drops, where it drops, loot quality, and Instability tracking.

**Responsible For:**
- Loot table lookups: when an enemy dies, determine what drops based on enemy type, current phase, and player's Loot Find stat
- Spawning pickup scenes at the death location
- Tracking the player's current extractable loot haul (list of items collected this run)
- Instability calculation: sum of Instability values from all carried loot
- Instability tier tracking: Stable → Unsettled → Volatile → Critical
- Applying Instability effects: tell EnemySpawnManager and StatManager to scale difficulty
- Cursed loot handling: flag items as cursed, apply bonus Instability on pickup

**Data Structure — Loot Item:**
```
LootItem:
    id: unique string
    name: display name
    category: Resource / Weapon / WeaponMod / Blueprint / Artifact / LoreFragment / Keystone
    rarity: Common / Uncommon / Rare / Epic / Legendary
    instability_value: how much Instability this item adds when carried
    is_cursed: boolean (cursed items have higher instability_value and better stats)
    data: (category-specific data — weapon stats, mod effects, resource amount, etc.)
    visual: sprite/particle reference for the pickup
    audio: sound reference for pickup collection
```

**Data Structure — Loot Table:**
```
LootTable:
    entries: [{loot_item_id, weight, phase_min, phase_max}]
    guaranteed_drops: [{loot_item_id, condition}] — always drop if condition met
    nothing_weight: chance of no extractable drop (just XP gems)
```

**Signals Emitted:**
- `loot_collected(loot_item_data)`
- `instability_changed(new_value, new_tier)`
- `instability_tier_crossed(new_tier)` — fires On Instability Threshold triggers
- `keystone_collected`

**Does NOT Do:** Does not determine enemy death (CombatManager does that). Does not handle what happens with loot after extraction (ProgressionManager does that).

---

### ExtractionManager (Autoload Singleton)

**Purpose:** Manages all extraction points, their states, and the extraction process.

**Responsible For:**
- Tracking all extraction points in the current arena (type, location, state)
- Timed extraction: opening/closing windows at phase transitions
- Guarded extraction: guardian state (alive/dead), window activation after kill
- Locked extraction: Keystone check, activation, bonus multiplier
- Sacrifice extraction: item selection UI, sacrifice processing
- Extraction channeling: start/interrupt/complete the channel timer
- Extraction reward calculation: base loot + phase bonus + extraction type bonus

**Data Structure — Extraction Point:**
```
ExtractionPoint:
    type: Timed / Guarded / Locked / Sacrifice
    position: Vector2 (arena coordinates)
    state: Inactive / Available / Channeling / Used
    activation_window: (for Timed) seconds remaining
    guardian_id: (for Guarded) enemy entity ID
    requires_keystone: (for Locked) boolean
    bonus_multiplier: (for Locked) phase-scaled bonus
```

**Signals Emitted:**
- `extraction_available(extraction_point_data)` — a point becomes usable
- `extraction_warning(extraction_point_data, seconds_until)` — timed extraction incoming
- `extraction_channel_started(extraction_point_data)`
- `extraction_channel_progress(percent_complete)`
- `extraction_complete(extraction_point_data, loot_haul, bonuses)`
- `extraction_window_closed(extraction_point_data)`

**Does NOT Do:** Does not handle combat with guardians (CombatManager does). Does not process loot rewards (ProgressionManager does that at the hub).

---

### ProgressionManager (Autoload Singleton)

**Purpose:** Everything persistent. Save data, unlocks, currency, hub state, loadouts.

**Responsible For:**
- Player save data (persists between sessions)
- Resource currency tracking (earned from extractions and penalized death XP)
- Unlocked characters, weapons, mods, blueprints, artifacts
- Hub upgrade state (which upgrades have been purchased)
- Loadout management (currently equipped starting weapons, mods, artifacts)
- Insurance state (which item is insured this run, if any)
- Lore collection state (which fragments have been found)
- Statistics tracking (personal bests, run history)
- Surprise unlock checking (milestone detection and reward granting)
- Save/load to disk

**Data Structure — Save Data:**
```
SaveData:
    resources: integer (universal currency)
    meta_xp: integer (account-level experience)
    unlocked_characters: [character_id list]
    unlocked_weapons: [weapon_id list] (extracted collection)
    unlocked_mods: [mod_id list] (extracted collection)
    activated_blueprints: [blueprint_id list]
    unlocked_artifacts: [artifact_id list]
    hub_upgrades: {upgrade_id: level}
    current_loadout:
        character_id: string
        starting_weapons: [weapon_id list]
        equipped_mods: {weapon_id: [mod_id list]}
        equipped_artifacts: [artifact_id list]
        insured_item: item_id or null
    lore_collection: [fragment_id list]
    statistics:
        total_runs: int
        successful_extractions: int
        deaths: int
        deepest_phase: int
        most_loot_extracted: int
        ... etc
    surprise_unlocks_triggered: [milestone_id list]
```

**Signals Emitted:**
- `resources_changed(new_amount)`
- `item_unlocked(item_type, item_id)`
- `hub_upgraded(upgrade_id, new_level)`
- `surprise_unlock(milestone_id, reward_data)` — a milestone was reached
- `save_completed`

**Does NOT Do:** Does not handle in-run gameplay. Only activated at run end and during hub interactions.

---

### ArenaManager (Autoload Singleton)

**Purpose:** Loads arena data files and builds the game world for each phase.

**Responsible For:**
- Loading arena data files (JSON/resource) for the selected arena
- Building the TileMap from terrain data
- Placing extraction points, hazards, cover objects, hidden spots, and spawn zones as child nodes
- Applying phase visual theming (CanvasModulate color, shader parameters, particle effects, lighting)
- Clearing the arena on phase transition
- Preloading the next phase's arena during extraction windows (to minimize transition time)

**Data Structure — Arena Data File:**
```
ArenaData:
    id: unique string
    phase: integer (1-5)
    dimensions: Vector2i (grid size)
    terrain_grid: 2D array of tile IDs
    spawn_zones: [{position, type}]
    extraction_points: [{position, type}]
    hazards: [{position, type, size, damage, behavior}]
    cover_objects: [{position, size, destructible}]
    hidden_spots: [{position, contents_type, contents_id}]
    visual_theme: string (references a theme config)
    ambient_config: {color_tint, fog_density, particle_type, light_config}
    lore_hook: string (optional environmental lore reference)
```

**Signals Emitted:**
- `arena_loaded(arena_data)`
- `arena_cleared`
- `hazard_triggered(hazard_data, position)`

---

### EnemySpawnManager (Autoload Singleton)

**Purpose:** Controls when and where enemies appear. Handles wave composition and difficulty scaling.

**Responsible For:**
- Wave generation: based on current phase, elapsed time, and Instability tier
- Enemy type selection: referencing the phase composition table (% Fodder, Swarmer, Brute, etc.)
- Spawn location selection: using arena spawn zones, avoiding spawning on top of the player
- Elite modifier assignment: rolling for elite status and selecting modifiers
- Miniboss spawning: placing guardians on guarded extraction points
- Special enemy spawning: Mimics, Stalkers, Carriers, etc. based on phase
- Density scaling: increasing spawn rate over time within a phase and across phases
- Instability scaling: when Instability tier increases, boost enemy stats and elite rates

**Data Structure — Enemy Definition:**
```
EnemyDefinition:
    id: unique string
    name: display name
    role: Fodder / Swarmer / Brute / Ranged / Elite / Miniboss / Special
    base_stats: {stat_name: value}
    behavior: string (references a behavior script: chase, ranged_kite, anchor, flee, etc.)
    animations: {idle, walk, attack, death, special}
    loot_table_id: reference to a LootTable
    phase_range: {min, max} — which phases this enemy can appear in
    elite_eligible: boolean — can this enemy become an elite?
    special_type: null / Stalker / Mimic / Herald / Anchor / Carrier / PhaseWarped
    visual_overrides: (for palette shifting per phase)
```

**Signals Emitted:**
- `wave_spawned(wave_number, enemy_count)`
- `enemy_spawned(enemy_id, enemy_data, position)`
- `all_enemies_cleared` — no enemies remain (useful for phase end checks)

---

### AudioManager (Autoload Singleton)

**Purpose:** Handles all audio: music, SFX, and ambient. Manages phase-based audio transitions.

**Responsible For:**
- Playing/stopping background music (different track per phase + hub)
- Crossfading music on phase transitions
- Playing SFX on game events (hit, kill, pickup, level-up, extraction, etc.)
- Ambient audio layers that change with phase and Instability
- Audio ducking during important moments (level-up choice, extraction channel)
- Volume control and audio settings

**Does NOT Do:** Does not determine WHEN sounds play. Other systems emit signals; AudioManager listens and plays the appropriate sound.

---

### UIManager (Autoload Singleton)

**Purpose:** Updates all UI elements based on game state. Reads from other managers, does not modify game state.

**Responsible For:**
- HUD: health bar, shield bar, XP bar, level indicator, Instability meter, minimap, extraction point indicators
- Level-up screen: display upgrade choices, handle selection input, communicate choice to UpgradeManager
- Extraction UI: channel progress bar, extraction available warnings, extraction type indicators
- Damage numbers: floating damage text spawned at hit locations
- Phase transition overlay: phase name, Instability, loot summary during transitions
- Hub UI: all hub menus (armory, research, roster, workshop, lore, records, launch)
- Notifications: pickup notifications, milestone alerts, surprise unlocks

---

## Entity Scene Structures

### Player Scene
```
Player (CharacterBody2D) — scripts/entities/player.gd
├── Sprite (AnimatedSprite2D)
├── CollisionShape2D
├── PickupCollector (Area2D — scaled by pickup_radius modifier)
│   └── CollisionShape (CircleShape2D)
├── HealthComponent (runtime child)
├── ModifierComponent (runtime child)
├── AbilityComponent (runtime child)
├── BehaviorComponent (runtime child — auto-attack timer, target resolution)
├── StatusEffectComponent (runtime child)
└── TriggerComponent (runtime child)
```

### Enemy Scene (Generic — ALL enemy types use enemy.gd)
```
Enemy (CharacterBody2D) — scripts/entities/enemy.gd
├── Sprite (AnimatedSprite2D — from scene, tinted/scaled by EnemyDefinition)
├── Hurtbox (Area2D — contact damage to player on overlap)
├── HealthComponent (runtime child)
├── ModifierComponent (runtime child)
├── AbilityComponent (runtime child — auto-attack + optional skills from definition)
├── BehaviorComponent (runtime child — AI targeting, attack timer)
├── StatusEffectComponent (runtime child)
└── TriggerComponent (runtime child)
```

Configured entirely by `EnemyDefinition` data factories via `setup_from_enemy_def(def)`.

### Projectiles
No projectile scene. `ProjectileManager` uses pooled parallel arrays with `_draw()` rendering. Projectiles are data (position, velocity, config), not nodes.

### Pickup Scene (Generic — configured by loot data)
```
Pickup (Area2D)
├── Sprite (AnimatedSprite2D — from loot visual data, scaled by rarity)
├── CollisionShape (collection radius)
├── GlowEffect (PointLight2D — intensity/color by rarity)
├── FloatAnimation (gentle bob up and down)
└── RarityParticles (GPUParticles2D — particles for higher rarity items)
```

---

## Signal Flow Diagram (One Kill Event)

```
BehaviorComponent resolves targets via SpatialGrid
    ↓
auto_attack_requested signal → player._on_auto_attack()
    ↓
EffectDispatcher.execute_effects(ability.effects, source, targets, ability, combat_manager)
    ├── SpawnProjectilesEffect → ProjectileManager.spawn_projectiles()
    │   ↓ (projectile hits enemy via spatial grid proximity check)
    │   ProjectileManager._on_hit() → EffectDispatcher.execute_effect(on_hit_effects...)
    │       ├── DealDamageEffect → DamageCalculator.calculate_damage() → HitData
    │       │   ↓
    │       │   enemy.take_damage(hit) → CombatUtils.process_incoming_damage()
    │       │       ├── HealthComponent.apply_damage()
    │       │       ├── EventBus.on_hit_dealt.emit() → CombatFeedbackManager (damage number)
    │       │       ├── EventBus.on_crit.emit() (if crit)
    │       │       ├── StatusEffectComponent.notify_hit_received() (thorns, on-hit reactives)
    │       │       └── source.StatusEffectComponent.notify_hit_dealt() (on-hit-dealt effects)
    │       └── ApplyStatusEffectData → target.status_effect_component.apply_status()
    │           └── EventBus.on_status_applied.emit()
    ↓ (if enemy HP ≤ 0)
    enemy._on_health_died()
        ├── EventBus.on_death.emit()
        ├── EventBus.on_kill.emit() → GameManager (kill count), EnemySpawnManager (active count)
        ├── EventBus.on_overkill.emit() (if overkill > 0)
        ├── TriggerComponent listeners fire (on_kill triggers)
        ├── XP gem spawned, health orb roll
        └── MainArena._on_entity_killed() → loot drop rolls
```

---

## Signal Flow Diagram (Extraction)

```
GameManager: phase_ending(phase_number)
    ↓
ExtractionManager: activates Timed extraction point
    ├── Emits: extraction_warning(point, 10 seconds)
    │   ├── UIManager hears → shows warning indicator
    │   └── AudioManager hears → plays warning audio
    ↓ (10 seconds later)
    ├── Emits: extraction_available(point)
    │   ├── UIManager hears → shows extraction marker
    │   └── AudioManager hears → plays portal opening SFX
    ↓
Player enters extraction zone (Area2D overlap)
    ↓
ExtractionManager: starts channel timer
    ├── Emits: extraction_channel_started(point)
    │   ├── UIManager hears → shows channel progress bar
    │   ├── AudioManager hears → plays channeling SFX
    │   └── Trigger system checks On Extraction Start triggers
    ↓ (channel completes)
ExtractionManager: extraction_complete(point, loot, bonuses)
    ├── GameManager hears → transitions to RUN_END state
    ├── ProgressionManager hears → processes loot into save data, grants meta XP
    ├── UIManager hears → shows extraction success screen
    └── AudioManager hears → plays extraction success fanfare
    ↓
GameManager: run_ended(EXTRACTION_SUCCESS)
    ↓
Transition to Hub
```

---

## Data File Examples

### Example Weapon Data (JSON/Resource)
```
{
    "id": "frost_shotgun",
    "name": "Frost Scattergun",
    "description": "Sprays a cone of ice shards. Applies Chilled.",
    "behavior": "spread",
    "damage_type": "cryo",
    "base_stats": {
        "damage": 8,
        "attack_speed": 0.8,
        "projectile_count": 5,
        "projectile_speed": 300,
        "aoe": 0,
        "pierce": 0
    },
    "mod_slots": 2,
    "rarity": "uncommon",
    "applies_status": "chilled",
    "visual": "res://assets/weapons/frost_shotgun.png",
    "projectile_visual": "res://assets/vfx/ice_shard.png",
    "fire_sfx": "res://assets/audio/sfx/ice_blast.ogg",
    "hit_sfx": "res://assets/audio/sfx/ice_impact.ogg"
}
```

### Example Enemy Data
```
{
    "id": "void_stalker",
    "name": "Void Stalker",
    "role": "special",
    "special_type": "stalker",
    "base_stats": {
        "health": 40,
        "damage": 25,
        "movement_speed": 120,
        "armor": 0
    },
    "behavior": "stalker_ambush",
    "phase_range": {"min": 3, "max": 5},
    "elite_eligible": false,
    "loot_table_id": "stalker_drops",
    "animations": {
        "idle": "res://assets/enemies/stalker/idle.tres",
        "reveal": "res://assets/enemies/stalker/reveal.tres",
        "walk": "res://assets/enemies/stalker/walk.tres",
        "attack": "res://assets/enemies/stalker/attack.tres",
        "death": "res://assets/enemies/stalker/death.tres"
    },
    "visual_overrides": {
        "phase_3": {"palette": "void_subtle"},
        "phase_4": {"palette": "void_intense"},
        "phase_5": {"palette": "void_maximum"}
    }
}
```

### Example Upgrade Data
```
{
    "id": "abyssal_pact",
    "name": "Abyssal Pact",
    "description": "Deal 40% more damage. Every loot pickup increases Instability by an extra 5%.",
    "rarity": "epic",
    "category": "corruption",
    "effects": [
        {"type": "percent_modifier", "stat": "damage", "value": 0.40}
    ],
    "corruption_penalty": [
        {"type": "trigger", "trigger": "on_loot_pickup", "effect": "instability_add", "value": 5}
    ],
    "max_level": 1,
    "phase_requirement": 0,
    "icon": "res://assets/ui/upgrades/abyssal_pact.png"
}
```

### Example Arena Data (Simplified)
```
{
    "id": "threshold_ruins_01",
    "phase": 1,
    "dimensions": {"x": 40, "y": 30},
    "visual_theme": "threshold",
    "ambient_config": {
        "color_tint": "#B8A080",
        "fog_density": 0.1,
        "particle_type": "dust_motes",
        "light_intensity": 0.8
    },
    "spawn_zones": [
        {"position": {"x": 0, "y": 15}, "type": "edge_left"},
        {"position": {"x": 40, "y": 15}, "type": "edge_right"},
        {"position": {"x": 20, "y": 0}, "type": "edge_top"},
        {"position": {"x": 20, "y": 30}, "type": "edge_bottom"}
    ],
    "extraction_points": [
        {"position": {"x": 35, "y": 5}, "type": "timed"},
        {"position": {"x": 5, "y": 25}, "type": "guarded"}
    ],
    "hazards": [
        {"position": {"x": 18, "y": 12}, "type": "damage_zone", "size": 3, "damage": 5}
    ],
    "cover_objects": [
        {"position": {"x": 10, "y": 10}, "size": 2, "destructible": false},
        {"position": {"x": 25, "y": 20}, "size": 1, "destructible": true}
    ],
    "hidden_spots": [
        {"position": {"x": 38, "y": 28}, "contents_type": "lore_fragment", "contents_id": "lore_threshold_01"}
    ],
    "lore_hook": "Scratched into the wall: 'They went deeper. None returned.'"
}
```

---

## Save System

**When saves happen:**
- Auto-save after every successful extraction (returning to hub)
- Auto-save after every hub action (purchase, equip, etc.)
- Auto-save on game close
- No mid-run saves. Runs are 15-20 minutes. If you quit mid-run, the run is lost. (Pillar 2: respect the clock — but also prevents save-scumming, which would undermine extraction tension.)

**Save format:** JSON file on disk. Encrypted or obfuscated to discourage casual save editing (not critical for v1, but worth noting).

**Save location:** Godot's `user://` directory (platform-appropriate user data folder).

---

## Performance Considerations

- **Object pooling for projectiles and pickups.** Don't create/destroy — reuse from a pool. Horde games can have hundreds of projectiles on screen.
- **Enemy count cap.** Maximum 150 simultaneous enemies on screen. New spawns queue until existing enemies die. Prevents frame drops.
- **Pickup magnet on screen clear.** If too many pickups accumulate, they get pulled toward the player automatically. Prevents thousands of pickup nodes.
- **Particle budget.** Limit total active particle systems. Reduce particle count on lower settings.
- **Tilemap optimization.** Godot 4's TileMap is efficient for 2D. No concerns here for arena sizes we're planning.

---

*Phase 7 (Architecture Blueprint) is complete. Every system has a defined purpose, clear boundaries, signal-based communication, and example data structures. The code/data separation means adding content after the framework is built is fast and requires no code changes.*

*Next: Phase 8 — Core Framework Decisions. Lock down the actual numbers: damage formulas, stat scaling, XP curves, Instability thresholds, phase timing. The math behind the systems.*
