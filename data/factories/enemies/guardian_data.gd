class_name GuardianData
extends RefCounted
## Factory for Guardian enemy — miniboss that guards extraction points.
## Stats are defined here; game-specific logic (keystone drop, sprite building)
## remains in enemy_guardian.gd as a subclass override.

static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id = "guardian"
	def.enemy_name = "Guardian"
	def.tags = ["Melee", "Heavy", "Boss"]
	def.base_stats = {"max_hp": 300.0}
	def.combat_role = "MELEE"
	def.move_speed = 42.0
	def.contact_damage = 20.0
	def.base_armor = 10.0
	def.xp_value = 50.0
	def.health_drop_chance = 0.25
	def.behavior_type = "chase"
	def.knockback_multiplier = 0.25
	def.base_modulate = Color(0.72, 0.14, 0.11, 1.0)
	def.groups = ["guardians"]

	# Slam: melee auto-attack + ground zone aftershock
	def.auto_attack = _create_guardian_slam(def.contact_damage)
	return def


static func _create_guardian_slam(base_damage: float) -> AbilityDefinition:
	## Immediate AoE slam + lingering void zone
	var slam_dmg := AreaDamageEffect.new()
	slam_dmg.damage_type = "Physical"
	slam_dmg.base_damage = base_damage * 1.5
	slam_dmg.aoe_radius = 40.0

	var zone_tick := DealDamageEffect.new()
	zone_tick.damage_type = "Void"
	zone_tick.base_damage = 5.0

	var zone := GroundZoneEffect.new()
	zone.zone_id = "guardian_slam_zone"
	zone.radius = 50.0
	zone.duration = 3.0
	zone.tick_interval = 0.5
	zone.target_faction = "enemy"  ## Damages player
	zone.tick_effects = [zone_tick]
	zone.debug_color = Color(0.5, 0.0, 0.0, 0.5)

	var aa := AbilityDefinition.new()
	aa.ability_id = "guardian_slam"
	aa.ability_name = "Guardian Slam"
	aa.tags = ["Melee", "AOE", "Zone"]
	aa.cooldown_base = 5.0
	aa.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "self_centered_burst"
	targeting.max_range = 50.0
	aa.targeting = targeting
	aa.effects = [slam_dmg, zone]
	return aa
