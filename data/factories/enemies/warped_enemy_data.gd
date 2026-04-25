class_name WarpedEnemyData
extends RefCounted
## Factories for Phase 5 Phase-Warped enemy variants.
## These enemies reuse existing base scenes (differentiated by base_modulate color).
## All stats: 1.3× base HP, 1.2× base contact damage.
## Phase 5 spawn composition assigns ~10% weight to each variant.

const VOID_MODULATE: Color = Color(0.6, 0.4, 1.0)


# ─────────────────────────────────────────────────────────────────────────────
# Warped Fodder — faster, contact briefly chills the player
# Base: 30 HP / 10 dmg / 42 speed
# ─────────────────────────────────────────────────────────────────────────────
static func create_warped_fodder() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id = "warped_fodder"
	def.enemy_name = "Warped Fodder"
	def.tags = ["Melee", "Void", "PhaseWarped"]
	def.base_stats = {"max_hp": 39.0}       ## 30 × 1.3
	def.combat_role = "MELEE"
	def.move_speed = 33.0                    ## Faster than base 25
	def.contact_damage = 7.0                ## 6 × 1.2
	def.base_armor = 0.0
	def.xp_value = 2.0
	def.health_drop_chance = 0.05
	def.behavior_type = "chase"
	def.base_modulate = VOID_MODULATE
	## Mechanic: contact briefly chills the player (-30% speed for 1.5s)
	def.on_spawn_statuses = [_create_chill_contact_passive("warped_fodder_chill")]
	return def


# ─────────────────────────────────────────────────────────────────────────────
# Warped Swarmer — spawns with a 20 HP void shield
# Base: 10 HP / 5 dmg / 120 speed
# ─────────────────────────────────────────────────────────────────────────────
static func create_warped_swarmer() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id = "warped_swarmer"
	def.enemy_name = "Warped Swarmer"
	def.tags = ["Melee", "Void", "Swarm", "PhaseWarped"]
	def.base_stats = {"max_hp": 13.0}       ## 10 × 1.3
	def.combat_role = "MELEE"
	def.move_speed = 84.0                   ## Faster than base 72
	def.contact_damage = 4.0               ## 3 × 1.2
	def.base_armor = 0.0
	def.xp_value = 1.0
	def.health_drop_chance = 0.05
	def.behavior_type = "chase"
	def.base_modulate = VOID_MODULATE
	## Mechanic: spawns with a 20 HP void shield absorbing the first hit
	def.on_spawn_statuses = [_create_spawn_shield_status(20.0)]
	return def


# ─────────────────────────────────────────────────────────────────────────────
# Warped Brute — drops void ground zones as it moves, void slam AoE
# Base: 80 HP / 15 dmg / 60 speed / 5 armor
# ─────────────────────────────────────────────────────────────────────────────
static func create_warped_brute() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id = "warped_brute"
	def.enemy_name = "Warped Brute"
	def.tags = ["Melee", "Heavy", "Void", "PhaseWarped"]
	def.base_stats = {"max_hp": 104.0}      ## 80 × 1.3
	def.combat_role = "MELEE"
	def.move_speed = 36.0
	def.contact_damage = 11.0              ## 9 × 1.2
	def.base_armor = 5.0
	def.xp_value = 8.0
	def.health_drop_chance = 0.08
	def.behavior_type = "chase"
	def.base_modulate = VOID_MODULATE
	def.sprite_scale = Vector2(1.8, 1.8)
	## Mechanic: periodic void ground zone dropped at own position
	def.auto_attack = _create_void_slam(11.0)
	def.skills = [_create_void_trail_skill()]
	return def


# ─────────────────────────────────────────────────────────────────────────────
# Warped Caster — fires a 5-bolt radial void burst; no single aimed shot
# Base: 20 HP / 8 dmg / 40 speed / ranged
# ─────────────────────────────────────────────────────────────────────────────
static func create_warped_caster() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id = "warped_caster"
	def.enemy_name = "Warped Caster"
	def.tags = ["Ranged", "Void", "PhaseWarped"]
	def.base_stats = {"max_hp": 26.0}       ## 20 × 1.3
	def.combat_role = "RANGED"
	def.move_speed = 24.0
	def.contact_damage = 6.0               ## 5 × 1.2, rounded up
	def.base_armor = 0.0
	def.xp_value = 5.0
	def.health_drop_chance = 0.05
	def.behavior_type = "ranged"
	def.preferred_range = 175.0
	def.base_modulate = VOID_MODULATE
	def.sprite_scale = Vector2(1.1, 1.1)
	## Mechanic: 5-bolt radial void burst — unpredictable, covers all directions
	def.auto_attack = _create_void_burst()
	return def


# ─────────────────────────────────────────────────────────────────────────────
# Shared mechanic helpers
# ─────────────────────────────────────────────────────────────────────────────

static func _create_chill_contact_passive(status_id: String) -> StatusEffectDefinition:
	## Permanent spawn status: fires a trigger on on_hit_dealt that applies
	## a brief chill (-30% speed, 1.5s) to the entity this enemy hits.
	var chill_def: StatusEffectDefinition = _inline_brief_chill()

	var apply_chill := ApplyStatusEffectData.new()
	apply_chill.status = chill_def
	apply_chill.stacks = 1
	apply_chill.apply_to_self = false

	var cond := TriggerConditionSourceIsSelf.new()

	var listener := TriggerListenerDefinition.new()
	listener.event = "on_hit_dealt"
	listener.target_self = false      ## Effect targets the entity that was hit (the player)
	listener.conditions = [cond]
	listener.effects = [apply_chill]

	var passive := StatusEffectDefinition.new()
	passive.status_id = status_id
	passive.tags = ["Void", "Passive"]
	passive.is_positive = true
	passive.max_stacks = 1
	passive.base_duration = -1.0      ## Permanent while alive
	passive.trigger_listeners = [listener]
	return passive


