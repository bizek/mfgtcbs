# CLAUDE.md — Extraction Survivors

## Project Context

This is a Godot 4 game project (extraction survivors). There are NO web servers, dev servers, or Node/npm tooling. Do not attempt to detect or start dev servers.

Top-down 2D arena survivor / extraction hybrid. WASD movement, auto-firing weapons, horde combat, 5-phase extraction loop. Built on a ported component-based combat engine with data-driven content creation.

**Developer:** Solo dev (Ben) + Claude. Ben provides creative direction. Claude handles all code.

## Architecture

Component-based entity system with data-driven content. CombatOrchestrator (scene-owned, child of MainArena) manages all combat subsystems. All effects route through `EffectDispatcher`. New content = new data factories, not new scripts.

### Autoloads
`EventBus` (combat signal bus), `GameManager` (state machine, phases, difficulty), `ProgressionManager` (save/load, unlocks, meta-progression), `UpgradeManager` (level-up choices), `EnemySpawnManager` (wave composition, spawn timing), `ExtractionManager` (channeling state)

### Entity Components
Every entity owns: `HealthComponent`, `ModifierComponent`, `AbilityComponent`, `BehaviorComponent`, `StatusEffectComponent`, `TriggerComponent`. Contract in `scripts/entities/entity_interface.gd`.

### Tick Order
SpatialGrid rebuild → StatusEffect.tick → AbilityComponent.tick_cooldowns → BehaviorComponent.tick

### Key Pipelines
- **Damage**: 8-step in DamageCalculator (base → conversion → offensive mods → dodge → block → resist → damage_taken → crit)
- **Effects**: EffectDispatcher type-switches on 15 effect Resource types → delegates to subsystems
- **Abilities**: BehaviorComponent resolves targets → emits signal → entity fires EffectDispatcher
- **Statuses**: StatusEffectComponent manages stacking, duration, modifier sync, aura ticks, trigger registration

## Documentation

| Doc | Contents |
|-----|----------|
| `docs/engine_reference.md` | **Read this first for any implementation work.** Full engine reference: all systems, data patterns, unused capabilities, effect/targeting vocabularies, wiring examples |
| `docs/mechanical_vocabulary.md` | Game-specific mechanical vocabulary: damage types, status effects, weapon behaviors, mod effects, triggers |
| `docs/core_framework_decisions.md` | Formulas: damage, XP curve, phase timing, enemy scaling, instability thresholds, economy |
| `docs/systems_design_part1.md` | Stat system, combat system, upgrade/build system design |
| `docs/systems_design_part2.md` | Enemy system, loot system, extraction system design |
| `docs/systems_design_part3.md` | Meta-progression, level/arena system design |
| `docs/architecture_blueprint.md` | System architecture, entity scene structures, signal flows, data file examples |
| `docs/asset_inventory.md` | Free asset sources, palette-shift strategy, license tracking |

### When to read what

| Task | Read these |
|------|-----------|
| **Any implementation** | `engine_reference.md` (always) |
| **New enemy/boss** | `engine_reference.md` → "New Enemy" + "Choreography" + "Enemy Skills" sections |
| **New weapon** | `engine_reference.md` → "New Weapon" + WeaponData/WeaponFactory patterns |
| **New status/buff/debuff** | `engine_reference.md` → "New Status Effect" + "Trigger System" |
| **Combat balancing** | `core_framework_decisions.md` + `mechanical_vocabulary.md` |
| **Game design questions** | `architecture_blueprint.md` (design principles section) |
| **Meta-progression** | `systems_design_part3.md` |
| **Loot/extraction** | `systems_design_part2.md` |

## Content Creation — The Pattern

All content follows the data factory pattern: `static func create() -> Resource`. Register in the appropriate registry. The engine wires everything automatically.

- **New enemy type**: Data factory → EnemyDefinition → register in EnemyRegistry → add scene + spawn logic
- **New weapon**: Entry in WeaponData.ALL → WeaponFactory builds AbilityDefinition automatically
- **New status effect**: StatusEffectDefinition in StatusFactory or inline → applied via ApplyStatusEffectData effect
- **New modifier**: ModifierDefinition → added to entity's ModifierComponent
- **Enemy with abilities**: AbilityDefinition on auto_attack/skills → BehaviorComponent handles targeting + cooldowns
- **Boss with phases**: ChoreographyDefinition on AbilityDefinition.choreography → enemy.gd executes automatically
- **Reactive effects**: TriggerListenerDefinition on StatusEffectDefinition.trigger_listeners → TriggerComponent handles EventBus wiring

## Coding Conventions

- GDScript, typed variables: `var speed: float = 200.0`
- Godot 4.6.1, Compatibility renderer
- 480x270 viewport, 4x integer scaling to 1920x1080
- Collision layers: 1=player, 2=enemies, 3=walls, 4=player_projectiles, 5=pickups, 6=extraction
- Signals for inter-system communication, autoloads for managers
- Entity scenes: CharacterBody2D for player/enemies, Area2D for pickups/projectiles
- File organization: `scripts/systems/`, `scripts/components/`, `scripts/entities/`, `scripts/managers/`, `scripts/ui/`, `data/resources/`, `data/factories/`
- All Resource subclasses: `@export` properties, zero behavior. Logic lives in dispatchers/components.
- Never invent patterns when existing ones work. Route through EffectDispatcher. Use ModifierDefinition for stats. Use StatusEffectDefinition for timed effects.

## Godot Rules

- **Never hand-edit `.tscn` files.** Use MCP tools or the Godot editor.
- **4x viewport scaling.** All UI text sizes must account for this.
- After implementing spatial/positioning features, verify coordinates are within arena bounds (±800 x ±600).

## Godot Scene Files (.tscn)

- Do NOT hand-edit .tscn files to add/remove nodes on instanced sub-scenes — Godot silently strips unowned nodes on save.
- Always use the Godot MCP editor tools for scene structure changes.
- When changing UI, account for the 4x viewport scaling (text/font sizes must be large enough to remain readable).

## Commit Workflow

Before declaring a commit done, run `git status` and `git diff` to verify zero unstaged or untracked files remain. Stage project.godot and any status/docs files explicitly.

## Gameplay Implementation Rules

- Knockback and similar forces must be gated on i-frames to avoid pinball effects.
- New status effects must defensively handle missing keys (e.g., 'timer') on existing status entries.

## Key Technical Details

- Arena bounds: ±800 x ±600 pixels
- ProjectileManager: 256-slot pooled parallel arrays, `_draw()` rendering, zero node churn
- CombatFeedbackManager: 128-slot pooled, composite damage numbers per frame
- SpatialGrid: cell-based proximity queries, rebuilt every frame
- Resistance formula: `raw * (1.0 - resist / (resist + 100.0))`
- XP formula: `base(10) * (1.0 + (level - 1) * 0.3)`
- Debug mode: `GameManager.debug_mode = true` enables F1-F5 hotkeys, debug panel, entity inspector
