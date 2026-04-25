class_name SwarmerData
extends RefCounted
## Factory for Swarmer enemy — fast weak goblin, chases in packs.

static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id = "swarmer"
	def.enemy_name = "Swarmer"
	def.tags = ["Melee", "Common", "Swarm"]
	def.base_stats = {"max_hp": 10.0}
	def.combat_role = "MELEE"
	def.move_speed = 72.0
	def.contact_damage = 3.0
	def.base_armor = 0.0
	def.xp_value = 0.5
	def.health_drop_chance = 0.05
	def.behavior_type = "chase"
	return def
