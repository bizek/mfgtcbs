# Session Prompt: Phase 5 Phase-Warped Enemy Variants

**Model:** Sonnet
**Scope:** Create 3–5 Phase-Warped enemy variants for Phase 5 using data factory pattern
**Output:** New EnemyDefinition factory methods in `enemy_registry.gd` + Phase 5 spawn composition update

## Project Context

Extraction Survivors — top-down 2D arena survivor/extraction hybrid in Godot 4.6.1 (GDScript). Component-based entity system with data-driven content.

- New content = new data factories (`static func create() -> Resource`), not new scripts
- EnemyDefinitions registered in `data/factories/enemy_registry.gd`
- Abilities are AbilityDefinition instances; unusual behaviors use ChoreographyDefinition
- Available effect types: ApplyStatusEffectData, AreaDamageData, DisplacementData, HealData, and others — read enemy_registry.gd to see which are already in use
- `scripts/managers/enemy_spawn_manager.gd` controls phase composition
- Do NOT create new enemy scene files — Phase-Warped enemies reuse existing base scenes, differentiated by modulate color and behavior definitions
- Do not create new GDScript classes or effect Resource types

## What This Task Is

Phase 5 is the final extraction phase — maximum instability, maximum chaos. Phase-Warped enemies are variants of existing enemy types that feel alien and unpredictable. They use the existing base enemy scenes but have:
1. A **visual distinction**: purple-violet modulate (`Color(0.6, 0.4, 1.0)`) — check EnemyDefinition for a `modulate` or `visual_modulate` field
2. A **behavioral twist**: at least one mechanic that doesn't exist on the base type

**Suggested variants (adjust based on what's mechanically feasible with existing effect types):**

| Variant | Base type | Suggested mechanic |
|---------|-----------|-------------------|
| Warped Fodder | Fodder | Teleports ~100px in a random direction when hit |
| Warped Brute | Brute | Leaves a void_touched AOE trail; apply void_touched to player on contact |
| Warped Caster | Caster | Projectiles home toward the player's predicted position, not current position |
| Warped Herald | Herald | Spawns 2 Fodder on death |
| Warped Swarmer | Swarmer | Shield that absorbs one hit, regenerates after 5 seconds |

Pick 3–5 of these based on what's actually implementable with the existing effect vocabulary. Prefer the ones that require the fewest new patterns.

## Your Task

### Step 1 — Read first

Read `data/factories/enemy_registry.gd` in full. Understand:
- The factory method pattern (`static func create_X() -> EnemyDefinition`)
- What fields EnemyDefinition has (especially modulate/color, hp, damage, speed, auto_attack, skills)
- What effect types are already used by existing enemies (so you know what's safe to reuse)
- The stats of Fodder, Brute, Caster, Herald, Swarmer (the base types you'll variant)

Read `scripts/managers/enemy_spawn_manager.gd` to find the Phase 5 spawn composition.

### Step 2 — Implement

**For each variant you create:**
- Write a `static func create_warped_X() -> EnemyDefinition` method
- Set HP to 1.3× the base type's HP, damage to 1.2× base type's damage
- Set the modulate color field (check the exact field name in EnemyDefinition)
- Add the behavioral mechanic using existing AbilityDefinition + effect Resource patterns

**Update EnemySpawnManager:**
- Add Phase-Warped variants to Phase 5 composition at ~10% weight each
- Reduce existing Phase 5 enemy weights proportionally to keep the total at 1.0

## Rules

- Read enemy_registry.gd before writing any code — base stats must come from what's actually there
- Only use existing effect Resource types — no new GDScript classes
- Do not create new .tscn scene files
- If a suggested mechanic isn't feasible with existing effect types, skip it and note why

## Output Format

1. **Variant design table** — Name | Base type | Mechanic | Implementation approach (which effect types)
2. **Factory methods** — full `create_warped_X()` functions ready to add to enemy_registry.gd
3. **Phase 5 composition update** — the updated spawn weights for EnemySpawnManager
4. **Any supporting definitions** — new AbilityDefinitions or StatusEffectDefinitions needed (inline, ready to add)
