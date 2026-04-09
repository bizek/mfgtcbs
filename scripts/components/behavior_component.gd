class_name BehaviorComponent
extends Node
## AI action loop for enemies: ability -> auto-attack -> chase.
## For player: input-driven weapon firing with auto-attack timer.

signal ability_requested(ability: AbilityDefinition, targets: Array)
signal auto_attack_requested(ability: AbilityDefinition, targets: Array)

var auto_attack_timer: float = 0.0
var _base_attack_interval: float = 1.0  ## From weapon/ability cooldown_base
var _modifier_comp: ModifierComponent = null
var _heal_reactive_target: Node2D = null  ## Most recently healed enemy (for heal-reactive targeting)
var _heal_reactive_connected: bool = false


func setup(modifier_comp: ModifierComponent, base_interval: float = 1.0) -> void:
	_modifier_comp = modifier_comp
	_base_attack_interval = base_interval


func enable_heal_reactive_targeting() -> void:
	## Connect to on_heal for heal-reactive targeting. Called during entity setup
	## when any ability uses the "most_recently_healed_enemy" targeting type.
	if _heal_reactive_connected:
		return
	_heal_reactive_connected = true
	EventBus.on_heal.connect(_on_heal_for_targeting)


func _on_heal_for_targeting(source: Node2D, target: Node2D, _amount: float) -> void:
	var entity: Node2D = get_parent()
	if not entity.is_alive:
		return
	if not is_instance_valid(target) or not target.is_alive:
		return
	var enemy_faction: int = 1 if int(entity.faction) == 0 else 0
	if int(target.faction) == enemy_faction:
		_heal_reactive_target = target


func _get_effective_aa_interval() -> float:
	var base: float = _base_attack_interval
	if _modifier_comp:
		var bonus: float = _modifier_comp.sum_modifiers("attack_speed", "bonus")
		if bonus != 0.0:
			var speed_mult: float = maxf(0.01, 1.0 + bonus)
			base = base / speed_mult
		var cdr: float = _modifier_comp.sum_modifiers("All", "cooldown_reduce")
		if cdr > 0.0:
			cdr = clampf(cdr, 0.0, 0.50)
			base *= (1.0 - cdr)
	return base


func tick(delta: float, entity: Node2D) -> void:
	if not entity.is_alive or entity.status_effect_component.is_disabled():
		return
	if entity.get("is_attacking") and entity.is_attacking:
		return

	var ability_comp: AbilityComponent = entity.ability_component

	# 1. Check abilities by priority
	var ready_abilities := ability_comp.get_ready_abilities(entity)
	for ability in ready_abilities:
		var targets := _resolve_targets(ability, entity)
		if targets.is_empty():
			continue
		if ability.cast_range > 0.0:
			var in_range := false
			for t in targets:
				if entity.global_position.distance_to(t.global_position) <= ability.cast_range:
					in_range = true
					break
			if not in_range:
				continue
		ability_requested.emit(ability, targets)
		ability_comp.consume_resource_cost(ability, entity)
		ability_comp.start_cooldown(ability)
		auto_attack_timer = _get_effective_aa_interval()
		return

	# 2. Auto-attack timer
	auto_attack_timer -= delta
	if auto_attack_timer <= 0.0:
		var aa := ability_comp.get_auto_attack()
		if aa:
			var aa_targets := _resolve_aa_targets(aa, entity)
			if not aa_targets.is_empty():
				auto_attack_requested.emit(aa, aa_targets)
				auto_attack_timer = _get_effective_aa_interval()
				return
		auto_attack_timer = 0.0


func _resolve_aa_targets(aa: AbilityDefinition, entity: Node2D) -> Array:
	if not aa.conditions.is_empty():
		if not entity.ability_component.check_conditions(aa, entity):
			return []
	if aa.targeting:
		var targets := _resolve_targets(aa, entity)
		if not targets.is_empty():
			return targets
	# Fallback: attack_target (backward compatible)
	if entity.get("attack_target") and is_instance_valid(entity.attack_target) and entity.attack_target.is_alive:
		return [entity.attack_target]
	return []


