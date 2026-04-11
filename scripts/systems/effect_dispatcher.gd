class_name EffectDispatcher
extends RefCounted
## Stateless utility. Dispatches typed effect sub-resources to the appropriate system.
## All effect dispatch sites (abilities, status ticks, status procs, projectile impacts)
## delegate here instead of maintaining their own type-switch.

static func execute_effect(effect: Resource, source: Node2D, target: Node2D,
		ability, combat_manager: Node2D,
		fallback_source: Node2D = null) -> void:
	## Dispatch a single effect to a single target.
	var source_alive: bool = is_instance_valid(source) and source.is_alive
	var target_alive: bool = is_instance_valid(target) and target.is_alive

	var cm_rng: RandomNumberGenerator = combat_manager.rng if combat_manager and combat_manager.get("rng") else null

	if effect is DealDamageEffect:
		if not source_alive or not target_alive:
			return
		var hit := DamageCalculator.calculate_damage(source, target, ability, effect, cm_rng)
		if hit.is_dodged:
			return
		target.take_damage(hit)
		# Leech: heal source for a percentage of damage dealt
		if not source.health.is_dead and hit.amount > 0.0:
			var leech: float = source.modifier_component.sum_modifiers("leech", "bonus")
			if leech > 0.0:
				var heal_amount: float = hit.amount * leech
				if source.status_effect_component.has_status("curse"):
					var curse_hit := DamageCalculator.calculate_curse_damage(
							source, source, heal_amount)
					source.take_damage(curse_hit)
				else:
					source.health.apply_healing(heal_amount)
					EventBus.on_heal.emit(source, source, heal_amount)

	elif effect is HealEffect:
		if not source_alive or not target_alive:
			return
		var heal_amount := DamageCalculator.calculate_healing(source, target, effect, cm_rng)
		if heal_amount > 0.0:
			if target.status_effect_component.has_status("curse"):
				var curse_hit := DamageCalculator.calculate_curse_damage(source, target, heal_amount)
				target.take_damage(curse_hit)
			elif not target.health.is_dead:
				target.health.apply_healing(heal_amount)
				EventBus.on_heal.emit(source, target, heal_amount)

	elif effect is ApplyStatusEffectData:
		var actual_target: Node2D = source if effect.apply_to_self else target
		var actual_alive: bool = (is_instance_valid(actual_target) and actual_target.is_alive)
		if not actual_alive:
			return
		var src: Node2D = source if source_alive else fallback_source
		if src == null:
			return
		actual_target.status_effect_component.apply_status(
				effect.status, src, effect.stacks, effect.duration)

	elif effect is ApplyShieldEffect:
		if not source_alive or not target_alive:
			return
		var attr_val: float = 0.0
		if effect.scaling_attribute != "":
			attr_val = source.modifier_component.sum_modifiers(effect.scaling_attribute, "add")
		var shield_amount: float = effect.base_shield * (
				1.0 + attr_val * effect.scaling_coefficient)
		if shield_amount > 0.0:
			var shield_source_name: String = ability.ability_name if ability else "status_effect"
			target.health.add_shield(shield_amount, shield_source_name)

	elif effect is CleanseEffect:
		if not target_alive:
			return
		var src: Node2D = source if source_alive else fallback_source
		if src == null:
			return
		if effect.target_status_id != "":
			target.status_effect_component.force_remove_status(effect.target_status_id, src)
		else:
			target.status_effect_component.cleanse(effect.count, effect.target_type, src)

	elif effect is SpawnProjectilesEffect:
		if not combat_manager or not combat_manager.get("projectile_manager"):
			return
		combat_manager.projectile_manager.spawn_projectiles(source, ability, effect, [])

	elif effect is SummonEffect:
		if not combat_manager or not combat_manager.has_method("spawn_summon"):
			return
		combat_manager.spawn_summon(source, ability, effect)

	elif effect is ConsumeStacksEffect:
		if not target_alive:
			return
		var sec: StatusEffectComponent = target.status_effect_component
		var consumed: int = sec.consume_stacks(effect.status_id, effect.stacks_to_consume)
		if consumed > 0 and not effect.per_stack_effects.is_empty():
			for _i in consumed:
				for sub_effect in effect.per_stack_effects:
					execute_effect(sub_effect, source, target, ability, combat_manager, source)

	elif effect is ResurrectEffect:
		if not combat_manager or not combat_manager.has_method("revive_entity"):
			return
		var corpse: Node2D = combat_manager.get_nearest_corpse(source.global_position, source.faction)
		if corpse:
			combat_manager.revive_entity(corpse, effect.hp_percent, source)

	elif effect is ApplyModifierEffectData:
		if not target_alive:
			return
		target.modifier_component.add_modifier(effect.modifier)

	elif effect is AreaDamageEffect:
		if not source_alive:
			return
		if not is_instance_valid(target):
			return
		if not combat_manager or not combat_manager.get("spatial_grid"):
			return
		var grid: SpatialGrid = combat_manager.spatial_grid
		var enemy_faction: int = _get_enemy_faction(source)
		var radius_sq: float = effect.aoe_radius * effect.aoe_radius
		var aoe_targets: Array = grid.get_nearby_in_range(target.global_position, enemy_faction, radius_sq)
		var dmg_effect := DealDamageEffect.new()
		dmg_effect.damage_type = effect.damage_type
		dmg_effect.scaling_attribute = effect.scaling_attribute
		dmg_effect.scaling_coefficient = effect.scaling_coefficient
		dmg_effect.base_damage = effect.base_damage
		var total_aoe_damage: float = 0.0
		for aoe_target in aoe_targets:
			if aoe_target == target:
				continue
			if not aoe_target.is_alive:
				continue
			var hit: HitData = DamageCalculator.calculate_damage(
					source, aoe_target, ability, dmg_effect, cm_rng)
			if hit.is_dodged:
				continue
			aoe_target.take_damage(hit)
			total_aoe_damage += hit.amount
			## Per-hit effects (e.g. Galvanized Bleed spread, Conductor chain slow)
			for sub_effect in effect.on_hit_effects:
				execute_effect(sub_effect, source, aoe_target, ability, combat_manager, source)
		## Leech: AoE damage also heals source (Lifesteal + Shock, Lifesteal + Explosive, etc.)
		if total_aoe_damage > 0.0 and source_alive and not source.health.is_dead:
			var leech: float = source.modifier_component.sum_modifiers("leech", "bonus")
			if leech > 0.0:
				var heal_amount: float = total_aoe_damage * leech
				source.health.apply_healing(heal_amount)
				EventBus.on_heal.emit(source, source, heal_amount)

	elif effect is SetMaxStacksEffect:
		if not target_alive:
			return
		if effect.required_talent_id != "":
			var picks = target.get("talent_picks")
			if picks == null or not picks.has(effect.required_talent_id):
				return
		if target.status_effect_component.has_status(effect.status_id):
			target.status_effect_component.set_max_stacks(effect.status_id)
		elif effect.status:
			target.status_effect_component.apply_status(
					effect.status, target, effect.status.max_stacks)

	elif effect is GroundZoneEffect:
		if not combat_manager:
			return
		var zone_pos: Vector2
		if is_instance_valid(target):
			zone_pos = target.global_position
		elif is_instance_valid(source):
			zone_pos = source.global_position
		else:
			return
		combat_manager.spawn_ground_zone(effect, source, zone_pos)

	elif effect is DisplacementEffect:
		if not combat_manager or not combat_manager.get("displacement_system"):
			return
		combat_manager.displacement_system.execute(source, ability, effect, [target] if target else [])


