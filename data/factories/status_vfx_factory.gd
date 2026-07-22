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
## Source sheets: Minifantasy Spell Effects "Aura" set. Per the pack's own Animation_Info.txt the
## three rows are laid out exactly like VfxLayerConfig's phased model:
##   row 0 = starting effect  -> start_animation
##   row 1 = continuous loop  -> animation
##   row 2 = ending effect    -> end_animation
## 32x32 frames, 8 per row, 100ms/frame = 10 fps.

const _AURA_DIR: String = "res://assets/minifantasy/Minifantasy_Spell Effects_v1.0/Minifantasy_Spell_Effects_Assets/%s/Aura/Aura_%s.png"

const FRAME_SIZE: int = 32
const FRAMES_PER_ROW: int = 8
const FPS: float = 10.0

## element -> the pack's folder/file stem (they match, but keep the mapping explicit).
const ELEMENTS: Dictionary = {
	"fire":   "Fire",
	"ice":    "Ice",
	"poison": "Poison",
}

## Cache: one SpriteFrames per element, shared by every entity wearing that status.
static var _cache: Dictionary = {}


## A phased (intro -> loop -> outro) aura layer for `element`, or null when the sheet is missing.
## `scale` lets a heavier status read bigger without a second sheet.
static func build_aura_layer(element: String, z_index: int = 1,
		offset: Vector2 = Vector2.ZERO, scale: Vector2 = Vector2.ONE) -> VfxLayerConfig:
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
	return layer


static func _aura_frames(element: String) -> SpriteFrames:
	if _cache.has(element):
		return _cache[element]
	if not ELEMENTS.has(element):
		push_warning("StatusVfxFactory: unknown element '%s'" % element)
		return null

	var path: String = _AURA_DIR % [ELEMENTS[element], ELEMENTS[element]]
	if not ResourceLoader.exists(path):
		push_warning("StatusVfxFactory: aura sheet missing — %s" % path)
		_cache[element] = null
		return null

	var sheet: Texture2D = load(path)
	if sheet == null:
		_cache[element] = null
		return null

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	## Row order is fixed by the pack: 0 intro, 1 loop, 2 outro. Only the loop repeats.
	_slice_row(frames, "intro", sheet, 0, false)
	_slice_row(frames, "loop",  sheet, 1, true)
	_slice_row(frames, "outro", sheet, 2, false)
	_cache[element] = frames
	return frames


static func _slice_row(frames: SpriteFrames, anim_name: String, sheet: Texture2D,
		row: int, loops: bool) -> void:
	var anim_sn := StringName(anim_name)
	frames.add_animation(anim_sn)
	frames.set_animation_loop(anim_sn, loops)
	frames.set_animation_speed(anim_sn, FPS)
	for i in FRAMES_PER_ROW:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
		atlas.filter_clip = true   ## clamp sampling to the region — no edge bleed between frames
		frames.add_frame(anim_sn, atlas)
