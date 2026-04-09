class_name DisplacementSystem
extends Node
## Manages entity displacement: throws, knockbacks, pulls, charges, teleports.
## Child of combat_manager (needs Node for tween creation).

## Arena bounds for clamping displacement destinations (±800×±600 arena)
const BOUNDS_MIN_X := -800.0
const BOUNDS_MAX_X := 800.0
const BOUNDS_MIN_Y := -600.0
const BOUNDS_MAX_Y := 600.0

var rng: RandomNumberGenerator


func _ready() -> void:
	var cm = get_parent()
	rng = cm.rng if cm and cm.get("rng") else RandomNumberGenerator.new()


func execute(source: Node2D, ability,
		effect: DisplacementEffect, targets: Array) -> void:
	var displaced_entity: Node2D
	var destination_entity: Node2D = null

	if effect.displaced == "self":
		displaced_entity = source
		destination_entity = targets[0] if not targets.is_empty() else null
	else:
		if targets.is_empty():
			return
		displaced_entity = targets[0]
		destination_entity = targets[1] if targets.size() > 1 else null

	if not is_instance_valid(displaced_entity) or not displaced_entity.is_alive:
		return

	# Anchored check: entity is immune to displacement
	if displaced_entity.modifier_component.has_negation("Displacement"):
		EventBus.on_displacement_resisted.emit(displaced_entity, source)
		return

	if effect.destination == "to_target":
		if not is_instance_valid(destination_entity) or not destination_entity.is_alive:
			return

	# Cancel projectile tracking so in-flight projectiles don't follow
	var cm: Node2D = get_parent()
	if cm and cm.get("projectile_manager"):
		cm.projectile_manager.clear_tracking_target(displaced_entity)

	var start_pos: Vector2 = displaced_entity.global_position

	# Teleport to source if configured ("grab" effect)
	if effect.teleport_to_source and is_instance_valid(source):
		displaced_entity.global_position = source.global_position
		start_pos = source.global_position

	var end_pos: Vector2 = _compute_end_position(
			displaced_entity, source, destination_entity, effect)

	# Instant motion: reposition immediately, no tween
	if effect.motion == "instant":
		displaced_entity.global_position = end_pos
		if displaced_entity.get("_last_position") != null:
			displaced_entity._last_position = end_pos
		_on_arrival(source, displaced_entity, destination_entity, ability, effect)
		return

	# Suppress displaced entity during flight
	if displaced_entity.get("is_channeling") != null:
		displaced_entity.is_channeling = true
	if displaced_entity.get("is_attacking") != null:
		displaced_entity.is_attacking = false

	# Play custom animation during flight
	if effect.displacement_animation != "" and displaced_entity.get("sprite"):
		displaced_entity.sprite.play(effect.displacement_animation)

	var tween := create_tween()
	if effect.motion == "arc":
		_tween_arc(tween, displaced_entity, start_pos, end_pos,
				effect.arc_height, effect.duration)
	else:
		_tween_linear(tween, displaced_entity, start_pos, end_pos, effect.duration)

	if effect.rotate and displaced_entity.get("sprite"):
		tween.parallel().tween_property(
				displaced_entity.sprite, "rotation", TAU, effect.duration)

	tween.tween_callback(func() -> void:
		_on_arrival(source, displaced_entity, destination_entity, ability, effect)
	)


func _compute_end_position(displaced: Node2D, source: Node2D,
		destination: Node2D, effect: DisplacementEffect) -> Vector2:
	var dist: float = effect.distance
	if effect.distance_min > 0.0 and effect.distance_min < effect.distance:
		dist = rng.randf_range(effect.distance_min, effect.distance)

	match effect.destination:
		"to_target":
			return destination.global_position
		"away_from_source":
			var dir := Vector2.RIGHT
			if is_instance_valid(source):
				dir = (displaced.global_position - source.global_position).normalized()
				if dir == Vector2.ZERO:
					dir = Vector2.RIGHT
			return _clamp_to_bounds(displaced.global_position + dir * dist)
		"toward_source":
			if not is_instance_valid(source):
				return displaced.global_position
			var dir := (source.global_position - displaced.global_position).normalized()
			var clamped_dist := minf(dist, displaced.global_position.distance_to(source.global_position))
			return _clamp_to_bounds(displaced.global_position + dir * clamped_dist)
		"random_away":
			return _compute_random_away(displaced, dist, effect.distance_min)
		_:
			return displaced.global_position


