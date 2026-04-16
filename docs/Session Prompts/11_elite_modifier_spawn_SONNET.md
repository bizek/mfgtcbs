# Session Prompt: Elite Enemy Modifier Spawn Logic Audit + Fix

**Model:** Sonnet
**Scope:** Verify all 7 elite modifiers exist and appear on enemies, implement any that are missing or incomplete
**Output:** All 7 elite modifiers registered, spawning, and behaviorally complete

## Project Context

Extraction Survivors — top-down 2D arena survivor/extraction hybrid in Godot 4.6.1 (GDScript). Component-based entity system with data-driven content.

- All effects route through EffectDispatcher (type-switches on 15 effect Resource types)
- Available effect types include: ApplyStatusEffectData, AreaDamageData, DisplacementData, and others
- StatusEffectDefinition in StatusFactory; ModifierDefinition in ModifierComponent
- EnemyDefinition data factories in `data/factories/enemy_registry.gd`
- `scripts/managers/enemy_spawn_manager.gd` controls what spawns and when
- Do not create new effect Resource types — use what already exists

## What This Task Is

Elite enemies are standard enemies with a special modifier applied at spawn. There are 7 intended elite modifiers. Shielded and Hasting are confirmed working. Exploding and Reflecting may be incomplete — they may have definitions but missing behavior, or may be missing entirely. The other 3 modifiers are unknown until you read the code.

**Known modifiers:**
- **Shielded** — absorbs damage (confirmed working)
- **Hasting** — increased move/attack speed (confirmed working)
- **Exploding** — deals AOE damage on death (may be incomplete)
- **Reflecting** — reflects projectiles back toward the player (may be incomplete)
- **3 others** — read from `enemy_registry.gd` and `enemy_spawn_manager.gd`

## Your Task

### Step 1 — Audit (read before writing code)

Read these files:
1. `data/factories/enemy_registry.gd` — find all elite modifier definitions; list them by name
2. `scripts/managers/enemy_spawn_manager.gd` — find where elite modifiers are selected and applied at spawn; check if all definitions are in the spawn pool
3. Any enemy behavior scripts referenced by the Exploding/Reflecting definitions — check if the behavior logic is actually implemented

For each modifier: note whether it (a) exists in the registry, (b) is wired to the spawn pool, and (c) has complete behavior logic.

### Step 2 — Fix

For any modifier that is registered but not in the spawn pool: add it to EnemySpawnManager's elite modifier selection.

For any modifier with incomplete behavior, implement it using existing effect Resource types:

- **Exploding** — on-death AOE damage: use `AreaDamageData` with radius ~60px, damage = 1× the enemy's base attack damage. Hook into the enemy's death signal or `_on_death()` function.
- **Reflecting** — when a player projectile hits a reflecting enemy, redirect it back toward the player: read the existing ProjectileManager to understand how projectile direction is stored, then reverse the velocity vector on hit. This may require a signal connection in the enemy script or a flag check in ProjectileManager.

For any modifier that is entirely missing from the registry: add a definition following the existing `create_elite_X()` factory pattern.

## Rules

- Read all three files before writing any code
- Use only existing effect Resource types and GDScript patterns — no new classes
- Exploding AOE should not trigger other Exploding enemies' deathburst (avoid chain explosions)
- All modifiers must appear in EnemySpawnManager's spawn pool, weighted by phase (higher phases = more elites)

## Output Format

1. **Modifier audit table** — Name | In registry | In spawn pool | Behavior complete | Notes
2. **Code changes** — modified/added functions with file paths
3. **Verification** — how to confirm all 7 appear: play through phases 2–5, note elite modifier variety
