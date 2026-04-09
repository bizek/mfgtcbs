class_name StalkerData
extends RefCounted
## Factory for Stalker enemy — nearly invisible, reveals with flash at close range.
## High damage, low HP. Atmosphere builder.

static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id = "stalker"
	def.enemy_name = "Stalker"
	def.tags = ["Melee", "Stealth"]
	def.base_stats = {"max_hp": 40.0}
	def.combat_role = "MELEE"
	def.move_speed = 120.0
	def.contact_damage = 25.0
	def.base_armor = 0.0
	def.xp_value = 4.0
	def.health_drop_chance = 0.06
	def.behavior_type = "chase"
	def.aggro_range = 60.0  # Reveal distance
	return def