static func _create_spawn_shield_status(shield_amount: float) -> StatusEffectDefinition:
	## Permanent spawn status whose on_apply_effects immediately grants shield HP.
	## The shield marker remains active (permanent) so it shows in the entity inspector.
	var shield_effect := ApplyShieldEffect.new()
	shield_effect.base_shield = shield_amount

	var def := StatusEffectDefinition.new()
	def.status_id = "warped_swarmer_shield"
	def.tags = ["Void", "Shield"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0          ## Marker stays active
	def.on_apply_effects = [shield_effect]
	return def


static func _create_void_trail_skill() -> SkillDefinition:
	## Every 6 seconds, drops a 4s void corruption zone at the brute's own position.
	## Zone deals 5 void damage every 0.5s to the player (enemy of the brute).
	var tick_dmg := DealDamageEffect.new()
	tick_dmg.damage_type = "Void"
	tick_dmg.base_damage = 3.0

	var zone := GroundZoneEffect.new()
	zone.zone_id = "warped_brute_void_trail"
	zone.radius = 40.0
	zone.duration = 4.0
	zone.tick_interval = 0.5
	zone.target_faction = "enemy"     ## "enemy" from the brute's POV = the player
	zone.tick_effects = [tick_dmg]
	zone.debug_color = Color(0.5, 0.0, 0.8, 0.5)

	var ability := AbilityDefinition.new()
	ability.ability_id = "warped_brute_void_trail"
	ability.ability_name = "Void Trail"
	ability.tags = ["AOE", "Void", "Zone"]
	ability.cooldown_base = 6.0
	ability.mode = "Auto"
	ability.priority = 10             ## Higher than slam — drop zone first when off cooldown
	var targeting := TargetingRule.new()
	targeting.type = "self"
	targeting.max_range = 9999.0      ## Always resolves (no range gate on self-cast)
	ability.targeting = targeting
	ability.effects = [zone]

	var skill := SkillDefinition.new()
	skill.skill_name = "Void Trail"
	skill.unlock_level = 1
	skill.ability = ability
	return skill


static func _create_void_slam(base_damage: float) -> AbilityDefinition:
	## AoE void slam around self — same radius as Brute ground slam but void-typed.
	var dmg := AreaDamageEffect.new()
	dmg.damage_type = "Void"
	dmg.base_damage = base_damage * 1.2
	dmg.aoe_radius = 45.0

	var aa := AbilityDefinition.new()
	aa.ability_id = "warped_brute_void_slam"
	aa.ability_name = "Void Slam"
	aa.tags = ["Melee", "AOE", "Void"]
	aa.cooldown_base = 3.0
	aa.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "self_centered_burst"
	targeting.max_range = 45.0
	aa.targeting = targeting
	aa.effects = [dmg]
	return aa


static func _create_void_burst() -> AbilityDefinition:
	## Fires 5 void bolts in a radial pattern — chaotic, hits all directions.
	## Range matches base caster; every direction is dangerous.
	var config := ProjectileConfig.new()
	config.motion_type = "directional"
	config.speed = 80.0
	config.max_range = 80.0 * 3.5    ## ~280px
	config.hit_radius = 8.0
	config.fallback_color = Color(0.5, 0.1, 0.9, 1.0)
	config.use_directional_anims = false
	config.pierce_count = 0

	var dmg := DealDamageEffect.new()
	dmg.damage_type = "Void"
	dmg.base_damage = 6.0
	config.on_hit_effects = [dmg]

	var spawn := SpawnProjectilesEffect.new()
	spawn.projectile = config
	spawn.spawn_pattern = "radial"
	spawn.count = 5

	var aa := AbilityDefinition.new()
	aa.ability_id = "warped_caster_void_burst"
	aa.ability_name = "Void Burst"
	aa.tags = ["Ranged", "Projectile", "Void"]
	aa.cooldown_base = 3.0            ## Slightly slower than base caster 2s
	aa.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 175.0 * 1.3  ## Triggers when player in range; bolts go radial
	aa.targeting = targeting
	aa.effects = [spawn]
	return aa


# ─────────────────────────────────────────────────────────────────────────────
# Inline status definitions (avoid dependency on StatusFactory build order)
# ─────────────────────────────────────────────────────────────────────────────

static func _inline_brief_chill() -> StatusEffectDefinition:
	## Reduced-duration Chilled: -30% speed for 1.5s (vs full 3s).
	## Less punishing than the weapon-applied version given swarmer attack rate.
	var def := StatusEffectDefinition.new()
	def.status_id = "chilled"
	def.tags = ["Ice", "CC"]
	def.is_positive = false
	def.max_stacks = 1
	def.base_duration = 1.5
	def.duration_refresh_mode = "overwrite"

	var slow_mod := ModifierDefinition.new()
	slow_mod.target_tag = "move_speed"
	slow_mod.operation = "bonus"
	slow_mod.value = -0.30
	slow_mod.source_name = "chilled"
	def.modifiers = [slow_mod]
	return def
