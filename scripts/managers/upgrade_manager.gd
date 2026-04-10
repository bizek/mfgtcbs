extends Node

## UpgradeManager — Level-up choices and stat upgrades for prototype

signal level_up_ready(choices: Array)
signal upgrade_chosen(upgrade: Dictionary)

## Pool of available upgrades (prototype: simple stat boosts)
var upgrade_pool: Array[Dictionary] = []
var player_upgrades: Array[Dictionary] = []

var EVOLUTION_RECIPES: Array[Dictionary] = [
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
		"id": "bullet_storm",
		"name": "BULLET STORM",
		"description": "+2 Projectiles, +25% Attack Speed",
		"requires": ["projectile_count_up", "attack_speed_up"],
		"is_evolution": true,
		"effects": [
			{"stat": "projectile_count", "type": "flat", "value": 2.0},
			{"stat": "attack_speed", "type": "percent", "value": 0.25},
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
		"id": "titan_rounds",
		"name": "TITAN ROUNDS",
		"description": "+40% Projectile Size, +50% Crit Damage",
		"requires": ["projectile_size_up", "crit_damage_up"],
		"is_evolution": true,
		"effects": [
			{"stat": "projectile_size", "type": "percent", "value": 0.40},
			{"stat": "crit_multiplier", "type": "flat", "value": 0.50},
		],
	},
	{
		"id": "magnetar",
		"name": "MAGNETAR",
		"description": "+50% Pickup Radius, +2 Pierce",
		"requires": ["pickup_radius_up", "pierce_up"],
		"is_evolution": true,
		"effects": [
			{"stat": "pickup_radius", "type": "percent", "value": 0.50},
			{"stat": "pierce", "type": "flat", "value": 2.0},
		],
	},
	{
		"id": "fortress",
		"name": "FORTRESS",
		"description": "+30 Max HP, +4 Armor, -10% Move Speed",
		"requires": ["max_hp_up", "armor_up"],
		"is_evolution": true,
		"effects": [
			{"stat": "max_hp", "type": "flat", "value": 30.0},
			{"stat": "armor", "type": "flat", "value": 4.0},
			{"stat": "move_speed", "type": "percent", "value": -0.10},
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
		"id": "overdrive",
		"name": "OVERDRIVE",
		"description": "On Kill: +40% Speed for 4s",
		"requires": ["adrenaline_rush", "move_speed_up"],
		"is_evolution": true,
		"effects": [
			{"type": "status", "status_id": "overdrive"},
			{"stat": "move_speed", "type": "percent", "value": 0.10},
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

var earned_evolutions: Array[String] = []

func _ready() -> void:
	_build_upgrade_pool()

func _build_upgrade_pool() -> void:
	upgrade_pool = [
		{"id": "damage_up", "name": "Damage Up", "description": "+20% Damage", "stat": "damage", "type": "percent", "value": 0.20},
		{"id": "attack_speed_up", "name": "Attack Speed Up", "description": "+15% Attack Speed", "stat": "attack_speed", "type": "percent", "value": 0.15},
		{"id": "max_hp_up", "name": "Max HP Up", "description": "+20 Max HP", "stat": "max_hp", "type": "flat", "value": 20.0},
		{"id": "move_speed_up", "name": "Speed Up", "description": "+15% Move Speed", "stat": "move_speed", "type": "percent", "value": 0.15},
		{"id": "crit_chance_up", "name": "Critical Strike", "description": "+5% Crit Chance", "stat": "crit_chance", "type": "flat", "value": 0.05},
		{"id": "crit_damage_up", "name": "Critical Power", "description": "+25% Crit Damage", "stat": "crit_multiplier", "type": "flat", "value": 0.25},
		{"id": "pickup_radius_up", "name": "Magnetism", "description": "+30% Pickup Radius", "stat": "pickup_radius", "type": "percent", "value": 0.30},
		{"id": "armor_up", "name": "Armor Up", "description": "+3 Armor", "stat": "armor", "type": "flat", "value": 3.0},
		{"id": "projectile_count_up", "name": "Multi Shot", "description": "+1 Projectile", "stat": "projectile_count", "type": "flat", "value": 1.0},
		{"id": "pierce_up", "name": "Pierce", "description": "+1 Pierce", "stat": "pierce", "type": "flat", "value": 1.0},
		{"id": "projectile_size_up", "name": "Bigger Shots", "description": "+25% Projectile Size", "stat": "projectile_size", "type": "percent", "value": 0.25},
		{"id": "bloodthirst", "name": "Bloodthirst", "description": "On Kill: Heal 5% Max HP", "type": "status", "status_id": "bloodthirst"},
		{"id": "static_discharge", "name": "Static Discharge", "description": "On Crit: Lightning AOE", "type": "status", "status_id": "static_discharge"},
		{"id": "serrated_strikes", "name": "Serrated Strikes", "description": "Hits apply Bleed", "type": "status", "status_id": "serrated_strikes"},
		{"id": "adrenaline_rush", "name": "Adrenaline Rush", "description": "On Kill: +25% Speed (3s)", "type": "status", "status_id": "adrenaline_rush"},
		{"id": "thorns_passive", "name": "Thorns", "description": "Reflect 8 damage when hit", "type": "status", "status_id": "thorns_passive"},
		{"id": "second_wind", "name": "Second Wind", "description": "On Dodge: Heal 3% Max HP", "type": "status", "status_id": "second_wind"},
	]

func generate_choices(count: int = 3) -> Array[Dictionary]:
	## Filter out status upgrades already owned (they're one-time pickups)
	var owned_ids: Array[String] = []
	for u in player_upgrades:
		owned_ids.append(u["id"])
	var pool_copy: Array[Dictionary] = []
	for entry in upgrade_pool:
		if entry.get("type") == "status" and entry["id"] in owned_ids:
			continue
		pool_copy.append(entry)
	pool_copy.shuffle()
	var choices: Array[Dictionary] = []
	for i in range(mini(count, pool_copy.size())):
		choices.append(pool_copy[i])

	## Check if player qualifies for any evolution
	var available_evo: Dictionary = _get_available_evolution()
	if not available_evo.is_empty() and not choices.is_empty():
		## Replace the last choice with the evolution
		choices[choices.size() - 1] = available_evo

	return choices

func _get_available_evolution() -> Dictionary:
	var owned_ids: Array[String] = []
	for u in player_upgrades:
		owned_ids.append(u["id"])

	var eligible: Array[Dictionary] = []
	for recipe in EVOLUTION_RECIPES:
		if recipe["id"] in earned_evolutions:
			continue
		var has_all: bool = true
		for req in recipe["requires"]:
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
	else:
		player_upgrades.append(upgrade)
		if player.has_method("apply_stat_upgrade"):
			player.apply_stat_upgrade(upgrade)
	upgrade_chosen.emit(upgrade)

func _apply_evolution(evo: Dictionary, player: Node) -> void:
	## Remove prerequisite upgrades and reverse their stats
	for req_id in evo["requires"]:
		for i in range(player_upgrades.size() - 1, -1, -1):
			if player_upgrades[i]["id"] == req_id:
				var old := player_upgrades[i]
				if player.has_method("remove_stat_upgrade"):
					player.remove_stat_upgrade(old)
				player_upgrades.remove_at(i)
				break

	## Apply each effect in the evolution
	for effect in evo["effects"]:
		var pseudo_upgrade: Dictionary
		if effect.get("type") == "status":
			pseudo_upgrade = {"id": evo["id"], "type": "status", "status_id": effect["status_id"]}
		else:
			pseudo_upgrade = {"id": evo["id"], "stat": effect["stat"], "type": effect["type"], "value": effect["value"]}
		if player.has_method("apply_stat_upgrade"):
			player.apply_stat_upgrade(pseudo_upgrade)

	player_upgrades.append(evo)
	earned_evolutions.append(evo["id"])

func reset() -> void:
	player_upgrades.clear()
	earned_evolutions.clear()
