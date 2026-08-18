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
## chain factory via get_anim_meta(). build() reads only {"from","to"} out of it (the authored
## column range — see the slicing block below); every other key is timing metadata it ignores.
##
## `sheet` is normally a filename appended to the "dir" base, but combat specials live in
## Special_Animations/<Name>/ subfolders — so a spec sheet starting with "res://" is treated
## as an ABSOLUTE path and used verbatim (back-compatible: bare filenames still join "dir").

## Animations that loop; everything else (attack/damage/death/combo/skill) plays once.
## Combo channels (e.g. Whirlwind) loop via choreography phase re-entry, not a looping SpriteFrames.
## "carry_idle"/"carry_walk" are the Ravager's Pile Driver carry locomotion — a phase-scoped
## replacement for idle/walk (ChoreographyPhase.recovery_locomotion), so they loop like them.
const LOOPING_ANIMS: Array[String] = ["idle", "walk", "carry_idle", "carry_walk"]

## Animations player.gd plays by name — warn if a character's data omits one.
const REQUIRED_ANIMS: Array[String] = ["idle", "walk", "attack", "damage", "death"]

## Facing → sheet row. The Minifantasy oblique style draws the four rows as DIAGONAL facings,
## not N/S/E/W: rows 0/1 are the front (face visible), rows 2/3 the back (hood/back of head).
## Horizontal order confirmed by Ben's in-game test 2026-07-04: row 0 faces down-RIGHT,
## row 1 down-LEFT, row 2 up-RIGHT, row 3 up-LEFT.
const DIR_ROWS: Dictionary = {"down_right": 0, "down_left": 1, "up_right": 2, "up_left": 3}

## Cardinal facing → row in an OPTIONAL orthogonal companion sheet (8-way facing, Ben 2026-07-20).
## An anim opts in via a {"ortho": <sheet>} 4th spec element; its four cardinal rows are sliced as
## "<anim>_down/_up/_left/_right". Anims without an ortho sheet never emit cardinal variants, so
## the player falls back to the nearest diagonal (unchanged from the old 4-quadrant behavior).
## ROW ORDER — VERIFIED 2026-07-29, was wrong before. The old guess was
## {"down": 0, "up": 1, "right": 2, "left": 3}, which put EVERY cardinal 90 degrees off its art:
## aiming right played the down row, aiming down played the right row (Ben: "the shield bash almost
## fires in the wrong direction for every direction I put the mouse in").
## Measured from the only cardinal sheets in the game (Paladin Shield_Bash) by taking each row's
## alpha-weighted centroid over its impact frames — the shove wedge points unambiguously:
##   row 0 -> right (357deg) · row 1 -> left (183deg) · row 2 -> down (84deg) · row 3 -> up (264deg)
## A sheet that ships a different order still remaps per facing via the Lab's "row" override
## (dirs.<cardinal>.row in anim_overrides.json), exactly like the diagonals.
const CARDINAL_ROWS: Dictionary = {"right": 0, "left": 1, "down": 2, "up": 3}

## ── Ben's Animation Lab overrides ────────────────────────────────────────────
## Per-character, per-anim tweaks authored in-game with the Animation Lab (F6, debug mode):
##   { "<char_id>": { "<anim>": { "from": int, "to": int, "fps": float, "hit_frame": int } } }
## from/to select a sub-range of the sheet's columns (inclusive); fps replaces playback speed;
## hit_frame (optional) is applied to matching choreography phases at kit build (player.gd).
## The file is read once and cached; the Lab calls reload_overrides() after saving.
const OVERRIDES_PATH: String = "res://data/anim_overrides.json"
## Staged-playback segment names, in play order. A sustained anim (channel body) authored with
## these in the Lab plays intro → loop (while held) → outro (on release).
const STAGE_NAMES: Array[String] = ["intro", "loop", "outro"]
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


