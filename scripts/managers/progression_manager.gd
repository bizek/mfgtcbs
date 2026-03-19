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
var total_runs: int = 0
var successful_extractions: int = 0
var deaths: int = 0
var deepest_phase: int = 0
var total_kills: int = 0
var most_loot_extracted: float = 0.0

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