static func execute_effects(effects: Array, source: Node2D, targets: Array,
		ability, combat_manager: Node2D,
		fallback_source: Node2D = null) -> void:
	## Convenience: dispatch an array of effects to an array of targets.
	for effect in effects:
		if effect is SpawnProjectilesEffect:
			if combat_manager and combat_manager.get("projectile_manager"):
				combat_manager.projectile_manager.spawn_projectiles(source, ability, effect, targets)
		elif effect is SummonEffect:
			execute_effect(effect, source, null, ability, combat_manager, fallback_source)
		elif effect is ResurrectEffect:
			execute_effect(effect, source, null, ability, combat_manager, fallback_source)
		elif effect is GroundZoneEffect:
			var zone_target: Node2D = targets[0] if not targets.is_empty() and is_instance_valid(targets[0]) else null
			execute_effect(effect, source, zone_target, ability, combat_manager, fallback_source)
		elif effect is DisplacementEffect:
			if combat_manager and combat_manager.get("displacement_system"):
				combat_manager.displacement_system.execute(source, ability, effect, targets)
		elif effect is OverflowChainEffect:
			_execute_overflow_chain(effect, source, targets, ability, combat_manager)
		elif effect is ApplyStatusEffectData and effect.apply_to_self:
			execute_effect(effect, source, source, ability, combat_manager, fallback_source)
		else:
			for target in targets:
				if is_instance_valid(target) and target.is_alive:
					execute_effect(effect, source, target, ability, combat_manager, fallback_source)


