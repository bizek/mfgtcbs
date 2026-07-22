# Architecture Blueprint

> **Status (Late-Alpha):** This is a high-level architectural overview. For technical specifics, see [engine_reference.md](engine_reference.md). For state diagrams, see [diagrams.md](diagrams.md).

The pre-implementation version of this document (full system specs, JSON arena format, planned autoloads that didn't ship) is preserved at [design_archive/architecture_blueprint_pre_implementation.md](design_archive/architecture_blueprint_pre_implementation.md). What remains here are the architectural principles and constraints that still hold.

---

## Architecture Principles

### 1. Data-Driven Everything
Anything we'll have 10+ of (weapons, mods, enemies, upgrades, levels) is defined in DATA, not in code. Adding a new weapon means a new data entry, not a new script. The code is the engine; the data is the fuel.

Concrete forms: Godot `Resource` subclasses with `@export` properties (e.g. `EnemyDefinition`, `AbilityDefinition`, `StatusEffectDefinition`, `ModifierDefinition`), data factories (`static func create() -> Resource`), and LDtk files for level layout.

### 2. Scene Tree Architecture
Each long-lived system is either an **autoloaded singleton** (`EventBus`, `GameManager`, `ProgressionManager`, `UpgradeManager`, `EnemySpawnManager`, `ExtractionManager`, `CodexManager`, `LootTables`, `Settings`, `AudioManager`, `InputGlyphs`, `AchievementManager`, `Logger`) or a **scene-owned orchestrator** child of `MainArena` (`CombatOrchestrator` and its subsystems). Game entities are scenes that instance into the world; UI lives on separate `CanvasLayer`s.

Note what is deliberately *not* an autoload: there is no ArenaManager and no UIManager. Arena assembly belongs to the scene (`MainArena` + `LdtkLoader` / `BlockManager`), and each UI panel is owned by whichever scene shows it. Adding a global for either would re-introduce the coupling the orchestrator pattern exists to avoid.

### 3. Signal-Based Communication
Systems talk through Godot signals — primarily the global `EventBus`. Producers don't know consumers. When an enemy dies, it emits `EventBus.on_kill`; loot rolls, XP spawns, kill-count tracking, and trigger-listener reactives all hook in independently.

### 4. Code vs Data Separation

| Code (built once) | Data (added repeatedly) |
|-------------------|------------------------|
| `DamageCalculator` 8-step pipeline | `WeaponData` / `AbilityDefinition` entries |
| `EffectDispatcher` type switch | Effect Resource subclasses on definitions |
| `StatusEffectComponent` stacking + tick | `StatusEffectDefinition` entries |
| `ModifierComponent` cached query | `ModifierDefinition` entries |
| `EnemySpawnManager` wave logic | `EnemyDefinition` + biome wave compositions |
| `LdtkLoader` arena builder | `.ldtkl` level files + biome metadata |
| `ChoreographyRunner` executor | `ChoreographyDefinition` combo graphs from `ChainFactory` / `SkillFactory` |
| `ModApplicability` resolver | `ModData` / `ClassModData` entries + kit capability tags |

All `Resource` subclasses are pure data (`@export` only, zero behavior). Logic lives in dispatchers and components.

---

## Save System Policy

`ProgressionManager` owns persistence (see [engine_reference.md#save--load](engine_reference.md) for the serialized state list and save-trigger details).

The architectural commitments:
- **No mid-run saves.** Runs are atomic. Quit mid-run = run lost. This is intentional: prevents save-scumming, which would undermine extraction tension (Pillar 2).
- **Auto-save on every state mutation.** Successful extraction, death, hub purchases, equip changes — each calls `save_data()` inline. No manual save action.
- **Save location:** Godot's `user://` directory (`progression.json`).

---

## Performance Considerations

- **Pooled hot paths.** Projectiles use 256-slot parallel arrays in `ProjectileManager` with `_draw()` rendering — zero node churn per shot. Damage numbers use a 128-slot pool in `CombatFeedbackManager`. Both compose multiple effects into a single `_draw()` per frame.
- **SpatialGrid proximity queries.** Cell-based grid rebuilt every frame; replaces O(n²) distance checks for targeting and collision.
- **Enemy count cap.** `EnemySpawnManager` enforces a simultaneous-enemy ceiling; new spawns queue until existing enemies die. Prevents frame drops in dense waves.
- **Particle/VFX budget.** `VfxManager` lifecycles ability and status visuals; long-lived auras share a single particle system per status.
- **Cached modifier queries.** `ModifierComponent.sum_modifiers(tag, op)` caches results until the modifier list mutates — stat reads are O(1) in the common case.

These constraints are non-negotiable for the horde-scale combat loop. New systems should pool, cache, or batch by default.
