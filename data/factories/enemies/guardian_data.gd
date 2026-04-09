class_name GuardianData
extends RefCounted
## Factory for Guardian enemy — miniboss that guards extraction points.
## Stats are defined here; game-specific logic (keystone drop, sprite building)
## remains in enemy_guardian.gd as a subclass override.

static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id = "guardian"
	def.enemy_name = "Guardian"
	def.tags = ["Melee", "Heavy", "Boss"]
	def.base_stats = {"max_hp": 300.0}
	def.combat_role = "MELEE"
	def.move_speed = 42.0
	def.contact_damage = 20.0
	def.base_armor = 10.0
	def.xp_value = 50.0
	def.health_drop_chance = 0.25
	def.behavior_type = "chase"
	def.knockback_multiplier = 0.25
	def.base_modulate = Color(0.72, 0.14, 0.11, 1.0)
	def.groups = ["guardians"]
	return def
