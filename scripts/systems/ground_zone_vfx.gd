class_name GroundZoneVfx
extends Node2D
## The persistent footprint of a GroundZoneEffect — the thing that makes a ground zone visible
## for as long as it is actually hurting people.
##
## Why this exists: CombatOrchestrator.spawn_ground_zone() stored a dict and ticked damage with
## NO visual of any kind. Every zone in the game (Brimstone Circle, Druid Root, Word of Pain,
## Blood Eruption, Archdemon's Call, the Deep's void wake, boss zones, napalm patches) was an
## invisible damage field the player could only find by standing in it. Casters dropped a one-shot
## decal at cast time and then lied for the rest of the duration.
##
## Source art: the Minifantasy Spell Effects "Tileable_Effect" sheets. Per the packs' own
## Animation_Info.txt these are 8x8 tiles laid out exactly like the phased model we need:
##   row 0 = starting effect · row 1 = continuous loop · row 2 = ending effect
## Pack II's Arcane/Shadow tileables ship a single loop row instead, so ROWS collapses to [0,0,0]
## for those and the intro/outro simply play the loop art.
##
## Rendering: ONE node with a single _draw() that blits the current frame's tile across the zone,
## not an AnimatedSprite2D per tile. A 46px zone is ~110 tiles and a 200px zone ~1900 — as pooled
## draw_texture_rect_region calls that is nothing; as nodes it would be a stampede.

const TILE: int = 8
const FPS: float = 10.0            ## every pack sheet is authored at 100ms/frame
const GROUND_ALPHA: float = 0.16   ## the soft wash under the tiles, so sparse fills still read
## Tiles are scattered, not solid: a 100%-filled grid of animated fire reads as a flat orange
## block. KEEP_RATIO is the fraction of grid cells that actually draw, chosen deterministically
## per cell so the pattern is stable frame to frame (it must not shimmer).
const KEEP_RATIO: float = 0.58
const MAX_TILES: int = 900         ## above this the grid step doubles — big boss zones stay cheap

## element -> sheet + layout. `rows` is [intro, loop, outro]; `frames` is columns per row.
const ELEMENTS: Dictionary = {
	"fire": {
		"path": "res://assets/minifantasy/Minifantasy_Spell Effects_v1.0/Minifantasy_Spell_Effects_Assets/Fire/Tileable_Effect/Tileable_Fire.png",
		"frames": 8, "rows": [0, 1, 2],
	},
	"ice": {
		## Tileable_Ice stacks THREE shard variants separated by an empty row (64x88):
		## variant 1 = rows 0-2, variant 2 = rows 4-6, variant 3 = rows 8-10. We take variant 1.
		"path": "res://assets/minifantasy/Minifantasy_Spell Effects_v1.0/Minifantasy_Spell_Effects_Assets/Ice/Tileable_Effect/Tileable_Ice.png",
		"frames": 8, "rows": [0, 1, 2],
	},
	"electric": {
		"path": "res://assets/minifantasy/Minifantasy_Spell Effects_v1.0/Minifantasy_Spell_Effects_Assets/Electric/Tileable_Effect/Tileable_Electric.png",
		"frames": 8, "rows": [0, 1, 2],
	},
	"poison": {
		"path": "res://assets/minifantasy/Minifantasy_Spell Effects_v1.0/Minifantasy_Spell_Effects_Assets/Poison/Tileable_Effect/Tileable_Poison.png",
		"frames": 8, "rows": [0, 1, 2],
	},
	"arcane": {
		## Pack II tileables are a single loop row — no authored intro/outro, so all three
		## phases play the loop and the fade in/out carries the transition instead.
		"path": "res://assets/minifantasy/Minifantasy_Spell_Effects_II_v1.0/Spell_Effects_II/Arcane_Magic_School/_Arcane_Tileable_Effect/Arcane_Tileable.png",
		"frames": 12, "rows": [0, 0, 0],
	},
	"shadow": {
		"path": "res://assets/minifantasy/Minifantasy_Spell_Effects_II_v1.0/Spell_Effects_II/Shadow_Magic_School/_Tileable_Effect/Double_Tileable_Effect.png",
		"frames": 23, "rows": [0, 0, 0],
	},
}

## Loaded sheets, shared by every live zone of that element.
static var _sheets: Dictionary = {}

var element: String = "fire"
var radius: float = 32.0
var duration: float = 4.0
var tint: Color = Color.WHITE

var _sheet: Texture2D = null
var _frames: int = 8
var _rows: Array = [0, 1, 2]
## Per-tile: [Vector2 local position, int frame phase offset]. Built once in setup().
var _tiles: Array = []
var _elapsed: float = 0.0
var _last_frame: int = -1
var _intro_time: float = 0.0
var _outro_time: float = 0.0