func resolve_targets_with_rule(rule: TargetingRule, entity: Node2D) -> Array:
	return _resolve_targets_internal(rule, entity)


func _resolve_targets(ability: AbilityDefinition, entity: Node2D) -> Array:
	if not ability.targeting:
		return []
	return _resolve_targets_internal(ability.targeting, entity)


func _resolve_targets_internal(rule: TargetingRule, entity: Node2D) -> Array:
	var grid: SpatialGrid = entity.get("spatial_grid")
	if not grid:
		return []
	if not rule:
		return []

	var enemy_faction: int = 1 if int(entity.faction) == 0 else 0
	var own_faction: int = int(entity.faction)

	var results: Array = []
	match rule.type:
		"self":
			results = [entity]
		"nearest_enemy":
			var target := grid.find_nearest(entity.global_position, enemy_faction)
			results = [target] if target else []
		"nearest_enemies":
			var range_sq := rule.max_range * rule.max_range if rule.max_range > 0.0 else 0.0
			if range_sq > 0.0:
				results = grid.find_nearest_n(entity.global_position, enemy_faction, rule.max_targets, range_sq)
			else:
				var pool := grid.get_all(enemy_faction)
				pool = pool.duplicate()
				pool.sort_custom(func(a, b):
					return entity.global_position.distance_squared_to(a.global_position) < entity.global_position.distance_squared_to(b.global_position))
				if rule.max_targets > 0:
					results = pool.slice(0, mini(rule.max_targets, pool.size()))
				else:
					results = pool
		"furthest_enemy":
			var target := grid.find_furthest(entity.global_position, enemy_faction)
			results = [target] if target else []
		"highest_hp_enemy":
			var pool := grid.get_all(enemy_faction)
			var best: Node2D = null
			var best_hp := -1.0
			for e in pool:
				if e.health.current_hp > best_hp:
					best_hp = e.health.current_hp
					best = e
			results = [best] if best else []
		"self_centered_burst":
			var range_sq := rule.max_range * rule.max_range if rule.max_range > 0.0 else 0.0
			if range_sq > 0.0:
				results = grid.find_nearest_n(entity.global_position, enemy_faction, rule.max_targets, range_sq)
			else:
				results = grid.get_all(enemy_faction)
		"all_enemies_in_range":
			var range_sq := rule.max_range * rule.max_range if rule.max_range > 0.0 else 0.0
			if range_sq > 0.0:
				results = grid.get_nearby_in_range(entity.global_position, enemy_faction, range_sq)
			else:
				results = grid.get_all(enemy_faction)
		"all_allies":
			results = grid.get_all(own_faction)
		"lowest_hp_ally":
			var allies := grid.get_all(own_faction)
			var lowest: Node2D = null
			var lowest_pct := INF
			for a in allies:
				var pct: float = a.health.current_hp / a.health.max_hp
				if pct < lowest_pct:
					lowest_pct = pct
					lowest = a
			results = [lowest] if lowest else []
		"lowest_stacks_enemy":
			results = _resolve_lowest_stacks_enemy(grid, entity, enemy_faction, rule)
		"frontal_rectangle":
			results = _resolve_frontal_rectangle(grid, entity, enemy_faction, rule)
		"nearest_enemy_targeting_owner":
			results = _resolve_nearest_enemy_targeting_owner(grid, entity, enemy_faction)
		"most_recently_healed_enemy":
			if is_instance_valid(_heal_reactive_target) and _heal_reactive_target.is_alive:
				results = [_heal_reactive_target]
				_heal_reactive_target = null
			else:
				_heal_reactive_target = null
				results = []
		"grab_nearest_throw_furthest":
			results = _resolve_grab_throw(grid, entity, enemy_faction, rule.max_range)
		_:
			var target := grid.find_nearest(entity.global_position, enemy_faction)
			results = [target] if target else []

	# Post-resolution cluster filter
	if rule.min_nearby > 0 and not results.is_empty():
		var pivot: Node2D = results[0]
		var radius_sq: float = rule.nearby_radius * rule.nearby_radius
		var nearby := grid.get_nearby_in_range(pivot.global_position, enemy_faction, radius_sq)
		var others: int = nearby.size()
		for n in nearby:
			if n == pivot:
				others -= 1
				break
		if others < rule.min_nearby:
			return []

	return results


