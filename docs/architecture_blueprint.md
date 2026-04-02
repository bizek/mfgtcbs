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
├── GameManager         — Game state, phase transitions, run lifecycle
├── StatManager         — Reads/writes stats for all entities
├── CombatManager       — Damage calculation, hit resolution
├── UpgradeManager      — Upgrade pool, level-up choices, build tracking
├── LootManager         — Drop tables, loot spawning, Instability tracking
├── ExtractionManager   — Extraction point state, extraction logic
├── ProgressionManager  — Meta-progression, currency, unlocks, save/load
├── ArenaManager        — Arena loading, phase environment setup
├── EnemySpawnManager   — Wave composition, spawn timing, difficulty scaling
├── AudioManager        — Music, SFX, ambient. Handles phase-based transitions.
└── UIManager           — HUD updates, menus, level-up screen, hub interface

GAME WORLD (instanced per run)
├── Arena (TileMap + environment objects)
│   ├── SpawnZones (markers for enemy spawning)
│   ├── ExtractionPoints (timed, guarded, locked, sacrifice)
│   ├── Hazards (damage zones, displacement, traps)
│   ├── Cover (collision obstacles)
│   └── HiddenSpots (keystone/lore locations)
├── Player (CharacterBody2D)
│   ├── WeaponSlots (child nodes, each fires independently)
│   ├── ActiveAbilities (cooldown-managed abilities)
│   ├── PickupCollector (Area2D for pickup radius)
│   └── HurtBox (takes damage)
├── Enemies (spawned by EnemySpawnManager)
│   ├── Each is a CharacterBody2D with AI behavior
│   ├── HitBox (deals damage)
│   ├── HurtBox (takes damage)
│   └── LootTable (what it drops on death)
├── Projectiles (spawned by weapons/abilities)
│   └── Each is an Area2D with movement behavior
├── Pickups (spawned by LootManager)
│   └── Each is an Area2D that auto-collects on player overlap
└── VFX (spawned for hit effects, death effects, environmental)

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

### StatManager (Autoload Singleton)

**Purpose:** Central authority on all entity stats. Every stat read/write goes through here.

**Responsible For:**
- Storing base stats for all active entities (player + all enemies on screen)
- Applying stat modifiers (from upgrades, mods, buffs, debuffs, corruption effects)
- Calculating final stat values: base + flat modifiers, then × percentage modifiers
- Providing stat lookup: "What is this entity's current Damage?" → returns final calculated value

**Data Structure — Entity Stats:**
```
EntityStats:
    entity_id: unique identifier
    base_stats: {stat_name: value} — from character/enemy definition
    flat_modifiers: [{source, stat_name, value}] — additive bonuses
    percent_modifiers: [{source, stat_name, value}] — multiplicative bonuses
    status_effects: [{effect_type, source, duration_remaining, stacks}]

Final value = (base + sum(flat_modifiers)) × (1 + sum(percent_modifiers))
```

**Signals Emitted:**
- `stat_changed(entity_id, stat_name, old_value, new_value)`
- `status_effect_applied(entity_id, effect_type, source)`
- `status_effect_removed(entity_id, effect_type)`

**Does NOT Do:** Does not decide WHEN stats change. Other systems tell StatManager to apply modifiers; StatManager just does the math and stores the results.

---

### CombatManager (Autoload Singleton)

**Purpose:** Resolves all damage events. When something hits something, CombatManager calculates the result.

**Responsible For:**
- Damage calculation: attacker stats vs defender stats → final damage number
- Crit resolution: roll against Crit Chance → apply Crit Damage multiplier
- Damage type interactions: check defender resistances/vulnerabilities to the damage type
- Status effect application: if the attack should apply a status (from weapon damage type, mods, etc.), tell StatManager
- Dodge resolution: roll against defender's Dodge Chance
- Knockback calculation: based on hit force vs Knockback Resistance
- Finisher check: after damage, check if target is now below Stagger threshold → apply Staggered status
- Trigger resolution: after a hit/kill/crit, check all registered triggers and fire matching ones

