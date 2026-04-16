# Session Prompt: Mod Codex Data Structure

**Model:** Haiku
**Scope:** Data structures and resource files only — NO UI code, NO scene building
**Depends On:** `mod_interaction_matrix.md` must exist (from Session 01)
**Output:** GDScript resource files for the codex data system

## Context

We have a survivors-like extraction game in Godot 4.6 (GDScript). We've designed a mod interaction matrix where every mod pair has a named combo with a specific effect. Now we need the data backbone that the codex UI and gameplay systems will read from.

The codex is a discoverable system:
- Players can see combo NAMES in the armory when they slot two mods together
- The mechanical DESCRIPTION is hidden ("???") until the player triggers the combo in a run
- There's a mastery tier — trigger the combo N times to unlock a small bonus to that combo

## Your Task

### 1. ModCombo Resource
Create a custom Resource class `ModCombo` (`mod_combo.gd`) with:
- `combo_id: StringName` — unique identifier (e.g., "frostfire", "carpet_bomb")
- `combo_name: String` — display name (e.g., "Frostfire", "Carpet Bomb")
- `required_mods: Array[StringName]` — 2 or 3 mod IDs that trigger this combo
- `description: String` — what it does mechanically (hidden until discovered)
- `combo_type: int` — enum: BEHAVIOR_BEHAVIOR, BEHAVIOR_ELEMENTAL, ELEMENTAL_ELEMENTAL, STAT_INTERACTION, TRIPLE_LEGENDARY
- `is_authored: bool` — true if this combo has a unique coded interaction, false if emergent
- `vfx_hint: String` — short tag for the VFX system (e.g., "fire_trail", "frost_nova")

### 2. CodexEntry Resource
Create `CodexEntry` (`codex_entry.gd`) with:
- `combo: ModCombo` — reference to the combo definition
- `discovered: bool` — has the player seen the name? (true once slotted in armory)
- `revealed: bool` — has the player triggered it in a run? (unlocks description)
- `times_triggered: int` — lifetime trigger count
- `mastery_threshold: int` — triggers needed for mastery (default 50)
- `mastery_bonus_description: String` — what mastery grants (e.g., "+10% radius")
- Helper: `func is_mastered() -> bool`
- Helper: `func mastery_progress() -> float` — returns 0.0 to 1.0

### 3. CodexManager Autoload
Create `codex_manager.gd` as an autoload singleton:
- `var entries: Dictionary` — keyed by combo_id
- `func discover_combo(combo_id: StringName)` — sets discovered = true
- `func reveal_combo(combo_id: StringName)` — sets revealed = true, could emit signal
- `func record_trigger(combo_id: StringName)` — increments counter, checks mastery
- `func get_combos_for_mod_pair(mod_a: StringName, mod_b: StringName) -> Array[CodexEntry]` — lookup
- `func get_all_discovered() -> Array[CodexEntry]`
- `func get_all_mastered() -> Array[CodexEntry]`
- `func get_discovery_percentage() -> float`
- Signals: `combo_discovered`, `combo_revealed`, `combo_mastered`
- Save/load integration: `func save_data() -> Dictionary` and `func load_data(data: Dictionary)`

### 4. Combo Registry
Create `combo_registry.gd` — a static data file that registers all combos from the design doc. Read `mod_interaction_matrix.md` and create a function `_build_registry() -> Array[ModCombo]` that instantiates every combo defined there. This is the tedious part — just go through the matrix methodically.

## Technical Notes
- Use `class_name` on all resources so they're available project-wide
- Use `@export` on resource properties for editor visibility
- CodexManager should be designed as an autoload (path: `res://scripts/systems/codex_manager.gd`)
- Combo lookups need to be fast — consider a secondary dictionary keyed by sorted mod pairs
- The combo_registry will be large. That's fine. Organize by section with comments matching the design doc sections.

## What NOT To Do
- Don't build any UI
- Don't implement the actual combo EFFECTS (that's a separate session)
- Don't create .tscn scene files
- Don't worry about hooking into the weapon/mod equip system yet