func _resolve_lowest_stacks_enemy(grid: SpatialGrid, entity: Node2D,
		enemy_faction: int, rule: TargetingRule) -> Array:
	var pool := grid.get_all(enemy_faction)
	if pool.is_empty():
		return []
	var status_id: String = rule.target_status_id
	var min_stacks: int = 0x7FFFFFFF
	var best: Node2D = null
	var best_dist_sq := INF
	for e in pool:
		var stacks: int = e.status_effect_component.get_stacks(status_id)
		if stacks < min_stacks:
			min_stacks = stacks
			best = e
			best_dist_sq = entity.global_position.distance_squared_to(e.global_position)
		elif stacks == min_stacks:
			var d_sq: float = entity.global_position.distance_squared_to(e.global_position)
			if d_sq < best_dist_sq:
				best_dist_sq = d_sq
				best = e
	return [best] if best else []


func _resolve_frontal_rectangle(grid: SpatialGrid, entity: Node2D, enemy_faction: int,
		rule: TargetingRule) -> Array:
	## Frontal rectangle: enemies within max_range forward and ±(height/2) vertically.
	## Uses entity facing direction (sprite.flip_h or facing vector).
	var range_sq: float = rule.max_range * rule.max_range
	var half_height: float = rule.height / 2.0
	var candidates := grid.get_nearby_in_range(entity.global_position, enemy_faction, range_sq)
	var results: Array = []
	var facing_right: bool = true
	if entity.get("sprite") and entity.sprite:
		facing_right = not entity.sprite.flip_h
	for e in candidates:
		var dx: float = e.global_position.x - entity.global_position.x
		var dy: float = e.global_position.y - entity.global_position.y
		if facing_right and dx < 0.0:
			continue
		if not facing_right and dx > 0.0:
			continue
		if absf(dy) > half_height:
			continue
		results.append(e)
	return results


func _resolve_nearest_enemy_targeting_owner(grid: SpatialGrid, entity: Node2D,
		enemy_faction: int) -> Array:
	## Bodyguard targeting: prefer enemies whose attack_target is the owner (summoner).
	## Falls back to nearest enemy if no enemies are targeting the owner.
	var owner: Node2D = entity.get("summoner") if entity.get("summoner") else null
	if not is_instance_valid(owner):
		var target := grid.find_nearest(entity.global_position, enemy_faction)
		return [target] if target else []
	var best: Node2D = null
	var best_dist_sq := INF
	var enemies := grid.get_all(enemy_faction)
	for e in enemies:
		if e.get("attack_target") == owner:
			var d_sq := entity.global_position.distance_squared_to(e.global_position)
			if d_sq < best_dist_sq:
				best_dist_sq = d_sq
				best = e
	if best:
		return [best]
	var target := grid.find_nearest(entity.global_position, enemy_faction)
	return [target] if target else []


func _resolve_grab_throw(grid: SpatialGrid, entity: Node2D, enemy_faction: int,
		max_range: float) -> Array:
	## Grab nearest + throw at furthest ranged: returns [nearest_enemy, furthest_ranged_enemy].
	## Returns empty if no ranged enemies exist or nearest is out of grab range.
	var pool := grid.get_all(enemy_faction)
	if pool.is_empty():
		return []
	var furthest_ranged: Node2D = null
	var furthest_dist_sq := -1.0
	for e in pool:
		if e.get("combat_role") == "RANGED":
			var d_sq := entity.global_position.distance_squared_to(e.global_position)
			if d_sq > furthest_dist_sq:
				furthest_dist_sq = d_sq
				furthest_ranged = e
	if not furthest_ranged:
		return []
	var grab_range: float = max_range if max_range > 0.0 else 30.0
	var grab_range_sq := grab_range * grab_range
	var nearest := grid.find_nearest(entity.global_position, enemy_faction)
	if not nearest:
		return []
	if entity.global_position.distance_squared_to(nearest.global_position) > grab_range_sq:
		return []
	return [nearest, furthest_ranged]
