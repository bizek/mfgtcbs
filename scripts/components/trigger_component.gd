class_name TriggerComponent
extends Node
## Manages this entity's event listeners (from statuses, talents, upgrades).
## Connects to EventBus signals, evaluates trigger conditions, dispatches effects.

class ActiveListener:
	var definition: TriggerListenerDefinition
	var source_id: String
	var source_entity: Node2D

var _listeners: Dictionary = {}  ## event_name -> Array[ActiveListener]
var _event_refcounts: Dictionary = {}
var combat_manager: Node2D = null


func register_listener(source_id: String, listener: TriggerListenerDefinition,
		source_entity: Node2D) -> void:
	var event: String = listener.event
	if not _listeners.has(event):
		_listeners[event] = []
	var active := ActiveListener.new()
	active.definition = listener
	active.source_id = source_id
	active.source_entity = source_entity
	_listeners[event].append(active)

	var count: int = _event_refcounts.get(event, 0)
	if count == 0:
		_connect_event(event)
	_event_refcounts[event] = count + 1


func unregister_listeners_for_source(source_id: String) -> void:
	var events_to_clean: Array[String] = []
	for event in _listeners:
		var list: Array = _listeners[event]
		var i: int = list.size() - 1
		while i >= 0:
			if list[i].source_id == source_id:
				list.remove_at(i)
				_event_refcounts[event] -= 1
			i -= 1
		if list.is_empty():
			events_to_clean.append(event)
	for event in events_to_clean:
		_disconnect_event(event)
		_listeners.erase(event)
		_event_refcounts.erase(event)


func cleanup() -> void:
	for event in _event_refcounts:
		_disconnect_event(event)
	_listeners.clear()
	_event_refcounts.clear()


# --- EventBus signal handlers ---

func _on_hit_dealt(source: Node2D, target: Node2D, hit_data) -> void:
	_evaluate_and_dispatch("on_hit_dealt", source, target, hit_data)

func _on_hit_received(source: Node2D, target: Node2D, hit_data) -> void:
	_evaluate_and_dispatch("on_hit_received", source, target, hit_data)

func _on_kill(killer: Node2D, victim: Node2D) -> void:
	_evaluate_and_dispatch("on_kill", killer, victim, null)

func _on_crit(source: Node2D, target: Node2D, hit_data) -> void:
	_evaluate_and_dispatch("on_crit", source, target, hit_data)

func _on_block(source: Node2D, target: Node2D, hit_data, _mitigated: float) -> void:
	_evaluate_and_dispatch("on_block", source, target, hit_data)

func _on_dodge(source: Node2D, target: Node2D, hit_data) -> void:
	_evaluate_and_dispatch("on_dodge", source, target, hit_data)

func _on_heal(source: Node2D, target: Node2D, _amount: float) -> void:
	_evaluate_and_dispatch("on_heal", source, target, null)

func _on_death(entity: Node2D) -> void:
	_evaluate_and_dispatch("on_death", entity, entity, null)

func _on_status_applied(source: Node2D, target: Node2D, status_id: String,
		_stacks: int) -> void:
	_evaluate_and_dispatch("on_status_applied", source, target, {"status_id": status_id})

func _on_status_expired(entity: Node2D, status_id: String) -> void:
	_evaluate_and_dispatch("on_status_expired", entity, entity, {"status_id": status_id})

func _on_absorb(entity: Node2D, hit_data, _absorbed: float) -> void:
	_evaluate_and_dispatch("on_absorb", entity, entity, hit_data)

func _on_displacement_resisted(resisted_by: Node2D, attempted_by: Node2D) -> void:
	_evaluate_and_dispatch("on_displacement_resisted", resisted_by, attempted_by, null)

func _on_overkill(killer: Node2D, victim: Node2D, _overkill_amount: float) -> void:
	_evaluate_and_dispatch("on_overkill", killer, victim, null)

func _on_revive(source: Node2D, target: Node2D) -> void:
	_evaluate_and_dispatch("on_revive", source, target, null)

