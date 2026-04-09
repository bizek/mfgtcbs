class_name StatusEffectComponent
extends Node
## Manages all active status effects on this entity.
## Handles stacking, duration, modifier registration/removal, and periodic ticks.

class ActiveStatus:
	var definition: StatusEffectDefinition
	var stacks: int = 1
	var time_remaining: float = 0.0
	var source: Node2D = null
	var tick_timer: float = 0.0
	var _runtime_modifiers: Array = []
	var _has_decay_modifiers: bool = false
	var _accumulated_shield: float = 0.0

signal status_expired(status_id: String)

var _active: Dictionary = {}  ## status_id -> ActiveStatus
var _modifier_comp: ModifierComponent = null
var _disable_count: int = 0
var _movement_disable_count: int = 0
var _death_prevention_count: int = 0
var _movement_override: String = ""
var _taunt_count: int = 0
var _taunt_radius: float = 0.0
var combat_manager: Node2D = null


func setup(modifier_comp: ModifierComponent) -> void:
	_modifier_comp = modifier_comp
	set_process(false)


func apply_status(status_def: StatusEffectDefinition, source: Node2D,
		stacks: int = 1, duration_override: float = -1.0) -> void:
	if not _modifier_comp:
		return

	for tag in status_def.tags:
		if _modifier_comp.has_negation(tag):
			EventBus.on_status_resisted.emit(source, get_parent(), status_def.status_id)
			return

	var duration := duration_override if duration_override > 0.0 else status_def.base_duration

	if _active.has(status_def.status_id):
		var active: ActiveStatus = _active[status_def.status_id]
		active.stacks = mini(active.stacks + stacks, status_def.max_stacks)
		if duration > 0.0:
			if status_def.duration_refresh_mode == "max":
				active.time_remaining = maxf(active.time_remaining, duration)
			else:
				active.time_remaining = duration
		active.source = source
		_sync_modifiers(active)
		EventBus.on_status_applied.emit(source, get_parent(),
				status_def.status_id, active.stacks)
	else:
		var active := ActiveStatus.new()
		active.definition = status_def
		active.stacks = mini(stacks, status_def.max_stacks)
		active.time_remaining = duration
		active.source = source
		active.tick_timer = status_def.tick_interval
		for mod in status_def.modifiers:
			if mod is ModifierDefinition and mod.decay:
				active._has_decay_modifiers = true
				break
		_active[status_def.status_id] = active
		_sync_modifiers(active)
		if status_def.disables_actions:
			_disable_count += 1
		if status_def.disables_movement:
			_movement_disable_count += 1
		if status_def.prevents_death:
			_death_prevention_count += 1
			get_parent().health._death_prevention_count += 1
		if status_def.movement_override != "":
			_movement_override = status_def.movement_override
		if status_def.grants_taunt:
			_taunt_count += 1
			_taunt_radius = maxf(_taunt_radius, status_def.taunt_radius)
		_register_trigger_listeners(status_def, source)
		var entity: Node2D = get_parent()
		for effect in status_def.on_apply_effects:
			EffectDispatcher.execute_effect(effect, source, entity, null, combat_manager, entity)
		EventBus.on_status_applied.emit(source, get_parent(),
				status_def.status_id, active.stacks)


func tick(delta: float) -> void:
	var entity: Node2D = get_parent()
	var expired: Array[String] = []
	for status_id in _active:
		var active: ActiveStatus = _active[status_id]
		if active.definition.tick_interval > 0.0:
			active.tick_timer -= delta
			if active.tick_timer <= 0.0:
				active.tick_timer += active.definition.tick_interval
				_execute_tick_effects(active, entity)
		if active.time_remaining > 0.0:
			active.time_remaining -= delta
			if active.time_remaining <= 0.0:
				expired.append(status_id)
			elif active._has_decay_modifiers:
				_sync_modifiers(active)
	for status_id in expired:
		_expire_status(status_id)


func is_disabled() -> bool:
	return _disable_count > 0


func is_movement_disabled() -> bool:
	return _movement_disable_count > 0