## Per-facing override inside an anim entry ("dirs"), or {} when that facing isn't authored.
## A facing may override from/to/fps/hit_frame independently, and "row" remaps which sheet row
## it reads (for packs whose rows don't follow the standard facing order).
static func get_dir_override(char_id: String, anim_name: String, facing: String) -> Dictionary:
	var dirs = get_anim_override(char_id, anim_name).get("dirs", {})
	if dirs is Dictionary and dirs.has(facing) and dirs[facing] is Dictionary:
		return dirs[facing]
	return {}


## The hit frame that applies to one facing: the facing's own override, else the anim-level
## override, else -1 (meaning "whatever the kit code authored").
static func get_hit_frame(char_id: String, anim_name: String, facing: String) -> int:
	var d: Dictionary = get_dir_override(char_id, anim_name, facing)
	if d.has("hit_frame"):
		return int(d["hit_frame"])
	var ov: Dictionary = get_anim_override(char_id, anim_name)
	if ov.has("hit_frame"):
		return int(ov["hit_frame"])
	return -1


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


## ── Imported animations ──────────────────────────────────────────────────────
## PNGs wired up from the Animation Lab rather than hand-added to CharacterData. Stored under
## the reserved "_custom_anims" key of the overrides file:
##   { "_custom_anims": { "<char_id>": { "<anim>": [sheet_path, frame_count, fps] } } }
## They are merged into the character's anim table at build time and behave exactly like a
## table entry from then on — trimmable, stageable, per-direction editable.
const CUSTOM_KEY: String = "_custom_anims"


static func get_custom_anims(char_id: String) -> Dictionary:
	var all = get_overrides().get(CUSTOM_KEY, {})
	if all is Dictionary and all.get(char_id, null) is Dictionary:
		return all[char_id]
	return {}