**Flow for one attack:**
1. Receive hit event: (attacker_id, defender_id, weapon_data, damage_type)
2. Get attacker's final Damage stat from StatManager
3. Roll dodge: if defender dodges, emit `dodge_occurred`, fire On Dodge triggers, done
4. Roll crit: if crit, multiply damage by Crit Damage stat
5. Apply defender's Armor reduction
6. Apply damage type resistance/vulnerability
7. Apply final damage to defender's HP via StatManager
8. Apply status effects if weapon/mod dictates
9. Check Stagger threshold
10. Emit signals: `damage_dealt`, `enemy_killed` (if HP ≤ 0), `crit_occurred` (if crit)
11. Fire registered triggers: On Hit, On Kill, On Crit as appropriate

**Signals Emitted:**
- `damage_dealt(attacker_id, defender_id, amount, damage_type, was_crit)`
- `entity_killed(killer_id, victim_id, victim_data, position)`
- `dodge_occurred(attacker_id, defender_id)`
- `crit_occurred(attacker_id, defender_id, damage)`
- `stagger_applied(entity_id)`
- `finisher_executed(player_id, enemy_id, enemy_data)`

**Does NOT Do:** Does not move entities, spawn projectiles, or spawn VFX. It only resolves "X hit Y for Z damage" and emits the results.

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
Player (CharacterBody2D)
├── Sprite (AnimatedSprite2D — character visuals)
├── CollisionShape (for physics/movement)
├── HurtBox (Area2D — detects incoming damage)
├── PickupCollector (Area2D — scaled by Pickup Radius stat)
├── WeaponMount (Node2D — container for weapon child nodes)
│   ├── WeaponSlot1 (fires independently based on weapon data)
│   ├── WeaponSlot2
│   └── WeaponSlot3
├── AbilityMount (Node2D — container for active abilities)
│   ├── AbilitySlot1
│   └── AbilitySlot2
├── VisionRadius (PointLight2D — scales with Vision stat, affects what player can see)
└── StatusEffectDisplay (visual indicators for active buffs/debuffs)
```

### Enemy Scene (Generic — configured by EnemyDefinition data)
```
Enemy (CharacterBody2D)
├── Sprite (AnimatedSprite2D — from enemy definition)
├── CollisionShape
├── HitBox (Area2D — deals damage to player on overlap)
├── HurtBox (Area2D — receives damage from player attacks)
├── BehaviorController (script that reads behavior type from definition)
├── StatusEffectDisplay
├── HealthBar (small bar above enemy, optional for non-bosses)
└── EliteIndicator (visual modifier overlays if elite)
```

### Projectile Scene (Generic — configured by weapon/ability data)
```
Projectile (Area2D)
├── Sprite (AnimatedSprite2D — from weapon VFX data)
├── CollisionShape (hitbox)
├── MovementController (handles projectile behavior: straight, homing, orbit, etc.)
└── TrailEffect (GPUParticles2D — optional visual trail)
```

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
Player's Weapon fires Projectile
    ↓
Projectile collides with Enemy HurtBox
    ↓
CombatManager.resolve_hit(attacker, defender, weapon_data)
    ├── Calculates damage (stats, crit, armor, type resistance)
    ├── Applies status effects via StatManager
    ├── Emits: damage_dealt(...)
    │   ├── UIManager hears → spawns damage number
    │   ├── AudioManager hears → plays hit SFX
    │   └── VFX spawned at hit location
    ├── If enemy HP ≤ 0:
    │   ├── Emits: entity_killed(...)
    │   │   ├── LootManager hears → rolls loot table → spawns pickups
    │   │   ├── EnemySpawnManager hears → decrements active enemy count
    │   │   ├── AudioManager hears → plays death SFX
    │   │   ├── VFX spawned (death animation/particles)
    │   │   └── Trigger system checks On Kill triggers → fires effects
    │   └── XP gem spawned at position
    └── If enemy HP ≤ stagger threshold:
        └── Emits: stagger_applied(...)
            └── Enemy enters vulnerable state (visual change, finisher available)
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
