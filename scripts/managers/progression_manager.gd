extends Node

## ProgressionManager — Persists meta-progression data between runs (save/load JSON).

signal resources_changed(amount: int)

const SAVE_PATH := "user://progression.json"

## ─── Save format versioning ──────────────────────────────────────────────────
## Every save carries a "version" integer at its JSON root. On load, an older save
## is run through _migrate_save() before its fields are applied; a save from a NEWER
## version than we understand is refused (never partially loaded) and the menu offers
## a fresh start via save_newer_than_supported.
##
## THE RULE — do not skip a step of this when you change the save format:
##   1. Bump SAVE_VERSION.
##   2. Add a `_migrate_vN_to_vN+1(data)` step and wire it into _migrate_save().
##   3. Confirm the committed snapshot `tests/save_snapshots/v1.json` still loads
##      cleanly (it is a real versionless dev save — the oldest thing we must accept).
## Missing "version" == 0 (every pre-versioning dev save), so the v0→v1 step is what
## catches those. Field-level defaults still live in load_data() as a second safety
## net; migrations are for STRUCTURAL changes (renames, reshapes, splits) that a
## simple `.get(key, default)` cannot express.
const SAVE_VERSION: int = 1

## Set true by load_data() when the save on disk is from a newer game version than
## this build supports. The save is NOT loaded (defaults remain); the main menu reads
## this to warn the player and steer them to New Game instead of silently continuing.
var save_newer_than_supported: bool = false

## Workshop upgrade definitions: id → cost
const UPGRADE_COSTS: Dictionary = {
	"insurance_license":      300,
	"armory_expansion_1":     750,
	"armory_expansion_2":    1500,
	"channel_accelerator_1":  400,
	"channel_accelerator_2":  800,
	"channel_accelerator_3": 1200,
	"reroll_capacity_1":      500,
	"reroll_capacity_2":     1000,
	"extraction_intel_1":    600,
}

var resources: int = 0
var run_stats: Dictionary = {}            ## Per-run stats (deepest_phase, etc.)
var unlocked_weapons: Array = []
var selected_weapon: String = "Hurled Steel"    ## Legacy global pick — superseded by character_loadouts; kept for save compat
var selected_weapon_2: String = ""          ## Only used when armory_expansion_1 is owned
var selected_weapon_3: String = ""          ## Only used when armory_expansion_2 is owned

## Per-character weapon loadouts — { char_id: [slot1, slot2, slot3] }. Slot 1 (index 0) is
## the weapon used in-run; each character defaults to its signature starting_weapon. This
## opens weapon choice to every character (class × weapon build diversity), replacing the
## old Drifter-only global selected_weapon model.
var character_loadouts: Dictionary = {}
var hub_upgrades: Array = []               ## IDs of purchased Workshop upgrades
var total_resources_spent: int = 0         ## Drives hub visual tier

## Mod inventory — all mod IDs the player has collected through successful extractions
var owned_mods: Array = []
## Equipped mods per weapon — { "weapon_id": ["mod_id_slot0", "mod_id_slot1"] }
## Empty string "" means the slot is empty.
var weapon_mods: Dictionary = {}
## Equipped CLASS mods per character — { "char_id": ["classmod_slot0", …] } (task 31).
## Class mods belong to a CLASS, not a weapon, so they equip per-character; loadouts stay
## isolated when the player switches character. owned_mods (above) still holds every mod
## instance — generic AND class — so the collection / insurance / save flow is one list.
var character_mods: Dictionary = {}

## Class-gear trinkets (task 34). owned_trinkets = the shared universal-trinket inventory
## (duplicates allowed, one per instance). character_trinkets = { char_id: [slot0, slot1, …] },
## "" for empty. Trinkets are universal but equip per-character (2 base slots + workshop 3rd).
var owned_trinkets: Array = []
var character_trinkets: Dictionary = {}

var total_runs: int = 0
var successful_extractions: int = 0
var deaths: int = 0
var deepest_phase: int = 0
var total_kills: int = 0
var most_loot_extracted: float = 0.0
var total_gold_earned: float = 0.0  ## Cumulative resources earned across all runs (achievements)

## Unlocked achievement IDs (see data/achievements.gd). Owning manager is AchievementManager.
var achievements_unlocked: Array = []