func get_movement_override() -> String:
	return _movement_override


func has_taunt() -> bool:
	return _taunt_count > 0


func get_taunt_radius() -> float:
	return _taunt_radius


func get_definition(status_id: String) -> StatusEffectDefinition:
	if _active.has(status_id):
		return _active[status_id].definition
	return null


func has_status(status_id: String) -> bool:
	return _active.has(status_id)


func get_stacks(status_id: String) -> int:
	if _active.has(status_id):
		return _active[status_id].stacks
	return 0


func expire_statuses_with_tag(tag: String) -> void:
	var to_expire: Array[String] = []
	for status_id in _active:
		var active: ActiveStatus = _active[status_id]
		if active.definition.tags.has(tag):
			to_expire.append(status_id)
	for status_id in to_expire:
		_expire_status(status_id)


func remove_status(status_id: String) -> void:
	if not _active.has(status_id):
		return
	var active: ActiveStatus = _active[status_id]
	_cleanup_status(active)
	var stacks := active.stacks
	_active.erase(status_id)
	EventBus.on_status_consumed.emit(get_parent(), status_id, stacks)


func consume_stacks(status_id: String, count: int) -> int:
	if not _active.has(status_id):
		return 0
	var active: ActiveStatus = _active[status_id]
	var current: int = active.stacks
	var consumed: int = current if count < 0 else mini(count, current)
	var entity: Node2D = get_parent()

	if consumed >= current:
		for effect in active.definition.on_consume_effects:
			EffectDispatcher.execute_effect(effect, active.source, entity, null, combat_manager, entity)
		_cleanup_status(active)
		_active.erase(status_id)
		EventBus.on_status_consumed.emit(entity, status_id, consumed)
	else:
		active.stacks -= consumed
		_sync_modifiers(active)
		EventBus.on_status_consumed.emit(entity, status_id, consumed)
	return consumed


func force_remove_status(status_id: String, source: Node2D = null) -> void:
	if not _active.has(status_id):
		return
	var entity := get_parent()
	var cleanse_source: Node2D = source if is_instance_valid(source) else entity
	var active: ActiveStatus = _active[status_id]
	_cleanup_status(active)
	_active.erase(status_id)
	status_expired.emit(status_id)
	EventBus.on_cleanse.emit(cleanse_source, entity, status_id)


func cleanse(count: int, target_type: String, source: Node2D = null) -> void:
	var entity := get_parent()
	var cleanse_source: Node2D = source if is_instance_valid(source) else entity
	var to_remove: Array[String] = []
	for status_id in _active:
		var active: ActiveStatus = _active[status_id]
		var matches := false
		match target_type:
			"negative":
				matches = not active.definition.is_positive
			"positive":
				matches = active.definition.is_positive
			"any":
				matches = true
		if matches:
			to_remove.append(status_id)
			if count > 0 and to_remove.size() >= count:
				break

	for status_id in to_remove:
		var active: ActiveStatus = _active[status_id]
		_cleanup_status(active)
		_active.erase(status_id)
		status_expired.emit(status_id)
		EventBus.on_cleanse.emit(cleanse_source, entity, status_id)


func on_death_prevented() -> void:
	var entity: Node2D = get_parent()
	for status_id in _active:
		var active: ActiveStatus = _active[status_id]
		if not active.definition.prevents_death:
			continue
		for effect in active.definition.on_death_prevented_effects:
			EffectDispatcher.execute_effect(effect, entity, entity, null, combat_manager, entity)
		_cleanup_status(active)
		_active.erase(status_id)
		status_expired.emit(status_id)
		break


func set_max_stacks(status_id: String) -> void:
	if not _active.has(status_id):
		return
	var active: ActiveStatus = _active[status_id]
	active.stacks = active.definition.max_stacks
	if active.time_remaining > 0.0:
		active.time_remaining = active.definition.base_duration
	_sync_modifiers(active)


