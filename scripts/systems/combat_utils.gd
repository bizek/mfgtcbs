class_name CombatUtils
extends RefCounted
## Shared damage reception logic for all entities.
## Entity-specific reactions (iframes, flash, camera shake) happen AFTER this call.

static func process_incoming_damage(entity: Node2D, hit_data) -> void:
	## Core damage reception: track hit, apply damage, fire signals, run status reactives.
	## Called from both player.take_damage and enemy.take_damage after their entity-specific guards.

	# Track hit source and timing for trigger conditions
	if hit_data is HitData:
		entity.last_hit_by = hit_data.source
		entity.last_hit_time = entity.combat_manager.run_time if entity.combat_manager else 0.0
		if hit_data.ability:
			var now: float = entity.last_hit_time
			for tag in hit_data.ability.tags:
				entity._last_hit_time_by_tag[tag] = now

	# Shocked: chain damage on first hit, then consume
	# (Shock's "50% of incoming damage" requires access to hit amount —
	# not expressible through standard on_hit_received_effects)
	var shock_chain_amount: float = 0.0
	if entity.status_effect_component.has_status("shocked"):
		var amount: float = hit_data.amount if hit_data is HitData else 0.0
		shock_chain_amount = amount * 0.5
		entity.status_effect_component.consume_stacks("shocked", 1)

	# Apply damage through HealthComponent
	entity.health.apply_damage(hit_data)

	# Fire shock chain after damage resolves
	if shock_chain_amount > 0.0:
		_fire_shock_chain(entity, shock_chain_amount)

	# EventBus signals
	var source = hit_data.source if hit_data is HitData else null
	EventBus.on_hit_dealt.emit(source, entity, hit_data)
	EventBus.on_hit_received.emit(source, entity, hit_data)
	if hit_data is HitData and hit_data.is_crit:
		EventBus.on_crit.emit(source, entity, hit_data)

	# Status reactive effects (thorns, on-hit-received, on-hit-dealt)
	entity.status_effect_component.notify_hit_received(hit_data)
	if entity.is_alive and hit_data is HitData and hit_data.ability != null:
		if is_instance_valid(source) and source.is_alive:
			source.status_effect_component.notify_hit_dealt(entity, hit_data)


static func _fire_shock_chain(entity: Node2D, chain_damage: float) -> void:
	## Chain 50% of incoming damage to nearest other enemy within 100px.
	const CHAIN_RANGE: float = 100.0
	var nearest: Node2D = null
	var nearest_dist: float = CHAIN_RANGE

	# Use spatial grid if available, otherwise group scan
	if entity.spatial_grid:
		var faction: int = int(entity.faction)
		var range_sq: float = CHAIN_RANGE * CHAIN_RANGE
		var candidates: Array = entity.spatial_grid.get_nearby_in_range(
			entity.global_position, faction, range_sq)
		for other in candidates:
			if not is_instance_valid(other) or other == entity:
				continue
			var dist: float = entity.global_position.distance_to(other.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = other
	else:
		var group: String = "enemies" if entity.faction == 1 else "player"
		for other in entity.get_tree().get_nodes_in_group(group):
			if not is_instance_valid(other) or other == entity:
				continue
			var dist: float = entity.global_position.distance_to(other.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = other

	if nearest == null or not nearest.has_method("take_damage"):
		return

	var hit := DamageCalculator.calculate_raw_hit(entity, nearest, chain_damage, "Lightning")
	if not hit.is_dodged:
		nearest.take_damage(hit)

	# Brief visual arc
	var line := Line2D.new()
	line.top_level = true
	line.add_point(entity.global_position)
	line.add_point(nearest.global_position)
	line.width = 2.5
	line.default_color = Color(1.0, 0.95, 0.2, 0.9)
	entity.get_tree().current_scene.add_child(line)
	var t := line.create_tween()
	t.tween_property(line, "modulate:a", 0.0, 0.18)
	t.tween_callback(line.queue_free)
