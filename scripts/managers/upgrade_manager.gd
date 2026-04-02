extends Node

## UpgradeManager — Level-up choices and stat upgrades for prototype

signal level_up_ready(choices: Array)
signal upgrade_chosen(upgrade: Dictionary)

## Pool of available upgrades (prototype: simple stat boosts)
var upgrade_pool: Array[Dictionary] = []
var player_upgrades: Array[Dictionary] = []

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
	]

func generate_choices(count: int = 3) -> Array[Dictionary]:
	var pool_copy := upgrade_pool.duplicate()
	pool_copy.shuffle()
	var choices: Array[Dictionary] = []
	for i in range(mini(count, pool_copy.size())):
		choices.append(pool_copy[i])
	return choices

func apply_upgrade(upgrade: Dictionary, player: Node) -> void:
	player_upgrades.append(upgrade)
	if player.has_method("apply_stat_upgrade"):
		player.apply_stat_upgrade(upgrade)
	upgrade_chosen.emit(upgrade)

func reset() -> void:
	player_upgrades.clear()
