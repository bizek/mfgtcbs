class_name BalanceOverrides
extends RefCounted

## BalanceOverrides — the editable layer under every balance number in the game.
##
## ── Why this exists ───────────────────────────────────────────────────────────
##
## Every balance value in this project lives in a `const` Dictionary compiled into a
## script: `CharacterData.ALL`, `WeaponData.ALL`, 24 enemy `*_data.gd` factories,
## `GameManager.PHASE_DURATIONS`, the phase graphs `ChainFactory` builds. Godot 4 makes
## const collections read-only at runtime, so none of it can be touched while the game
## runs — tuning meant editing source, restarting, and losing your read on how the
## previous value felt.
##
## This is the same shape as `anim_overrides.json` (CharacterSpriteFactory), which solved
## the identical problem for animation slicing: a JSON file read at load, applied over the
## static data at the few seams where it is consumed, writable from an in-game tool, and
## shipped with the build.
##
## ── The contract ──────────────────────────────────────────────────────────────
##
## Values are addressed by a flat `/`-separated PATH. Flat rather than nested because
## every operation the editor needs — is this overridden, revert it, diff against base,
## bake it to source — is a single dictionary lookup on the path, and a nested tree would
## turn each one into a walk.
##
##   character/<char_id>/<field>        base_hp, base_armor, base_move_speed
##   player_stat/<char_id>/<stat>       per-character override of a player `_base_stats` entry
##   player_stat/_global/<stat>         the baseline every character starts from
##   hitbox/<field>                     hurtbox/body extents, pickup radius
##   weapon/<weapon_id>/<field>         damage, attack_speed, projectile_speed, ...
##   enemy/<enemy_id>/<field>           max_hp, contact_damage, move_speed, ...
##   chain/<kit_id>/<graph>/<anim>/<field>   one choreography phase's timing or damage
##   difficulty/<field>                 phase durations, scaling ramp, enemy cap
##
## `_global` is a reserved subject id. No character may use it (nothing does — all 12 ids
## start with "The ").
##
## ── Profiles ──────────────────────────────────────────────────────────────────
##
## The file holds several named sets of values and one active selection, so a tuning pass
## can be A/B'd against the shipped numbers without losing either. "default" always exists
## and is what an exported build reads.
##
## ── Write policy ──────────────────────────────────────────────────────────────
##
## `res://` is writable when running from the project (editor or `godot --path`), which is
## the only context the Unit Editor runs in. Exported builds only ever READ this file —
## same policy as anim_overrides.json. Saving is explicit: edits live in memory until the
## editor calls save(), so a session of experimenting can be thrown away wholesale.

const PATH: String = "res://data/balance_overrides.json"
const VERSION: int = 1
const DEFAULT_PROFILE: String = "default"
## Reserved subject id under `player_stat/` meaning "the baseline, before any character".
const GLOBAL: String = "_global"

static var _profiles: Dictionary = {}
static var _active: String = DEFAULT_PROFILE
static var _loaded: bool = false
static var _dirty: bool = false


# ─── Store ────────────────────────────────────────────────────────────────────

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_profiles = {DEFAULT_PROFILE: {}}
	_active = DEFAULT_PROFILE
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		push_warning("BalanceOverrides: %s is not a JSON object — ignoring" % PATH)
		return
	var root: Dictionary = parsed
	var profiles: Variant = root.get("profiles", null)
	if profiles is Dictionary and not (profiles as Dictionary).is_empty():
		_profiles = {}
		for name: String in (profiles as Dictionary).keys():
			var body: Variant = (profiles as Dictionary)[name]
			_profiles[name] = body if body is Dictionary else {}
	if not _profiles.has(DEFAULT_PROFILE):
		_profiles[DEFAULT_PROFILE] = {}
	var want: String = str(root.get("active", DEFAULT_PROFILE))
	_active = want if _profiles.has(want) else DEFAULT_PROFILE
	_dirty = false


## Drop the cache so the next read re-parses from disk. Used after an external edit.
static func reload() -> void:
	_loaded = false
	_ensure_loaded()


static func _values() -> Dictionary:
	_ensure_loaded()
	return _profiles[_active]


# ─── Read ─────────────────────────────────────────────────────────────────────

## The override at `path`, or `fallback` when none is authored. This is THE read used by
## every seam — if a value can be tuned, its consumption site calls this.
static func get_value(path: String, fallback: Variant) -> Variant:
	var v: Dictionary = _values()
	return v[path] if v.has(path) else fallback


static func get_float(path: String, fallback: float) -> float:
	var v: Variant = get_value(path, fallback)
	return float(v) if (v is float or v is int) else fallback


static func get_int(path: String, fallback: int) -> int:
	var v: Variant = get_value(path, fallback)
	return int(v) if (v is float or v is int) else fallback


static func get_bool(path: String, fallback: bool) -> bool:
	var v: Variant = get_value(path, fallback)
	return bool(v) if v is bool else fallback


## Vector2 round-trips through JSON as a 2-element array.
static func get_vector2(path: String, fallback: Vector2) -> Vector2:
	var v: Variant = get_value(path, null)
	if v is Array and (v as Array).size() == 2:
		var arr: Array = v
		return Vector2(float(arr[0]), float(arr[1]))
	return fallback


