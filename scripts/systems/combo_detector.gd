class_name ComboDetector
extends RefCounted
## Detects which authored mod combos are active for a set of equipped mod IDs.
##
## Builds an index from ComboRegistry on first use. Results are cached by loadout
## fingerprint so repeated calls during the same run are O(1).
##
## Excludes ELEMENTAL_ELEMENTAL combos — those fire on enemy status state and are
## handled entirely by ComboEffectResolver via EventBus, not by mod loadout.
##
## Triple combos override their component doubles. If [pierce, fire, gravity] activates
## VAMPIRE LORD (pierce+fire+gravity triple), Flaming Lance (pierce+fire) and Needle
## Vortex (pierce+gravity) are suppressed so their effects don't double-dip.
##
## ── INTEGRATION POINTS ──────────────────────────────────────────────────────────────
##
## 1. HubArmoryPanel — after every equip/unequip:
##        var combos := _combo_detector.get_active_combos(weapon.get_equipped_mod_ids())
##        CodexManager.discover_combo(c.combo_id) for c in combos
##        weapon.active_combo_ids = combos.map(func(c): return c.combo_id)
##
## 2. Run start — recompute for each weapon when transitioning to RUN phase:
##        (same as above, called from GameManager or player _ready)
##
## 3. ComboEffectResolver.set_active_combos() — pass results so the resolver
##    knows which combos to record triggers for on projectile events.
## ────────────────────────────────────────────────────────────────────────────────────

## Pair index: "mod_a|mod_b" (sorted) → ModCombo (2-mod combos only)
var _pair_index: Dictionary = {}

## Triple index: "mod_a|mod_b|mod_c" (sorted) → ModCombo (3-mod combos only)
var _triple_index: Dictionary = {}

## Cache: sorted loadout key → Array[ModCombo]
var _cache: Dictionary = {}


func _init() -> void:
	_build_index()


func _build_index() -> void:
	for combo: ModCombo in ComboRegistry.build_registry():
		## Skip elemental reactions — they don't require specific mods to be equipped
		if combo.combo_type == ModCombo.ComboType.ELEMENTAL_ELEMENTAL:
			continue
		var sorted_mods: Array[StringName] = combo.required_mods.duplicate()
		sorted_mods.sort()
		var key: String = "|".join(sorted_mods)
		if combo.required_mods.size() == 3:
			_triple_index[key] = combo
		elif combo.required_mods.size() == 2:
			_pair_index[key] = combo


func get_active_combos(equipped_mods: Array[StringName]) -> Array[ModCombo]:
	## Returns the full list of active authored combos for this mod loadout.
	## Triples are listed first; dominated doubles are excluded.
	if equipped_mods.is_empty():
		return []
	var cache_key: String = _make_cache_key(equipped_mods)
	if _cache.has(cache_key):
		return _cache[cache_key]
	var result: Array[ModCombo] = _compute(equipped_mods)
	_cache[cache_key] = result
	return result


func get_active_combo_ids(equipped_mods: Array[StringName]) -> Array[StringName]:
	## Convenience wrapper — returns just the combo IDs.
	var ids: Array[StringName] = []
	for combo in get_active_combos(equipped_mods):
		ids.append(combo.combo_id)
	return ids


func invalidate_cache() -> void:
	## Call when the registry changes (e.g. mod unlocks mid-session).
	_cache.clear()


## ── Internal ────────────────────────────────────────────────────────────────────────

func _compute(mods: Array[StringName]) -> Array[ModCombo]:
	var active_triples: Array[ModCombo] = []
	var active_doubles: Array[ModCombo] = []

	## Triples first
	for key: String in _triple_index:
		if _all_present(mods, key.split("|")):
			active_triples.append(_triple_index[key])

	## Build the union of all mods covered by active triples, for suppression below
	var triple_covered: Array[StringName] = []
	for triple: ModCombo in active_triples:
		for m: StringName in triple.required_mods:
			if not triple_covered.has(m):
				triple_covered.append(m)

	## Doubles — skip any pair where BOTH mods are already covered by a triple
	for key: String in _pair_index:
		var parts: PackedStringArray = key.split("|")
		if not _all_present(mods, parts):
			continue
		## Check if this double is superseded (both its mods appear in a single triple)
		if _pair_superseded_by_triples(active_triples, StringName(parts[0]), StringName(parts[1])):
			continue
		active_doubles.append(_pair_index[key])

	var result: Array[ModCombo] = []
	result.append_array(active_triples)
	result.append_array(active_doubles)
	return result


func _pair_superseded_by_triples(
		triples: Array[ModCombo], mod_a: StringName, mod_b: StringName) -> bool:
	## Returns true if SOME active triple contains both mod_a and mod_b.
	for triple: ModCombo in triples:
		if triple.required_mods.has(mod_a) and triple.required_mods.has(mod_b):
			return true
	return false


func _all_present(mods: Array[StringName], required: PackedStringArray) -> bool:
	for m: String in required:
		if not mods.has(StringName(m)):
			return false
	return true


static func _make_cache_key(mods: Array[StringName]) -> String:
	var sorted: Array[StringName] = mods.duplicate()
	sorted.sort()
	return "|".join(sorted)