## Passive skill tree — see data/passive_tree.gd and docs/passive_tree.md
var passive_points: int = 0
var passive_allocations: Dictionary = {}   ## {node_id: ranks}
var lifetime_passive_points: int = 0

## Character roster
var selected_character: String = "The Drifter"
var unlocked_characters: Array = ["The Drifter"]

## Win state — account-level flag set the first time any character clears the final
## biome's boss gate and extracts. Per-character tracking lists which characters have
## done it (a character can appear more than once is not tracked; presence is enough).
var game_cleared: bool = false
var cleared_characters: Array = []

## First-run onboarding — set true once a first Caves run ends (extraction or
## death). Gates the FirstRunOverlay tooltip cues (scripts/ui/first_run_overlay.gd).
var first_run_complete: bool = false

func _ready() -> void:
	load_data()

func save_data() -> void:
	var data := {
		"version":                SAVE_VERSION,
		"resources":              resources,
		"unlocked_weapons":       unlocked_weapons,
		"selected_weapon":        selected_weapon,
		"selected_weapon_2":      selected_weapon_2,
		"selected_weapon_3":      selected_weapon_3,
		"hub_upgrades":           hub_upgrades,
		"total_resources_spent":  total_resources_spent,
		"total_runs":             total_runs,
		"successful_extractions": successful_extractions,
		"deaths":                 deaths,
		"deepest_phase":          deepest_phase,
		"total_kills":            total_kills,
		"most_loot_extracted":    most_loot_extracted,
		"total_gold_earned":      total_gold_earned,
		"achievements_unlocked":  achievements_unlocked,
		"selected_character":     selected_character,
		"unlocked_characters":    unlocked_characters,
		"owned_mods":             owned_mods,
		"weapon_mods":            weapon_mods,
		"character_mods":         character_mods,
		"owned_trinkets":         owned_trinkets,
		"character_trinkets":     character_trinkets,
		"character_loadouts":     character_loadouts,
		"game_cleared":           game_cleared,
		"cleared_characters":     cleared_characters,
		"first_run_complete":     first_run_complete,
		"passive_points":         passive_points,
		"passive_allocations":    passive_allocations,
		"lifetime_passive_points": lifetime_passive_points,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_data() -> void:
	save_newer_than_supported = false
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("ProgressionManager: could not open save for reading — starting fresh.")
		return
	var text := file.get_as_text()
	file.close()

	var result = JSON.parse_string(text)
	if typeof(result) != TYPE_DICTIONARY:
		## Corrupt or unparseable save. Preserve the evidence, then start fresh —
		## the in-memory defaults set at declaration stand, and the next save_data()
		## writes a clean file over the (now backed-up) original.
		_backup_corrupt_save(text)
		push_warning("ProgressionManager: save file was corrupt — backed up and starting fresh.")
		return

	## Version gate. Missing field == 0 (pre-versioning dev saves).
	var save_version: int = int(result.get("version", 0))
	if save_version > SAVE_VERSION:
		## A save from a newer build. Refuse it wholesale rather than dropping the
		## fields this build doesn't understand. Defaults remain; the menu warns.
		save_newer_than_supported = true
		push_warning("ProgressionManager: save is from a newer version (v%d > v%d) — not loaded." \
				% [save_version, SAVE_VERSION])
		return
	if save_version < SAVE_VERSION:
		result = _migrate_save(result, save_version)

	resources             = int(result.get("resources", 0))
	unlocked_weapons      = result.get("unlocked_weapons", [])
	selected_weapon       = str(result.get("selected_weapon", "Hurled Steel"))
	selected_weapon_2     = str(result.get("selected_weapon_2", ""))
	selected_weapon_3     = str(result.get("selected_weapon_3", ""))
	hub_upgrades          = result.get("hub_upgrades", [])
	## Migrate legacy "armory_expansion" → "armory_expansion_1"
	var _old_idx: int = hub_upgrades.find("armory_expansion")
	if _old_idx >= 0:
		hub_upgrades[_old_idx] = "armory_expansion_1"
	total_resources_spent = int(result.get("total_resources_spent", 0))
	total_runs            = int(result.get("total_runs", 0))
	successful_extractions = int(result.get("successful_extractions", 0))
	deaths                = int(result.get("deaths", 0))
	deepest_phase         = int(result.get("deepest_phase", 0))
	total_kills           = int(result.get("total_kills", 0))
	most_loot_extracted   = float(result.get("most_loot_extracted", 0.0))
	total_gold_earned     = float(result.get("total_gold_earned", 0.0))
	achievements_unlocked = result.get("achievements_unlocked", [])
	selected_character    = str(result.get("selected_character", "The Drifter"))
	unlocked_characters   = result.get("unlocked_characters", ["The Drifter"])
	## Always ensure The Drifter is unlocked (safety net for old save files)
	if "The Drifter" not in unlocked_characters:
		unlocked_characters.append("The Drifter")
	owned_mods   = result.get("owned_mods",  [])
	weapon_mods  = result.get("weapon_mods", {})
	character_mods = result.get("character_mods", {})   ## defensive: absent in pre-task-31 saves
	owned_trinkets = result.get("owned_trinkets", [])     ## defensive: absent in pre-task-34 saves
	character_trinkets = result.get("character_trinkets", {})
	character_loadouts = result.get("character_loadouts", {})
	game_cleared = bool(result.get("game_cleared", false))
	cleared_characters = result.get("cleared_characters", [])
	first_run_complete = bool(result.get("first_run_complete", false))
	passive_points = int(result.get("passive_points", 0))
	passive_allocations = result.get("passive_allocations", {})
	lifetime_passive_points = int(result.get("lifetime_passive_points", 0))

## Walk a save dict up to the current format, one version at a time. Each step is
## responsible only for the delta between two adjacent versions, so the chain stays
## readable as versions accumulate. Returns the upgraded dict (stamped to SAVE_VERSION).
func _migrate_save(data: Dictionary, from_version: int) -> Dictionary:
	var v: int = from_version
	while v < SAVE_VERSION:
		match v:
			0:
				data = _migrate_v0_to_v1(data)
			_:
				## Unknown gap — refuse to guess. Stamp current and let the
				## field-level defaults in load_data() fill anything absent.
				push_warning("ProgressionManager: no migration step for v%d; loading with defaults." % v)
				break
		v += 1
	data["version"] = SAVE_VERSION
	return data

## v0 (pre-versioning) → v1. No structural change is required: every field load_data()
## reads already uses `.get(key, default)`, and the two historical key renames
## (armory_expansion→armory_expansion_1, absent character_mods/trinkets) are handled
## inline there. This step exists to (a) formally accept every legacy dev save as v1
## and (b) be the worked example for the next author. When v2 arrives, copy this shape.
func _migrate_v0_to_v1(data: Dictionary) -> Dictionary:
	return data

## Copy a corrupt save aside before it gets overwritten, so a player (or we) can
## recover data or diagnose the failure. Best-effort: a failed backup must not block
## starting fresh, so errors here are swallowed after a warning.
func _backup_corrupt_save(raw_text: String) -> void:
	var stamp: int = int(Time.get_unix_time_from_system())
	var backup_path: String = "user://save_corrupt_%d.json" % stamp
	var f := FileAccess.open(backup_path, FileAccess.WRITE)
	if f:
		f.store_string(raw_text)
		f.close()
		push_warning("ProgressionManager: corrupt save backed up to %s" % backup_path)
	else:
		push_warning("ProgressionManager: could not write corrupt-save backup to %s" % backup_path)

## Returns true if a save file exists on disk (used by the main menu to gate Continue).
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Wipes the save file and resets all in-memory progression to defaults, then
## writes the fresh state immediately. Used by the main menu's New Game flow
## when overwriting an existing save.
func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	resources             = 0
	run_stats              = {}
	unlocked_weapons       = []
	selected_weapon        = "Hurled Steel"
	selected_weapon_2      = ""
	selected_weapon_3      = ""
	character_loadouts     = {}
	hub_upgrades           = []
	total_resources_spent  = 0
	owned_mods             = []
	weapon_mods            = {}
	character_mods         = {}
	owned_trinkets         = []
	character_trinkets     = {}
	total_runs             = 0
	successful_extractions = 0
	deaths                 = 0
	deepest_phase          = 0
	total_kills            = 0
	most_loot_extracted    = 0.0
	total_gold_earned      = 0.0
	achievements_unlocked  = []
	selected_character     = "The Drifter"
	unlocked_characters    = ["The Drifter"]
	game_cleared           = false
	cleared_characters     = []
	first_run_complete     = false
	passive_points         = 0
	passive_allocations    = {}
	lifetime_passive_points = 0
	save_data()

## Returns true if the player owns Extraction Intel I (timed zone revealed at run start).
func has_extraction_intel() -> bool:
	return has_upgrade("extraction_intel_1")

## Returns true if the player owns the upgrade.
func has_upgrade(id: String) -> bool:
	return id in hub_upgrades

## How many starting weapon slots the player has (1 base + 1 per armory_expansion tier).
func starting_weapon_slots() -> int:
	return 1 + get_upgrade_tier("armory_expansion")

## Returns how many tiers of a tiered upgrade the player owns (e.g., "channel_accelerator" → 0-3).
func get_upgrade_tier(base_id: String) -> int:
	var tier := 0
	for i in range(1, 10):
		if has_upgrade("%s_%d" % [base_id, i]):
			tier = i
		else:
			break
	return tier

## Returns the max number of rerolls per level-up (base 2, +1 per tier, max 4).
func get_max_rerolls() -> int:
	return 2 + get_upgrade_tier("reroll_capacity")

## Returns the extraction channel duration based on purchased Channel Accelerator tiers.
## Base: 4.0s → Tier 1: 3.25s → Tier 2: 2.5s → Tier 3: 2.0s
func get_channel_duration() -> float:
	var tier := get_upgrade_tier("channel_accelerator")
	match tier:
		1: return 3.25
		2: return 2.5
		3: return 2.0
		_: return 4.0

## Attempt to purchase a Workshop upgrade. Returns true on success.
func purchase_upgrade(id: String) -> bool:
	if has_upgrade(id):
		return false
	var cost: int = UPGRADE_COSTS.get(id, 0)
	if resources < cost:
		return false
	resources -= cost
	total_resources_spent += cost
	hub_upgrades.append(id)
	save_data()
	resources_changed.emit(resources)
	return true

## Hub visual tier (0-2) driven by total resources ever spent.
func get_hub_tier() -> int:
	if total_resources_spent >= 750:
		return 2
	elif total_resources_spent >= 300:
		return 1
	return 0

## Call after a successful extraction. Adds resources and records stats.
## levels_gained = player.level - 1 at run end; banked as passive points.
func record_extraction(resources_earned: int, kills_this_run: int, phase: int, loot_value: float = 0.0, levels_gained: int = 0) -> void:
	bank_passive_points(levels_gained)
	resources += resources_earned
	total_gold_earned += resources_earned
	successful_extractions += 1
	total_runs += 1
	total_kills += kills_this_run
	if phase > deepest_phase:
		deepest_phase = phase
	if loot_value > most_loot_extracted:
		most_loot_extracted = loot_value
	save_data()
	resources_changed.emit(resources)

## Call when a run clears the final biome's boss gate and extracts. Idempotent —
## a second (or later) win with any character is always safe to call again.
func record_win(char_id: String) -> void:
	game_cleared = true
	if char_id not in cleared_characters:
		cleared_characters.append(char_id)
	save_data()

## Call on death. Awards 25% of carried loot as penalized meta resources.
## levels_gained = player.level - 1 at run end; banked as passive points.
func record_death(loot_value: int, kills_this_run: int, phase: int, levels_gained: int = 0) -> void:
	bank_passive_points(levels_gained)
	var penalty: int = int(loot_value * 0.25)
	resources += penalty
	total_gold_earned += penalty
	deaths += 1
	total_runs += 1
	total_kills += kills_this_run
	if phase > deepest_phase:
		deepest_phase = phase
	save_data()
	resources_changed.emit(resources)

func add_weapon(weapon_id: String) -> void:
	if weapon_id not in unlocked_weapons:
		unlocked_weapons.append(weapon_id)
		save_data()

## Attempt to purchase a weapon blueprint. Returns true on success.
## Cost and eligibility are read from WeaponData (unlock_id must be non-empty).
func purchase_weapon_blueprint(weapon_id: String) -> bool:
	if weapon_id in unlocked_weapons:
		return false
	var weapon_data: Dictionary = WeaponData.ALL.get(weapon_id, {})
	if weapon_data.get("unlock_id", "").is_empty():
		return false  ## Starter / character-exclusive — not blueprint-purchasable
	var cost: int = weapon_data.get("blueprint_cost", 0)
	if cost <= 0 or resources < cost:
		return false
	resources -= cost
	total_resources_spent += cost
	add_weapon(weapon_id)  ## also calls save_data()
	resources_changed.emit(resources)
	return true

## Returns true if the weapon is available this run (no unlock required, or blueprint owned).
func is_weapon_available(weapon_id: String) -> bool:
	var weapon_data: Dictionary = WeaponData.ALL.get(weapon_id, {})
	if weapon_data.get("unlock_id", "").is_empty():
		return true  ## Always-available starters
	return weapon_id in unlocked_weapons

# ─── Mod management ────────────────────────────────────────────────────────────

## Add a mod to the player's collection (called on successful extraction).
func add_mod(mod_id: String) -> void:
	owned_mods.append(mod_id)   ## Allow duplicates — each instance is a separate item
	save_data()

## ── Per-character weapon loadouts ────────────────────────────────────────────
## Each character picks its own weapon(s); slot 1 (index 0) is what fires in-run.
## A character with no stored loadout defaults to its signature starting_weapon.

func get_character_loadout(char_id: String) -> Array:
	if not character_loadouts.has(char_id):
		var sig: String = CharacterData.ALL.get(char_id, {}).get("starting_weapon", "Hurled Steel")
		character_loadouts[char_id] = [sig, "", ""]
	return character_loadouts[char_id]

## Weapon equipped in the given 1-based slot for a character ("" if the slot is empty).
func get_character_weapon(char_id: String, slot: int = 1) -> String:
	var loadout: Array = get_character_loadout(char_id)
	var idx: int = slot - 1
	if idx >= 0 and idx < loadout.size():
		return str(loadout[idx])
	return ""

## Assign a weapon to a character's 1-based slot. Caller saves.
func set_character_weapon(char_id: String, slot: int, weapon_id: String) -> void:
	var loadout: Array = get_character_loadout(char_id)
	while loadout.size() < slot:
		loadout.append("")
	loadout[slot - 1] = weapon_id
	character_loadouts[char_id] = loadout


## Returns the equipped mod IDs for a weapon as an Array (may include "" for empty slots).
func get_weapon_mods(weapon_id: String) -> Array:
	return weapon_mods.get(weapon_id, [])

## Equip a mod into a specific slot (0-indexed) on a weapon. Saves immediately.
func set_weapon_mod(weapon_id: String, slot: int, mod_id: String) -> void:
	if not weapon_mods.has(weapon_id):
		weapon_mods[weapon_id] = []
	## Grow the array to accommodate this slot
	while weapon_mods[weapon_id].size() <= slot:
		weapon_mods[weapon_id].append("")
	weapon_mods[weapon_id][slot] = mod_id
	## Remove one copy from owned_mods inventory (it's now slotted)
	var idx: int = owned_mods.find(mod_id)
	if idx >= 0:
		owned_mods.remove_at(idx)
	save_data()

## Remove the mod from a weapon slot (0-indexed) and return it to owned_mods.
func remove_weapon_mod(weapon_id: String, slot: int) -> void:
	if not weapon_mods.has(weapon_id):
		return
	if slot >= weapon_mods[weapon_id].size():
		return
	var existing: String = weapon_mods[weapon_id][slot]
	if not existing.is_empty():
		owned_mods.append(existing)
	weapon_mods[weapon_id][slot] = ""
	save_data()

## ── Class-mod loadout (task 31) ──────────────────────────────────────────────
## Class mods equip per-character (not per-weapon). Storage mirrors weapon_mods: an array of
## slot strings per char_id, "" for empty. owned_mods is the shared inventory for both layers.

## How many class-mod slots a character has. Flat for now; task 34's class gear rarity is slated
## to drive this later (see docs/class_mod_system.md). Kept as a func so callers don't hardcode.
const CLASS_MOD_SLOTS: int = 2

func class_mod_slots(_char_id: String = "") -> int:
	return CLASS_MOD_SLOTS

## Equipped class-mod ids for a character (may include "" for empty slots).
func get_character_mods(char_id: String) -> Array:
	return character_mods.get(char_id, [])

## Class-mod ids equipped for a character that are actually valid for its kit — the set the
## player installs into the combo. Filters defensively so a stale/foreign id can never leak in.
func get_active_class_mods(char_id: String) -> Array:
	var out: Array = []
	for mod_id in get_character_mods(char_id):
		if mod_id is String and not (mod_id as String).is_empty() \
				and ModApplicability.class_applies(mod_id, char_id):
			out.append(mod_id)
	return out

## Equip a class mod into a character slot (0-indexed). Consumes one copy from owned_mods.
func set_character_mod(char_id: String, slot: int, mod_id: String) -> void:
	if not character_mods.has(char_id):
		character_mods[char_id] = []
	while character_mods[char_id].size() <= slot:
		character_mods[char_id].append("")
	character_mods[char_id][slot] = mod_id
	var idx: int = owned_mods.find(mod_id)
	if idx >= 0:
		owned_mods.remove_at(idx)
	save_data()

## Remove a class mod from a character slot (0-indexed) and return it to owned_mods.
func remove_character_mod(char_id: String, slot: int) -> void:
	if not character_mods.has(char_id):
		return
	if slot >= character_mods[char_id].size():
		return
	var existing: String = character_mods[char_id][slot]
	if not existing.is_empty():
		owned_mods.append(existing)
	character_mods[char_id][slot] = ""
	save_data()

## ── Trinkets & class-gear stash (task 34) ────────────────────────────────────
## Trinkets are universal but equip per-character (2 base slots + workshop 3rd).
## owned_trinkets is the shared unequipped inventory; equipping moves an instance
## out of it into a character slot (mirrors weapon_mods / class_mods).
const TRINKET_BASE_SLOTS: int = 2
const TRINKET_SLOT_UPGRADE: String = "trinket_slot"

func trinket_slots() -> int:
	return TRINKET_BASE_SLOTS + (1 if has_upgrade(TRINKET_SLOT_UPGRADE) else 0)

func add_trinket(trinket_id: String) -> void:
	owned_trinkets.append(trinket_id)   ## duplicates allowed — one per instance
	save_data()

## Equipped trinket ids for a character (may include "" for empty slots).
func get_character_trinkets(char_id: String) -> Array:
	return character_trinkets.get(char_id, [])

## Equip a trinket into a character slot (0-indexed). Consumes one copy from owned_trinkets.
func set_character_trinket(char_id: String, slot: int, trinket_id: String) -> void:
	if not character_trinkets.has(char_id):
		character_trinkets[char_id] = []
	while character_trinkets[char_id].size() <= slot:
		character_trinkets[char_id].append("")
	character_trinkets[char_id][slot] = trinket_id
	var idx: int = owned_trinkets.find(trinket_id)
	if idx >= 0:
		owned_trinkets.remove_at(idx)
	save_data()

## Remove a trinket from a character slot (0-indexed) and return it to owned_trinkets.
func remove_character_trinket(char_id: String, slot: int) -> void:
	if not character_trinkets.has(char_id):
		return
	if slot >= character_trinkets[char_id].size():
		return
	var existing: String = character_trinkets[char_id][slot]
	if not existing.is_empty():
		owned_trinkets.append(existing)
	character_trinkets[char_id][slot] = ""
	save_data()

## Roster badge (task 34): true when this character has an unlocked class weapon that
## isn't in its loadout — i.e. off-class cargo banked to its stash, waiting to be equipped.
func has_unequipped_gear(char_id: String) -> bool:
	var loadout: Array = get_character_loadout(char_id)
	for wid in unlocked_weapons:
		if WeaponData.get_weapon_class(wid) == char_id and wid not in loadout:
			return true
	return false


## Returns true if the character is already unlocked.
func has_character(char_id: String) -> bool:
	return char_id in unlocked_characters

## Attempt to purchase a character unlock. Returns true on success.
func purchase_character(char_id: String) -> bool:
	if has_character(char_id):
		return false
	if not CharacterData.ALL.has(char_id):
		return false
	var cost: int = CharacterData.ALL[char_id].get("unlock_cost", 0)
	if resources < cost:
		return false
	resources -= cost
	total_resources_spent += cost
	unlocked_characters.append(char_id)
	selected_character = char_id
	save_data()
	resources_changed.emit(resources)
	return true

## Select an already-unlocked character. Returns true on success.
func select_character(char_id: String) -> bool:
	if not has_character(char_id):
		return false
	selected_character = char_id
	save_data()
	return true


# ─── Passive skill tree ────────────────────────────────────────────────────────

func get_passive_points() -> int:
	return passive_points

func get_node_ranks(node_id: String) -> int:
	return int(passive_allocations.get(node_id, 0))

## Total ranks spent in a given branch (used for tier-gate and bridge checks).
func branch_ranks(branch: String) -> int:
	var total: int = 0
	for node_id: String in passive_allocations:
		if PassiveTreeData.NODES.get(node_id, {}).get("branch") == branch:
			total += int(passive_allocations[node_id])
	return total

## True if the node can be purchased right now (points, max_ranks, tier gate).
## Behavior nodes are purchasable — they're just inert until prompt 27.
func can_allocate(node_id: String) -> bool:
	var node: Dictionary = PassiveTreeData.NODES.get(node_id, {})
	if node.is_empty():
		return false
	var current_ranks: int = get_node_ranks(node_id)
	if current_ranks >= int(node.get("max_ranks", 1)):
		return false
	var cost: int = int(node.get("cost", 1))
	if passive_points < cost:
		return false
	## Rank 2+ only need the point check above; no tier re-gate (spec §3).
	if current_ranks > 0:
		return true
	## First rank: apply tier gate.
	var branch: String = node.get("branch", "core")
	if branch == "core":
		return true
	if branch == "bridge":
		var bridges: Array = node.get("bridges", [])
		for adj: String in bridges:
			if branch_ranks(adj) >= 4:
				return true
		return false
	## Normal branch node: needs 3 × tier ranks already spent in that branch.
	var tier: int = int(node.get("tier", 0))
	return branch_ranks(branch) >= tier * 3

## True if the node's tier/bridge gate is satisfied right now (ignores points and
## max_ranks). Lets the hub UI distinguish a tier-locked node from a merely
## unaffordable one without re-implementing the gate rule. Nodes with ≥1 rank
## already purchased always report their gate as met.
func node_gate_met(node_id: String) -> bool:
	var node: Dictionary = PassiveTreeData.NODES.get(node_id, {})
	if node.is_empty():
		return false
	if get_node_ranks(node_id) > 0:
		return true
	var branch: String = node.get("branch", "core")
	if branch == "core":
		return true
	if branch == "bridge":
		for adj: String in node.get("bridges", []):
			if branch_ranks(adj) >= 4:
				return true
		return false
	var tier: int = int(node.get("tier", 0))
	return branch_ranks(branch) >= tier * 3

## Human-readable requirement string for a gated node, e.g. "REQ 6 MIGHT" or
## "REQ 4 FINESSE / ARCANA". Empty for core nodes or nodes whose gate is met.
func node_gate_text(node_id: String) -> String:
	var node: Dictionary = PassiveTreeData.NODES.get(node_id, {})
	if node.is_empty():
		return ""
	var branch: String = node.get("branch", "core")
	if branch == "core":
		return ""
	if branch == "bridge":
		var bs: Array = node.get("bridges", [])
		if bs.size() == 2:
			return "REQ 4 %s / %s" % [str(bs[0]).to_upper(), str(bs[1]).to_upper()]
		return ""
	var tier: int = int(node.get("tier", 0))
	return "REQ %d %s" % [tier * 3, branch.to_upper()]

## Spend points to allocate one rank. Returns true on success.
func allocate(node_id: String) -> bool:
	if not can_allocate(node_id):
		return false
	var cost: int = int(PassiveTreeData.NODES[node_id].get("cost", 1))
	passive_points -= cost
	passive_allocations[node_id] = get_node_ranks(node_id) + 1
	save_data()
	return true

## Return all spent points and clear every allocation.
func refund_all() -> void:
	var refund: int = 0
	for node_id: String in passive_allocations:
		var node: Dictionary = PassiveTreeData.NODES.get(node_id, {})
		refund += int(node.get("cost", 1)) * int(passive_allocations[node_id])
	passive_points += refund
	passive_allocations.clear()
	save_data()

## Bank passive points earned at run end (called from record_extraction / record_death).
func bank_passive_points(levels_gained: int) -> void:
	var pts: int = maxi(levels_gained, 0)
	if pts <= 0:
		return
	passive_points += pts
	lifetime_passive_points += pts
	## save_data() is always called by the caller (record_extraction/record_death) after this.