static func _execute_overflow_chain(effect: OverflowChainEffect, source: Node2D,
		targets: Array, ability, combat_manager: Node2D) -> void:
	if not is_instance_valid(source) or not source.is_alive:
		return
	var grid: SpatialGrid = combat_manager.spatial_grid if combat_manager else null
	if not grid:
		return

	var enemy_faction: int = _get_enemy_faction(source)
	var range_sq: float = effect.max_range * effect.max_range
	var hit_set: Dictionary = {}
	var overflow_queue: Array = []

	for t in targets:
		if not is_instance_valid(t):
			continue
		if not t.health.is_dead:
			continue
		var overkill: float = t.health.last_overkill
		if overkill > 0.0:
			overflow_queue.append({overkill = overkill, from_pos = t.global_position})

	var chains_used: int = 0
	var overflow_damage_dealt: float = 0.0
	while not overflow_queue.is_empty() and chains_used < effect.max_chains:
		var entry: Dictionary = overflow_queue.pop_front()
		var overkill: float = entry.overkill
		var from_pos: Vector2 = entry.from_pos

		var best: Node2D = null
		var best_dist_sq: float = INF
		var pool: Array = grid.get_all(enemy_faction)
		for e in pool:
			if hit_set.has(e):
				continue
			if not e.is_alive:
				continue
			var d_sq: float = from_pos.distance_squared_to(e.global_position)
			if d_sq <= range_sq and d_sq < best_dist_sq:
				best_dist_sq = d_sq
				best = e

		if not best:
			break

		hit_set[best] = true
		chains_used += 1
		var hit: HitData = HitData.create(overkill, effect.damage_type, source, best, null)
		best.take_damage(hit)
		overflow_damage_dealt += overkill

		if best.health.is_dead and best.health.last_overkill > 0.0:
			overflow_queue.append({overkill = best.health.last_overkill, from_pos = best.global_position})

	if effect.heal_percent > 0.0 and is_instance_valid(source) and not source.health.is_dead:
		var heal_amount: float = overflow_damage_dealt * effect.heal_percent
		if heal_amount > 0.0:
			if source.status_effect_component.has_status("curse"):
				var curse_hit: HitData = DamageCalculator.calculate_curse_damage(
						source, source, heal_amount)
				source.take_damage(curse_hit)
			else:
				source.health.apply_healing(heal_amount)
				EventBus.on_heal.emit(source, source, heal_amount)


static func _get_enemy_faction(entity: Node2D) -> int:
	## Returns the enemy faction index for the given entity.
	## Convention: 0 = player/allies, 1 = enemies.
	return 1 if int(entity.faction) == 0 else 0