## Register (or with frame_count <= 0, remove) an imported animation.
static func save_custom_anim(char_id: String, anim_name: String, sheet_path: String,
		frame_count: int, fps: float) -> bool:
	var all: Dictionary = get_overrides().duplicate(true)
	var registry: Dictionary = all.get(CUSTOM_KEY, {})
	var by_char: Dictionary = registry.get(char_id, {})
	if frame_count <= 0:
		by_char.erase(anim_name)
	else:
		by_char[anim_name] = [sheet_path, frame_count, fps]
	if by_char.is_empty():
		registry.erase(char_id)
	else:
		registry[char_id] = by_char
	if registry.is_empty():
		all.erase(CUSTOM_KEY)
	else:
		all[CUSTOM_KEY] = registry
	var f := FileAccess.open(OVERRIDES_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("CharacterSpriteFactory: cannot write " + OVERRIDES_PATH)
		return false
	f.store_string(JSON.stringify(all, "  "))
	f.close()
	_overrides = all
	_overrides_loaded = true
	return true


## Every animation name available to a character: data-table entries plus imported ones.
static func all_anim_specs(char_id: String) -> Dictionary:
	var meta: Dictionary = CharacterData.ALL.get(char_id, {}).get("sprite", {})
	var out: Dictionary = {}
	for k in meta.get("anims", {}):
		out[str(k)] = meta["anims"][k]
	for k in get_custom_anims(char_id):
		out[str(k)] = get_custom_anims(char_id)[k]
	return out


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
	var anims: Dictionary = all_anim_specs(char_id)
	## Stage aliases that point at ANOTHER animation are resolved after every animation is
	## sliced (they copy frames, so their source has to exist first).
	var pending_aliases: Array = []

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
		## Imported sheets may use a different cell size than the character's 32px body (the
		## Wizard's explosion sheets are 64px). Data-table specs put a timing Dictionary in
		## slot 3, so only a NUMBER there means "frame size".
		var a_fs: int = frame_size
		if spec.size() >= 4 and (typeof(spec[3]) == TYPE_INT or typeof(spec[3]) == TYPE_FLOAT):
			a_fs = maxi(int(spec[3]), 1)
		if not ResourceLoader.exists(path):
			push_warning("CharacterSpriteFactory: missing sheet %s (%s/%s)" % [path, char_id, anim_name])
			continue
		var sheet: Texture2D = load(path)
		if sheet == null:
			continue

		var sheet_rows: int = int(sheet.get_height() / float(a_fs))
		var sheet_cols: int = int(sheet.get_width() / float(a_fs))
		var loops: bool = anim_name in LOOPING_ANIMS
		## Authored sub-range: the spec's timing Dictionary may carry {"from": int} (and optionally
		## "to") to slice PART of a sheet under this name. Needed whenever one pack sheet holds two
		## distinct beats the kit drives separately — the Barbarian's Throw_Things is one animation
		## on disk but a grab (f0-8) and a hurl (f8-15) in the game. Without a spec-level `from`,
		## the only way to start a slice past column 0 was an Animation Lab override, which is Ben's
		## in-game tuning file, not a place to author a kit's structure.
		## Omitted `from` = 0 and `to` = count-1, i.e. exactly the old behavior.
		var timing: Dictionary = spec[3] if spec.size() >= 4 and spec[3] is Dictionary else {}
		var spec_from: int = int(timing.get("from", 0))
		var spec_to: int = int(timing.get("to", spec_from + count - 1))
		## Animation Lab override: sub-range of the sheet's columns + fps replacement. Still wins
		## over the authored range — retrimming in the Lab must keep working on a sliced anim.
		var ov: Dictionary = get_anim_override(char_id, str(anim_name))
		var first: int = clampi(int(ov.get("from", spec_from)), 0, sheet_cols - 1)
		var last: int = clampi(int(ov.get("to", spec_to)), first, sheet_cols - 1)
		fps = float(ov.get("fps", fps))
		## Anim-level overlay layers: "<anim>_fx" (above the body) and "<anim>_base" (below).
		## Lets a ONE-SHOT anim carry pack layers too, not just staged channels.
		for layer in ["fx", "base"]:
			if str(ov.get(layer, "")) != "":
				pending_aliases.append({
					"dst": "%s_%s" % [anim_name, layer],
					"src": str(ov[layer]),
					"loops": false,
				})
		## Base name (back-compat fallback): dir_row on 4-row sheets, row 0 on single-row sheets.
		_slice_row(frames, anim_name, sheet, first, last, fps, mini(dir_row, sheet_rows - 1), a_fs, loops)
		## Directional variants — the pack's 4 rows ARE the facings; slice them all so the
		## player can face the cursor. Each facing may carry its own Animation Lab override
		## (different trim/fps, or a remapped sheet row when a pack's rows are out of order).
		## A sheet flagged {"cardinal": true} has CARDINAL rows (down/up/left/right), not the usual
		## diagonals — the Shield Bash is one (Ben 2026-07-20: it should fire up/down/left/right).
		## Its rows are sliced as the cardinal facings; diagonal aims fall back to the nearest
		## cardinal at play time (player._facing_variant).
		var is_cardinal: bool = spec.size() >= 4 and spec[3] is Dictionary and bool(spec[3].get("cardinal", false))
		if sheet_rows >= 4 and not is_cardinal:
			for facing in DIR_ROWS:
				var d: Dictionary = get_dir_override(char_id, str(anim_name), str(facing))
				var d_first: int = clampi(int(d.get("from", first)), 0, sheet_cols - 1)
				var d_last: int = clampi(int(d.get("to", last)), d_first, sheet_cols - 1)
				var d_fps: float = float(d.get("fps", fps))
				var d_row: int = clampi(int(d.get("row", int(DIR_ROWS[facing]))), 0, sheet_rows - 1)
				_slice_row(frames, "%s_%s" % [anim_name, facing], sheet, d_first, d_last, d_fps,
						d_row, a_fs, loops)
		elif sheet_rows >= 4 and is_cardinal:
			for card in CARDINAL_ROWS:
				var cd: Dictionary = get_dir_override(char_id, str(anim_name), str(card))
				var cc_first: int = clampi(int(cd.get("from", first)), 0, sheet_cols - 1)
				var cc_last: int = clampi(int(cd.get("to", last)), cc_first, sheet_cols - 1)
				var cc_fps: float = float(cd.get("fps", fps))
				var cc_row: int = clampi(int(cd.get("row", int(CARDINAL_ROWS[card]))), 0, sheet_rows - 1)
				_slice_row(frames, "%s_%s" % [anim_name, card], sheet, cc_first, cc_last, cc_fps,
						cc_row, a_fs, loops)
		## Optional orthogonal companion sheet → the four CARDINAL facing rows (8-way facing).
		## Opt in with a {"ortho": <sheet>} 4th spec element (bare filename joins "dir", or an
		## absolute res:// path). Each cardinal may remap its row / trim via get_dir_override.
		if spec.size() >= 4 and spec[3] is Dictionary and str(spec[3].get("ortho", "")) != "":
			var raw_o: String = str(spec[3]["ortho"])
			var o_path: String = raw_o if raw_o.begins_with("res://") else base_dir + raw_o
			if ResourceLoader.exists(o_path):
				var osheet: Texture2D = load(o_path)
				if osheet != null:
					var o_cols: int = int(osheet.get_width() / float(a_fs))
					var o_rows: int = int(osheet.get_height() / float(a_fs))
					for card in CARDINAL_ROWS:
						var cd: Dictionary = get_dir_override(char_id, str(anim_name), str(card))
						var c_first: int = clampi(int(cd.get("from", 0)), 0, o_cols - 1)
						var c_last: int = clampi(int(cd.get("to", count - 1)), c_first, o_cols - 1)
						var c_fps: float = float(cd.get("fps", fps))
						var c_row: int = clampi(int(cd.get("row", int(CARDINAL_ROWS[card]))), 0, o_rows - 1)
						_slice_row(frames, "%s_%s" % [anim_name, card], osheet, c_first, c_last,
								c_fps, c_row, a_fs, loops)
		## Staged segments (Animation Lab): a sustained anim can be cut into
		## intro (plays once) → loop (repeats while held) → outro (plays on release).
		## Yields "<anim>_intro"/"_loop"/"_outro" + their facing variants; the choreography
		## runner picks them up automatically for channel phases (see ChoreographyRunner).
		## A stage is one of:
		##   [from, to]                          — columns of this anim's own sheet
		##   {"sheet": "res://…", from, to}      — columns of a DIFFERENT sheet
		##   {"anim": "<name>", "fx": "<name>"}  — play a whole OTHER animation as this stage,
		##                                         with an optional overlay animation
		## The "anim" form is the one the Lab writes: a held ability's loop can be its own
		## imported sheet (dome intro → DomeCycle loop) rather than a slice of the body sheet.
		var stages = ov.get("stages", {})
		if stages is Dictionary:
			for stage_name in STAGE_NAMES:
				if not stages.has(stage_name):
					continue
				var spec_stage = stages[stage_name]
				var s_sheet: Texture2D = sheet
				var s_from: int = 0
				var s_to: int = 0
				var s_loops_stage: bool = stage_name == "loop"
				## True when the body comes from another animation (resolved in the alias pass)
				## rather than from a column slice here.
				var body_is_alias: bool = false

				if spec_stage is Array and spec_stage.size() >= 2:
					s_from = int(spec_stage[0])
					s_to = int(spec_stage[1])
				elif spec_stage is Dictionary:
					## "fx" / "base" attach overlay animations to a stage independently of the
					## body: a stage may keep the body's own columns and only swap its effect
					## layer (the Warden holds the cast pose while DomeStart → DomeCycle plays
					## over it). "base" renders BELOW the character, per the packs' own
					## _AnimationInfo.txt.
					for layer in ["fx", "base"]:
						if str(spec_stage.get(layer, "")) != "":
							pending_aliases.append({
								"dst": "%s_%s_%s" % [anim_name, stage_name, layer],
								"src": str(spec_stage[layer]),
								"loops": s_loops_stage,
							})
					if str(spec_stage.get("anim", "")) != "":
						## Body is a whole other animation (its own PNG).
						pending_aliases.append({
							"dst": "%s_%s" % [anim_name, stage_name],
							"src": str(spec_stage["anim"]),
							"loops": s_loops_stage,
						})
						body_is_alias = true
					elif not spec_stage.has("from"):
						## Overlay-only stage: the body keeps this anim's own trim.
						pending_aliases.append({
							"dst": "%s_%s" % [anim_name, stage_name],
							"src": str(anim_name),
							"loops": s_loops_stage,
						})
						body_is_alias = true
					else:
						s_from = int(spec_stage.get("from", 0))
						s_to = int(spec_stage.get("to", 0))
						var alt_path: String = str(spec_stage.get("sheet", ""))
						if alt_path != "" and ResourceLoader.exists(alt_path):
							var alt: Texture2D = load(alt_path)
							if alt:
								s_sheet = alt
				else:
					continue

				if body_is_alias:
					continue
				var s_cols: int = int(s_sheet.get_width() / float(a_fs))
				var s_rows: int = int(s_sheet.get_height() / float(a_fs))
				var s_first: int = clampi(s_from, 0, s_cols - 1)
				var s_last: int = clampi(s_to, s_first, s_cols - 1)
				var s_base: String = "%s_%s" % [anim_name, stage_name]
				_slice_row(frames, s_base, s_sheet, s_first, s_last, fps,
						mini(dir_row, s_rows - 1), a_fs, s_loops_stage)
				if s_rows >= 4:
					for facing in DIR_ROWS:
						_slice_row(frames, "%s_%s" % [s_base, facing], s_sheet, s_first, s_last,
								fps, int(DIR_ROWS[facing]), a_fs, s_loops_stage)
		built_any = true

	if not built_any:
		return null

	## Stage aliases: copy a whole animation's frames under the "<base>_<stage>" name, for the
	## base slice and every facing row, so staged playback and the fx overlay find them.
	for req_alias in pending_aliases:
		_alias_animation(frames, str(req_alias.dst), str(req_alias.src), bool(req_alias.loops))
		for facing in DIR_ROWS:
			_alias_animation(frames, "%s_%s" % [req_alias.dst, facing],
					"%s_%s" % [req_alias.src, facing], bool(req_alias.loops))

	for req in REQUIRED_ANIMS:
		if not frames.has_animation(StringName(req)):
			push_warning("CharacterSpriteFactory: %s is missing required anim '%s'" % [char_id, req])
	return frames


## Re-publish an already-sliced animation under another name (frames are shared AtlasTextures,
## so this costs nothing). Used for stage aliases; no-ops when the source doesn't exist.
static func _alias_animation(frames: SpriteFrames, dst: String, src: String, loops: bool) -> void:
	var s := StringName(src)
	var d := StringName(dst)
	if not frames.has_animation(s):
		return
	if frames.has_animation(d):
		frames.remove_animation(d)
	frames.add_animation(d)
	frames.set_animation_loop(d, loops)
	frames.set_animation_speed(d, frames.get_animation_speed(s))
	for i in range(frames.get_frame_count(s)):
		frames.add_frame(d, frames.get_frame_texture(s, i))


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
##
## The Animation Lab override wins over the authored spec, so `cancel_open` is retunable in-game
## exactly like `hit_frame` — that's the point of the seam (player.choreo_min_advance_time reads it).
static func get_anim_meta(char_id: String, anim_name: String) -> Dictionary:
	var char_data: Dictionary = CharacterData.ALL.get(char_id, {})
	var anims: Dictionary = char_data.get("sprite", {}).get("anims", {})
	var spec: Array = anims.get(anim_name, [])
	var meta: Dictionary = {"hit_frame": -1, "cancel_open": -1, "cancel_close": -1}
	if spec.size() >= 4 and spec[3] is Dictionary:
		for k in spec[3]:
			meta[k] = spec[3][k]
	var ov: Dictionary = get_anim_override(char_id, anim_name)
	for k in ["hit_frame", "cancel_open", "cancel_close"]:
		if ov.has(k):
			meta[k] = int(ov[k])
	return meta
