# Session Prompt: Phase Enemy Composition Verification + Fix

**Model:** Sonnet
**Scope:** Read EnemySpawnManager, verify wave composition matches design, fix weights if off
**Output:** Phase-correct enemy composition with updated wave_composition data

## Project Context

Extraction Survivors — top-down 2D arena survivor/extraction hybrid in Godot 4.6.1 (GDScript).

- `scripts/managers/enemy_spawn_manager.gd` controls spawn timing and enemy type weighting
- 9 enemy types: Fodder, Swarmer, Brute, Caster, Stalker, Carrier, Guardian, Herald, Anchor
- 5 phases; current phase is tracked by `GameManager.current_phase` (or equivalent)
- Do not add new autoloads or scripts — edit EnemySpawnManager only

## What This Task Is

The game is designed so each phase feels progressively harder and more varied. Early phases should be mostly weak enemies; late phases should introduce dangerous specialist types. The spawn weights per phase may not match this intent.

**Intended composition:**
| Phase | Primary enemies | Notes |
|-------|-----------------|-------|
| 1 | ~80% Fodder, ~20% Swarmer | Pure swarm — teach movement |
| 2 | ~50% Fodder, ~40% Swarmer, ~10% other | First variety introduction |
| 3 | ~25% Fodder, ~25% Swarmer, ~25% Brute, ~25% Caster | Tanky + ranged threats appear |
| 4 | ~10% Fodder, ~20% Swarmer, ~25% Stalker, ~25% Carrier, ~20% Guardian | Specialist-dominant |
| 5 | ~10% Swarmer, ~20% Herald, ~30% Anchor, ~40% Phase-Warped variants (if implemented, else redistribute) | Boss-tier density |

## Your Task

### Step 1 — Read

Read `scripts/managers/enemy_spawn_manager.gd` in full. Find:
- The data structure that controls per-phase enemy type weights (may be a Dictionary, array of arrays, or a function with conditionals)
- How the current phase is read
- Whether the weights sum to 1.0 per phase or use a different scheme

### Step 2 — Compare and Fix

Print out the current weights as a table (Phase | Enemy type → weight). Compare to the intended composition above.

If they match: say so and make no changes.

If they differ materially: update the weights to match the intended composition. Preserve the existing data structure shape — if it's a Dictionary, keep it a Dictionary; if it's a function, keep it a function.

If the composition is hardcoded in a way that makes per-phase gating unclear (e.g., one big function without phase separation): refactor to a Dictionary keyed by phase index. This is the only acceptable scope expansion.

## Rules

- Weights per phase must sum to 1.0 (normalize if needed)
- Use `GameManager.current_phase` (or whatever field already exists) — do not add new state
- Enemy types must be referenced by whichever identifier (string, enum, constant) the file already uses
- No new autoloads, no new scripts

## Output Format

1. **Current composition table** — Phase | Enemy type weights as found in code
2. **Corrected composition table** — your target values
3. **Code change** — the updated wave_composition data with file path
