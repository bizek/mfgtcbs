class_name AncientTrollData
extends RefCounted
## Factory for the Cave miniboss — "The Ancient Troll" (Minifantasy Ancient_Troll pack).
## Replaces the tinted Warped Colossus in Level 1; same choreographed-telegraph
## language, re-themed Physical. Signature: Devour — below half HP it stops to eat
## (the pack's Eat animation) and regains health unless burst or stunned.

const COLOR_MOSS: Color = Color(0.45, 0.72, 0.28, 0.55)   ## telegraph base color


static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id = "ancient_troll"
	def.enemy_name = "The Ancient Troll"
	def.tags = ["Melee", "Heavy", "Boss"]
	def.base_stats = {"max_hp": 520.0}
	def.combat_role = "MELEE"
	def.move_speed = 20.0
	def.contact_damage = 15.0
	def.base_armor = 8.0
	def.xp_value = 70.0
	def.health_drop_chance = 0.60
	def.behavior_type = "chase"
	def.knockback_multiplier = 0.10
	def.sprite_scale = Vector2(2.4, 2.4)
	def.groups = ["bosses"]
	def.is_boss = true
	def.boss_bar_color = Color(0.55, 0.75, 0.25)  ## mossy-green miniboss bar

	def.auto_attack = _crushing_blow()

	var sk_shudder := SkillDefinition.new()
	sk_shudder.skill_name = "Ground Shudder"
	sk_shudder.unlock_level = 1
	sk_shudder.ability = _ground_shudder()

	var sk_charge := SkillDefinition.new()
	sk_charge.skill_name = "Troll Charge"
	sk_charge.unlock_level = 1
	sk_charge.ability = _troll_charge()

	var sk_devour := SkillDefinition.new()
	sk_devour.skill_name = "Devour"
	sk_devour.unlock_level = 1
	sk_devour.ability = _devour()

	def.skills = [sk_shudder, sk_charge, sk_devour]
	return def


## ── Auto-attack: Crushing Blow ────────────────────────────────────────────────
## Telegraph circle at target, then a heavy Physical slam.

static func _crushing_blow() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "circle"
	telegraph.anchor = "target_position"
	telegraph.radius = 75.0
	telegraph.duration = 0.8
	telegraph.color = COLOR_MOSS
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "troll_blow"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.5
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 0.8
	windup.default_next = 1

	var slam_dmg := AreaDamageEffect.new()
	slam_dmg.damage_type = "Physical"
	slam_dmg.base_damage = 22.0
	slam_dmg.aoe_radius = 75.0

	var hit := ChoreographyPhase.new()
	hit.effects = [slam_dmg]
	hit.hit_frame = -1
	hit.exit_type = "wait"
	hit.wait_duration = 0.4
	hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, hit]

	var aa := AbilityDefinition.new()
	aa.ability_id = "troll_crushing_blow"
	aa.ability_name = "Crushing Blow"
	aa.tags = ["Melee", "AOE", "Boss"]
	aa.cooldown_base = 5.0
	aa.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 200.0
	aa.targeting = targeting
	aa.choreography = choreo
	return aa


## ── Skill: Ground Shudder ─────────────────────────────────────────────────────
## Ring telegraph → radial burst of slow debris projectiles around the troll.

static func _ground_shudder() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "ring"
	telegraph.anchor = "source_position"
	telegraph.radius = 130.0
	telegraph.duration = 1.0
	telegraph.color = Color(0.55, 0.80, 0.30, 0.55)
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "troll_shudder"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.35
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 1.0
	windup.default_next = 1

	var hit_dmg := DealDamageEffect.new()
	hit_dmg.damage_type = "Physical"
	hit_dmg.base_damage = 11.0

	var proj := ProjectileConfig.new()
	proj.motion_type = "directional"
	proj.speed = 130.0
	proj.max_range = 240.0
	proj.hit_radius = 10.0
	proj.pierce_count = -1
	proj.on_hit_effects = [hit_dmg]
	proj.fallback_color = Color(0.60, 0.52, 0.30, 0.9)

	var spawn := SpawnProjectilesEffect.new()
	spawn.projectile = proj
	spawn.spawn_pattern = "radial"
	spawn.count = 10

	var hit := ChoreographyPhase.new()
	hit.effects = [spawn]
	hit.hit_frame = -1
	hit.exit_type = "wait"
	hit.wait_duration = 0.5
	hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, hit]

	var ab := AbilityDefinition.new()
	ab.ability_id = "troll_ground_shudder"
	ab.ability_name = "Ground Shudder"
	ab.tags = ["AOE", "Ranged", "Boss"]
	ab.cooldown_base = 12.0
	ab.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 240.0
	ab.targeting = targeting
	ab.choreography = choreo
	return ab


