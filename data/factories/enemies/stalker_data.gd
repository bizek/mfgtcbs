class_name StalkerData
extends RefCounted
## Factory for Stalker enemy — nearly invisible, reveals with flash at close range.
## High damage, low HP. Lunges at close range for burst damage.

static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id = "stalker"
	def.enemy_name = "Stalker"
	def.tags = ["Melee", "Stealth"]
	def.base_stats = {"max_hp": 40.0}
	def.combat_role = "MELEE"
	def.move_speed = 72.0
	def.contact_damage = 15.0
	def.base_armor = 0.0
	def.xp_value = 4.0
	def.health_drop_chance = 0.06
	def.behavior_type = "chase"
	def.aggro_range = 60.0  # Reveal distance

	# Melee auto-attack (required to wire ability system)
	def.auto_attack = _create_melee_attack(def.contact_damage)
	# Lunge: charge toward player, deal burst damage on arrival (higher priority)
	def.skills = [_create_lunge_skill(def.contact_damage)]
	return def


static func _create_melee_attack(base_damage: float) -> AbilityDefinition:
	var dmg := AreaDamageEffect.new()
	dmg.damage_type = "Physical"
	dmg.base_damage = base_damage
	dmg.aoe_radius = 20.0

	var aa := AbilityDefinition.new()
	aa.ability_id = "stalker_slash"
	aa.ability_name = "Stalker Slash"
	aa.tags = ["Melee"]
	aa.cooldown_base = 1.0
	aa.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 30.0
	aa.targeting = targeting
	aa.effects = [dmg]
	return aa


static func _create_lunge_skill(base_damage: float) -> SkillDefinition:
	var skill := SkillDefinition.new()
	skill.skill_name = "Stalker Lunge"
	skill.unlock_level = 1

	var dmg := AreaDamageEffect.new()
	dmg.damage_type = "Physical"
	dmg.base_damage = base_damage * 1.5
	dmg.aoe_radius = 25.0

	var charge := DisplacementEffect.new()
	charge.displaced = "self"
	charge.destination = "to_target"
	charge.motion = "linear"
	charge.duration = 0.2
	charge.on_arrival_displaced_effects = [dmg]

	var aa := AbilityDefinition.new()
	aa.ability_id = "stalker_lunge"
	aa.ability_name = "Stalker Lunge"
	aa.tags = ["Melee", "Charge"]
	aa.cooldown_base = 4.0
	aa.mode = "Auto"
	aa.priority = 10
	aa.cast_range = 80.0
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 80.0
	aa.targeting = targeting
	aa.effects = [charge]

	skill.ability = aa
	return skill
