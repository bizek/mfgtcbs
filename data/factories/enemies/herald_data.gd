class_name HeraldData
extends RefCounted
## Factory for Herald enemy — fragile support that buffs nearby allies via engine aura.
## The aura is a StatusEffectDefinition applied at spawn. Zero bespoke aura code.

static func create() -> EnemyDefinition:
	var def := EnemyDefinition.new()
	def.enemy_id = "herald"
	def.enemy_name = "Herald"
	def.tags = ["Support", "Aura"]
	def.base_stats = {"max_hp": 25.0}
	def.combat_role = "MELEE"
	def.move_speed = 70.0
	def.contact_damage = 0.0
	def.base_armor = 0.0
	def.xp_value = 4.0
	def.health_drop_chance = 0.05
	def.behavior_type = "chase"
	def.base_modulate = Color(0.85, 0.25, 1.0, 1.0)

	# Aura: permanent status on self that ticks a buff to nearby allies
	def.on_spawn_statuses = [_create_herald_aura()]

	# Corruption circle: ground zone that damages player and buffs allies
	def.auto_attack = _create_corruption_circle()
	return def


static func _create_corruption_circle() -> AbilityDefinition:
	var tick_dmg := DealDamageEffect.new()
	tick_dmg.damage_type = "Void"
	tick_dmg.base_damage = 3.0

	var zone := GroundZoneEffect.new()
	zone.zone_id = "herald_corruption"
	zone.radius = 45.0
	zone.duration = 5.0
	zone.tick_interval = 0.5
	zone.target_faction = "enemy"  ## Damages player
	zone.tick_effects = [tick_dmg]
	zone.debug_color = Color(0.6, 0.1, 0.8, 0.5)

	var aa := AbilityDefinition.new()
	aa.ability_id = "herald_corruption_circle"
	aa.ability_name = "Corruption Circle"
	aa.tags = ["AOE", "Void", "Zone"]
	aa.cooldown_base = 10.0
	aa.mode = "Auto"
	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = 150.0
	aa.targeting = targeting
	aa.effects = [zone]
	return aa


static func _create_herald_aura() -> StatusEffectDefinition:
	# The buff applied to each enemy in range
	var buff_status := StatusEffectDefinition.new()
	buff_status.status_id = "herald_buff"
	buff_status.base_duration = 0.6  # Slightly > tick interval so no flicker
	buff_status.is_positive = true
	buff_status.max_stacks = 1
	buff_status.duration_refresh_mode = "overwrite"
	var dmg_mod := ModifierDefinition.new()
	dmg_mod.target_tag = "All"
	dmg_mod.operation = "bonus"
	dmg_mod.value = 0.30
	dmg_mod.source_name = "herald_aura"
	buff_status.modifiers = [dmg_mod]
	var spd_mod := ModifierDefinition.new()
	spd_mod.target_tag = "move_speed"
	spd_mod.operation = "bonus"
	spd_mod.value = 0.20
	spd_mod.source_name = "herald_aura"
	buff_status.modifiers.append(spd_mod)

	# The aura status on the Herald itself
	var aura_status := StatusEffectDefinition.new()
	aura_status.status_id = "herald_aura"
	aura_status.base_duration = -1.0  # Permanent
	aura_status.is_positive = true
	aura_status.max_stacks = 1
	aura_status.tick_interval = 0.4
	aura_status.aura_radius = 100.0
	aura_status.aura_target_faction = "ally"

	var apply_buff := ApplyStatusEffectData.new()
	apply_buff.status = buff_status
	apply_buff.stacks = 1
	aura_status.aura_tick_effects = [apply_buff]

	return aura_status
