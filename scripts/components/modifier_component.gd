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

## ── Silent-miss guard (added 2026-08-01 after six live modifiers turned out to do nothing) ──
## Queries are an exact "tag:operation" dictionary lookup, so a modifier filed under a pair no
## reader ever asks for is simply never seen: no error, no warning, the buff applies and displays
## normally and changes nothing. That is how Second Wind / Lay on Hands / Sanctuary's wards, three
## class mods, and four passive-tree crit nodes all shipped dead.
##
## These two tables encode the pairings the readers actually use. They are deliberately narrow —
## they only catch the mistake that has actually happened (a right-sounding tag with the wrong
## operation), so anything not listed passes untouched.
##
## Tags that are only ever summed with ONE operation. DamageCalculator reads crit/block/dodge as
## ("<tag>", "add") and nothing calls get_stat() on them, so "bonus" on these is dead.
const STRICT_OP: Dictionary = {
	"crit_chance": "add", "crit_multiplier": "add",
	"block_chance": "add", "block_mitigation": "add", "dodge_chance": "add",
}
## Names that are OPERATIONS in the damage pipeline and are NOT also stat tags, so they must never
## appear as a target_tag. The tag for these is a damage type or "All" — e.g. ("All",
## "damage_taken"), not ("damage_taken", <anything>). Verified by grepping get_stat("<name>"):
## zero callers for all three.
##
## "pierce" is deliberately ABSENT even though it is an operation too — it is genuinely dual-use.
## ("<DamageType>", "pierce") is resistance penetration in DamageCalculator, while ("pierce", "add")
## is the projectile pierce COUNT read by player.get_stat("pierce"). Listing it here made this guard
## flag the correct passive-tree node f_fletcher on its first run. A guard that cries wolf on working
## content is worse than no guard, so keep this list to names with no legitimate tag use.
const NEVER_A_TAG: Array[String] = ["damage_taken", "vulnerability", "resist"]


# --- Modifier management ---

func add_modifier(mod: ModifierDefinition) -> void:
	if OS.is_debug_build():
		_warn_if_unreadable(mod)
	_modifiers.append(mod)
	_cache_dirty = true


## Debug-only. Flags a modifier whose tag/operation pair no reader will ever query, naming the
## source so the offending factory entry is findable. Never raises — a false positive must not be
## able to break a run.
func _warn_if_unreadable(mod: ModifierDefinition) -> void:
	if mod == null:
		return
	var tag: String = mod.target_tag
	var op: String = mod.operation
	if STRICT_OP.has(tag) and op != STRICT_OP[tag]:
		push_warning(("ModifierComponent: (\"%s\", \"%s\") from source \"%s\" is never read — " +
			"\"%s\" is only summed with \"%s\". This modifier will silently do nothing.") % [
			tag, op, mod.source_name, tag, STRICT_OP[tag]])
	elif tag in NEVER_A_TAG:
		push_warning(("ModifierComponent: (\"%s\", \"%s\") from source \"%s\" is never read — " +
			"\"%s\" is an OPERATION, not a tag. Use target_tag \"All\" (or a damage type) with " +
			"operation \"%s\". This modifier will silently do nothing.") % [
			tag, op, mod.source_name, tag, tag])


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
