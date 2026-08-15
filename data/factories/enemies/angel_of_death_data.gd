class_name AngelOfDeathData
extends RefCounted
## Level 3 — The Nightmare Realm — FINAL BOSS: "The Angel of Death" (Minifantasy Angel_of_Death).
##
## Three tools, escalating in area, mirroring the Charnel Giant's role as Level 2's phase-5 gate:
## a telegraphed scythe reap, a lingering grave-mark pool where it points, and a full-arena
## wing storm. It flies, so its "walk" is the pack's Fly sheet and it moves faster than any
## previous boss — the arena stops being a place you can simply out-walk.
## Placed by LevelData.LEVELS[3].final_boss_id.

const COLOR_VOID: Color = Color(0.55, 0.35, 0.78, 0.55)


static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id       = "angel_of_death"
	def.enemy_name     = "The Angel of Death"
	def.tags           = ["Melee", "Aerial", "Boss"]
	def.base_stats     = {"max_hp": 1900.0}
	def.combat_role    = "MELEE"
	def.move_speed     = 34.0                       ## airborne: faster than both prior bosses
	def.contact_damage = 28.0
	def.base_armor     = 16.0
	def.xp_value       = 210.0
	def.health_drop_chance   = 0.75
	def.behavior_type        = "chase"
	def.knockback_multiplier = 0.05
	def.sprite_scale         = Vector2(2.8, 2.8)
	def.groups   = ["bosses"]
	def.is_boss  = true
	def.boss_bar_color = Color(0.62, 0.42, 0.85)    ## void-violet final-boss bar

	def.auto_attack = _scythe_reap()

	var sk_mark := SkillDefinition.new()
	sk_mark.skill_name = "Grave Mark"
	sk_mark.unlock_level = 1
	sk_mark.ability = _grave_mark()

	var sk_storm := SkillDefinition.new()
	sk_storm.skill_name = "Wing Storm"
	sk_storm.unlock_level = 1
	sk_storm.ability = _wing_storm()

	def.skills = [sk_mark, sk_storm]
	return def


## Telegraphed scythe sweep at the player's position — the bread-and-butter pressure tool.
static func _scythe_reap() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "circle"
	telegraph.anchor = "target_position"
	telegraph.radius = 76.0
	telegraph.duration = 0.7
	telegraph.color = COLOR_VOID
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "angel_reap"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.5
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 0.7
	windup.default_next = 1

	var reap := AreaDamageEffect.new()
	reap.damage_type = "Void"
	reap.base_damage = 38.0
	reap.aoe_radius = 76.0

	var hit := ChoreographyPhase.new()
	hit.effects = [reap]
	hit.hit_frame = -1
	hit.exit_type = "wait"
	hit.wait_duration = 0.4
	hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, hit]

	var aa := AbilityDefinition.new()
	aa.ability_id = "angel_scythe_reap"
	aa.ability_name = "Scythe Reap"
	aa.tags = ["Melee", "AOE", "Boss"]
	aa.cooldown_base = 4.2
	aa.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 210.0
	aa.targeting = targeting
	aa.choreography = choreo
	return aa


## Leaves a lingering void pool under the player — the tool that denies territory, so the
## fight keeps moving.
##
## Deliberately NOT telegraphed, mirroring the Charnel Giant's Plague Pool. EffectDispatcher
## places a GroundZoneEffect at the TARGET's position at the moment the effect fires
## (effect_dispatcher.gd:188), so a telegraph drawn during a wind-up would mark where the
## player *was* and the pool would land somewhere else. A telegraph that lies is worse than
## no telegraph; the Angel's other two tools are both telegraphed.
static func _grave_mark() -> AbilityDefinition:
	var burn := DealDamageEffect.new()
	burn.damage_type = "Void"
	burn.base_damage = 9.0

	var zone := GroundZoneEffect.new()
	zone.zone_id = "angel_grave_pool"
	zone.radius = 68.0
	zone.duration = 6.0
	zone.tick_interval = 0.5
	zone.target_faction = "enemy"          ## "enemy" of the caster = the player
	zone.tick_effects = [burn]
	zone.debug_color = Color(0.42, 0.26, 0.62, 0.55)
	## "shadow", not "void": GroundZoneVfx.ELEMENTS has no void entry, and an unknown element
	## degrades to NO visual at all (ground_zone_vfx.gd:86) — an invisible damage pool.
	zone.vfx_element = "shadow"

	var ab := AbilityDefinition.new()
	ab.ability_id = "angel_grave_mark"
	ab.ability_name = "Grave Mark"
	ab.tags = ["AOE", "Void", "Boss"]
	ab.cooldown_base = 9.0
	ab.mode = "Auto"
	ab.priority = 5
	ab.cast_range = 220.0
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 220.0
	ab.targeting = targeting
	ab.effects = [zone]
	return ab


## Full-arena wing storm — the long-cooldown "get away from me and keep moving" beat.
static func _wing_storm() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "ring"
	telegraph.anchor = "source_position"
	telegraph.radius = 190.0
	telegraph.duration = 1.35
	telegraph.color = Color(0.58, 0.38, 0.80, 0.50)
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "angel_wing_storm"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.35
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 1.35
	windup.default_next = 1

	var burst := AreaDamageEffect.new()
	burst.damage_type = "Void"
	burst.base_damage = 46.0
	burst.aoe_radius = 190.0

	var hit := ChoreographyPhase.new()
	hit.effects = [burst]
	hit.hit_frame = -1
	hit.exit_type = "wait"
	hit.wait_duration = 0.6
	hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, hit]

	var ab := AbilityDefinition.new()
	ab.ability_id = "angel_wing_storm"
	ab.ability_name = "Wing Storm"
	ab.tags = ["Melee", "AOE", "Boss"]
	ab.cooldown_base = 14.0
	ab.mode = "Auto"
	ab.priority = 8
	ab.cast_range = 200.0
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 200.0
	ab.targeting = targeting
	ab.choreography = choreo
	return ab