func _clamp_to_bounds(pos: Vector2) -> Vector2:
	pos.x = clampf(pos.x, BOUNDS_MIN_X, BOUNDS_MAX_X)
	pos.y = clampf(pos.y, BOUNDS_MIN_Y, BOUNDS_MAX_Y)
	return pos


func _compute_random_away(displaced: Node2D, dist: float, min_dist: float) -> Vector2:
	var away_dir := Vector2.RIGHT
	var last_hit_by = displaced.get("last_hit_by")
	if is_instance_valid(last_hit_by) and last_hit_by.is_alive:
		away_dir = (displaced.global_position - last_hit_by.global_position).normalized()
		if away_dir == Vector2.ZERO:
			away_dir = Vector2.RIGHT

	var best_pos := displaced.global_position
	var best_dist_sq := 0.0
	var min_dist_sq: float = min_dist * min_dist

	for _attempt in 8:
		var spread: float = rng.randf_range(-PI * 0.5, PI * 0.5)
		var dir := away_dir.rotated(spread)
		var candidate := displaced.global_position + dir * dist
		candidate = _clamp_to_bounds(candidate)
		var d_sq: float = displaced.global_position.distance_squared_to(candidate)
		if d_sq >= min_dist_sq:
			return candidate
		if d_sq > best_dist_sq:
			best_dist_sq = d_sq
			best_pos = candidate

	return best_pos


func _tween_arc(tween: Tween, entity: Node2D, start: Vector2, end: Vector2,
		height: float, dur: float) -> void:
	tween.tween_method(func(t: float) -> void:
		if not is_instance_valid(entity):
			return
		var pos := start.lerp(end, t)
		pos.y -= 4.0 * height * t * (1.0 - t)
		entity.global_position = pos
	, 0.0, 1.0, dur)


func _tween_linear(tween: Tween, entity: Node2D, start: Vector2, end: Vector2,
		dur: float) -> void:
	tween.tween_method(func(t: float) -> void:
		if not is_instance_valid(entity):
			return
		entity.global_position = start.lerp(end, t)
	, 0.0, 1.0, dur)


func _on_arrival(source: Node2D, displaced: Node2D, destination: Node2D,
		ability, effect: DisplacementEffect) -> void:
	if is_instance_valid(displaced):
		if displaced.get("sprite"):
			displaced.sprite.rotation = 0.0
		if displaced.get("is_channeling") != null:
			displaced.is_channeling = false

	var source_alive: bool = is_instance_valid(source) and source.is_alive

	if is_instance_valid(displaced) and displaced.is_alive:
		for e in effect.on_arrival_displaced_effects:
			EffectDispatcher.execute_effect(e, source, displaced, ability, get_parent())
		for e in effect.on_arrival_both_effects:
			EffectDispatcher.execute_effect(e, source, displaced, ability, get_parent())

	if is_instance_valid(destination) and destination.is_alive:
		for e in effect.on_arrival_destination_effects:
			EffectDispatcher.execute_effect(e, source, destination, ability, get_parent())
		for e in effect.on_arrival_both_effects:
			EffectDispatcher.execute_effect(e, source, destination, ability, get_parent())

	# Talent/item displacement arrival modifications
	if ability and is_instance_valid(source) and source.is_alive:
		var arrival_mods: Array = source.ability_component.get_displacement_arrival_modifications(ability.ability_id)
		if not arrival_mods.is_empty():
			var arrival_targets: Array = []
			if is_instance_valid(displaced):
				arrival_targets.append(displaced)
			if is_instance_valid(destination) and destination != displaced:
				arrival_targets.append(destination)
			EffectDispatcher.execute_effects(arrival_mods, source, arrival_targets,
					ability, get_parent())

	# Bounce
	if effect.bounce_distance > 0.0 and is_instance_valid(displaced) and displaced.is_alive:
		var bounce_dir: Vector2
		if is_instance_valid(source):
			bounce_dir = (source.global_position - displaced.global_position).normalized()
		else:
			bounce_dir = Vector2.RIGHT
		if bounce_dir == Vector2.ZERO:
			bounce_dir = Vector2.RIGHT
		var bounce_tween := create_tween()
		bounce_tween.tween_property(displaced, "global_position",
				displaced.global_position + bounce_dir * effect.bounce_distance,
				0.2).set_ease(Tween.EASE_OUT)