func notify_hit_received(hit_data = null) -> void:
	if hit_data is HitData and hit_data.is_reflected:
		return
	var entity: Node2D = get_parent()
	var total_thorns: float = 0.0
	for status_id in _active:
		var active: ActiveStatus = _active[status_id]
		if active.definition.shield_on_hit_absorbed_percent > 0.0 and hit_data is HitData:
			var absorbed: float = hit_data.dr_mitigated
			if absorbed > 0.0:
				active._accumulated_shield += absorbed * active.definition.shield_on_hit_absorbed_percent
		if active.definition.thorns_percent > 0.0:
			total_thorns += active.definition.thorns_percent
		if active.definition.on_hit_received_effects.is_empty():
			continue
		if not active.definition.on_hit_received_damage_filter.is_empty() and hit_data is HitData:
			if not active.definition.on_hit_received_damage_filter.has(hit_data.damage_type):
				continue
		for effect in active.definition.on_hit_received_effects:
			EffectDispatcher.execute_effect(effect, active.source, entity, null, combat_manager, entity)
	if total_thorns > 0.0 and hit_data is HitData:
		var attacker: Node2D = hit_data.source
		if is_instance_valid(attacker) and attacker.is_alive:
			var reflect_amount: float = hit_data.amount * total_thorns
			if reflect_amount > 0.0:
				var reflect_hit := HitData.create(reflect_amount, hit_data.damage_type, entity, attacker, null)
				reflect_hit.is_reflected = true
				attacker.take_damage(reflect_hit)
				EventBus.on_reflect.emit(entity, attacker, reflect_hit)


func notify_hit_dealt(target: Node2D, _hit_data) -> void:
	for status_id in _active:
		var active: ActiveStatus = _active[status_id]
		if active.definition.on_hit_dealt_effects.is_empty():
			continue
		var fallback: Node2D = get_parent()
		for effect in active.definition.on_hit_dealt_effects:
			EffectDispatcher.execute_effect(effect, active.source, target, null, combat_manager, fallback)


# --- Internal ---

func _cleanup_status(active: ActiveStatus) -> void:
	## Shared cleanup for all removal paths (expire, cleanse, consume, death prevention).
	_unregister_modifiers(active)
	_unregister_trigger_listeners(active.definition)
	if active.definition.disables_actions:
		_disable_count -= 1
	if active.definition.disables_movement:
		_movement_disable_count -= 1
	if active.definition.prevents_death:
		_death_prevention_count -= 1
		get_parent().health._death_prevention_count -= 1
	if active.definition.movement_override != "":
		_recompute_movement_override()
	if active.definition.grants_taunt:
		_taunt_count -= 1
		_recompute_taunt_radius()


func _expire_status(status_id: String) -> void:
	if not _active.has(status_id):
		return
	var active: ActiveStatus = _active[status_id]
	var entity: Node2D = get_parent()
	# Apply accrued shield on expiry
	if active._accumulated_shield > 0.0:
		var shield_amount: float = active._accumulated_shield
		if active.definition.shield_cap_percent_max_hp > 0.0:
			var cap: float = entity.health.max_hp * active.definition.shield_cap_percent_max_hp
			shield_amount = minf(shield_amount, maxf(0.0, cap - entity.health.shield_hp))
		if shield_amount > 0.0:
			entity.health.add_shield(shield_amount, active.definition.status_id)
	for effect in active.definition.on_expire_effects:
		EffectDispatcher.execute_effect(effect, active.source, entity, null, combat_manager, entity)
	_cleanup_status(active)
	_active.erase(status_id)
	status_expired.emit(status_id)
	EventBus.on_status_expired.emit(get_parent(), status_id)


func _recompute_movement_override() -> void:
	_movement_override = ""
	for status_id in _active:
		var active: ActiveStatus = _active[status_id]
		if active.definition.movement_override != "":
			_movement_override = active.definition.movement_override


func _recompute_taunt_radius() -> void:
	_taunt_radius = 0.0
	for status_id in _active:
		var active: ActiveStatus = _active[status_id]
		if active.definition.grants_taunt:
			_taunt_radius = maxf(_taunt_radius, active.definition.taunt_radius)


