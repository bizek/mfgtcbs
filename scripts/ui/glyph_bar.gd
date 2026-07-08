class_name GlyphBar
extends Label

## Small bottom hint bar ("Ⓐ Confirm   Ⓑ Back") that live-updates whenever
## InputGlyphs detects a device switch. Build with GlyphBar.build(pairs),
## e.g. GlyphBar.build([["confirm", "Select"], ["back", "Close"]]).

var _pairs: Array = []


static func build(pairs: Array) -> GlyphBar:
	var bar := GlyphBar.new()
	bar._pairs = pairs
	return bar


func _ready() -> void:
	var font: FontFile = load("res://assets/fonts/m5x7.ttf")
	if font:
		add_theme_font_override("font", font)
	add_theme_font_size_override("font_size", 14)
	add_theme_color_override("font_color", Color(0.60, 0.60, 0.66))
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()
	InputGlyphs.device_changed.connect(func(_v: bool): _refresh())


func set_pairs(pairs: Array) -> void:
	_pairs = pairs
	_refresh()


func _refresh() -> void:
	text = InputGlyphs.hint(_pairs)
