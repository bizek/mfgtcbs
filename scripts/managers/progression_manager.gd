extends Node

## ProgressionManager — Persists meta-progression data between runs (save/load JSON).

signal resources_changed(amount: int)

const SAVE_PATH := "user://progression.json"

## Workshop upgrade definitions: id → cost
const UPGRADE_COSTS: Dictionary = {
	"insurance_license": 300,
	"armory_expansion":  750,
}

var resources: int = 0
var unlocked_weapons: Array = []
var selected_weapon: String = "Standard Sidearm"
var selected_weapon_2: String = ""          ## Only used when armory_expansion is owned
var hub_upgrades: Array = []               ## IDs of purchased Workshop upgrades
var total_resources_spent: int = 0         ## Drives hub visual tier

## Mod inventory — all mod IDs the player has collected through successful extractions
var owned_mods: Array = []
## Equipped mods per weapon — { "weapon_id": ["mod_id_slot0", "mod_id_slot1"] }
## Empty string "" means the slot is empty.
var weapon_mods: Dictionary = {}
var total_runs: int = 0
var successful_extractions: int = 0
var deaths: int = 0
var deepest_phase: int = 0
var total_kills: int = 0
var most_loot_extracted: float = 0.0

## Character roster
var selected_character: String = "The Drifter"
var unlocked_characters: Array = ["The Drifter"]

func _ready() -> void:
	load_data()

func save_data() -> void:
	var data := {
		"resources":              resources,
		"unlocked_weapons":       unlocked_weapons,
		"selected_weapon":        selected_weapon,
		"selected_weapon_2":      selected_weapon_2,
		"hub_upgrades":           hub_upgrades,
		"total_resources_spent":  total_resources_spent,
		"total_runs":             total_runs,
		"successful_extractions": successful_extractions,
		"deaths":                 deaths,
		"deepest_phase":          deepest_phase,
		"total_kills":            total_kills,
		"most_loot_extracted":    most_loot_extracted,
		"selected_character":     selected_character,
		"unlocked_characters":    unlocked_characters,
		"owned_mods":             owned_mods,
		"weapon_mods":            weapon_mods,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	var result = JSON.parse_string(text)
	if typeof(result) != TYPE_DICTIONARY:
		return
	resources             = int(result.get("resources", 0))
	unlocked_weapons      = result.get("unlocked_weapons", [])
	selected_weapon       = str(result.get("selected_weapon", "Standard Sidearm"))
	selected_weapon_2     = str(result.get("selected_weapon_2", ""))
	hub_upgrades          = result.get("hub_upgrades", [])
	total_resources_spent = int(result.get("total_resources_spent", 0))
	total_runs            = int(result.get("total_runs", 0))
	successful_extractions = int(result.get("successful_extractions", 0))
	deaths                = int(result.get("deaths", 0))
	deepest_phase         = int(result.get("deepest_phase", 0))
	total_kills           = int(result.get("total_kills", 0))
	most_loot_extracted   = float(result.get("most_loot_extracted", 0.0))
	selected_character    = str(result.get("selected_character", "The Drifter"))
	unlocked_characters   = result.get("unlocked_characters", ["The Drifter"])
	## Always ensure The Drifter is unlocked (safety net for old save files)
	if "The Drifter" not in unlocked_characters:
		unlocked_characters.append("The Drifter")
	owned_mods   = result.get("owned_mods",  [])
	weapon_mods  = result.get("weapon_mods", {})

## Returns true if the player owns the upgrade.
func has_upgrade(id: String) -> bool:
	return id in hub_upgrades

## How many starting weapon slots the player has.
func starting_weapon_slots() -> int:
	return 2 if has_upgrade("armory_expansion") else 1

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
func record_extraction(resources_earned: int, kills_this_run: int, phase: int, loot_value: float = 0.0) -> void:
	resources += resources_earned
	successful_extractions += 1
	total_runs += 1
	total_kills += kills_this_run
	if phase > deepest_phase:
		deepest_phase = phase
	if loot_value > most_loot_extracted:
		most_loot_extracted = loot_value
	save_data()
	resources_changed.emit(resources)

## Call on death. Awards 25% of carried loot as penalized meta resources.
func record_death(loot_value: int, kills_this_run: int, phase: int) -> void:
	var penalty: int = int(loot_value * 0.25)
	resources += penalty
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

# ─── Mod management ────────────────────────────────────────────────────────────

## Add a mod to the player's collection (called on successful extraction).
func add_mod(mod_id: String) -> void:
	owned_mods.append(mod_id)   ## Allow duplicates — each instance is a separate item
	save_data()

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
