# Session Prompt: Blueprint Activation System Audit + Fix

**Model:** Sonnet
**Scope:** Audit the Research Terminal → ProgressionManager → UpgradeManager chain, then fix any broken links
**Output:** Working blueprint system — purchased blueprints appear as upgrade choices in-run

## Project Context

Extraction Survivors — top-down 2D arena survivor/extraction hybrid in Godot 4.6.1 (GDScript). Component-based entity system with data-driven content.

- Autoloads: EventBus, GameManager, ProgressionManager, UpgradeManager, EnemySpawnManager, ExtractionManager
- ProgressionManager handles save/load, unlocks, and meta-progression
- UpgradeManager handles level-up choices during runs
- Content follows data factory pattern: `static func create() -> Resource`
- File org: `scripts/managers/`, `data/resources/`, `data/factories/`, `scripts/ui/`

## What This Task Is

The hub has a Research Terminal where players purchase weapon/mod blueprints using meta-currency. Purchased blueprints should unlock that weapon or mod as a possible choice in future run level-up screens. Weapons/mods not yet purchased should not appear. This chain — purchase → persist → filter → appear — may be partially wired or completely broken.

**The full chain to verify:**
1. Research Terminal UI calls a method on ProgressionManager when a blueprint is purchased
2. ProgressionManager stores the unlock (persists to save)
3. UpgradeManager's `_get_available_upgrades()` (or equivalent) checks `is_unlocked()` before adding a weapon/mod to the pool
4. Weapons and mods have an unlock ID field that ProgressionManager can check against

## Your Task

### Step 1 — Audit (read before writing any code)

Read these files:
1. `scripts/managers/progression_manager.gd` — find the unlock storage structure and the `is_unlocked(id)` function (or whatever it's called)
2. `scripts/managers/upgrade_manager.gd` — find the available-upgrades building logic; check if it calls anything from ProgressionManager to filter
3. `data/resources/weapon_data.gd` (and WeaponFactory if it exists) — check if weapons have an `unlock_id`, `blueprint_id`, or `requires_unlock` field
4. The Research Terminal UI script (find it under `scripts/ui/`) — confirm what method it calls on ProgressionManager when a purchase happens

**Key question to answer:** Does the upgrade pool builder in UpgradeManager actually gate weapons/mods behind unlock checks, or does it just offer everything?

### Step 2 — Fix

Based on your findings, fix whichever links in the chain are broken:

- If UpgradeManager doesn't filter by unlocks: add the filter using the existing `is_unlocked()` function — one conditional per weapon/mod entry is enough
- If weapons have no unlock ID field: add `@export var unlock_id: String = ""` to WeaponData (empty string = always available, no unlock required)
- If the Research Terminal UI calls the wrong ProgressionManager method, or calls nothing: fix the call site
- Do not add new persistence mechanisms or change the save file format — use what exists in ProgressionManager

## Rules

- Read all relevant files before writing code
- Follow the existing @export property pattern for any new fields
- Weapons with no unlock_id (empty string) should always be available — do not accidentally gate default weapons
- Do not change the Research Terminal's visual layout

## Output Format

1. **Chain audit** — bullet list showing each link: what it calls, whether it works
2. **Code changes** — modified functions with file path noted
3. **Verification** — what to do in-game to confirm: purchase one blueprint, start a run, confirm the weapon appears in upgrade choices
