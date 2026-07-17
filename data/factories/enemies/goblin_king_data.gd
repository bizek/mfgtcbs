class_name GoblinKingData
extends RefCounted
## Factory for the Cave final boss — "The Goblin King" (Minifantasy Goblin_King pack).
## Replaces the tinted Heart of the Deep in Level 1. Same stance-machine language:
## HP > 60% runs Scepter Smash, ≤ 60% branches into Royal Rampage, ≤ 30% into
## Crown Nova. Signature: Summon the Horde — the king raises his arms (the pack's
## IdleStart/IdleEnd gesture sheets) and refills a retinue of goblin adds.
##
## Gates extraction: groups includes "final_boss", so the portal stays locked
## until he dies (same wiring as heart_of_the_deep).

const COLOR_GOLD: Color = Color(0.95, 0.75, 0.20, 0.55)   ## telegraph base color


static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id = "goblin_king"
	def.enemy_name = "The Goblin King"
	def.tags = ["Boss", "Final"]
	def.base_stats = {"max_hp": 1600.0}
	def.combat_role = "MELEE"
	def.move_speed = 15.0
	def.contact_damage = 16.0
	def.base_armor = 10.0
	def.xp_value = 220.0
	def.health_drop_chance = 1.0
	def.behavior_type = "chase"
	def.knockback_multiplier = 0.0
	def.sprite_scale = Vector2(2.0, 2.0)
	def.groups = ["bosses", "final_boss"]
	def.is_boss = true
	def.boss_bar_color = Color(0.95, 0.75, 0.20)  ## gold final-boss bar

	def.auto_attack = _royal_wrath_stance_machine()

	var sk_horde := SkillDefinition.new()
	sk_horde.skill_name = "Summon the Horde"
	sk_horde.unlock_level = 1
	sk_horde.ability = _summon_the_horde()

	var sk_volley := SkillDefinition.new()
	sk_volley.skill_name = "Goblin Volley"
	sk_volley.unlock_level = 1
	sk_volley.ability = _goblin_volley()

	def.skills = [sk_horde, sk_volley]
	return def


## ── Auto-attack: the stance machine ───────────────────────────────────────────
## Phase 0 branches by current HP (desperate tested first — both match below 30%):
##   HP ≤ 30% → phase 5 (Crown Nova wind-up)
##   HP ≤ 60% → phase 3 (Royal Rampage wind-up)
##   else     → phase 1 (Scepter Smash wind-up)

