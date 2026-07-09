extends Node

## UpgradeManager — Level-up choices, stat upgrades, and ability upgrades for in-run progression.
##
## Pool = filtered generic stats + the current class's ability upgrades (task 33).
## Filtering uses ModApplicability capability tags (task 31), replacing the old requires_melee flag.
## One slot per generate_choices call is reserved for an ability upgrade (if any remain unpicked).
## Evolutions replace a generic slot (never the ability upgrade slot) when their requirements land.

signal level_up_ready(choices: Array)
signal upgrade_chosen(upgrade: Dictionary)

## Generic stat / status upgrades — run-scoped, applied to the player directly.
var player_upgrades: Array[Dictionary] = []

## Run-scoped ability upgrades picked this run. Kit-mutation entries feed _load_combo;
## modifier entries add a ModifierDefinition with source "ability_upgrade".
var ability_upgrades: Array[Dictionary] = []

var EVOLUTION_RECIPES: Array[Dictionary] = [
	## Pruned per D2: removed fortress (duplicate recipe of juggernaut), bullet_storm, titan_rounds,
	## magnetar (all three required projectile-gated ingredients and were dead picks for melee kits),
	## and overdrive (overlaps with the adrenaline_rush generic upgrade). Remaining 7 are distinctive
	## and their ingredients are all universal (no projectile-gating).
	{
		"id": "glass_cannon",
		"name": "GLASS CANNON",
		"description": "+40% Damage, +10% Crit Chance, -15 Max HP",
		"requires": ["damage_up", "crit_chance_up"],
		"is_evolution": true,
		"effects": [
			{"stat": "damage", "type": "percent", "value": 0.40},
			{"stat": "crit_chance", "type": "flat", "value": 0.10},
			{"stat": "max_hp", "type": "flat", "value": -15.0},
		],
	},
	{
		"id": "juggernaut",
		"name": "JUGGERNAUT",
		"description": "+40 Max HP, +5 Armor",
		"requires": ["max_hp_up", "armor_up"],
		"is_evolution": true,
		"effects": [
			{"stat": "max_hp", "type": "flat", "value": 40.0},
			{"stat": "armor", "type": "flat", "value": 5.0},
		],
	},
	{
		"id": "velocity",
		"name": "VELOCITY",
		"description": "+25% Move Speed, +20% Attack Speed",
		"requires": ["move_speed_up", "attack_speed_up"],
		"is_evolution": true,
		"effects": [
			{"stat": "move_speed", "type": "percent", "value": 0.25},
			{"stat": "attack_speed", "type": "percent", "value": 0.20},
		],
	},
	{
		"id": "assassin",
		"name": "ASSASSIN",
		"description": "+10% Crit Chance, +50% Crit Damage, +15% Move Speed",
		"requires": ["crit_chance_up", "crit_damage_up"],
		"is_evolution": true,
		"effects": [
			{"stat": "crit_chance", "type": "flat", "value": 0.10},
			{"stat": "crit_multiplier", "type": "flat", "value": 0.50},
			{"stat": "move_speed", "type": "percent", "value": 0.15},
		],
	},
	{
		"id": "vampiric_blade",
		"name": "VAMPIRIC BLADE",
		"description": "Hits apply Bleed + On Kill: Heal 8% Max HP",
		"requires": ["bloodthirst", "serrated_strikes"],
		"is_evolution": true,
		"effects": [
			{"type": "status", "status_id": "vampiric_blade"},
		],
	},
	{
		"id": "phase_runner",
		"name": "PHASE RUNNER",
		"description": "+1 Dash Charge, +30% Dash Dist, +15% Speed",
		"requires": ["fleetfoot", "dash_charge_up"],
		"is_evolution": true,
		"effects": [
			{"stat": "dash_charges", "type": "flat", "value": 1.0},
			{"stat": "dash_speed", "type": "percent", "value": 0.30},
			{"stat": "move_speed", "type": "percent", "value": 0.15},
		],
	},
	{
		"id": "lightning_reflexes",
		"name": "LIGHTNING REFLEXES",
		"description": "On Crit: 20 Lightning AoE + On Dodge: Heal 5%",
		"requires": ["static_discharge", "second_wind"],
		"is_evolution": true,
		"effects": [
			{"type": "status", "status_id": "lightning_reflexes"},
		],
	},
]

var upgrade_pool: Array[Dictionary] = []
var earned_evolutions: Array[String] = []

func _ready() -> void:
	_build_upgrade_pool()