static func has_override(path: String) -> bool:
	return _values().has(path)


## Every authored path in the active profile. The editor's change list reads this.
static func overridden_paths() -> Array[String]:
	var out: Array[String] = []
	for k: String in _values().keys():
		out.append(k)
	out.sort()
	return out


static func override_count() -> int:
	return _values().size()


static func is_dirty() -> bool:
	_ensure_loaded()
	return _dirty


# ─── Write ────────────────────────────────────────────────────────────────────

## Set an override. Writes to memory only — save() persists. Setting a value equal to the
## field's base is NOT special-cased here; the editor decides whether that means "clear".
static func set_value(path: String, value: Variant) -> void:
	var store: Dictionary = _values()
	if store.has(path) and _same(store[path], value):
		return
	store[path] = value
	_dirty = true


## Remove an override so the path falls back to the value in source.
static func clear_value(path: String) -> void:
	var store: Dictionary = _values()
	if not store.has(path):
		return
	store.erase(path)
	_dirty = true


## Remove every override whose path starts with `prefix` — "revert this whole character".
static func clear_prefix(prefix: String) -> int:
	var store: Dictionary = _values()
	var doomed: Array[String] = []
	for k: String in store.keys():
		if k.begins_with(prefix):
			doomed.append(k)
	for k: String in doomed:
		store.erase(k)
	if not doomed.is_empty():
		_dirty = true
	return doomed.size()


static func clear_all() -> void:
	var store: Dictionary = _values()
	if store.is_empty():
		return
	store.clear()
	_dirty = true


static func _same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	return a == b


# ─── Profiles ─────────────────────────────────────────────────────────────────

static func active_profile() -> String:
	_ensure_loaded()
	return _active


static func profile_names() -> Array[String]:
	_ensure_loaded()
	var out: Array[String] = []
	for k: String in _profiles.keys():
		out.append(k)
	out.sort()
	return out


static func set_active_profile(name: String) -> bool:
	_ensure_loaded()
	if not _profiles.has(name):
		return false
	_active = name
	_dirty = true
	return true


## Create a profile, optionally seeded with a copy of the active one's values.
static func create_profile(name: String, copy_active: bool = true) -> bool:
	_ensure_loaded()
	if name.is_empty() or _profiles.has(name):
		return false
	_profiles[name] = (_values().duplicate(true) if copy_active else {})
	_active = name
	_dirty = true
	return true


static func delete_profile(name: String) -> bool:
	_ensure_loaded()
	if name == DEFAULT_PROFILE or not _profiles.has(name):
		return false
	_profiles.erase(name)
	if _active == name:
		_active = DEFAULT_PROFILE
	_dirty = true
	return true


# ─── Persist ──────────────────────────────────────────────────────────────────

static func save() -> bool:
	_ensure_loaded()
	var root: Dictionary = {
		"version": VERSION,
		"active": _active,
		"profiles": _profiles,
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("BalanceOverrides: cannot write %s (exported build?)" % PATH)
		return false
	f.store_string(JSON.stringify(root, "  ", true))
	f.close()
	_dirty = false
	return true


# ─── Path helpers ─────────────────────────────────────────────────────────────
#
# One builder per domain so a typo in a path is a compile-visible function call rather
# than a string literal that silently reads the fallback forever. Every seam and the
# registry go through these.

static func character_path(char_id: String, field: String) -> String:
	return "character/%s/%s" % [char_id, field]


static func player_stat_path(char_id: String, stat: String) -> String:
	return "player_stat/%s/%s" % [char_id, stat]


static func hitbox_path(field: String) -> String:
	return "hitbox/%s" % field


static func weapon_path(weapon_id: String, field: String) -> String:
	return "weapon/%s/%s" % [weapon_id, field]


static func enemy_path(enemy_id: String, field: String) -> String:
	return "enemy/%s/%s" % [enemy_id, field]


static func chain_path(kit_id: String, graph: String, anim: String, field: String) -> String:
	return "chain/%s/%s/%s/%s" % [kit_id, graph, anim, field]


static func difficulty_path(field: String) -> String:
	return "difficulty/%s" % field


# ─── Domain reads ─────────────────────────────────────────────────────────────
#
# What the consumption seams actually call.

## A CharacterData balance field (base_hp / base_armor / base_move_speed).
static func character_field(char_id: String, field: String, fallback: float) -> float:
	return get_float(character_path(char_id, field), fallback)


## A player `_base_stats` entry: the character's own override if one is authored, else the
## global baseline override, else the value compiled into player.gd.
##
## Two levels rather than one because both questions are real: "the Warden should crit less"
## is per-character, "everyone's dash cooldown is too long" is global, and collapsing them
## would make the second a twelve-edit chore.
static func player_stat(char_id: String, stat: String, fallback: float) -> float:
	var per_char: String = player_stat_path(char_id, stat)
	if has_override(per_char):
		return get_float(per_char, fallback)
	return get_float(player_stat_path(GLOBAL, stat), fallback)


static func weapon_field(weapon_id: String, field: String, fallback: Variant) -> Variant:
	return get_value(weapon_path(weapon_id, field), fallback)


static func difficulty(field: String, fallback: float) -> float:
	return get_float(difficulty_path(field), fallback)
