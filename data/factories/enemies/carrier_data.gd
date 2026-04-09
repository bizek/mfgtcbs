class_name CarrierData
extends RefCounted
## Factory for Carrier enemy — flees from player, drops loot on death.
## Despawns at arena bounds if it escapes.

static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id = "carrier"
	def.enemy_name = "Carrier"
	def.tags = ["Common", "Carrier"]
	def.base_stats = {"max_hp": 15.0}
	def.combat_role = "MELEE"
	def.move_speed = 180.0
	def.contact_damage = 0.0
	def.base_armor = 0.0
	def.xp_value = 2.0
	def.health_drop_chance = 0.0
	def.behavior_type = "flee"
	def.flee_despawn_at_bounds = true
	def.groups = ["carriers"]
	def.base_modulate = Color(1.0, 0.85, 0.1, 1.0)
	def.sprite_scale = Vector2(0.8, 0.8)
	return def
