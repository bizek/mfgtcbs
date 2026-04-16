class_name ModifierComponent
extends Node
## Flat list of active modifiers with cached query layer.
## Modifiers come from upgrades, weapon mods, status effects, character passives, zone buffs.
## Cache invalidated on add/remove, rebuilt lazily on next query.

var _modifiers: Array[ModifierDefinition] = []
var _conversions: Array[ConversionDefinition] = []

## Cache: keyed by "tag:operation" -> precomputed sum
var _cache: Dictionary = {}
var _cache_dirty: bool = true


# --- Modifier management ---

func add_modifier(mod: ModifierDefinition) -> void:
	_modifiers.append(mod)
	_cache_dirty = true


func remove_modifier(mod: ModifierDefinition) -> void:
	var idx := _modifiers.find(mod)
	if idx >= 0:
		_modifiers.remove_at(idx)
		_cache_dirty = true


func remove_modifiers_by_source(source: String) -> void:
	var i := _modifiers.size() - 1
	while i >= 0:
		if _modifiers[i].source_name == source:
			_modifiers.remove_at(i)
			_cache_dirty = true
		i -= 1


func remove_by_source_prefix(prefix: String) -> void:
	var i := _modifiers.size() - 1
	while i >= 0:
		if _modifiers[i].source_name.begins_with(prefix):
			_modifiers.remove_at(i)
			_cache_dirty = true
		i -= 1


func add_conversion(conv: ConversionDefinition) -> void:
	_conversions.append(conv)


func remove_conversion(conv: ConversionDefinition) -> void:
	var idx := _conversions.find(conv)
	if idx >= 0:
		_conversions.remove_at(idx)


func remove_conversions_by_source(source: String) -> void:
	var i := _conversions.size() - 1
	while i >= 0:
		if _conversions[i].source_name == source:
			_conversions.remove_at(i)
		i -= 1


# --- Queries ---

func sum_modifiers(tag: String, operation: String) -> float:
	if _cache_dirty:
		_rebuild_cache()
	var key := tag + ":" + operation
	return _cache.get(key, 0.0)


func has_negation(tag: String) -> bool:
	## Returns true if any modifier negates the given tag (immunity).
	if _cache_dirty:
		_rebuild_cache()
	return _cache.get(tag + ":negate", 0.0) > 0.0


func get_pierce_value(tag: String) -> float:
	return sum_modifiers(tag, "pierce")


func get_first_conversion(source_type: String) -> ConversionDefinition:
	## Returns the first conversion matching source_type. Processing order = insertion order
	## (passives -> upgrades -> status effects -> zone buffs).
	for conv in _conversions:
		if conv.source_type == source_type:
			return conv
	return null


func get_all_modifiers() -> Array[ModifierDefinition]:
	return _modifiers


# --- Cache ---

func _rebuild_cache() -> void:
	_cache.clear()
	for mod in _modifiers:
		var key := mod.target_tag + ":" + mod.operation
		_cache[key] = _cache.get(key, 0.0) + mod.value
	_cache_dirty = false
