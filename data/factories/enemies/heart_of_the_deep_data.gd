class_name HeartOfTheDeepData
extends RefCounted
## Factory for the Phase 5 final boss — "The Heart of the Deep".
## Multi-stance encounter: HP > 50% runs the normal path, ≤ 50% branches into
## Tidal Sweep, ≤ 25% branches into Collapse Nova. Branching happens via
## ConditionHpThreshold on ChoreographyPhase.branches, evaluated during wait exits.
##
## Gates extraction: while this boss is alive, GameManager.is_extraction_allowed()
## returns false. Spawn/defeat flips the flag via enemy_spawn_manager.

const COLOR_VOID: Color = Color(0.52, 0.08, 0.92, 0.55)
const COLOR_BODY: Color = Color(0.45, 0.10, 0.85, 1.0)

static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id = "heart_of_the_deep"
	def.enemy_name = "The Heart of the Deep"
	def.tags = ["Boss", "Final"]
	def.base_stats = {"max_hp": 1600.0}
	def.combat_role = "MELEE"
	def.move_speed = 13.0
	def.contact_damage = 18.0
	def.base_armor = 10.0
	def.xp_value = 200.0
	def.health_drop_chance = 1.0
	def.behavior_type = "chase"
	def.knockback_multiplier = 0.0
	def.base_modulate = COLOR_BODY
	def.sprite_scale = Vector2(3.2, 3.2)
	def.groups = ["bosses", "final_boss"]
	def.is_boss = true
	def.boss_bar_color = Color(0.55, 0.10, 0.95)  ## deep-purple final-boss bar

	def.auto_attack = _abyssal_slam_stance_machine()

	var sk_spit := SkillDefinition.new()
	sk_spit.skill_name = "Void Spit"
	sk_spit.unlock_level = 1
	sk_spit.ability = _void_spit()

	def.skills = [sk_spit]
	return def


## ── Auto-attack: the stance machine ───────────────────────────────────────────
## Phase 0 is a short wait that branches by current HP:
##   HP ≤ 25% → jump to phase 5 (Collapse Nova wind-up)
##   HP ≤ 50% → jump to phase 3 (Tidal Sweep wind-up)
##   else     → default to phase 1 (Abyssal Slam wind-up)
## Phases 1–2 are normal slam, 3–4 are enraged sweep, 5–6 are desperate nova.