func _build_upgrade_pool() -> void:
	upgrade_pool = [
		{"id": "damage_up",          "name": "Damage Up",        "description": "+20% Damage",         "stat": "damage",         "type": "percent", "value": 0.20},
		{"id": "attack_speed_up",    "name": "Attack Speed Up",  "description": "+15% Attack Speed",   "stat": "attack_speed",   "type": "percent", "value": 0.15},
		{"id": "max_hp_up",          "name": "Max HP Up",        "description": "+20 Max HP",          "stat": "max_hp",         "type": "flat",    "value": 20.0},
		{"id": "move_speed_up",      "name": "Speed Up",         "description": "+15% Move Speed",     "stat": "move_speed",     "type": "percent", "value": 0.15},
		{"id": "fleetfoot",          "name": "Fleetfoot",        "description": "+12 Move Speed",      "stat": "move_speed",     "type": "flat",    "value": 12.0},
		{"id": "crit_chance_up",     "name": "Critical Strike",  "description": "+5% Crit Chance",     "stat": "crit_chance",    "type": "flat",    "value": 0.05},
		{"id": "crit_damage_up",     "name": "Critical Power",   "description": "+25% Crit Damage",    "stat": "crit_multiplier","type": "flat",    "value": 0.25},
		{"id": "pickup_radius_up",   "name": "Magnetism",        "description": "+30% Pickup Radius",  "stat": "pickup_radius",  "type": "percent", "value": 0.30},
		{"id": "armor_up",           "name": "Armor Up",         "description": "+3 Armor",            "stat": "armor",          "type": "flat",    "value": 3.0},
		## Projectile-only — filtered out for kits without the "projectile" capability tag.
		{"id": "projectile_count_up","name": "Multi Shot",       "description": "+1 Projectile",       "stat": "projectile_count","type": "flat",   "value": 1.0,  "requires_cap": "projectile"},
		{"id": "pierce_up",          "name": "Pierce",           "description": "+1 Pierce",           "stat": "pierce",         "type": "flat",    "value": 1.0,  "requires_cap": "projectile"},
		{"id": "projectile_size_up", "name": "Bigger Shots",     "description": "+25% Projectile Size","stat": "projectile_size","type": "percent", "value": 0.25, "requires_cap": "projectile"},
		## Universal — all kits land melee hits so Reach always applies.
		{"id": "reach_up",           "name": "Reach",            "description": "+25% Melee Range",    "stat": "melee_range",    "type": "percent", "value": 0.25},
		{"id": "dash_distance_up",   "name": "Dash Distance",    "description": "+20% Dash Distance",  "stat": "dash_speed",     "type": "percent", "value": 0.20},
		{"id": "dash_charge_up",     "name": "Extra Dash Charge","description": "+1 Dash Charge",      "stat": "dash_charges",   "type": "flat",    "value": 1.0},
		{"id": "dash_cooldown_down",  "name": "Quick Recovery",  "description": "-15% Dash Cooldown",  "stat": "dash_cooldown",  "type": "percent", "value": -0.15},
		{"id": "bloodthirst",        "name": "Bloodthirst",      "description": "On Kill: Heal 5% Max HP",        "type": "status", "status_id": "bloodthirst"},
		{"id": "static_discharge",   "name": "Static Discharge", "description": "On Crit: Lightning AOE",         "type": "status", "status_id": "static_discharge"},
		{"id": "serrated_strikes",   "name": "Serrated Strikes", "description": "Hits apply Bleed",               "type": "status", "status_id": "serrated_strikes"},
		{"id": "adrenaline_rush",    "name": "Adrenaline Rush",  "description": "On Kill: +25% Speed (3s)",       "type": "status", "status_id": "adrenaline_rush"},
		{"id": "thorns_passive",     "name": "Thorns",           "description": "Reflect 8 damage when hit",      "type": "status", "status_id": "thorns_passive"},
		{"id": "second_wind",        "name": "Second Wind",      "description": "On Dodge: Heal 3% Max HP",       "type": "status", "status_id": "second_wind"},
	]


