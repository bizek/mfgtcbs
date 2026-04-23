class_name CaveEnemyData
extends RefCounted
## Level 1 — The Cave — enemy definitions.
##
## cave_fodder  = Tiny Goblin (Trasgo sprite)  — fast fragile swarm unit
## cave_swarmer = Goblin (existing swarmer sprite) — standard pack unit
## cave_brute   = Troll — slow, very tanky melee bruiser
##
## Scenes: cave_fodder.tscn, swarmer.tscn (reused), cave_brute.tscn
## Registered in EnemyRegistry under their enemy_id keys.


static func create_cave_fodder() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id       = "cave_fodder"
	def.enemy_name     = "Tiny Goblin"
	def.tags           = ["Melee", "Common", "Swarm"]
	def.base_stats     = {"max_hp": 8.0}
	def.combat_role    = "MELEE"
	def.move_speed     = 80.0  ## Faster than swarmer — skittery and annoying
	def.contact_damage = 6.0
	def.base_armor     = 0.0
	def.xp_value       = 0.4
	def.health_drop_chance   = 0.04
	def.behavior_type        = "chase"
	def.knockback_multiplier = 1.2  ## Light — gets knocked around easily
	return def


static func create_cave_swarmer() -> EnemyDefinition:
	## Goblin — cave identity wrapper around the existing swarmer stats.
	## Uses the same swarmer.tscn (Goblin sprites already correct).
	var def := EnemyDefinition.new()
	def.enemy_id       = "cave_swarmer"
	def.enemy_name     = "Goblin"
	def.tags           = ["Melee", "Common", "Swarm"]
	def.base_stats     = {"max_hp": 12.0}
	def.combat_role    = "MELEE"
	def.move_speed     = 110.0
	def.contact_damage = 6.0
	def.base_armor     = 0.0
	def.xp_value       = 0.6
	def.health_drop_chance   = 0.05
	def.behavior_type        = "chase"
	def.knockback_multiplier = 1.0
	return def


static func create_cave_brute() -> EnemyDefinition:
	## Troll — the cave's heavy. Slow, hits hard, shrugs off most knockback.
	var def := EnemyDefinition.new()
	def.enemy_id       = "cave_brute"
	def.enemy_name     = "Troll"
	def.tags           = ["Melee", "Tank"]
	def.base_stats     = {"max_hp": 90.0}
	def.combat_role    = "MELEE"
	def.move_speed     = 38.0
	def.contact_damage = 20.0
	def.base_armor     = 8.0
	def.xp_value       = 5.0
	def.health_drop_chance   = 0.18
	def.behavior_type        = "chase"
	def.knockback_multiplier = 0.25  ## Barely moves when hit
	def.sprite_scale         = Vector2(1.0, 1.0)
	return def
