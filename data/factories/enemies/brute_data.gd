class_name BruteData
extends RefCounted
## Factory for Brute enemy — big, slow, tough. Ground slams nearby targets.

static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id = "brute"
	def.enemy_name = "Brute"
	def.tags = ["Melee", "Heavy"]
	def.base_stats = {"max_hp": 80.0}
	def.combat_role = "MELEE"
	def.move_speed = 36.0
	def.contact_damage = 9.0
	def.base_armor = 5.0
	def.xp_value = 5.0
	def.health_drop_chance = 0.08
	def.behavior_type = "chase"
	def.base_modulate = Color(0.72, 0.14, 0.11, 1.0)
	def.sprite_scale = Vector2(1.8, 1.8)

	# Ground slam: AoE burst around self
	def.auto_attack = _create_ground_slam(def.contact_damage)
	return def


static func _create_ground_slam(base_damage: float) -> AbilityDefinition:
	var dmg := AreaDamageEffect.new()
	dmg.damage_type = "Physical"
	dmg.base_damage = base_damage * 1.2
	dmg.aoe_radius = 45.0

	var aa := AbilityDefinition.new()
	aa.ability_id = "brute_slam"
	aa.ability_name = "Ground Slam"
	aa.tags = ["Melee", "AOE"]
	aa.cooldown_base = 3.0
	aa.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "self_centered_burst"
	targeting.max_range = 45.0
	aa.targeting = targeting
	aa.effects = [dmg]
	return aa