func generate_choices(count: int = 3) -> Array[Dictionary]:
	var char_id: String = ProgressionManager.selected_character
	var char_caps: Array = ModApplicability.capabilities_for_character(char_id)
	var kit_id: String = ModApplicability.kit_of(char_id)

	## Build set of already-owned upgrade ids (generic + ability upgrades).
	var owned_ids: Array[String] = []
	for u: Dictionary in player_upgrades:
		owned_ids.append(u["id"])
	for u: Dictionary in ability_upgrades:
		owned_ids.append(u["id"])

	## Generic pool: filter out one-time status upgrades already owned and projectile-only
	## entries for kits that emit no projectiles (capability-tag resolver from task 31).
	var generic_pool: Array[Dictionary] = []
	for entry: Dictionary in upgrade_pool:
		if entry.get("type") == "status" and entry["id"] in owned_ids:
			continue
		var req_cap: String = entry.get("requires_cap", "")
		if req_cap != "" and req_cap not in char_caps:
			continue
		generic_pool.append(entry)

	## Ability upgrade pool: this class's kit-specific upgrades not yet picked this run.
	var ability_pool: Array[Dictionary] = []
	for entry: Dictionary in AbilityUpgradeData.get_upgrades_for_kit(kit_id):
		if entry["id"] not in owned_ids:
			ability_pool.append(entry)

	## Weighting: reserve 1 slot for an ability upgrade (guaranteed exposure), fill the rest
	## from generics. This gives one class-flavored option per level-up until they're exhausted,
	## without crowding out stats (2 generic slots remain every time an ability upgrade is offered).
	var choices: Array[Dictionary] = []
	ability_pool.shuffle()
	generic_pool.shuffle()

	if not ability_pool.is_empty():
		choices.append(ability_pool[0])

	## Fill remaining (count - reserved) slots from generics, skipping any already-chosen id.
	var chosen_ids: Array[String] = []
	for c: Dictionary in choices:
		chosen_ids.append(c["id"])
	for entry: Dictionary in generic_pool:
		if entry["id"] in chosen_ids:
			continue
		choices.append(entry)
		chosen_ids.append(entry["id"])
		if choices.size() >= count:
			break

	## Evolution: replace the last GENERIC slot (never the ability upgrade slot) if eligible.
	var available_evo: Dictionary = _get_available_evolution()
	if not available_evo.is_empty() and not choices.is_empty():
		var replace_idx: int = choices.size() - 1
		for i: int in range(choices.size() - 1, -1, -1):
			if not choices[i].get("is_ability_upgrade", false) \
					and not choices[i].get("is_evolution", false):
				replace_idx = i
				break
		choices[replace_idx] = available_evo

	return choices


func _get_available_evolution() -> Dictionary:
	var owned_ids: Array[String] = []
	for u: Dictionary in player_upgrades:
		owned_ids.append(u["id"])

	var eligible: Array[Dictionary] = []
	for recipe: Dictionary in EVOLUTION_RECIPES:
		if recipe["id"] in earned_evolutions:
			continue
		var has_all: bool = true
		for req: String in recipe["requires"]:
			if req not in owned_ids:
				has_all = false
				break
		if has_all:
			eligible.append(recipe)

	if eligible.is_empty():
		return {}
	return eligible[randi() % eligible.size()]


func apply_upgrade(upgrade: Dictionary, player: Node) -> void:
	if upgrade.get("is_evolution", false):
		_apply_evolution(upgrade, player)
	elif upgrade.get("is_ability_upgrade", false):
		ability_upgrades.append(upgrade)
		if player.has_method("apply_ability_upgrade"):
			player.apply_ability_upgrade(upgrade)
	else:
		player_upgrades.append(upgrade)
		if player.has_method("apply_stat_upgrade"):
			player.apply_stat_upgrade(upgrade)
	upgrade_chosen.emit(upgrade)


func _apply_evolution(evo: Dictionary, player: Node) -> void:
	## Remove prerequisite upgrades and reverse their stats.
	for req_id: String in evo["requires"]:
		for i: int in range(player_upgrades.size() - 1, -1, -1):
			if player_upgrades[i]["id"] == req_id:
				var old: Dictionary = player_upgrades[i]
				if player.has_method("remove_stat_upgrade"):
					player.remove_stat_upgrade(old)
				player_upgrades.remove_at(i)
				break

	## Apply each effect in the evolution.
	for effect: Dictionary in evo["effects"]:
		var pseudo_upgrade: Dictionary
		if effect.get("type") == "status":
			pseudo_upgrade = {"id": evo["id"], "type": "status", "status_id": effect["status_id"]}
		else:
			pseudo_upgrade = {"id": evo["id"], "stat": effect["stat"], "type": effect["type"], "value": effect["value"]}
		if player.has_method("apply_stat_upgrade"):
			player.apply_stat_upgrade(pseudo_upgrade)

	player_upgrades.append(evo)
	earned_evolutions.append(evo["id"])


## Returns kit-mutation ability upgrades for the given kit (excludes modifier ops, which are
## applied directly to the modifier component and do not need a _load_combo pass).
func get_kit_mutation_upgrades_for_kit(kit_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for up: Dictionary in ability_upgrades:
		if up.get("kit", "") == kit_id and up.get("op", "") != "modifier":
			result.append(up)
	return result


func reset() -> void:
	player_upgrades.clear()
	ability_upgrades.clear()
	earned_evolutions.clear()
