class_name CharacterSpriteFactory
extends RefCounted
## Builds a SpriteFrames for a playable character from its CharacterData entry's
## "sprite" metadata, slicing each Minifantasy True Heroes sheet into
## frame_size x frame_size frames.
##
## This is the ONLY code that touches per-character sprites — adding character #8
## is pure data (a "sprite" block in CharacterData.ALL) + assets, zero code change.
##
## Sheet layout contract (see docs/character_overhaul_design.md §1/§3):
##   rows = 4 facing directions, columns = animation frames; Die is a single row.
## ALL four facing rows are sliced (assets fully utilized — CLAUDE.md rule): every 4-row sheet
## yields "<anim>" (the dir_row fallback) plus "<anim>_<facing>" variants per DIR_ROWS below;
## the player picks the variant matching its cursor quadrant. Single-row sheets yield "<anim>".
## Mirrors the runtime-slicing pattern in enemy_guardian.gd and player_vfx_helper.gd.
##
## Anim spec shape (per docs/combat_chain_architecture.md §7):
##   [sheet, frame_count, fps]                                  ## base (idle/walk/attack/...)
##   [sheet, frame_count, fps, {hit_frame, cancel_open, cancel_close}]  ## combo/skill nodes
## The optional 4th element carries per-anim combat timing read by the choreography runner /
## chain factory via get_anim_meta(); build() ignores it (slicing doesn't need it).
##
## `sheet` is normally a filename appended to the "dir" base, but combat specials live in
## Special_Animations/<Name>/ subfolders — so a spec sheet starting with "res://" is treated
## as an ABSOLUTE path and used verbatim (back-compatible: bare filenames still join "dir").

## Animations that loop; everything else (attack/damage/death/combo/skill) plays once.
## Combo channels (e.g. Whirlwind) loop via choreography phase re-entry, not a looping SpriteFrames.
const LOOPING_ANIMS: Array[String] = ["idle", "walk"]

## Animations player.gd plays by name — warn if a character's data omits one.
const REQUIRED_ANIMS: Array[String] = ["idle", "walk", "attack", "damage", "death"]

## Facing → sheet row. The Minifantasy oblique style draws the four rows as DIAGONAL facings,
## not N/S/E/W: rows 0/1 are the front (face visible), rows 2/3 the back (hood/back of head).
## Horizontal order confirmed by Ben's in-game test 2026-07-04: row 0 faces down-RIGHT,
## row 1 down-LEFT, row 2 up-RIGHT, row 3 up-LEFT.
const DIR_ROWS: Dictionary = {"down_right": 0, "down_left": 1, "up_right": 2, "up_left": 3}

## ── Ben's Animation Lab overrides ────────────────────────────────────────────
## Per-character, per-anim tweaks authored in-game with the Animation Lab (F6, debug mode):
##   { "<char_id>": { "<anim>": { "from": int, "to": int, "fps": float, "hit_frame": int } } }
## from/to select a sub-range of the sheet's columns (inclusive); fps replaces playback speed;
## hit_frame (optional) is applied to matching choreography phases at kit build (player.gd).
## The file is read once and cached; the Lab calls reload_overrides() after saving.
const OVERRIDES_PATH: String = "res://data/anim_overrides.json"
static var _overrides: Dictionary = {}
static var _overrides_loaded: bool = false


static func get_overrides() -> Dictionary:
	if not _overrides_loaded:
		_overrides_loaded = true
		_overrides = {}
		if FileAccess.file_exists(OVERRIDES_PATH):
			var f := FileAccess.open(OVERRIDES_PATH, FileAccess.READ)
			if f:
				var parsed = JSON.parse_string(f.get_as_text())
				if parsed is Dictionary:
					_overrides = parsed
	return _overrides


static func get_anim_override(char_id: String, anim_name: String) -> Dictionary:
	var by_char = get_overrides().get(char_id, {})
	return by_char.get(anim_name, {}) if by_char is Dictionary else {}


static func reload_overrides() -> void:
	_overrides_loaded = false


