# Session Prompt: Weapon Mod Slot Enforcement Audit + Fix

**Model:** Sonnet
**Scope:** Audit Armory UI for mod slot limit enforcement, add it if missing
**Output:** Armory correctly prevents equipping more mods than a weapon's rarity allows

## Project Context

Extraction Survivors — top-down 2D arena survivor/extraction hybrid in Godot 4.6.1 (GDScript). Component-based entity system with data-driven content.

- Weapons are defined in `data/resources/weapon_data.gd` using @export properties
- The Armory hub station (in `scripts/ui/`) lets players equip mods onto weapons
- Mods follow the data factory pattern; weapon rarity is a field on WeaponData
- Do not hand-edit `.tscn` files
- File org: `scripts/ui/`, `data/resources/`, `data/factories/`

## What This Task Is

Each weapon has a rarity-based mod slot limit:
- Common / Uncommon: **1 mod slot**
- Rare / Epic: **2 mod slots**
- Legendary: **3 mod slots**

The Armory UI should prevent the player from equipping more mods than the weapon's slot limit. If the weapon is full, the equip button should be disabled (or grayed out with a tooltip). Right now this check may not exist at all.

## Your Task

### Step 1 — Audit (read before writing code)

Read these files:
1. `data/resources/weapon_data.gd` (or WeaponFactory) — does a `mod_slots` field exist? Does a `rarity` field exist that could be used to derive it?
2. The Armory UI script (find under `scripts/ui/`) — find the "equip mod" button handler; does it check slot count before calling equip?
3. `data/factories/mod_factory.gd` (if it exists) — is there any slot-check logic here?

**Key question:** Is there any check between the equip button press and the actual mod equipping that enforces the slot limit?

### Step 2 — Fix

- If `mod_slots` doesn't exist on WeaponData: derive slot count from rarity inline — `Common/Uncommon → 1, Rare/Epic → 2, Legendary → 3`. Add a helper function or inline conditional, whichever matches existing code style in that file.
- The slot check must happen in the **Armory UI**, before the equip call — not buried inside the equip method itself
- If the weapon is at capacity: disable the equip button (set `disabled = true`) or display a brief status message using existing UI feedback patterns
- Do not change the save data format for weapons

## Rules

- Read all three files before writing code
- The check lives in the UI layer — the equip method itself should not change
- If `mod_slots` is already a field, use it; only derive from rarity if the field doesn't exist
- Match existing code style — if the file uses `weapon_data.mod_slots`, don't switch to `weapon_data.get("mod_slots")`

## Output Format

1. **Audit findings** — where the gap is (2–3 bullets)
2. **Code changes** — modified functions with file paths
3. **Verification** — try to equip a 2nd mod on a Common weapon; button should be disabled
