class_name AbilityComponent
extends Node
## Manages the entity's skill bar. Tracks cooldowns, evaluates conditions,
## returns the highest-priority ready ability for BehaviorComponent.

class AbilitySlot:
	var definition: AbilityDefinition
	var cooldown_remaining: float = 0.0
	var is_held: bool = false  ## Player toggled to manual hold

	func _init(p_def: AbilityDefinition) -> void:
		definition = p_def

var _slots: Array[AbilitySlot] = []
var _display_slots: Array[AbilitySlot] = []
var _auto_attack: AbilityDefinition = null
var _ability_modifications: Dictionary = {}  ## ability_id -> Array[Array[Resource]]
var _displacement_arrival_modifications: Dictionary = {}
var _cooldown_flat_reductions: Dictionary = {}  ## ability_id -> float


func setup_abilities(auto_attack: AbilityDefinition, skills: Array[SkillDefinition],
		character_level: int, unlocked_ultimate_ids: Array[String] = []) -> void:
	_auto_attack = auto_attack
	_slots.clear()
	_display_slots.clear()
	for skill in skills:
		if skill.unlock_level <= character_level:
			if skill.is_ultimate and not unlocked_ultimate_ids.has(skill.ability.ability_id):
				continue
			var slot := AbilitySlot.new(skill.ability)
			_slots.append(slot)
			_display_slots.append(slot)
	_slots.sort_custom(func(a, b): return a.definition.priority > b.definition.priority)


func tick_cooldowns(delta: float) -> void:
	for slot in _slots:
		if slot.cooldown_remaining > 0.0:
			slot.cooldown_remaining = maxf(slot.cooldown_remaining - delta, 0.0)


func get_highest_priority_ready(source: Node2D) -> AbilityDefinition:
	for slot in _slots:
		if slot.is_held:
			continue
		if slot.cooldown_remaining > 0.0:
			continue
		if _check_conditions(slot.definition, source):
			return slot.definition
	return null


func get_ready_abilities(source: Node2D) -> Array[AbilityDefinition]:
	var result: Array[AbilityDefinition] = []
	for slot in _slots:
		if slot.is_held:
			continue
		if slot.cooldown_remaining > 0.0:
			continue
		if _check_conditions(slot.definition, source):
			result.append(slot.definition)
	return result


func start_cooldown(ability: AbilityDefinition) -> void:
	var entity := get_parent()
	var cdr: float = 0.0
	if entity.get("modifier_component"):
		var mods: ModifierComponent = entity.modifier_component
		cdr = mods.sum_modifiers("All", "cooldown_reduce")
		cdr = clampf(cdr, 0.0, 0.50)  ## 50% CDR cap
	for slot in _slots:
		if slot.definition == ability:
			var base_cd: float = ability.cooldown_base
			var flat_reduce: float = _cooldown_flat_reductions.get(ability.ability_id, 0.0)
			slot.cooldown_remaining = maxf(0.0, base_cd - flat_reduce) * (1.0 - cdr)
			break


func get_auto_attack() -> AbilityDefinition:
	return _auto_attack


func register_ability_modification(target_ability_id: String,
		additional_effects: Array, on_displacement_arrival: bool = false,
		cooldown_flat_reduction: float = 0.0) -> void:
	var target_dict: Dictionary = _displacement_arrival_modifications if on_displacement_arrival else _ability_modifications
	if not additional_effects.is_empty():
		if not target_dict.has(target_ability_id):
			target_dict[target_ability_id] = []
		target_dict[target_ability_id].append(additional_effects)
	if cooldown_flat_reduction > 0.0:
		var current: float = _cooldown_flat_reductions.get(target_ability_id, 0.0)
		_cooldown_flat_reductions[target_ability_id] = current + cooldown_flat_reduction


func get_ability_modifications(ability_id: String) -> Array:
	if not _ability_modifications.has(ability_id):
		return []
	var result: Array = []
	for effect_group in _ability_modifications[ability_id]:
		result.append_array(effect_group)
	return result


func get_displacement_arrival_modifications(ability_id: String) -> Array:
	if not _displacement_arrival_modifications.has(ability_id):
		return []
	var result: Array = []
	for effect_group in _displacement_arrival_modifications[ability_id]:
		result.append_array(effect_group)
	return result


func check_conditions(ability: AbilityDefinition, source: Node2D) -> bool:
	return _check_conditions(ability, source)


func check_resource_cost(ability: AbilityDefinition, source: Node2D) -> bool:
	if ability.resource_cost_status_id == "":
		return true
	var stacks: int = source.status_effect_component.get_stacks(ability.resource_cost_status_id)
	return stacks >= ability.resource_cost_amount


func consume_resource_cost(ability: AbilityDefinition, source: Node2D) -> void:
	if ability.resource_cost_status_id == "":
		return
	source.status_effect_component.consume_stacks(
			ability.resource_cost_status_id, ability.resource_cost_amount)


