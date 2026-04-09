class_name BruteData
extends RefCounted
## Factory for Brute enemy — big, slow, tough. Scaled-up zombie with armor.

static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id = "brute"
	def.enemy_name = "Brute"
	def.tags = ["Melee", "Heavy"]
	def.base_stats = {"max_hp": 80.0}
	def.combat_role = "MELEE"
	def.move_speed = 60.0
	def.contact_damage = 15.0
	def.base_armor = 5.0
	def.xp_value = 5.0
	def.health_drop_chance = 0.08
	def.behavior_type = "chase"
	def.base_modulate = Color(0.72, 0.14, 0.11, 1.0)
	def.sprite_scale = Vector2(1.8, 1.8)
	return def
