class_name ZombieGiantData
extends RefCounted
## Level 2 — The Catacombs — FINAL BOSS: "The Charnel Giant" (Minifantasy Zombie_Giant).
##
## Three tools, escalating in area: a telegraphed fist slam, a plague pool it leaves behind,
## and a full-arena shockwave. Mirrors the Goblin King's role as Level 1's phase-5 gate.
## Placed by LevelData.LEVELS[2].final_boss_id.

const COLOR_ROT: Color = Color(0.45, 0.62, 0.32, 0.55)


static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id       = "zombie_giant"
	def.enemy_name     = "The Charnel Giant"
	def.tags           = ["Melee", "Heavy", "Boss", "Undead"]
	def.base_stats     = {"max_hp": 1400.0}
	def.combat_role    = "MELEE"
	def.move_speed     = 22.0
	def.contact_damage = 24.0
	def.base_armor     = 14.0
	def.xp_value       = 160.0
	def.health_drop_chance   = 0.75
	def.behavior_type        = "chase"
	def.knockback_multiplier = 0.05
	def.sprite_scale         = Vector2(2.8, 2.8)
	def.groups   = ["bosses"]
	def.is_boss  = true
	def.boss_bar_color = Color(0.50, 0.70, 0.30)   ## rot-green final-boss bar

	def.auto_attack = _fist_slam()

	var sk_pool := SkillDefinition.new()
	sk_pool.skill_name = "Plague Pool"
	sk_pool.unlock_level = 1
	sk_pool.ability = _plague_pool()

	var sk_wave := SkillDefinition.new()
	sk_wave.skill_name = "Charnel Wave"
	sk_wave.unlock_level = 1
	sk_wave.ability = _charnel_wave()

	def.skills = [sk_pool, sk_wave]
	return def


static func _fist_slam() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "circle"
	telegraph.anchor = "target_position"
	telegraph.radius = 85.0
	telegraph.duration = 0.85
	telegraph.color = COLOR_ROT
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "giant_slam"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.5
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 0.85
	windup.default_next = 1

	var slam := AreaDamageEffect.new()
	slam.damage_type = "Physical"
	slam.base_damage = 34.0
	slam.aoe_radius = 85.0

	var hit := ChoreographyPhase.new()
	hit.effects = [slam]
	hit.hit_frame = -1
	hit.exit_type = "wait"
	hit.wait_duration = 0.45
	hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, hit]

	var aa := AbilityDefinition.new()
	aa.ability_id = "giant_fist_slam"
	aa.ability_name = "Fist Slam"
	aa.tags = ["Melee", "AOE", "Boss"]
	aa.cooldown_base = 4.0
	aa.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 220.0
	aa.targeting = targeting
	aa.choreography = choreo
	return aa


## Lingering poison ground at the player's feet — denies the spot they were standing in.
static func _plague_pool() -> AbilityDefinition:
	var tick := DealDamageEffect.new()
	tick.damage_type = "Poison"
	tick.base_damage = 4.0

	var zone := GroundZoneEffect.new()
	zone.zone_id = "giant_plague_pool"
	zone.radius = 55.0
	zone.duration = 6.0
	zone.tick_interval = 0.5
	zone.target_faction = "enemy"          ## "enemy" of the caster = the player
	zone.tick_effects = [tick]
	zone.debug_color = Color(0.35, 0.65, 0.25, 0.55)
	zone.vfx_element = "poison"

	var ab := AbilityDefinition.new()
	ab.ability_id = "giant_plague_pool"
	ab.ability_name = "Plague Pool"
	ab.tags = ["AOE", "Poison", "Boss"]
	ab.cooldown_base = 8.0
	ab.mode = "Auto"
	ab.priority = 5
	ab.cast_range = 220.0
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 220.0
	ab.targeting = targeting
	ab.effects = [zone]
	return ab


## The phase-gate pressure tool: a wide ring the player has to actually leave.
static func _charnel_wave() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "ring"
	telegraph.anchor = "source_position"
	telegraph.radius = 170.0
	telegraph.duration = 1.3
	telegraph.color = Color(0.50, 0.70, 0.30, 0.55)
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "giant_wave"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.35
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 1.3
	windup.default_next = 1

	var burst := AreaDamageEffect.new()
	burst.damage_type = "Physical"
	burst.base_damage = 40.0
	burst.aoe_radius = 170.0

	var hit := ChoreographyPhase.new()
	hit.effects = [burst]
	hit.hit_frame = -1
	hit.exit_type = "wait"
	hit.wait_duration = 0.6
	hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, hit]

	var ab := AbilityDefinition.new()
	ab.ability_id = "giant_charnel_wave"
	ab.ability_name = "Charnel Wave"
	ab.tags = ["Melee", "AOE", "Boss"]
	ab.cooldown_base = 12.0
	ab.mode = "Auto"
	ab.priority = 6
	ab.cast_range = 190.0
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 190.0
	ab.targeting = targeting
	ab.choreography = choreo
	return ab