## ── Skill: Troll Charge ───────────────────────────────────────────────────────
## Line telegraph → charge to the target (displacement), slam on arrival.
## Exercises the fixed choreography-displacement path; the invulnerable charge
## phase is covered by the displacement watchdog in enemy.gd.

static func _troll_charge() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "line"
	telegraph.anchor = "source_forward_line"
	telegraph.length = 200.0
	telegraph.width = 44.0
	telegraph.duration = 0.6
	telegraph.color = Color(0.85, 0.60, 0.20, 0.55)
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "troll_charge"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.5
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 0.6
	windup.default_next = 1

	var arrival_dmg := AreaDamageEffect.new()
	arrival_dmg.damage_type = "Physical"
	arrival_dmg.base_damage = 24.0
	arrival_dmg.aoe_radius = 60.0

	var disp := DisplacementEffect.new()
	disp.displaced = "self"
	disp.destination = "to_target"
	disp.motion = "linear"
	disp.duration = 0.35
	disp.on_arrival_displaced_effects = [arrival_dmg]

	var charge := ChoreographyPhase.new()
	charge.displacement = disp
	charge.hit_frame = -1
	charge.exit_type = "displacement_complete"
	charge.default_next = 2
	charge.set_invulnerable = true

	var recover := ChoreographyPhase.new()
	recover.hit_frame = -1
	recover.exit_type = "wait"
	recover.wait_duration = 0.4
	recover.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, charge, recover]

	var ab := AbilityDefinition.new()
	ab.ability_id = "troll_charge"
	ab.ability_name = "Troll Charge"
	ab.tags = ["Melee", "Charge", "Boss"]
	ab.cooldown_base = 9.0
	ab.mode = "Auto"
	ab.cast_range = 240.0
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 260.0
	ab.targeting = targeting
	ab.choreography = choreo
	return ab


## ── Skill: Devour ─────────────────────────────────────────────────────────────
## Troll regeneration with counterplay. Below 55% HP the troll stops and eats
## (the pack's Eat animation) for 2.2s, then heals 20% max HP. The channel is a
## normal choreography — a stun/freeze interrupts it (StatusEffectComponent
## is_disabled ends choreographies), and burst damage can kill through it.

static func _devour() -> AbilityDefinition:
	var cond_hungry := ConditionHpThreshold.new()
	cond_hungry.target = "self"
	cond_hungry.threshold = 0.55
	cond_hungry.direction = "below"

	var branch_eat := ChoreographyBranch.new()
	branch_eat.condition = cond_hungry
	branch_eat.next_phase = 1

	## Selector: only eat when hurt; otherwise the cast fizzles instantly.
	var selector := ChoreographyPhase.new()
	selector.hit_frame = -1
	selector.exit_type = "wait"
	selector.wait_duration = 0.02
	selector.default_next = -1
	selector.branches = [branch_eat]

	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "circle"
	telegraph.anchor = "source_position"
	telegraph.radius = 55.0
	telegraph.duration = 2.2
	telegraph.color = Color(0.35, 0.85, 0.35, 0.45)
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "troll_devour"

	var chew := ChoreographyPhase.new()
	chew.animation = "eat"
	chew.effects = [telegraph]
	chew.hit_frame = -1
	chew.exit_type = "wait"
	chew.wait_duration = 2.2
	chew.default_next = 2

	var heal := HealEffect.new()
	heal.percent_max_hp = 0.20

	var swallow := ChoreographyPhase.new()
	swallow.effects = [heal]
	swallow.hit_frame = -1
	swallow.exit_type = "wait"
	swallow.wait_duration = 0.3
	swallow.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [selector, chew, swallow]

	var ab := AbilityDefinition.new()
	ab.ability_id = "troll_devour"
	ab.ability_name = "Devour"
	ab.tags = ["Heal", "Boss"]
	ab.cooldown_base = 16.0
	ab.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "self"
	ab.targeting = targeting
	ab.choreography = choreo
	return ab