func _on_status_resisted(source: Node2D, target: Node2D, status_id: String) -> void:
	_evaluate_and_dispatch("on_status_resisted", source, target, {"status_id": status_id})

func _on_summon(summoner: Node2D, summon: Node2D) -> void:
	_evaluate_and_dispatch("on_summon", summoner, summon, null)

func _on_summon_death(summoner: Node2D, summon: Node2D) -> void:
	_evaluate_and_dispatch("on_summon_death", summoner, summon, null)

func _on_ability_used(source: Node2D, ability) -> void:
	_evaluate_and_dispatch("on_ability_used", source, source, null)


# --- Core evaluation + dispatch ---

func _evaluate_and_dispatch(event: String, source: Node2D, target: Node2D,
		hit_data) -> void:
	if not _listeners.has(event):
		return
	var entity: Node2D = get_parent()
	if not entity.is_alive:
		return

	for active_listener in _listeners[event]:
		var def: TriggerListenerDefinition = active_listener.definition
		if not _check_trigger_conditions(def.conditions, entity, source, target, hit_data):
			continue
		var effect_source: Node2D = entity
		var effect_target: Node2D
		if def.target_self:
			effect_target = entity
		elif def.target_event_source:
			effect_target = source if is_instance_valid(source) else entity
		else:
			effect_target = target if is_instance_valid(target) else entity
		for effect in def.effects:
			EffectDispatcher.execute_effect(effect, effect_source, effect_target,
					null, combat_manager, entity)


func _check_trigger_conditions(conditions: Array, entity: Node2D,
		source: Node2D, target: Node2D, hit_data) -> bool:
	for condition in conditions:
		if condition is TriggerConditionSourceIsSelf:
			if source != entity:
				return false
		elif condition is TriggerConditionTargetIsSelf:
			if target != entity:
				return false
		elif condition is TriggerConditionNotCrit:
			if hit_data is HitData and hit_data.is_crit:
				return false
		elif condition is TriggerConditionEventEntityFaction:
			var check_entity: Node2D
			match condition.entity_role:
				"source":
					check_entity = source
				"target":
					check_entity = target
				_:
					return false
			if not is_instance_valid(check_entity):
				return false
			var expected_faction: int
			match condition.faction:
				"enemy":
					expected_faction = 1 if int(entity.faction) == 0 else 0
				"ally":
					expected_faction = int(entity.faction)
				_:
					return false
			if int(check_entity.faction) != expected_faction:
				return false
		elif condition is TriggerConditionStatusId:
			if not (hit_data is Dictionary and hit_data.has("status_id")):
				return false
			if hit_data["status_id"] != condition.status_id:
				return false
		elif condition is TriggerConditionHpThreshold:
			var hp_pct: float = entity.health.current_hp / entity.health.max_hp
			match condition.direction:
				"below":
					if hp_pct >= condition.threshold:
						return false
				"above":
					if hp_pct <= condition.threshold:
						return false
				_:
					return false
		elif condition is TriggerConditionAbilityId:
			if hit_data is HitData and hit_data.ability != null:
				if hit_data.ability.ability_id != condition.ability_id:
					return false
			else:
				return false
		elif condition is TriggerConditionTargetHitByTag:
			if not is_instance_valid(target):
				return false
			var tag_time: float = target._last_hit_time_by_tag.get(condition.tag, -1e18)
			var current_time: float = combat_manager.run_time if combat_manager else 0.0
			if (current_time - tag_time) > condition.window:
				return false
	return true


# --- Signal connection management ---

