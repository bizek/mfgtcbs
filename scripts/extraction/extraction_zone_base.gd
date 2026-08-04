extends Node2D
class_name ExtractionZoneBase


## ExtractionZoneBase — Shared logic for all extraction zone types.
## Each subclass implements its own zone visuals, activation conditions,
## and channeling behavior. The base handles proximity detection and
## common zone-building helpers.

signal zone_entered
signal zone_exited
signal extraction_triggered(extraction_type: String)

const ZONE_SIZE: float = 96.0
const ZONE_HALF: float = 48.0
const PROXIMITY_RANGE: float = 40.0

## Every zone has a fill and a state label
var _fill: ColorRect = null
var _state_label: Label = null

## Whether this zone is currently active (can be used for extraction)
var active: bool = false

## The string type key for this extraction (e.g. "timed", "guarded", "locked", "sacrifice")
var extraction_type: String = ""

## ── Proximity check (called by main_arena each frame) ────────────────────────

func check_proximity(player_pos: Vector2) -> bool:
	return player_pos.distance_to(global_position) <= PROXIMITY_RANGE

## ── Common zone-building helpers ─────────────────────────────────────────────

func _build_border(parent: Node2D, border_color: Color, thickness: float = 3.0) -> void:
	var bw: float = ZONE_SIZE
	for side in 4:
		var b := ColorRect.new()
		b.color = border_color
		match side:
			0: b.size = Vector2(bw, thickness); b.position = Vector2(-bw * 0.5, -bw * 0.5)
			1: b.size = Vector2(bw, thickness); b.position = Vector2(-bw * 0.5,  bw * 0.5 - thickness)
			2: b.size = Vector2(thickness, bw); b.position = Vector2(-bw * 0.5, -bw * 0.5)
			3: b.size = Vector2(thickness, bw); b.position = Vector2( bw * 0.5 - thickness, -bw * 0.5)
		parent.add_child(b)

func _build_fill(parent: Node2D, fill_color: Color) -> ColorRect:
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = fill_color
	fill.size = Vector2(ZONE_SIZE, ZONE_SIZE)
	fill.position = Vector2(-ZONE_HALF, -ZONE_HALF)
	parent.add_child(fill)
	_fill = fill
	return fill

func _build_state_label(parent: Node2D, text: String, label_color: Color, x_offset: float = -52.0) -> Label:
	var lbl := Label.new()
	lbl.name = "StateLabel"
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(x_offset, -80.0)
	lbl.modulate = label_color
	lbl.add_theme_font_size_override("font_size", 16)
	_apply_pixel_font(lbl)
	parent.add_child(lbl)
	_state_label = lbl
	return lbl


## ── Pixel font ────────────────────────────────────────────────────────────────
## Every site in this file set a font_size but no FONT, so the text rendered in Godot's default
## vector font — antialiased at 640x360, then nearest-upscaled 3x into mush. It is the same bug
## game_over_screen.gd shipped with, and a font_size override on its own does nothing to fix it.
const PIXEL_FONT_PATH: String = "res://assets/fonts/m5x7.ttf"


func _apply_pixel_font(c: Control) -> void:
	if not ResourceLoader.exists(PIXEL_FONT_PATH):
		return
	c.add_theme_font_override("font", load(PIXEL_FONT_PATH))