func force_cooldown_by_id(ability_id: String) -> void:
	var entity := get_parent()
	var cdr: float = 0.0
	if entity.get("modifier_component"):
		var mods: ModifierComponent = entity.modifier_component
		cdr = mods.sum_modifiers("All", "cooldown_reduce")
		cdr = clampf(cdr, 0.0, 0.50)
	for slot in _slots:
		if slot.definition.ability_id == ability_id:
			var base_cd: float = slot.definition.cooldown_base
			var flat_reduce: float = _cooldown_flat_reductions.get(ability_id, 0.0)
			slot.cooldown_remaining = maxf(0.0, base_cd - flat_reduce) * (1.0 - cdr)
			break


func get_display_slots() -> Array[AbilitySlot]:
	return _display_slots


func _check_conditions(ability: AbilityDefinition, source: Node2D) -> bool:
	if not check_resource_cost(ability, source):
		return false
	if ability.conditions.is_empty():
		return true
	for condition in ability.conditions:
		if condition is ConditionTakingDamage:
			var check_time: float
			if condition.required_tag != "":
				var tag_times: Dictionary = source.get("_last_hit_time_by_tag")
				if tag_times == null or not tag_times.has(condition.required_tag):
					return false
				check_time = float(tag_times[condition.required_tag])
			else:
				var hit_time = source.get("last_hit_time")
				if hit_time == null:
					return false
				check_time = float(hit_time)
			var cm: Node2D = source.get("combat_manager")
			var now: float = cm.run_time if cm else 0.0
			if (now - check_time) >= condition.window:
				return false
		elif condition is ConditionHpThreshold:
			if not _check_hp_threshold(condition, source):
				return false
		elif condition is ConditionNoActiveSummon:
			if source.get("_active_summons") != null and source._active_summons.has(condition.summon_id):
				var summon = source._active_summons[condition.summon_id]
				if is_instance_valid(summon) and summon.is_alive:
					return false
		elif condition is ConditionEntityCount:
			if not _check_entity_count(condition, source):
				return false
		elif condition is ConditionStackCount:
			if not _check_stack_count(condition, source):
				return false
		elif condition is ConditionCorpseExists:
			if not _check_corpse_exists(condition, source):
				return false
	return true


func _check_entity_count(condition: ConditionEntityCount, source: Node2D) -> bool:
	var grid: SpatialGrid = source.get("spatial_grid")
	if not grid:
		return false
	var check_faction: int
	match condition.faction:
		"enemy":
			check_faction = 1 if int(source.faction) == 0 else 0
		"ally":
			check_faction = int(source.faction)
		_:
			return false
	if condition.range > 0.0:
		var range_sq: float = condition.range * condition.range
		var in_range := grid.get_nearby_in_range(source.position, check_faction, range_sq)
		if in_range.size() < condition.min_count:
			return false
		if condition.exclude_range > 0.0:
			var exclude_sq: float = condition.exclude_range * condition.exclude_range
			for e in in_range:
				if source.position.distance_squared_to(e.position) < exclude_sq:
					return false
		return true
	else:
		var all := grid.get_all(check_faction)
		return all.size() >= condition.min_count


func _check_hp_threshold(condition: ConditionHpThreshold, source: Node2D) -> bool:
	var grid: SpatialGrid = source.get("spatial_grid")
	if not grid:
		return false
	var own_faction: int = int(source.faction)
	var entities_to_check: Array = []
	match condition.target:
		"self":
			entities_to_check = [source]
		"any_ally":
			entities_to_check = grid.get_all(own_faction)
		"any_enemy":
			var enemy_faction: int = 1 if own_faction == 0 else 0
			entities_to_check = grid.get_all(enemy_faction)
		_:
			return false
	for entity in entities_to_check:
		var hp_pct: float = entity.health.current_hp / entity.health.max_hp
		match condition.direction:
			"below":
				if hp_pct < condition.threshold:
					return true
			"above":
				if hp_pct > condition.threshold:
					return true
	return false


func _check_corpse_exists(condition: ConditionCorpseExists, source: Node2D) -> bool:
	var cm: Node2D = source.get("combat_manager")
	if not cm or not cm.get("corpses"):
		return false
	var check_faction: int
	match condition.faction:
		"ally":
			check_faction = int(source.faction)
		"enemy":
			check_faction = 1 if int(source.faction) == 0 else 0
		_:
			return false
	for corpse in cm.corpses:
		if is_instance_valid(corpse) and int(corpse.faction) == check_faction:
			return true
	return false


func _check_stack_count(condition: ConditionStackCount, source: Node2D) -> bool:
	match condition.target:
		"self":
			var stacks: int = source.status_effect_component.get_stacks(condition.status_id)
			if stacks < condition.min_stacks:
				return false
			if condition.max_stacks >= 0 and stacks > condition.max_stacks:
				return false
			return true
		"any_enemy":
			var grid: SpatialGrid = source.get("spatial_grid")
			if not grid:
				return false
			var enemy_faction: int = 1 if int(source.faction) == 0 else 0
			var enemies: Array = grid.get_all(enemy_faction)
			for e in enemies:
				var stacks: int = e.status_effect_component.get_stacks(condition.status_id)
				if stacks < condition.min_stacks:
					continue
				if condition.max_stacks >= 0 and stacks > condition.max_stacks:
					continue
				return true
			return false
		_:
			return false