static func _abyssal_slam_stance_machine() -> AbilityDefinition:
	## ── Stance selector (phase 0) ────────────────────────────────────────────
	var cond_desperate := ConditionHpThreshold.new()
	cond_desperate.target = "self"
	cond_desperate.threshold = 0.25
	cond_desperate.direction = "below"

	var branch_desperate := ChoreographyBranch.new()
	branch_desperate.condition = cond_desperate
	branch_desperate.next_phase = 5

	var cond_enraged := ConditionHpThreshold.new()
	cond_enraged.target = "self"
	cond_enraged.threshold = 0.50
	cond_enraged.direction = "below"

	var branch_enraged := ChoreographyBranch.new()
	branch_enraged.condition = cond_enraged
	branch_enraged.next_phase = 3

	## Desperate must be tested before enraged (both match at < 25%; first-pass wins).
	var selector := ChoreographyPhase.new()
	selector.hit_frame = -1
	selector.exit_type = "wait"
	selector.wait_duration = 0.02
	selector.default_next = 1
	selector.branches = [branch_desperate, branch_enraged]

	## ── Abyssal Slam (normal, phases 1–2) ────────────────────────────────────
	var tel_slam := SpawnTelegraphEffect.new()
	tel_slam.shape = "circle"
	tel_slam.anchor = "target_position"
	tel_slam.radius = 100.0
	tel_slam.duration = 1.0
	tel_slam.color = COLOR_VOID
	tel_slam.telegraph_id = "heart_slam"

	var slam_windup := ChoreographyPhase.new()
	slam_windup.animation = "attack"
	slam_windup.telegraph_speed_scale = 0.5
	slam_windup.effects = [tel_slam]
	slam_windup.hit_frame = -1
	slam_windup.exit_type = "wait"
	slam_windup.wait_duration = 1.0
	slam_windup.default_next = 2

	var slam_dmg := AreaDamageEffect.new()
	slam_dmg.damage_type = "Void"
	slam_dmg.base_damage = 33.0
	slam_dmg.aoe_radius = 100.0

	var slam_hit := ChoreographyPhase.new()
	slam_hit.effects = [slam_dmg]
	slam_hit.hit_frame = -1
	slam_hit.exit_type = "wait"
	slam_hit.wait_duration = 0.5
	slam_hit.default_next = -1

	## ── Tidal Sweep (enraged, phases 3–4) ────────────────────────────────────
	## Visual is a cone telegraph for thematic direction; the actual hit is a
	## larger radial slam around the boss. v1 approximation — cone-shaped
	## damage would need a sector test in AreaDamageEffect.
	var tel_sweep := SpawnTelegraphEffect.new()
	tel_sweep.shape = "cone"
	tel_sweep.anchor = "source_forward_line"
	tel_sweep.length = 170.0
	tel_sweep.cone_angle_deg = 70.0
	tel_sweep.duration = 0.9
	tel_sweep.color = Color(0.95, 0.18, 0.55, 0.55)
	tel_sweep.telegraph_id = "heart_sweep"

	var sweep_windup := ChoreographyPhase.new()
	sweep_windup.animation = "attack"
	sweep_windup.telegraph_speed_scale = 0.5
	sweep_windup.effects = [tel_sweep]
	sweep_windup.hit_frame = -1
	sweep_windup.exit_type = "wait"
	sweep_windup.wait_duration = 0.9
	sweep_windup.default_next = 4

	var sweep_dmg := AreaDamageEffect.new()
	sweep_dmg.damage_type = "Void"
	sweep_dmg.base_damage = 27.0
	sweep_dmg.aoe_radius = 150.0

	var sweep_hit := ChoreographyPhase.new()
	sweep_hit.effects = [sweep_dmg]
	sweep_hit.hit_frame = -1
	sweep_hit.exit_type = "wait"
	sweep_hit.wait_duration = 0.5
	sweep_hit.default_next = -1

	## ── Collapse Nova (desperate, phases 5–6) ────────────────────────────────
	var tel_nova := SpawnTelegraphEffect.new()
	tel_nova.shape = "ring"
	tel_nova.anchor = "source_position"
	tel_nova.radius = 260.0
	tel_nova.duration = 1.5
	tel_nova.color = Color(0.98, 0.25, 0.85, 0.55)
	tel_nova.telegraph_id = "heart_nova"

	var nova_windup := ChoreographyPhase.new()
	nova_windup.animation = "attack"
	nova_windup.telegraph_speed_scale = 0.4
	nova_windup.effects = [tel_nova]
	nova_windup.hit_frame = -1
	nova_windup.exit_type = "wait"
	nova_windup.wait_duration = 1.5
	nova_windup.default_next = 6

	## Radial projectile burst + persistent Void ground zone under the boss.
	var nova_hit_dmg := DealDamageEffect.new()
	nova_hit_dmg.damage_type = "Void"
	nova_hit_dmg.base_damage = 18.0

	var nova_proj := ProjectileConfig.new()
	nova_proj.motion_type = "directional"
	nova_proj.speed = 160.0
	nova_proj.max_range = 380.0
	nova_proj.hit_radius = 12.0
	nova_proj.pierce_count = -1
	nova_proj.on_hit_effects = [nova_hit_dmg]
	nova_proj.fallback_color = Color(0.98, 0.25, 0.85, 0.92)

	var nova_burst := SpawnProjectilesEffect.new()
	nova_burst.projectile = nova_proj
	nova_burst.spawn_pattern = "radial"
	nova_burst.count = 18

	var void_tick := DealDamageEffect.new()
	void_tick.damage_type = "Void"
	void_tick.base_damage = 4.0

	var void_zone := GroundZoneEffect.new()
	void_zone.zone_id = "heart_void_pool"
	void_zone.radius = 140.0
	void_zone.duration = 8.0
	void_zone.tick_interval = 0.4
	void_zone.target_faction = "enemy"
	void_zone.tick_effects = [void_tick]
	void_zone.debug_color = Color(0.35, 0.05, 0.55, 0.5)

	var nova_hit := ChoreographyPhase.new()
	nova_hit.effects = [nova_burst, void_zone]
	nova_hit.hit_frame = -1
	nova_hit.exit_type = "wait"
	nova_hit.wait_duration = 0.8
	nova_hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [
		selector,      # 0 — stance branch
		slam_windup,   # 1
		slam_hit,      # 2
		sweep_windup,  # 3
		sweep_hit,     # 4
		nova_windup,   # 5
		nova_hit,      # 6
	]

	var aa := AbilityDefinition.new()
	aa.ability_id = "heart_stance_machine"
	aa.ability_name = "Abyssal Slam"
	aa.tags = ["AOE", "Boss", "Final"]
	aa.cooldown_base = 4.0
	aa.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 380.0
	aa.targeting = targeting
	aa.choreography = choreo
	return aa


## ── Void Spit (skill, always available, cd 6s) ────────────────────────────────

static func _void_spit() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "line"
	telegraph.anchor = "source_forward_line"
	telegraph.length = 260.0
	telegraph.width = 28.0
	telegraph.duration = 0.5
	telegraph.color = Color(0.60, 0.22, 0.95, 0.55)
	telegraph.telegraph_id = "heart_spit"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.6
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 0.5
	windup.default_next = 1

	var hit_dmg := DealDamageEffect.new()
	hit_dmg.damage_type = "Void"
	hit_dmg.base_damage = 17.0

	var proj := ProjectileConfig.new()
	proj.motion_type = "aimed"
	proj.speed = 210.0
	proj.max_range = 340.0
	proj.hit_radius = 10.0
	proj.pierce_count = 1
	proj.on_hit_effects = [hit_dmg]
	proj.fallback_color = Color(0.60, 0.22, 0.95, 0.92)

	var spit := SpawnProjectilesEffect.new()
	spit.projectile = proj
	spit.spawn_pattern = "spread"
	spit.count = 5
	spit.spread_angle = 60.0

	var hit := ChoreographyPhase.new()
	hit.effects = [spit]
	hit.hit_frame = -1
	hit.exit_type = "wait"
	hit.wait_duration = 0.35
	hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, hit]

	var ab := AbilityDefinition.new()
	ab.ability_id = "heart_void_spit"
	ab.ability_name = "Void Spit"
	ab.tags = ["Ranged", "AOE", "Boss", "Final"]
	ab.cooldown_base = 6.0
	ab.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 340.0
	ab.targeting = targeting
	ab.choreography = choreo
	return ab
