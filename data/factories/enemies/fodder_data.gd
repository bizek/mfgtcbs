class_name FodderData
extends RefCounted
## Factory for Fodder enemy — basic melee zombie, chases player.

static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id = "fodder"
	def.enemy_name = "Fodder"
	def.tags = ["Melee", "Common"]
	def.base_stats = {"max_hp": 30.0}
	def.combat_role = "MELEE"
	def.move_speed = 25.0
	def.contact_damage = 6.0
	def.base_armor = 0.0
	def.xp_value = 1.0
	def.health_drop_chance = 0.05
	def.behavior_type = "chase"
	return def