func _sync_modifiers(active: ActiveStatus) -> void:
	_unregister_modifiers(active)
	var decay_factor: float = 1.0
	if active._has_decay_modifiers and active.definition.base_duration > 0.0:
		decay_factor = clampf(active.time_remaining / active.definition.base_duration, 0.0, 1.0)
	for base_mod in active.definition.modifiers:
		if base_mod.min_stacks > 0 and active.stacks < base_mod.min_stacks:
			continue
		var runtime_mod := ModifierDefinition.new()
		runtime_mod.target_tag = base_mod.target_tag
		runtime_mod.operation = base_mod.operation
		var mod_decay: float = decay_factor if base_mod.decay else 1.0
		var stack_mult: int = 1 if base_mod.min_stacks > 0 else active.stacks
		runtime_mod.value = base_mod.value * stack_mult * mod_decay
		runtime_mod.source_name = active.definition.status_id
		active._runtime_modifiers.append(runtime_mod)
		_modifier_comp.add_modifier(runtime_mod)


func _execute_tick_effects(active: ActiveStatus, entity: Node2D) -> void:
	for effect in active.definition.tick_effects:
		EffectDispatcher.execute_effect(effect, active.source, entity, null, combat_manager, entity)
	if active.definition.aura_radius > 0.0 and not active.definition.aura_tick_effects.is_empty():
		_execute_aura_tick(active, entity)
	if active.definition.targeting_count_threshold > 0 and active.definition.targeting_count_status:
		_check_targeting_threshold(active, entity)


func _execute_aura_tick(active: ActiveStatus, entity: Node2D) -> void:
	if not combat_manager or not combat_manager.get("spatial_grid"):
		return
	var grid: SpatialGrid = combat_manager.spatial_grid
	var aura_faction: int
	match active.definition.aura_target_faction:
		"enemy":
			aura_faction = 1 if int(entity.faction) == 0 else 0
		"ally":
			aura_faction = int(entity.faction)
		_:
			return
	var range_sq: float = active.definition.aura_radius * active.definition.aura_radius
	var targets: Array = grid.get_nearby_in_range(entity.position, aura_faction, range_sq)
	for aura_target in targets:
		if not aura_target.is_alive:
			continue
		for effect in active.definition.aura_tick_effects:
			EffectDispatcher.execute_effect(effect, active.source, aura_target, null, combat_manager, entity)


func _check_targeting_threshold(active: ActiveStatus, entity: Node2D) -> void:
	if not combat_manager or not combat_manager.get("spatial_grid"):
		return
	var grid: SpatialGrid = combat_manager.spatial_grid
	var enemy_faction: int = 1 if int(entity.faction) == 0 else 0
	var enemies: Array = grid.get_all(enemy_faction)
	var count: int = 0
	for e in enemies:
		if is_instance_valid(e) and e.is_alive and e.get("attack_target") == entity:
			count += 1
	if count >= active.definition.targeting_count_threshold:
		apply_status(active.definition.targeting_count_status, entity)


func _register_trigger_listeners(status_def: StatusEffectDefinition, source: Node2D) -> void:
	if status_def.trigger_listeners.is_empty():
		return
	var entity: Node2D = get_parent()
	var trigger_comp = entity.get("trigger_component")
	if not trigger_comp:
		return
	for listener in status_def.trigger_listeners:
		trigger_comp.register_listener(status_def.status_id, listener, source)


func _unregister_trigger_listeners(status_def: StatusEffectDefinition) -> void:
	if status_def.trigger_listeners.is_empty():
		return
	var entity: Node2D = get_parent()
	var trigger_comp = entity.get("trigger_component")
	if not trigger_comp:
		return
	trigger_comp.unregister_listeners_for_source(status_def.status_id)


func _unregister_modifiers(active: ActiveStatus) -> void:
	for mod in active._runtime_modifiers:
		_modifier_comp.remove_modifier(mod)
	active._runtime_modifiers.clear()
