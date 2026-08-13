class_name SkeletonMinotaurData
extends RefCounted
## Level 2 — The Catacombs — MINIBOSS: "The Bonewarden" (Minifantasy Skeleton_Minotaur).
##
## Same choreographed-telegraph language as the Ancient Troll (Level 1's miniboss), re-themed
## to bone: a heavy gore charge, and a ring quake that punishes standing next to it.
## Placed by LevelData.LEVELS[2].miniboss_id.

const COLOR_BONE: Color = Color(0.86, 0.84, 0.74, 0.55)


static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id       = "skeleton_minotaur"
	def.enemy_name     = "The Bonewarden"
	def.tags           = ["Melee", "Heavy", "Boss", "Undead"]
	def.base_stats     = {"max_hp": 700.0}
	def.combat_role    = "MELEE"
	def.move_speed     = 26.0
	def.contact_damage = 18.0
	def.base_armor     = 10.0
	def.xp_value       = 85.0
	def.health_drop_chance   = 0.60
	def.behavior_type        = "chase"
	def.knockback_multiplier = 0.10
	def.sprite_scale         = Vector2(2.2, 2.2)
	def.groups   = ["bosses"]
	def.is_boss  = true
	def.boss_bar_color = Color(0.82, 0.80, 0.68)   ## bone-white miniboss bar

	def.auto_attack = _gore_slam()

	var sk_quake := SkillDefinition.new()
	sk_quake.skill_name = "Bone Quake"
	sk_quake.unlock_level = 1
	sk_quake.ability = _bone_quake()
	def.skills = [sk_quake]
	return def


## Telegraphed overhead slam at the player's position.
static func _gore_slam() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "circle"
	telegraph.anchor = "target_position"
	telegraph.radius = 70.0
	telegraph.duration = 0.75
	telegraph.color = COLOR_BONE
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "minotaur_slam"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.5
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 0.75
	windup.default_next = 1

	var slam := AreaDamageEffect.new()
	slam.damage_type = "Physical"
	slam.base_damage = 26.0
	slam.aoe_radius = 70.0

	var hit := ChoreographyPhase.new()
	hit.effects = [slam]
	hit.hit_frame = -1
	hit.exit_type = "wait"
	hit.wait_duration = 0.4
	hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, hit]

	var aa := AbilityDefinition.new()
	aa.ability_id = "minotaur_gore_slam"
	aa.ability_name = "Gore Slam"
	aa.tags = ["Melee", "AOE", "Boss"]
	aa.cooldown_base = 4.5
	aa.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 200.0
	aa.targeting = targeting
	aa.choreography = choreo
	return aa


## Ring telegraph centred on the boss, then a wide burst — the "stop hugging me" tool.
static func _bone_quake() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "ring"
	telegraph.anchor = "source_position"
	telegraph.radius = 125.0
	telegraph.duration = 1.0
	telegraph.color = Color(0.80, 0.78, 0.66, 0.55)
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "minotaur_quake"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.4
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 1.0
	windup.default_next = 1

	var burst := AreaDamageEffect.new()
	burst.damage_type = "Physical"
	burst.base_damage = 30.0
	burst.aoe_radius = 125.0

	var hit := ChoreographyPhase.new()
	hit.effects = [burst]
	hit.hit_frame = -1
	hit.exit_type = "wait"
	hit.wait_duration = 0.5
	hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, hit]

	var ab := AbilityDefinition.new()
	ab.ability_id = "minotaur_bone_quake"
	ab.ability_name = "Bone Quake"
	ab.tags = ["Melee", "AOE", "Boss"]
	ab.cooldown_base = 9.0
	ab.mode = "Auto"
	ab.priority = 5
	ab.cast_range = 140.0
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 140.0
	ab.targeting = targeting
	ab.choreography = choreo
	return ab