static func _royal_wrath_stance_machine() -> AbilityDefinition:
	var cond_desperate := ConditionHpThreshold.new()
	cond_desperate.target = "self"
	cond_desperate.threshold = 0.30
	cond_desperate.direction = "below"

	var branch_desperate := ChoreographyBranch.new()
	branch_desperate.condition = cond_desperate
	branch_desperate.next_phase = 5

	var cond_enraged := ConditionHpThreshold.new()
	cond_enraged.target = "self"
	cond_enraged.threshold = 0.60
	cond_enraged.direction = "below"

	var branch_enraged := ChoreographyBranch.new()
	branch_enraged.condition = cond_enraged
	branch_enraged.next_phase = 3

	var selector := ChoreographyPhase.new()
	selector.hit_frame = -1
	selector.exit_type = "wait"
	selector.wait_duration = 0.02
	selector.default_next = 1
	selector.branches = [branch_desperate, branch_enraged]

	## ── Scepter Smash (normal, phases 1–2) ───────────────────────────────────
	var tel_smash := SpawnTelegraphEffect.new()
	tel_smash.shape = "circle"
	tel_smash.anchor = "target_position"
	tel_smash.radius = 90.0
	tel_smash.duration = 1.0
	tel_smash.color = COLOR_GOLD
	tel_smash.telegraph_id = "king_smash"

	var smash_windup := ChoreographyPhase.new()
	smash_windup.animation = "attack"
	smash_windup.telegraph_speed_scale = 0.5
	smash_windup.effects = [tel_smash]
	smash_windup.hit_frame = -1
	smash_windup.exit_type = "wait"
	smash_windup.wait_duration = 1.0
	smash_windup.default_next = 2

	var smash_dmg := AreaDamageEffect.new()
	smash_dmg.damage_type = "Physical"
	smash_dmg.base_damage = 30.0
	smash_dmg.aoe_radius = 90.0

	var smash_hit := ChoreographyPhase.new()
	smash_hit.effects = [smash_dmg]
	smash_hit.hit_frame = -1
	smash_hit.exit_type = "wait"
	smash_hit.wait_duration = 0.5
	smash_hit.default_next = -1

	## ── Royal Rampage (enraged, phases 3–4) ──────────────────────────────────
	var tel_rampage := SpawnTelegraphEffect.new()
	tel_rampage.shape = "cone"
	tel_rampage.anchor = "source_forward_line"
	tel_rampage.length = 160.0
	tel_rampage.cone_angle_deg = 70.0
	tel_rampage.duration = 0.9
	tel_rampage.color = Color(0.95, 0.45, 0.15, 0.55)
	tel_rampage.telegraph_id = "king_rampage"

	var rampage_windup := ChoreographyPhase.new()
	rampage_windup.animation = "attack"
	rampage_windup.telegraph_speed_scale = 0.5
	rampage_windup.effects = [tel_rampage]
	rampage_windup.hit_frame = -1
	rampage_windup.exit_type = "wait"
	rampage_windup.wait_duration = 0.9
	rampage_windup.default_next = 4

	var rampage_dmg := AreaDamageEffect.new()
	rampage_dmg.damage_type = "Physical"
	rampage_dmg.base_damage = 26.0
	rampage_dmg.aoe_radius = 140.0

	var rampage_hit := ChoreographyPhase.new()
	rampage_hit.effects = [rampage_dmg]
	rampage_hit.hit_frame = -1
	rampage_hit.exit_type = "wait"
	rampage_hit.wait_duration = 0.5
	rampage_hit.default_next = -1

	## ── Crown Nova (desperate, phases 5–6) ───────────────────────────────────
	var tel_nova := SpawnTelegraphEffect.new()
	tel_nova.shape = "ring"
	tel_nova.anchor = "source_position"
	tel_nova.radius = 240.0
	tel_nova.duration = 1.4
	tel_nova.color = Color(0.98, 0.85, 0.25, 0.55)
	tel_nova.telegraph_id = "king_nova"

	var nova_windup := ChoreographyPhase.new()
	nova_windup.animation = "attack"
	nova_windup.telegraph_speed_scale = 0.4
	nova_windup.effects = [tel_nova]
	nova_windup.hit_frame = -1
	nova_windup.exit_type = "wait"
	nova_windup.wait_duration = 1.4
	nova_windup.default_next = 6

	var nova_hit_dmg := DealDamageEffect.new()
	nova_hit_dmg.damage_type = "Physical"
	nova_hit_dmg.base_damage = 15.0

	var nova_proj := ProjectileConfig.new()
	nova_proj.motion_type = "directional"
	nova_proj.speed = 150.0
	nova_proj.max_range = 340.0
	nova_proj.hit_radius = 11.0
	nova_proj.pierce_count = -1
	nova_proj.on_hit_effects = [nova_hit_dmg]
	nova_proj.fallback_color = Color(0.98, 0.80, 0.25, 0.92)

	var nova_burst := SpawnProjectilesEffect.new()
	nova_burst.projectile = nova_proj
	nova_burst.spawn_pattern = "radial"
	nova_burst.count = 16

	var court_tick := DealDamageEffect.new()
	court_tick.damage_type = "Physical"
	court_tick.base_damage = 4.0

	var court_zone := GroundZoneEffect.new()
	court_zone.zone_id = "kings_court"
	court_zone.radius = 120.0
	court_zone.duration = 6.0
	court_zone.tick_interval = 0.4
	court_zone.target_faction = "enemy"
	court_zone.tick_effects = [court_tick]
	court_zone.debug_color = Color(0.75, 0.60, 0.10, 0.45)

	var nova_hit := ChoreographyPhase.new()
	nova_hit.effects = [nova_burst, court_zone]
	nova_hit.hit_frame = -1
	nova_hit.exit_type = "wait"
	nova_hit.wait_duration = 0.8
	nova_hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [
		selector,        # 0 — stance branch
		smash_windup,    # 1
		smash_hit,       # 2
		rampage_windup,  # 3
		rampage_hit,     # 4
		nova_windup,     # 5
		nova_hit,        # 6
	]

	var aa := AbilityDefinition.new()
	aa.ability_id = "king_royal_wrath"
	aa.ability_name = "Royal Wrath"
	aa.tags = ["AOE", "Boss", "Final"]
	aa.cooldown_base = 4.0
	aa.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 380.0
	aa.targeting = targeting
	aa.choreography = choreo
	return aa


