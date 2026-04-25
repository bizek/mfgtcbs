class_name WarpedColossusData
extends RefCounted
## Factory for the Phase 3 miniboss — "The Warped Colossus".
## Big, tanky, three choreographed abilities that use telegraph wind-ups.

const COLOR_WARP: Color = Color(0.68, 0.24, 0.82, 0.65)   ## telegraph base color
const COLOR_BODY: Color = Color(0.62, 0.22, 0.78, 1.0)    ## body tint

static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id = "warped_colossus"
	def.enemy_name = "The Warped Colossus"
	def.tags = ["Melee", "Heavy", "Boss"]
	def.base_stats = {"max_hp": 480.0}
	def.combat_role = "MELEE"
	def.move_speed = 18.0
	def.contact_damage = 14.0
	def.base_armor = 6.0
	def.xp_value = 60.0
	def.health_drop_chance = 0.60
	def.behavior_type = "chase"
	def.knockback_multiplier = 0.10
	def.base_modulate = COLOR_BODY
	def.sprite_scale = Vector2(2.4, 2.4)
	def.groups = ["bosses"]
	def.is_boss = true
	def.boss_bar_color = Color(0.90, 0.45, 0.10)  ## dark-orange miniboss bar

	def.auto_attack = _tremor_slam()

	var sk_ring := SkillDefinition.new()
	sk_ring.skill_name = "Shockwave Ring"
	sk_ring.unlock_level = 1
	sk_ring.ability = _shockwave_ring()

	var sk_lunge := SkillDefinition.new()
	sk_lunge.skill_name = "Heavy Lunge"
	sk_lunge.unlock_level = 1
	sk_lunge.ability = _heavy_lunge()

	def.skills = [sk_ring, sk_lunge]
	return def


## ── Ability 1: Tremor Slam ────────────────────────────────────────────────────
## Auto-attack. Telegraph circle at target, then AoE slam + lingering debris zone.

static func _tremor_slam() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "circle"
	telegraph.anchor = "target_position"
	telegraph.radius = 80.0
	telegraph.duration = 0.75
	telegraph.color = COLOR_WARP
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "colossus_slam"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.5
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 0.75
	windup.default_next = 1

	var slam_dmg := AreaDamageEffect.new()
	slam_dmg.damage_type = "Physical"
	slam_dmg.base_damage = 21.0
	slam_dmg.aoe_radius = 80.0

	var debris_tick := DealDamageEffect.new()
	debris_tick.damage_type = "Void"
	debris_tick.base_damage = 2.0

	var debris_zone := GroundZoneEffect.new()
	debris_zone.zone_id = "colossus_debris"
	debris_zone.radius = 50.0
	debris_zone.duration = 2.0
	debris_zone.tick_interval = 0.4
	debris_zone.target_faction = "enemy"
	debris_zone.tick_effects = [debris_tick]
	debris_zone.debug_color = Color(0.45, 0.12, 0.55, 0.45)

	var hit := ChoreographyPhase.new()
	hit.effects = [slam_dmg, debris_zone]
	hit.hit_frame = -1
	hit.exit_type = "wait"
	hit.wait_duration = 0.4
	hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, hit]

	var aa := AbilityDefinition.new()
	aa.ability_id = "colossus_tremor_slam"
	aa.ability_name = "Tremor Slam"
	aa.tags = ["Melee", "AOE", "Boss"]
	aa.cooldown_base = 5.0
	aa.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 200.0
	aa.targeting = targeting
	aa.choreography = choreo
	return aa


## ── Ability 2: Shockwave Ring ─────────────────────────────────────────────────
## Ring telegraph → radial burst of 12 slow projectiles around the boss.

static func _shockwave_ring() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "ring"
	telegraph.anchor = "source_position"
	telegraph.radius = 140.0
	telegraph.duration = 1.0
	telegraph.color = Color(0.78, 0.32, 0.95, 0.55)
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "colossus_ring"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.35
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 1.0
	windup.default_next = 1

	## Projectile: slow travel outward, heavy hit
	var hit_dmg := DealDamageEffect.new()
	hit_dmg.damage_type = "Void"
	hit_dmg.base_damage = 12.0

	var proj := ProjectileConfig.new()
	proj.motion_type = "directional"
	proj.speed = 140.0
	proj.max_range = 260.0
	proj.hit_radius = 10.0
	proj.pierce_count = -1
	proj.on_hit_effects = [hit_dmg]
	proj.fallback_color = Color(0.80, 0.25, 0.95, 0.9)

	var spawn := SpawnProjectilesEffect.new()
	spawn.projectile = proj
	spawn.spawn_pattern = "radial"
	spawn.count = 12

	var hit := ChoreographyPhase.new()
	hit.effects = [spawn]
	hit.hit_frame = -1
	hit.exit_type = "wait"
	hit.wait_duration = 0.5
	hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, hit]

	var ab := AbilityDefinition.new()
	ab.ability_id = "colossus_shockwave_ring"
	ab.ability_name = "Shockwave Ring"
	ab.tags = ["AOE", "Ranged", "Boss"]
	ab.cooldown_base = 12.0
	ab.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 260.0
	ab.targeting = targeting
	ab.choreography = choreo
	return ab


## ── Ability 3: Heavy Lunge ────────────────────────────────────────────────────
## Line telegraph aimed at target → charge along the line, slam on arrival.

static func _heavy_lunge() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "line"
	telegraph.anchor = "source_forward_line"
	telegraph.length = 200.0
	telegraph.width = 48.0
	telegraph.duration = 0.6
	telegraph.color = Color(0.95, 0.45, 0.12, 0.55)
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "colossus_lunge"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.5
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 0.6
	windup.default_next = 1

	## On-arrival AoE at landing point
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
	ab.ability_id = "colossus_heavy_lunge"
	ab.ability_name = "Heavy Lunge"
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