## Persist one anim's override (empty dict removes it). Editor/dev workflow — res:// is
## writable when running from the project; exported builds only ever read the file.
static func save_anim_override(char_id: String, anim_name: String, data: Dictionary) -> bool:
	var all: Dictionary = get_overrides().duplicate(true)
	var by_char: Dictionary = all.get(char_id, {})
	if data.is_empty():
		by_char.erase(anim_name)
	else:
		by_char[anim_name] = data
	if by_char.is_empty():
		all.erase(char_id)
	else:
		all[char_id] = by_char
	var f := FileAccess.open(OVERRIDES_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("CharacterSpriteFactory: cannot write " + OVERRIDES_PATH)
		return false
	f.store_string(JSON.stringify(all, "  "))
	f.close()
	_overrides = all
	_overrides_loaded = true
	return true


## Returns a SpriteFrames with the character's animations, or null when the
## character has no "sprite" metadata or none of its sheets could be loaded
## (callers keep their existing/baked frames as a fallback).
static func build(char_id: String) -> SpriteFrames:
	var char_data: Dictionary = CharacterData.ALL.get(char_id, {})
	var meta: Dictionary = char_data.get("sprite", {})
	if meta.is_empty():
		return null

	var base_dir: String = meta.get("dir", "")
	var frame_size: int = int(meta.get("frame_size", 32))
	var dir_row: int = int(meta.get("dir_row", 0))
	var anims: Dictionary = meta.get("anims", {})

	var frames := SpriteFrames.new()
	frames.clear_all()   ## drop the auto-created "default" animation

	var built_any: bool = false
	for anim_name in anims:
		var spec: Array = anims[anim_name]
		if spec.size() < 3:
			push_warning("CharacterSpriteFactory: bad anim spec for %s/%s" % [char_id, anim_name])
			continue
		var raw_sheet: String = str(spec[0])
		## Specials in subfolders pass an absolute res:// path; base anims pass a bare filename.
		var path: String = raw_sheet if raw_sheet.begins_with("res://") else base_dir + raw_sheet
		var count: int = int(spec[1])
		var fps: float = float(spec[2])
		if not ResourceLoader.exists(path):
			push_warning("CharacterSpriteFactory: missing sheet %s (%s/%s)" % [path, char_id, anim_name])
			continue
		var sheet: Texture2D = load(path)
		if sheet == null:
			continue

		var sheet_rows: int = int(sheet.get_height() / float(frame_size))
		var sheet_cols: int = int(sheet.get_width() / float(frame_size))
		var loops: bool = anim_name in LOOPING_ANIMS
		## Animation Lab override: sub-range of the sheet's columns + fps replacement.
		var ov: Dictionary = get_anim_override(char_id, str(anim_name))
		var first: int = clampi(int(ov.get("from", 0)), 0, sheet_cols - 1)
		var last: int = clampi(int(ov.get("to", count - 1)), first, sheet_cols - 1)
		fps = float(ov.get("fps", fps))
		## Base name (back-compat fallback): dir_row on 4-row sheets, row 0 on single-row sheets.
		_slice_row(frames, anim_name, sheet, first, last, fps, mini(dir_row, sheet_rows - 1), frame_size, loops)
		## Directional variants — the pack's 4 rows ARE the facings; slice them all so the
		## player can face the cursor.
		if sheet_rows >= 4:
			for facing in DIR_ROWS:
				_slice_row(frames, "%s_%s" % [anim_name, facing], sheet, first, last, fps,
						int(DIR_ROWS[facing]), frame_size, loops)
		built_any = true

	if not built_any:
		return null

	for req in REQUIRED_ANIMS:
		if not frames.has_animation(StringName(req)):
			push_warning("CharacterSpriteFactory: %s is missing required anim '%s'" % [char_id, req])
	return frames


## Slice one sheet row's columns [first..last] (inclusive) into a SpriteFrames animation.
static func _slice_row(frames: SpriteFrames, anim_name: String, sheet: Texture2D, first: int,
		last: int, fps: float, row: int, frame_size: int, loops: bool) -> void:
	var anim_sn := StringName(anim_name)
	frames.add_animation(anim_sn)
	frames.set_animation_loop(anim_sn, loops)
	frames.set_animation_speed(anim_sn, fps)
	for i in range(first, last + 1):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_size, row * frame_size, frame_size, frame_size)
		atlas.filter_clip = true   ## clamp sampling to the region — no edge bleed between frames
		frames.add_frame(anim_sn, atlas)


## Per-anim combat timing metadata (the optional 4th element of an anims spec), or {} if absent.
## Read by the choreography runner / chain factory: {hit_frame:int, cancel_open:int, cancel_close:int}
## in animation frames. Returns a copy with safe defaults so callers can index freely.
static func get_anim_meta(char_id: String, anim_name: String) -> Dictionary:
	var char_data: Dictionary = CharacterData.ALL.get(char_id, {})
	var anims: Dictionary = char_data.get("sprite", {}).get("anims", {})
	var spec: Array = anims.get(anim_name, [])
	var meta: Dictionary = {"hit_frame": -1, "cancel_open": -1, "cancel_close": -1}
	if spec.size() >= 4 and spec[3] is Dictionary:
		for k in spec[3]:
			meta[k] = spec[3][k]
	return meta
