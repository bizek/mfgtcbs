class_name CasterData
extends RefCounted
## Factory for Caster enemy — ranged, stops at preferred range and fires slow projectiles.

static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id = "caster"
	def.enemy_name = "Caster"
	def.tags = ["Ranged", "Common"]
	def.base_stats = {"max_hp": 20.0}
	def.combat_role = "RANGED"
	def.move_speed = 24.0
	def.contact_damage = 5.0
	def.base_armor = 0.0
	def.xp_value = 3.0
	def.health_drop_chance = 0.05
	def.behavior_type = "ranged"
	def.preferred_range = 175.0
	def.base_modulate = Color(0.45, 0.5, 1.0, 1.0)
	def.sprite_scale = Vector2(1.1, 1.1)

	# Ranged auto-attack: slow orange bolt via ProjectileManager
	def.auto_attack = _create_caster_bolt(def.contact_damage)

	# Skill: fire puddle ground zone at player location
	def.skills = [_create_fire_puddle_skill()]
	return def


static func _create_caster_bolt(base_damage: float) -> AbilityDefinition:
	var config := ProjectileConfig.new()
	config.motion_type = "directional"
	config.speed = 90.0
	config.max_range = 90.0 * 3.5
	config.hit_radius = 8.0
	config.sprite_frames = null  # Uses procedural circle fallback
	config.fallback_color = Color(1.0, 0.55, 0.12, 1.0)
	config.use_directional_anims = false
	config.pierce_count = 0

	var dmg := DealDamageEffect.new()
	dmg.damage_type = "Physical"
	dmg.base_damage = base_damage
	config.on_hit_effects = [dmg]

	var spawn := SpawnProjectilesEffect.new()
	spawn.projectile = config
	spawn.spawn_pattern = "aimed_single"
	spawn.count = 1

	var aa := AbilityDefinition.new()
	aa.ability_id = "caster_bolt"
	aa.ability_name = "Caster Bolt"
	aa.tags = ["Ranged", "Projectile"]
	aa.cooldown_base = 2.0
	aa.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 175.0 * 1.3
	aa.targeting = targeting
	aa.effects = [spawn]
	return aa


static func _create_fire_puddle_skill() -> SkillDefinition:
	var skill := SkillDefinition.new()
	skill.skill_name = "Fire Puddle"
	skill.unlock_level = 1

	var tick_dmg := DealDamageEffect.new()
	tick_dmg.damage_type = "Fire"
	tick_dmg.base_damage = 2.0

	var zone := GroundZoneEffect.new()
	zone.zone_id = "caster_fire_puddle"
	zone.radius = 35.0
	zone.duration = 4.0
	zone.tick_interval = 0.5
	zone.target_faction = "enemy"  ## Damages player (enemy of the caster)
	zone.tick_effects = [tick_dmg]
	zone.debug_color = Color(0.9, 0.3, 0.0, 0.6)

	var ability := AbilityDefinition.new()
	ability.ability_id = "caster_fire_puddle"
	ability.ability_name = "Fire Puddle"
	ability.tags = ["Ranged", "AOE", "Fire"]
	ability.cooldown_base = 8.0
	ability.mode = "Auto"
	ability.priority = 5  ## Higher priority than bolt — fires first when off cooldown
	ability.cast_range = 200.0
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 200.0
	ability.targeting = targeting
	ability.effects = [zone]

	skill.ability = ability
	return skill
