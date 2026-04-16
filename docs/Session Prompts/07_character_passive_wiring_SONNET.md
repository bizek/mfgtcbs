# Session Prompt: Character Passive Wiring Audit + Fix

**Model:** Sonnet
**Scope:** Audit existing code, then fix any wiring gaps
**Output:** Working character passives — changes to `player.gd`, `status_factory.gd`, and/or `upgrade_manager.gd`

## Project Context

Extraction Survivors — top-down 2D arena survivor/extraction hybrid in Godot 4.6.1 (GDScript). Component-based entity system with data-driven content.

- Every entity owns: HealthComponent, ModifierComponent, AbilityComponent, BehaviorComponent, StatusEffectComponent, TriggerComponent
- All effects route through EffectDispatcher; new stat changes use ModifierDefinition on ModifierComponent
- Autoloads: EventBus, GameManager, ProgressionManager, UpgradeManager, EnemySpawnManager, ExtractionManager
- File org: `scripts/player/`, `scripts/managers/`, `scripts/components/`, `data/factories/`
- Never invent patterns — use ModifierComponent, ModifierDefinition, and StatusFactory as they already exist

## What This Task Is

5 playable characters exist: Drifter, Scavenger, Warden, Spark, Shade. Each has a passive ability that should modify player stats during a run. The wiring between character selection and passive application is unclear — it may be partially implemented, entirely missing, or wired but never triggered.

**Expected passive behaviors (verify against actual code — these may differ):**
- Scavenger: +2 pickup radius (flat ModifierComponent stat increase)
- Drifter: +0.5% dodge per equipped weapon (recalculates each time a weapon is added)
- Spark: +0.5% crit chance per non-fire weapon mod equipped (recalculates each time a mod is added)
- Warden / Shade: read from code — may have different passives than expected

## Your Task

### Step 1 — Audit (read before writing any code)

Read these files in full:
1. `scripts/player/player.gd` — find `_passive_id` or equivalent; find where run init happens; find whether passive application logic exists
2. `data/factories/status_factory.gd` — look for character-named passive definitions
3. `scripts/managers/upgrade_manager.gd` — check if passive recalculation is triggered when a weapon or mod is added

Document what you find: what exists, what is called, what is never called, what is missing entirely.

### Step 2 — Fix

Based on what you find:

- If `_passive_id` is set but never used: wire it to passive application logic at run start (`_ready` or `start_run()` equivalent)
- If ModifierComponent is not updated with passive stats: add the correct ModifierDefinition call — follow the exact pattern already used elsewhere in the file
- If Drifter/Spark passives need to recalculate dynamically: hook into the signal that fires when a weapon or mod is added to the player's loadout — do not poll
- If passive definitions don't exist in StatusFactory: add them following the existing `static func create_X() -> StatusEffectDefinition` pattern
- If passives are already fully wired and working: say so and make no changes

## Rules

- Read all three files before writing any code
- Do not invent new components or systems
- Do not change anything that is already working correctly
- One passive per character — if a passive has multiple conditions (like Drifter's per-weapon bonus), implement it as a single modifier that recalculates, not multiple stacking modifiers

## Output Format

1. **Audit summary** — bullet list: what exists, what's broken, what's missing
2. **Code changes** — full modified/added functions only, with file path and line range noted for each
3. **Verification** — one sentence: how to confirm each passive works in-game
