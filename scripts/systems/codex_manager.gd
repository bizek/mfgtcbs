extends Node

## Singleton autoload: Manages codex discovery and combo mastery state

var entries: Dictionary = {}  # keyed by combo_id (StringName) → CodexEntry

signal combo_discovered(combo_id: StringName)
signal combo_revealed(combo_id: StringName)
signal combo_mastered(combo_id: StringName)


func _ready() -> void:
	_initialize_entries()


func _initialize_entries() -> void:
	"""Build CodexEntry for each combo in the registry."""
	var combos = ComboRegistry.build_registry()
	for combo in combos:
		var entry = CodexEntry.new()
		entry.combo = combo
		entry.discovered = false
		entry.revealed = false
		entry.times_triggered = 0
		entry.mastery_threshold = 50

		# Set mastery descriptions based on combo type
		match combo.combo_type:
			ModCombo.ComboType.TRIPLE_LEGENDARY:
				entry.mastery_bonus_description = "+20% effect potency"
			ModCombo.ComboType.BEHAVIOR_BEHAVIOR:
				entry.mastery_bonus_description = "+15% projectile speed"
			ModCombo.ComboType.BEHAVIOR_ELEMENTAL:
				entry.mastery_bonus_description = "+10% element effectiveness"
			ModCombo.ComboType.ELEMENTAL_ELEMENTAL:
				entry.mastery_bonus_description = "+25% proc radius"
			ModCombo.ComboType.STAT_INTERACTION:
				entry.mastery_bonus_description = "+5% stat bonus"

		entries[combo.combo_id] = entry


func discover_combo(combo_id: StringName) -> void:
	"""Mark a combo as discovered (player slotted it in armory)."""
	if combo_id not in entries:
		push_error("Combo not found: %s" % combo_id)
		return

	var entry = entries[combo_id]
	if not entry.discovered:
		entry.discovered = true
		combo_discovered.emit(combo_id)


func reveal_combo(combo_id: StringName) -> void:
	"""Mark a combo as revealed (player triggered it in a run)."""
	if combo_id not in entries:
		push_error("Combo not found: %s" % combo_id)
		return

	var entry = entries[combo_id]
	if not entry.revealed:
		entry.revealed = true
		combo_revealed.emit(combo_id)


func record_trigger(combo_id: StringName) -> void:
	"""Increment trigger count and check for mastery."""
	if combo_id not in entries:
		push_error("Combo not found: %s" % combo_id)
		return

	var entry = entries[combo_id]
	var was_mastered = entry.is_mastered()

	entry.times_triggered += 1

	# If we just crossed the mastery threshold, emit signal
	if not was_mastered and entry.is_mastered():
		combo_mastered.emit(combo_id)


func get_combos_for_mod_pair(mod_a: StringName, mod_b: StringName) -> Array[CodexEntry]:
	"""Lookup all combos that require exactly mod_a and mod_b (2-mod combos only)."""
	var result: Array[CodexEntry] = []
	var sorted_pair = _sort_string_pair(mod_a, mod_b)

	for entry in entries.values():
		if entry.combo.required_mods.size() != 2:
			continue  # Skip triples and singles

		var combo_pair = _sort_string_pair(entry.combo.required_mods[0], entry.combo.required_mods[1])
		if combo_pair == sorted_pair:
			result.append(entry)

	return result


func get_all_discovered() -> Array[CodexEntry]:
	"""Return all discovered combos."""
	var result: Array[CodexEntry] = []
	for entry in entries.values():
		if entry.discovered:
			result.append(entry)
	return result


func get_all_mastered() -> Array[CodexEntry]:
	"""Return all mastered combos."""
	var result: Array[CodexEntry] = []
	for entry in entries.values():
		if entry.is_mastered():
			result.append(entry)
	return result


func get_discovery_percentage() -> float:
	"""Return percentage of combos discovered (0.0 to 1.0)."""
	if entries.is_empty():
		return 0.0

	var discovered_count = 0
	for entry in entries.values():
		if entry.discovered:
			discovered_count += 1

	return float(discovered_count) / float(entries.size())


func save_data() -> Dictionary:
	"""Serialize codex state for save file."""
	var data = {}
	for combo_id: StringName in entries:
		var entry = entries[combo_id]
		data[combo_id] = {
			"discovered": entry.discovered,
			"revealed": entry.revealed,
			"times_triggered": entry.times_triggered,
		}
	return data


func load_data(data: Dictionary) -> void:
	"""Load codex state from save file."""
	if data.is_empty():
		return

	for combo_id: StringName in data:
		if combo_id not in entries:
			continue  # Combo registry changed; skip stale entries

		var entry = entries[combo_id]
		var combo_data = data[combo_id]

		entry.discovered = combo_data.get("discovered", false)
		entry.revealed = combo_data.get("revealed", false)
		entry.times_triggered = combo_data.get("times_triggered", 0)


static func _sort_string_pair(a: StringName, b: StringName) -> Array:
	"""Return consistently sorted pair [min, max] for lookup."""
	if a < b:
		return [a, b]
	else:
		return [b, a]