## ── Skill: Summon the Horde (cd 14s) ──────────────────────────────────────────
## The king raises his arms (IdleStart), goblins pour in, arms lower (IdleEnd).
## SummonEffect maintains the retinue: each cast refills up to max_active live
## adds per summoner (CombatOrchestrator.spawn_summon).

static func _summon_the_horde() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "circle"
	telegraph.anchor = "source_position"
	telegraph.radius = 60.0
	telegraph.duration = 0.7
	telegraph.color = Color(0.55, 0.85, 0.30, 0.45)
	telegraph.fill_build_up = true
	telegraph.telegraph_id = "king_horde"

	var gesture := ChoreographyPhase.new()
	gesture.animation = "idle_start"
	gesture.effects = [telegraph]
	gesture.hit_frame = -1
	gesture.exit_type = "wait"
	gesture.wait_duration = 0.7
	gesture.default_next = 1

	var horde := SummonEffect.new()
	horde.summon_id = "cave_fodder"
	horde.max_active = 5

	var call_phase := ChoreographyPhase.new()
	call_phase.effects = [horde]
	call_phase.hit_frame = -1
	call_phase.exit_type = "wait"
	call_phase.wait_duration = 0.2
	call_phase.default_next = 2

	var lower := ChoreographyPhase.new()
	lower.animation = "idle_end"
	lower.hit_frame = -1
	lower.exit_type = "wait"
	lower.wait_duration = 0.65
	lower.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [gesture, call_phase, lower]

	var ab := AbilityDefinition.new()
	ab.ability_id = "king_summon_horde"
	ab.ability_name = "Summon the Horde"
	ab.tags = ["Summon", "Boss", "Final"]
	ab.cooldown_base = 14.0
	ab.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "self"
	ab.targeting = targeting
	ab.choreography = choreo
	return ab


## ── Skill: Goblin Volley (cd 8s) ──────────────────────────────────────────────
## Line telegraph → aimed spread of thrown junk at the player.

static func _goblin_volley() -> AbilityDefinition:
	var telegraph := SpawnTelegraphEffect.new()
	telegraph.shape = "line"
	telegraph.anchor = "source_forward_line"
	telegraph.length = 240.0
	telegraph.width = 30.0
	telegraph.duration = 0.5
	telegraph.color = Color(0.80, 0.65, 0.20, 0.55)
	telegraph.telegraph_id = "king_volley"

	var windup := ChoreographyPhase.new()
	windup.animation = "attack"
	windup.telegraph_speed_scale = 0.6
	windup.effects = [telegraph]
	windup.hit_frame = -1
	windup.exit_type = "wait"
	windup.wait_duration = 0.5
	windup.default_next = 1

	var hit_dmg := DealDamageEffect.new()
	hit_dmg.damage_type = "Physical"
	hit_dmg.base_damage = 14.0

	var proj := ProjectileConfig.new()
	proj.motion_type = "aimed"
	proj.speed = 200.0
	proj.max_range = 300.0
	proj.hit_radius = 9.0
	proj.pierce_count = 1
	proj.on_hit_effects = [hit_dmg]
	proj.fallback_color = Color(0.80, 0.65, 0.25, 0.92)

	var volley := SpawnProjectilesEffect.new()
	volley.projectile = proj
	volley.spawn_pattern = "spread"
	volley.count = 4
	volley.spread_angle = 50.0

	var hit := ChoreographyPhase.new()
	hit.effects = [volley]
	hit.hit_frame = -1
	hit.exit_type = "wait"
	hit.wait_duration = 0.35
	hit.default_next = -1

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [windup, hit]

	var ab := AbilityDefinition.new()
	ab.ability_id = "king_goblin_volley"
	ab.ability_name = "Goblin Volley"
	ab.tags = ["Ranged", "AOE", "Boss", "Final"]
	ab.cooldown_base = 8.0
	ab.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 340.0
	ab.targeting = targeting
	ab.choreography = choreo
	return ab
