class_name StatusVfxFactory
extends RefCounted
## Builds the looping VfxLayerConfig overlays that ride an afflicted entity while a status is
## active. Data-only: hands StatusEffectDefinition.vfx_layers a configured layer; VfxManager does
## the spawning (it already listens to on_status_applied / on_status_expired / on_cleanse).
##
## Why this exists (2026-07-21 doc audit): statuses had NO visual representation at all — a
## burning, frozen or poisoned enemy looked identical to a healthy one. Ability visuals are owned
## by the player's frame-locked ComboFx overlay and are NOT routed through vfx_layers; the status
## path is what vfx_layers is actually for.
##
## Source sheets: the Minifantasy Spell Effects "Aura" sets. Per each pack's own info file the
## three rows are laid out exactly like VfxLayerConfig's phased model:
##   row 0 = starting effect  -> start_animation
##   row 1 = continuous loop  -> animation
##   row 2 = ending effect    -> end_animation
## Pack I auras are 8 frames of 32px; Pack II's Shadow school is 32 frames of 32px, hence the
## per-element frame count below rather than one shared constant.

const _PACK_I: String = "res://assets/minifantasy/Minifantasy_Spell Effects_v1.0/Minifantasy_Spell_Effects_Assets/"
const _PACK_II: String = "res://assets/minifantasy/Minifantasy_Spell_Effects_II_v1.0/Spell_Effects_II/"

const FRAME_SIZE: int = 32
const FPS: float = 10.0   ## every sheet in both packs is authored at 100ms/frame

## element -> sheet + frames per row.
const ELEMENTS: Dictionary = {
	"fire":     {"path": _PACK_I + "Fire/Aura/Aura_Fire.png",         "frames": 8},
	"ice":      {"path": _PACK_I + "Ice/Aura/Aura_Ice.png",           "frames": 8},
	"poison":   {"path": _PACK_I + "Poison/Aura/Aura_Poison.png",     "frames": 8},
	"electric": {"path": _PACK_I + "Electric/Aura/Aura_Electric.png", "frames": 8},
	## Pack II Shadow: 32 frames per row of orbiting void motes — the Void/Curse look.
	"shadow":   {"path": _PACK_II + "Shadow_Magic_School/Aura/Aura_1.png", "frames": 32},
}

## Cache: one SpriteFrames per element, shared by every entity wearing that status.
static var _cache: Dictionary = {}


## A phased (intro -> loop -> outro) aura layer for `element`, or null when the sheet is missing.
## `scale` lets a heavier status read bigger without a second sheet; `tint` lets one sheet serve
## several fantasies (the green Poison aura goes crimson for Bleed).
static func build_aura_layer(element: String, z_index: int = 1,
		offset: Vector2 = Vector2.ZERO, scale: Vector2 = Vector2.ONE,
		tint: Color = Color.WHITE) -> VfxLayerConfig:
	var frames: SpriteFrames = _aura_frames(element)
	if frames == null:
		return null
	var layer := VfxLayerConfig.new()
	layer.sprite_frames = frames
	layer.start_animation = "intro"
	layer.animation = "loop"
	layer.end_animation = "outro"
	layer.z_index = z_index
	layer.offset = offset
	layer.scale = scale
	layer.modulate = tint
	return layer


static func _aura_frames(element: String) -> SpriteFrames:
	if _cache.has(element):
		return _cache[element]
	if not ELEMENTS.has(element):
		push_warning("StatusVfxFactory: unknown element '%s'" % element)
		return null

	var spec: Dictionary = ELEMENTS[element]
	var path: String = String(spec["path"])
	if not ResourceLoader.exists(path):
		push_warning("StatusVfxFactory: aura sheet missing — %s" % path)
		_cache[element] = null
		return null

	var sheet: Texture2D = load(path)
	if sheet == null:
		_cache[element] = null
		return null

	var per_row: int = int(spec["frames"])
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	## Row order is fixed by the packs: 0 intro, 1 loop, 2 outro. Only the loop repeats.
	_slice_row(frames, "intro", sheet, 0, false, per_row)
	_slice_row(frames, "loop",  sheet, 1, true,  per_row)
	_slice_row(frames, "outro", sheet, 2, false, per_row)
	_cache[element] = frames
	return frames


static func _slice_row(frames: SpriteFrames, anim_name: String, sheet: Texture2D,
		row: int, loops: bool, per_row: int) -> void:
	var anim_sn := StringName(anim_name)
	frames.add_animation(anim_sn)
	frames.set_animation_loop(anim_sn, loops)
	frames.set_animation_speed(anim_sn, FPS)
	for i in per_row:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
		atlas.filter_clip = true   ## clamp sampling to the region — no edge bleed between frames
		frames.add_frame(anim_sn, atlas)