## Build a footprint for `element` covering `radius` px for `duration` s. Returns false when the
## element is unknown or its sheet is missing — the caller then simply gets no visual, never a
## broken zone (same degrade-to-nothing contract as StatusVfxFactory).
func setup(elem: String, r: float, dur: float, colour: Color = Color.WHITE) -> bool:
	if not ELEMENTS.has(elem):
		push_warning("GroundZoneVfx: unknown element '%s'" % elem)
		return false
	var spec: Dictionary = ELEMENTS[elem]
	_sheet = _get_sheet(elem, String(spec["path"]))
	if _sheet == null:
		return false
	element = elem
	radius = maxf(r, 4.0)
	duration = maxf(dur, 0.2)
	tint = colour
	_frames = int(spec["frames"])
	_rows = spec["rows"]

	## A zone that barely outlives its own intro should just be the loop — playing a 0.8s
	## wind-up and a 0.8s wind-down inside a 1s zone reads as a flicker, not an effect.
	var phase_len: float = float(_frames) / FPS
	if duration >= phase_len * 2.5:
		_intro_time = phase_len
		_outro_time = phase_len
	_build_tiles()
	z_index = -1            ## a floor decal: under every body standing in it
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return true


static func _get_sheet(elem: String, path: String) -> Texture2D:
	if _sheets.has(elem):
		return _sheets[elem]
	if not ResourceLoader.exists(path):
		push_warning("GroundZoneVfx: tileable sheet missing — %s" % path)
		_sheets[elem] = null
		return null
	var tex: Texture2D = load(path)
	_sheets[elem] = tex
	return tex


## Lay a grid over the circle and keep a deterministic scatter of its cells. Determinism matters:
## the kept set and each tile's frame phase are derived from the cell coordinates, so the pattern
## is fixed for the zone's whole life and never shimmers between redraws.
func _build_tiles() -> void:
	_tiles.clear()
	var step: int = TILE
	## Grow the step for very large zones so the tile count stays bounded.
	while int(PI * pow(radius / float(step), 2.0)) > MAX_TILES:
		step *= 2
	var span: int = int(ceil(radius / float(step)))
	var r_sq: float = radius * radius
	for gy in range(-span, span + 1):
		for gx in range(-span, span + 1):
			var pos := Vector2(float(gx * step), float(gy * step))
			if pos.length_squared() > r_sq:
				continue
			## Stable hashes of the cell — the same cell always makes the same keep/phase decision,
			## so the scatter is fixed for the zone's life. Two independent hashes rather than
			## slicing one, so keep and phase don't correlate into visible banding.
			var h_keep: int = absi(hash(Vector2i(gx, gy)))
			if float(h_keep % 1000) / 1000.0 > KEEP_RATIO:
				continue
			var h_phase: int = absi(hash(Vector2i(gx + 977, gy - 613)))
			_tiles.append([pos, h_phase % _frames])


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return
	var frame: int = int(_elapsed * FPS)
	if frame != _last_frame:
		_last_frame = frame
		queue_redraw()


## Which sheet row is live right now: intro while winding up, outro once the zone is dying,
## loop for the long middle.
func _current_row() -> int:
	if _intro_time > 0.0 and _elapsed < _intro_time:
		return int(_rows[0])
	if _outro_time > 0.0 and _elapsed >= duration - _outro_time:
		return int(_rows[2])
	return int(_rows[1])


func _draw() -> void:
	if _sheet == null:
		return
	## Soft ground wash first — keeps the zone readable where the scatter leaves gaps, and fades
	## with the tiles so the whole footprint dies together.
	var a: float = _fade_alpha()
	draw_circle(Vector2.ZERO, radius, Color(tint.r, tint.g, tint.b, GROUND_ALPHA * a))

	var row: int = _current_row()
	## Intro and outro play ONCE (clamped to their last frame); the loop wraps.
	var base: int = int(_elapsed * FPS)
	var in_intro: bool = _intro_time > 0.0 and _elapsed < _intro_time
	var in_outro: bool = _outro_time > 0.0 and _elapsed >= duration - _outro_time
	var draw_tint := Color(tint.r, tint.g, tint.b, tint.a * a)
	for t in _tiles:
		var pos: Vector2 = t[0]
		var phase: int = t[1]
		var col: int
		if in_intro:
			col = mini(base, _frames - 1)
		elif in_outro:
			col = mini(int((_elapsed - (duration - _outro_time)) * FPS), _frames - 1)
		else:
			col = (base + phase) % _frames
		draw_texture_rect_region(_sheet,
				Rect2(pos - Vector2(TILE, TILE) * 0.5, Vector2(TILE, TILE)),
				Rect2(col * TILE, row * TILE, TILE, TILE),
				draw_tint)


## Short fade at both ends so a zone never pops in or out, on top of whatever the intro/outro
## art already does. Zones too short for an authored intro rely on this alone.
func _fade_alpha() -> float:
	const EDGE: float = 0.25
	if _elapsed < EDGE:
		return _elapsed / EDGE
	if _elapsed > duration - EDGE:
		return maxf(0.0, (duration - _elapsed) / EDGE)
	return 1.0
