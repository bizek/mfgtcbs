@tool
class_name HubPanelBase
extends Panel

## Shared base for all hub overlay panels.
## Provides panel chrome (background, title bar, close button) and helper utilities
## for building dynamic content. Each concrete panel instances this scene as a child,
## accesses ContentContainer to add rows, and forwards the close_requested signal.

const PIXEL_FONT  := preload("res://assets/fonts/m5x7.ttf")
const FONT_TITLE  := 21
const FONT_BODY   := 19
const FONT_DIM    := 16
const ROW_GAP     := 23
const LABEL_W     := 363
const LABEL_H     := 27
const PANEL_W     := 400
const PANEL_H     := 267
const TITLE_H     := 29
const CONTENT_H   := 238   ## PANEL_H - TITLE_H

## Set these exports in each panel's scene file (Inspector) for per-panel identity.
@export var title_text: String  = "PANEL"
@export var accent_color: Color = Color(0.4, 0.4, 0.9)

## Emitted when the × button is pressed. Parent panel scripts forward this to hub.gd.
signal close_requested

func _ready() -> void:
	## Apply accent color to title bar and panel border (duplicating the resource
	## so each instance gets its own copy, not a shared one).
	$TitleBar.color = Color(
		accent_color.r * 0.25,
		accent_color.g * 0.25,
		accent_color.b * 0.25
	)
	$TitleBar/TitleLabel.text = title_text
	$TitleBar/TitleLabel.add_theme_color_override("font_color", accent_color)
	$TitleBar/TitleLabel.add_theme_font_size_override("font_size", FONT_TITLE)
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = accent_color
	add_theme_stylebox_override("panel", style)
	$TitleBar/CloseButton.pressed.connect(func(): close_requested.emit())

	## Amber accent rule — 2px strip at the bottom edge of the title bar.
	var accent_rule := ColorRect.new()
	accent_rule.anchor_left   = 0.0
	accent_rule.anchor_right  = 1.0
	accent_rule.anchor_top    = 1.0
	accent_rule.anchor_bottom = 1.0
	accent_rule.offset_top    = -2.0
	accent_rule.offset_bottom = 0.0
	accent_rule.color         = Color(accent_color.r, accent_color.g, accent_color.b, 0.5)
	accent_rule.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	$TitleBar.add_child(accent_rule)

	## Soften close button hover from harsh red to dark red.
	var close_hover_sb := StyleBoxFlat.new()
	close_hover_sb.bg_color = Color(0.55, 0.18, 0.12, 0.80)
	close_hover_sb.set_border_width_all(0)
	$TitleBar/CloseButton.add_theme_stylebox_override("hover",   close_hover_sb)
	$TitleBar/CloseButton.add_theme_stylebox_override("pressed", close_hover_sb)

	## Left-edge accent strip — 2px glow on the content area's left side.
	var left_strip := ColorRect.new()
	left_strip.anchor_left   = 0.0
	left_strip.anchor_right  = 0.0
	left_strip.anchor_top    = 0.0
	left_strip.anchor_bottom = 1.0
	left_strip.offset_right  = 2.0
	left_strip.color         = Color(accent_color.r, accent_color.g, accent_color.b, 0.18)
	left_strip.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	$ContentContainer.add_child(left_strip)

## Returns the Content area Control where panels add their dynamic rows.
func get_content() -> Control:
	return $ContentContainer

# ── Shared UI helpers ─────────────────────────────────────────────────────────

## Strips Godot's default button chrome and applies a clean flat style.
## normal_col / hover_col are the bg fills; left_pad is x content margin.
func style_btn(btn: Button, normal_col: Color, hover_col: Color,
		left_pad: int = 4) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = hover_col if state in ["hover", "pressed"] else normal_col
		sb.set_border_width_all(0)
		sb.set_content_margin(SIDE_LEFT,   left_pad)
		sb.set_content_margin(SIDE_RIGHT,  left_pad)
		sb.set_content_margin(SIDE_TOP,    0)
		sb.set_content_margin(SIDE_BOTTOM, 0)
		btn.add_theme_stylebox_override(state, sb)

## Adds a text label at (12, y) in parent's local space. y is relative to the
## top of ContentContainer (i.e., subtract TITLE_H from old panel-root y values).
func add_row(parent: Control, text: String, y: float,
		color: Color = Color(0.82, 0.82, 0.87), font_size: int = FONT_BODY) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", PIXEL_FONT)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = Vector2(12, y)
	lbl.size = Vector2(LABEL_W, LABEL_H)
	parent.add_child(lbl)
