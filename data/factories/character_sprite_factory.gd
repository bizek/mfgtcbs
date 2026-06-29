class_name CharacterSpriteFactory
extends RefCounted
## Builds a SpriteFrames for a playable character from its CharacterData entry's
## "sprite" metadata. Slices the front-facing direction row (dir_row) of each
## Minifantasy True Heroes sheet into frame_size x frame_size frames.
##
## This is the ONLY code that touches per-character sprites — adding character #8
## is pure data (a "sprite" block in CharacterData.ALL) + assets, zero code change.
##
## Sheet layout contract (see docs/character_overhaul_design.md §1/§3):
##   rows = 4 facing directions, columns = animation frames; Die is a single row.
##   The engine renders one facing + flip_h, so we slice dir_row (0 = Down/front).
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

		var anim_sn := StringName(anim_name)
		frames.add_animation(anim_sn)
		frames.set_animation_loop(anim_sn, anim_name in LOOPING_ANIMS)
		frames.set_animation_speed(anim_sn, fps)
		for i in range(count):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * frame_size, dir_row * frame_size, frame_size, frame_size)
			atlas.filter_clip = true   ## clamp sampling to the region — no edge bleed between frames
			frames.add_frame(anim_sn, atlas)
		built_any = true

	if not built_any:
		return null

	for req in REQUIRED_ANIMS:
		if not frames.has_animation(StringName(req)):
			push_warning("CharacterSpriteFactory: %s is missing required anim '%s'" % [char_id, req])
	return frames


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
