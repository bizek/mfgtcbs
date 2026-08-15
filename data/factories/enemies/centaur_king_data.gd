class_name CentaurKingData
extends RefCounted
## Level 3 — The Nightmare Realm — MINIBOSS: "The Centaur King" (Minifantasy Centaur_King).
##
## Same choreographed-telegraph language as the Bonewarden (Level 2's miniboss), re-themed to
## cavalry: a lance thrust that reaches further than any miniboss tool so far, and a trampling
## stomp that punishes standing under the hooves.
## Placed by LevelData.LEVELS[3].miniboss_id.

const COLOR_ROYAL: Color = Color(0.72, 0.58, 0.86, 0.55)


static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id       = "centaur_king"
	def.enemy_name     = "The Centaur King"
	def.tags           = ["Melee", "Heavy", "Boss"]
	def.base_stats     = {"max_hp": 950.0}
	def.combat_role    = "MELEE"
	def.move_speed     = 38.0                       ## faster than the Bonewarden — it is a horse
	def.contact_damage = 22.0
	def.base_armor     = 12.0
	def.xp_value       = 110.0
	def.health_drop_chance   = 0.60
	def.behavior_type        = "chase"
	def.knockback_multiplier = 0.10
	def.sprite_scale         = Vector2(2.2, 2.2)
	def.groups   = ["bosses"]
	def.is_boss  = true
	def.boss_bar_color = Color(0.70, 0.55, 0.85)    ## royal-violet miniboss bar

	def.auto_attack = _lance_thrust()

	var sk_trample := SkillDefinition.new()
	sk_trample.skill_name = "Trample"
	sk_trample.unlock_level = 1
	sk_trample.ability = _trample()
	def.skills = [sk_trample]
	return def


## Telegraphed lance thrust at the player's position. Longer reach than the Bonewarden's slam
## and a shorter wind-up — the pressure tool that makes backing off the right answer.
static func _lance_thrust() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "circle"
	telegraph.anchor = "target_position"
	telegraph.radius = 62.0
	telegraph.duration = 0.65
	telegraph.color = COLOR_ROYAL
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "centaur_lance"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.5
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 0.65
	windup.default_next = 1

	var thrust := AreaDamageEffect.new()
	thrust.damage_type = "Physical"
	thrust.base_damage = 32.0
	thrust.aoe_radius = 62.0

	var hit := ChoreographyPhase.new()
	hit.effects = [thrust]
	hit.hit_frame = -1
	hit.exit_type = "wait"
	hit.wait_duration = 0.35
	hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, hit]

	var aa := AbilityDefinition.new()
	aa.ability_id = "centaur_lance_thrust"
	aa.ability_name = "Lance Thrust"
	aa.tags = ["Melee", "AOE", "Boss"]
	aa.cooldown_base = 4.0
	aa.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 230.0
	aa.targeting = targeting
	aa.choreography = choreo
	return aa


## Ring telegraph centred on the boss, then a wide burst — the "stop hugging me" tool,
## wider than the Bonewarden's quake because the Centaur King is meant to keep moving.
static func _trample() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "ring"
	telegraph.anchor = "source_position"
	telegraph.radius = 140.0
	telegraph.duration = 0.95
	telegraph.color = Color(0.66, 0.52, 0.80, 0.55)
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "centaur_trample"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.4
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 0.95
	windup.default_next = 1

	var burst := AreaDamageEffect.new()
	burst.damage_type = "Physical"
	burst.base_damage = 36.0
	burst.aoe_radius = 140.0

	var hit := ChoreographyPhase.new()
	hit.effects = [burst]
	hit.hit_frame = -1
	hit.exit_type = "wait"
	hit.wait_duration = 0.5
	hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, hit]

	var ab := AbilityDefinition.new()
	ab.ability_id = "centaur_trample"
	ab.ability_name = "Trample"
	ab.tags = ["Melee", "AOE", "Boss"]
	ab.cooldown_base = 8.5
	ab.mode = "Auto"
	ab.priority = 5
	ab.cast_range = 155.0
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 155.0
	ab.targeting = targeting
	ab.choreography = choreo
	return ab
