# Session Prompt: Insurance System Implementation

**Model:** Sonnet
**Scope:** Implement per-run item insurance from scratch (likely missing or stub-only)
**Output:** Working insurance — player can protect one item per run from extraction loss

## Project Context

Extraction Survivors — top-down 2D arena survivor/extraction hybrid in Godot 4.6.1 (GDScript). Component-based entity system with data-driven content.

- Autoloads: EventBus, GameManager, ProgressionManager, UpgradeManager, EnemySpawnManager, ExtractionManager
- ExtractionManager handles all extraction outcomes (success, failure, partial loss)
- `scripts/player/player.gd` holds per-run state (current weapons, mods, health, etc.)
- Signals for inter-system communication; autoloads for managers
- Do not hand-edit `.tscn` files — describe scene changes for the Godot editor instead
- File org: `scripts/managers/`, `scripts/player/`, `scripts/ui/`

## What This Task Is

The game has an extraction loop where failing to extract (dying, leaving empty) causes loot loss. The insurance system lets the player designate one item per run as "insured" — that item survives even if extraction fails. This feature may be entirely absent, or there may be a stub in the extraction UI with no backing logic.

**Design spec:**
- Player picks one weapon or mod as insured during the run (via extraction UI or inventory)
- On failed extraction, the insured item is kept; all other accumulated loot is lost
- Insurance resets each run — it's per-run state, not meta-progression
- Only one insured item at a time; insuring a second item replaces the first
- The insured item should have a visible indicator in the extraction UI

## Your Task

### Step 1 — Read first

Before writing any code, read:
1. `scripts/player/player.gd` — understand how per-run items are stored (weapons array, mods dict, or similar)
2. `scripts/managers/extraction_manager.gd` (ExtractionManager autoload) — find where item loss is calculated on failed extraction
3. The extraction UI script (find under `scripts/ui/`) — check if an insurance slot or "insure" button already exists

Note exactly what exists and what's missing. Do not assume anything is implemented.

### Step 2 — Implement

Based on what you find, implement these pieces:

**player.gd:**
- Add `var insured_item_id: String = ""` (or use a Resource reference if that matches how items are stored)
- Add `func set_insured_item(item_id: String) -> void` that sets the insured item (replacing any previous)
- Clear `insured_item_id` in whatever function resets run state at the start of a new run

**ExtractionManager:**
- In the failed-extraction / item-loss logic: before removing an item from the player's inventory, check if its ID matches `player.insured_item_id` — if so, skip removal
- Do not change the flow for uninsured items

**Extraction UI:**
- Add an "Insure" button or indicator next to each item in the item list
- Pressing it calls `player.set_insured_item(item_id)` and updates the visual indicator on that item
- If a second item is insured, remove the indicator from the previously-insured item
- Match the visual style of existing UI elements (same font, same button style) — no new scene files unless absolutely necessary

## Rules

- Read the three files above before writing a single line of code
- Insurance state is per-run only — do not save it to ProgressionManager
- Do not break the normal extraction flow for uninsured items
- Do not hand-edit `.tscn` files — describe any needed scene node additions for the Godot editor

## Output Format

1. **What exists** — what you found in each of the three files (bullet list per file)
2. **Implementation plan** — what you're adding to each file (2–4 bullets per file)
3. **Code changes** — full new/modified functions with file paths
4. **Scene changes** — describe any new nodes needed in the extraction UI scene (node type, name, parent, properties)
5. **Verification** — how to test: accumulate loot, insure one item, fail extraction, confirm insured item is kept