func _connect_event(event: String) -> void:
	match event:
		"on_hit_dealt":
			EventBus.on_hit_dealt.connect(_on_hit_dealt)
		"on_hit_received":
			EventBus.on_hit_received.connect(_on_hit_received)
		"on_kill":
			EventBus.on_kill.connect(_on_kill)
		"on_crit":
			EventBus.on_crit.connect(_on_crit)
		"on_block":
			EventBus.on_block.connect(_on_block)
		"on_dodge":
			EventBus.on_dodge.connect(_on_dodge)
		"on_heal":
			EventBus.on_heal.connect(_on_heal)
		"on_death":
			EventBus.on_death.connect(_on_death)
		"on_status_applied":
			EventBus.on_status_applied.connect(_on_status_applied)
		"on_status_expired":
			EventBus.on_status_expired.connect(_on_status_expired)
		"on_absorb":
			EventBus.on_absorb.connect(_on_absorb)
		"on_displacement_resisted":
			EventBus.on_displacement_resisted.connect(_on_displacement_resisted)
		"on_overkill":
			EventBus.on_overkill.connect(_on_overkill)
		"on_revive":
			EventBus.on_revive.connect(_on_revive)
		"on_status_resisted":
			EventBus.on_status_resisted.connect(_on_status_resisted)
		"on_summon":
			EventBus.on_summon.connect(_on_summon)
		"on_summon_death":
			EventBus.on_summon_death.connect(_on_summon_death)
		"on_ability_used":
			EventBus.on_ability_used.connect(_on_ability_used)
		_:
			push_warning("TriggerComponent: unsupported event type '%s'" % event)


func _disconnect_event(event: String) -> void:
	match event:
		"on_hit_dealt":
			if EventBus.on_hit_dealt.is_connected(_on_hit_dealt):
				EventBus.on_hit_dealt.disconnect(_on_hit_dealt)
		"on_hit_received":
			if EventBus.on_hit_received.is_connected(_on_hit_received):
				EventBus.on_hit_received.disconnect(_on_hit_received)
		"on_kill":
			if EventBus.on_kill.is_connected(_on_kill):
				EventBus.on_kill.disconnect(_on_kill)
		"on_crit":
			if EventBus.on_crit.is_connected(_on_crit):
				EventBus.on_crit.disconnect(_on_crit)
		"on_block":
			if EventBus.on_block.is_connected(_on_block):
				EventBus.on_block.disconnect(_on_block)
		"on_dodge":
			if EventBus.on_dodge.is_connected(_on_dodge):
				EventBus.on_dodge.disconnect(_on_dodge)
		"on_heal":
			if EventBus.on_heal.is_connected(_on_heal):
				EventBus.on_heal.disconnect(_on_heal)
		"on_death":
			if EventBus.on_death.is_connected(_on_death):
				EventBus.on_death.disconnect(_on_death)
		"on_status_applied":
			if EventBus.on_status_applied.is_connected(_on_status_applied):
				EventBus.on_status_applied.disconnect(_on_status_applied)
		"on_status_expired":
			if EventBus.on_status_expired.is_connected(_on_status_expired):
				EventBus.on_status_expired.disconnect(_on_status_expired)
		"on_absorb":
			if EventBus.on_absorb.is_connected(_on_absorb):
				EventBus.on_absorb.disconnect(_on_absorb)
		"on_displacement_resisted":
			if EventBus.on_displacement_resisted.is_connected(_on_displacement_resisted):
				EventBus.on_displacement_resisted.disconnect(_on_displacement_resisted)
		"on_overkill":
			if EventBus.on_overkill.is_connected(_on_overkill):
				EventBus.on_overkill.disconnect(_on_overkill)
		"on_revive":
			if EventBus.on_revive.is_connected(_on_revive):
				EventBus.on_revive.disconnect(_on_revive)
		"on_status_resisted":
			if EventBus.on_status_resisted.is_connected(_on_status_resisted):
				EventBus.on_status_resisted.disconnect(_on_status_resisted)
		"on_summon":
			if EventBus.on_summon.is_connected(_on_summon):
				EventBus.on_summon.disconnect(_on_summon)
		"on_summon_death":
			if EventBus.on_summon_death.is_connected(_on_summon_death):
				EventBus.on_summon_death.disconnect(_on_summon_death)
		"on_ability_used":
			if EventBus.on_ability_used.is_connected(_on_ability_used):
				EventBus.on_ability_used.disconnect(_on_ability_used)
