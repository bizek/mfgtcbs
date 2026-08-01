class_name GlyphBar
extends RichTextLabel

## Small bottom hint bar ("Ⓐ Confirm   Ⓑ Back") that live-updates whenever
## InputGlyphs detects a device switch. Build with GlyphBar.build(pairs),
## e.g. GlyphBar.build([["confirm", "Select"], ["back", "Close"]]).
##
## RichTextLabel rather than Label so the prompts can be the pack's actual
## button sprites — InputGlyphs.hint_bb() emits inline [img] regions, and falls
## back to the old text glyph for any input the sheets have no art for.

var _pairs: Array = []


static func build(pairs: Array) -> GlyphBar:
	var bar := GlyphBar.new()
	bar._pairs = pairs
	return bar


## A plain RichTextLabel set up to render InputGlyphs BBCode — for the prompts
## that aren't hint bars (world interact prompts, tutorial cues). Callers own
## the text; this just gets the single-line/no-scroll/pixel-font setup right,
## which is fiddly enough to be worth having in one place.
##
## Note the theme override names: RichTextLabel wants "normal_font" /
## "normal_font_size" / "default_color" where Label wants "font" / "font_size" /
## "font_color". Using the Label names here silently does nothing.
## Centre text by wrapping it in [center] — RichTextLabel aligns through BBCode,
## it has no horizontal_alignment property.
static func rich_prompt(size: int, color: Color) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_OFF
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.add_theme_font_size_override("normal_font_size", size)
	rt.add_theme_color_override("default_color", color)
	if ResourceLoader.exists("res://assets/fonts/m5x7.ttf"):
		rt.add_theme_font_override("normal_font", load("res://assets/fonts/m5x7.ttf"))
	return rt


func _ready() -> void:
	var font: FontFile = load("res://assets/fonts/m5x7.ttf")
	if font:
		add_theme_font_override("normal_font", font)
	add_theme_font_size_override("normal_font_size", 14)
	add_theme_color_override("default_color", Color(0.60, 0.60, 0.66))
	bbcode_enabled = true
	## A hint bar is one line that sizes to its content — without these it
	## inherits RichTextLabel's scrolling multi-line box and collapses to 0px
	## high inside the containers that hold it.
	fit_content = true
	scroll_active = false
	autowrap_mode = TextServer.AUTOWRAP_OFF
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()
	InputGlyphs.device_changed.connect(func(_v: bool): _refresh())


func set_pairs(pairs: Array) -> void:
	_pairs = pairs
	_refresh()


func _refresh() -> void:
	## [center] rather than horizontal_alignment — RichTextLabel aligns through
	## BBCode, and the old Label property does not exist on it.
	text = "[center]%s[/center]" % InputGlyphs.hint_bb(_pairs)
