class_name RitualGuardData
extends RefCounted
## Level 4 — The Threshold — MINIBOSS: "The Ritual Guard" (Minifantasy Dark_Brotherhood).
##
## The thing standing in the doorway. Where the Centaur King was cavalry — reach and
## trampling — the Ritual Guard is a warden: it does not chase you down, it denies ground.
## Both of its tools are area denial anchored on itself or on where you are about to be,
## which suits a biome whose blocks are wide open plane with few walls to break line of
## sight. Placed by LevelData.LEVELS[4].miniboss_id.

const COLOR_RITE: Color = Color(0.60, 0.44, 0.84, 0.55)


static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id       = "ritual_guard"
	def.enemy_name     = "The Ritual Guard"
	def.tags           = ["Melee", "Heavy", "Boss", "Cultist"]
	def.base_stats     = {"max_hp": 1180.0}
	def.combat_role    = "MELEE"
	def.move_speed     = 34.0                       ## slower than the Centaur King: it holds, it does not charge
	def.contact_damage = 25.0
	def.base_armor     = 14.0
	def.xp_value       = 135.0
	def.health_drop_chance   = 0.60
	def.behavior_type        = "chase"
	def.knockback_multiplier = 0.10
	def.sprite_scale         = Vector2(2.2, 2.2)
	def.groups   = ["bosses"]
	def.is_boss  = true
	def.boss_bar_color = Color(0.62, 0.46, 0.86)    ## rite-violet miniboss bar

	def.auto_attack = _warding_strike()

	var sk_seal := SkillDefinition.new()
	sk_seal.skill_name = "Seal the Door"
	sk_seal.unlock_level = 1
	sk_seal.ability = _seal_the_door()
	def.skills = [sk_seal]
	return def


## Telegraphed strike at the player's position. Tighter radius and a longer wind-up than the
## Centaur King's lance — this one is dodgeable on reaction, and it is meant to be, because
## the pressure comes from the ring below rather than from the auto-attack.
static func _warding_strike() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "circle"
	telegraph.anchor = "target_position"
	telegraph.radius = 52.0
	telegraph.duration = 0.75
	telegraph.color = COLOR_RITE
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "ritual_guard_strike"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.5
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 0.75
	windup.default_next = 1

	var strike := AreaDamageEffect.new()
	strike.damage_type = "Physical"
	strike.base_damage = 36.0
	strike.aoe_radius = 52.0

	var hit := ChoreographyPhase.new()
	hit.effects = [strike]
	hit.hit_frame = -1
	hit.exit_type = "wait"
	hit.wait_duration = 0.35
	hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, hit]

	var aa := AbilityDefinition.new()
	aa.ability_id = "ritual_guard_strike"
	aa.ability_name = "Warding Strike"
	aa.tags = ["Melee", "AOE", "Boss"]
	aa.cooldown_base = 4.2
	aa.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 210.0
	aa.targeting = targeting
	aa.choreography = choreo
	return aa


## A wide Void ring centred on the guard, wound up slowly and hitting hard. The long tell
## is deliberate: on The Threshold's open blocks there is almost always somewhere to go, so
## the skill tests whether the player will disengage rather than whether they can find cover.
static func _seal_the_door() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "ring"
	telegraph.anchor = "source_position"
	telegraph.radius = 155.0
	telegraph.duration = 1.15
	telegraph.color = Color(0.54, 0.38, 0.80, 0.55)
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "ritual_guard_seal"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.35
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 1.15
	windup.default_next = 1

	var burst := AreaDamageEffect.new()
	burst.damage_type = "Void"
	burst.base_damage = 44.0
	burst.aoe_radius = 155.0

	var hit := ChoreographyPhase.new()
	hit.effects = [burst]
	hit.hit_frame = -1
	hit.exit_type = "wait"
	hit.wait_duration = 0.55
	hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, hit]

	var ab := AbilityDefinition.new()
	ab.ability_id = "ritual_guard_seal"
	ab.ability_name = "Seal the Door"
	ab.tags = ["Melee", "AOE", "Boss"]
	ab.cooldown_base = 9.0
	ab.mode = "Auto"
	ab.priority = 5
	ab.cast_range = 170.0
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 170.0
	ab.targeting = targeting
	ab.choreography = choreo
	return ab
