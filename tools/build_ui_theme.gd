@tool
extends EditorScript

## Builds `assets/ui/grim_theme.tres` from the Minifantasy Grim UI sheet.
##
## Run it from the editor (File ▸ Run) or via godot-mcp `execute_editor_script`:
##     load("res://tools/build_ui_theme.gd").new()._run()
##
## Why a generator instead of a hand-written .tres: a Theme with this many
## sub-resources is thousands of lines of opaque `SubResource("...")` ids, and
## every source rect in it would be a magic number with no provenance. Here the
## rects are named constants next to the reasoning, and re-running regenerates
## the whole file, so a tweak to one margin is a one-line edit.
##
## It also keeps the theme reproducible where the art is not: `assets/minifantasy/`
## is gitignored (licensed pack, kept out of the repo — same as every other
## consumer, e.g. `hud.gd`'s UI_SHEET_PATH). The committed .tres embeds the
## sheet's local import UID, which a fresh clone would regenerate differently;
## Godot falls back to the `path=` in that case, and if anything does go wrong
## the fix is to run this script again rather than to repair a .tres by hand.
##
## ── Where the numbers come from ───────────────────────────────────────────────
## The pack ships `_Use_Guidelines/Use_Guideline_Layer.png`, a 1:1 overlay that
## draws a coloured box around each group. Compositing it over the sheet and
## component-labelling the alpha inside each box yields every sprite rect
## exactly; the nine-patch margins below were then measured by walking in from
## each edge until the rows stopped changing. Nothing here was eyeballed.
##
## The sheet's macro layout is 5 colour columns (stride 912) x 3 ornament rows.
## The ornament rows are a built-in hierarchy, not three copies of one look:
##   R0 plain plate + rivet edge   → dense lists, debug panels
##   R1 corner brackets            → standard panels        ← the default
##   R2 full filigree              → hero panels, modals
## Using all three is the whole point; a theme that picked one would throw away
## the hierarchy the artist built in.

const SHEET_PATH: String = "res://assets/minifantasy/Minifantasy_UI _Overhaul_v1.0/_Minifantasy_UI_Overhaul_Assets/Grim_Minifantasy_UI/_Grim_UI.png"
const FONT_PATH: String  = "res://assets/fonts/m5x7.ttf"
const OUT_PATH: String   = "res://assets/ui/grim_theme.tres"

## Distance between the sheet's five colour columns.
const COL_STRIDE: int = 912

## PANELS group, colour column 0. Margin rises with the ornament tier because
## the decoration itself is bigger — 5/9/13 measured, not assumed.
const PANEL_R0: Rect2 = Rect2(112, 160, 48, 48)
const PANEL_R1: Rect2 = Rect2(112, 704, 48, 48)
const PANEL_R2: Rect2 = Rect2(108, 1244, 56, 56)
const PANEL_M0: int = 5
const PANEL_M1: int = 9
const PANEL_M2: int = 13

## PUSH BUTTONS group. Frame is 128x128 and each colour column carries four
## tints, so a button's four states come out of the art rather than out of a
## modulate hack. The square 48x48 cell is used for every button: the wide 48x16
## cell leaves only a 2px vertical stretch band, which smears badly on anything
## taller than about 20px.
const BTN_Y: int = 1088          ## ornament row R1 — the outlined variant
const BTN_X0: int = 80
const BTN_SIZE: int = 48
const TINT_STRIDE: int = 128
const BTN_MARGIN: int = 6

## Which tint reads as which state. Tint 0 is the darkest fill, 1 the lightest,
## 2 dark with a bright bone outline, 3 mid with a bright outline.
const TINT_NORMAL: int = 0
const TINT_HOVER: int = 1
const TINT_PRESSED: int = 2
const TINT_FOCUS: int = 3

## The five palettes, in sheet order. These become Button type variations, so a
## destructive action can be styled with `btn.theme_type_variation = "DangerButton"`
## instead of another hand-rolled StyleBoxFlat.
const PALETTES: Dictionary = {
	"Button": 0,          ## brown — the default
	"ConfirmButton": 1,   ## green
	"InfoButton": 2,      ## blue
	"DangerButton": 3,    ## red
	"NeutralButton": 4,   ## white/grey
}

## CHECK BOXES group, ornament row R1, bright tint. Squares are the checkbox,
## circles the radio.
const CHK_OFF: Rect2 = Rect2(258, 850, 12, 12)
const CHK_ON: Rect2  = Rect2(354, 850, 12, 12)
const RAD_OFF: Rect2 = Rect2(258, 818, 12, 12)
const RAD_ON: Rect2  = Rect2(354, 818, 12, 12)

## SLIDERS and DIVIDERS groups, R1.
const SLIDER_TRACK: Rect2 = Rect2(339, 740, 42, 7)
const SLIDER_GRAB: Rect2  = Rect2(325, 740, 6, 7)
const DIVIDER: Rect2      = Rect2(323, 678, 42, 3)

## SLOTS group — the 22x22 item slot, margin 2. Two ornament tiers: R0 is the plainer frame,
## R1 adds brighter corners, which makes them a natural idle/hover pair for a clickable slot.
const SLOT_R0: Rect2 = Rect2(109, 237, 22, 22)
const SLOT: Rect2 = Rect2(109, 285, 22, 22)

## TABS group, colour column 0, the brighter (right-hand) sub-group. Tabs come in two heights and
## that IS the selected/unselected metaphor — the active tab is taller and stands proud of the
## row. Using one short and one tall rect gets that for free instead of faking it with colour.
const TAB_SHORT: Rect2 = Rect2(544, 213, 48, 15)   ## unselected
const TAB_TALL: Rect2 = Rect2(544, 333, 48, 23)    ## selected
const TAB_MARGIN: int = 6

## ── Selectors (_General_UI_Resources/Selectors/_Selectors.png) ────────────────
## A separate sheet from Grim, 4 designs x 4 tints. Corner brackets are the focus visual:
## they mark the control without boxing it, so a focused button does not gain a second border on
## top of the one its own stylebox already draws.
## Bounding boxes measured, not assumed — the designs are NOT on an even stride
## (solid y47, brackets y95, dotted y143), which is why eyeballing a stride produced misaligned
## crops on the first try.
const SELECTOR_SHEET: String = "res://assets/minifantasy/Minifantasy_UI _Overhaul_v1.0/_Minifantasy_UI_Overhaul_Assets/_General_UI_Resources/Selectors/_Selectors.png"
const SELECTOR_BRACKETS: Rect2 = Rect2(255, 95, 18, 18)  ## white tint; +48 per tint
const SELECTOR_MARGIN: int = 5

## ── Palette ───────────────────────────────────────────────────────────────────
## Taken from what the UI code already uses, not invented: these are the most
## frequent Color() literals across scripts/ui. Matching them means the theme
## agrees with the ~53 scripts that still style themselves, so the two layers
## read as one design instead of fighting.
const BONE: Color      = Color(0.800, 0.690, 0.565)  ## primary text
const BONE_DIM: Color  = Color(0.541, 0.408, 0.282)  ## secondary text
const AMBER: Color     = Color(0.831, 0.447, 0.102)  ## accent / focus
const BROWN: Color     = Color(0.314, 0.235, 0.157)
const DARK: Color      = Color(0.165, 0.145, 0.125)
const INK: Color       = Color(0.082, 0.075, 0.063)
const DISABLED: Color  = Color(0.45, 0.40, 0.35)

## Per CLAUDE.md: m5x7 is 16px-native and only 16/32/48 are crisp. 16 is the
## body size for the entire game, so it is the theme default. Every Control
## built in code now inherits it — which is the point. Six player-facing scripts
## had shipped sizing text without ever setting a font, rendering in Godot's
## default vector font; a project-wide default font makes that class of bug
## impossible rather than something to remember.
const FONT_SIZE: int = 16

var _sheet: Texture2D = null


func _run() -> void:
	_sheet = load(SHEET_PATH)
	if _sheet == null:
		push_error("build_ui_theme: could not load the Grim sheet at %s" % SHEET_PATH)
		return

	var theme := Theme.new()
	var font: FontFile = load(FONT_PATH)
	if font == null:
		push_error("build_ui_theme: could not load %s" % FONT_PATH)
		return
	theme.default_font = font
	theme.default_font_size = FONT_SIZE

	_build_panels(theme)
	_build_buttons(theme)
	_build_labels(theme)
	_build_checkboxes(theme)
	_build_sliders_and_bars(theme)
	_build_separators(theme)
	_build_text_inputs(theme)
	_build_scrollbars(theme)
	_build_tabs(theme)
	_build_focus(theme)

	DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())
	var err := ResourceSaver.save(theme, OUT_PATH)
	if err != OK:
		push_error("build_ui_theme: save failed (%d)" % err)
		return
	print("build_ui_theme: wrote %s" % OUT_PATH)
	print("  types: %s" % ", ".join(theme.get_type_list()))


# ── Builders ──────────────────────────────────────────────────────────────────

func _nine(region: Rect2, margin: int, content: int = -1) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _sheet
	sb.region_rect = region
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, float(margin))
		sb.set_content_margin(side, float(margin if content < 0 else content))
	## TILE the edge and centre bands, never STRETCH them (the default). The Grim frames carry
	## a dashed rivet border, and stretching that band across a wide button or panel scales the
	## dashes by a fractional factor — an uneven "- -- -" edge on every button in the game
	## (visible on the training panel, 2026-08-17). The pack's own note: "16x16px sliced to
	## facilitate the creation of panels of any size" — i.e. repeat at authored scale.
	## `_slot_box` had already done this for the item slots for the same reason.
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return sb


## A slot frame sized for a WIDE row rather than a square cell.
##
## The slot art is authored as a 22x22 item cell. Stretching that across a ~190px mod row smears
## its edge detail into an uneven dashed line — the same mistake as picking a breastplate for the
## Paladin portrait: the art has an intended shape and the wide row is not it. The pack's own note
## says it is "16x16px sliced to facilitate the creation of panels of any size", i.e. TILE the
## middle, do not stretch it, so the edge repeats at its authored scale instead of being
## interpolated across nine times its width.
func _slot_box(region: Rect2) -> StyleBoxTexture:
	var sb := _nine(region, 2)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.set_content_margin(SIDE_LEFT, 5.0)
	sb.set_content_margin(SIDE_RIGHT, 3.0)
	sb.set_content_margin(SIDE_TOP, 2.0)
	sb.set_content_margin(SIDE_BOTTOM, 2.0)
	return sb


func _atlas(region: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = _sheet
	a.region = region
	## Without filter_clip an AtlasTexture bleeds one pixel of whatever sits
	## next to it on the sheet — on a densely packed sheet like this one that is
	## a visible seam on every checkbox.
	a.filter_clip = true
	return a


func _build_panels(theme: Theme) -> void:
	## Content margin is deliberately larger than the texture margin: the frame
	## art wants breathing room inside it, and every hub panel currently adds
	## that padding by hand.
	theme.set_stylebox("panel", "Panel", _nine(PANEL_R1, PANEL_M1, PANEL_M1 + 2))
	theme.set_stylebox("panel", "PanelContainer", _nine(PANEL_R1, PANEL_M1, PANEL_M1 + 2))
	theme.set_stylebox("panel", "PopupPanel", _nine(PANEL_R2, PANEL_M2, PANEL_M2 + 2))

	## R0 for dense content — lists, grids, rows. Less frame, more room.
	theme.set_type_variation("PanelDense", "PanelContainer")
	theme.set_stylebox("panel", "PanelDense", _nine(PANEL_R0, PANEL_M0, PANEL_M0 + 2))

	## R2 for the screens that should feel like an event: results, level-up.
	theme.set_type_variation("PanelHero", "PanelContainer")
	theme.set_stylebox("panel", "PanelHero", _nine(PANEL_R2, PANEL_M2, PANEL_M2 + 2))

	## The 22x22 item slot, for the armory and codex grids.
	theme.set_type_variation("SlotPanel", "PanelContainer")
	theme.set_stylebox("panel", "SlotPanel", _nine(SLOT, 2, 3))

	## Clickable slot — the armory's mod and weapon slots are Buttons, not panels, so they need
	## the full state set rather than one `panel` entry. The two ornament tiers ARE the states:
	## R0 (plainer) sits idle, R1 (brighter corners) lights up under the cursor.
	##
	## Left deliberately un-tinted here. hub_armory_panel duplicates these and applies the mod's
	## rarity colour as a modulate, because the colour is the panel's semantics, not the theme's —
	## same split as hub_panel_base's accent tinting.
	theme.set_type_variation("SlotButton", "Button")
	var slot_idle := _slot_box(SLOT_R0)
	var slot_hot := _slot_box(SLOT)
	theme.set_stylebox("normal", "SlotButton", slot_idle)
	theme.set_stylebox("disabled", "SlotButton", slot_idle)
	theme.set_stylebox("hover", "SlotButton", slot_hot)
	theme.set_stylebox("pressed", "SlotButton", slot_hot)


func _build_buttons(theme: Theme) -> void:
	for variation: String in PALETTES.keys():
		var col: int = PALETTES[variation]
		if variation != "Button":
			theme.set_type_variation(variation, "Button")

		var x: int = BTN_X0 + COL_STRIDE * col
		theme.set_stylebox("normal", variation, _btn(x, TINT_NORMAL))
		theme.set_stylebox("hover", variation, _btn(x, TINT_HOVER))
		theme.set_stylebox("pressed", variation, _btn(x, TINT_PRESSED))
		theme.set_stylebox("focus", variation, _btn(x, TINT_FOCUS))

		## Disabled reuses the normal frame dimmed, because the sheet's fourth
		## tint is spoken for by focus and a greyed frame reads more clearly as
		## "unavailable" than a differently-coloured one does.
		var dis := _btn(x, TINT_NORMAL)
		dis.modulate_color = Color(0.55, 0.55, 0.55, 0.75)
		theme.set_stylebox("disabled", variation, dis)

		theme.set_color("font_color", variation, BONE)
		theme.set_color("font_hover_color", variation, Color(0.95, 0.88, 0.76))
		theme.set_color("font_pressed_color", variation, AMBER)
		theme.set_color("font_focus_color", variation, Color(0.95, 0.88, 0.76))
		theme.set_color("font_disabled_color", variation, DISABLED)
		theme.set_color("font_outline_color", variation, Color(0, 0, 0, 0.85))
		theme.set_constant("outline_size", variation, 0)
		theme.set_font_size("font_size", variation, FONT_SIZE)


func _btn(x: int, tint: int) -> StyleBoxTexture:
	var r := Rect2(x + TINT_STRIDE * tint, BTN_Y, BTN_SIZE, BTN_SIZE)
	## Horizontal content margin is wider than vertical so label text does not
	## touch the frame on a short, wide button — the common shape in this game.
	var sb := _nine(r, BTN_MARGIN)
	sb.set_content_margin(SIDE_LEFT, 8.0)
	sb.set_content_margin(SIDE_RIGHT, 8.0)
	sb.set_content_margin(SIDE_TOP, 3.0)
	sb.set_content_margin(SIDE_BOTTOM, 3.0)
	return sb


func _build_labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", BONE)
	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	theme.set_constant("outline_size", "Label", 0)
	theme.set_font_size("font_size", "Label", FONT_SIZE)

	## Dim and accent label variants, so the "secondary text" and "this is the
	## number that matters" cases stop being a per-script Color literal.
	theme.set_type_variation("LabelDim", "Label")
	theme.set_color("font_color", "LabelDim", BONE_DIM)
	theme.set_type_variation("LabelAccent", "Label")
	theme.set_color("font_color", "LabelAccent", AMBER)

	## Screen titles. The only other crisp size m5x7 has.
	theme.set_type_variation("LabelTitle", "Label")
	theme.set_font_size("font_size", "LabelTitle", 32)
	theme.set_color("font_color", "LabelTitle", BONE)

	theme.set_color("default_color", "RichTextLabel", BONE)
	theme.set_font_size("normal_font_size", "RichTextLabel", FONT_SIZE)
	theme.set_font_size("bold_font_size", "RichTextLabel", FONT_SIZE)
	theme.set_font_size("italics_font_size", "RichTextLabel", FONT_SIZE)
	theme.set_font_size("mono_font_size", "RichTextLabel", FONT_SIZE)
	theme.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())


func _build_checkboxes(theme: Theme) -> void:
	for t in ["CheckBox", "CheckButton"]:
		theme.set_icon("unchecked", t, _atlas(CHK_OFF))
		theme.set_icon("checked", t, _atlas(CHK_ON))
		theme.set_icon("radio_unchecked", t, _atlas(RAD_OFF))
		theme.set_icon("radio_checked", t, _atlas(RAD_ON))
		theme.set_color("font_color", t, BONE)
		theme.set_color("font_hover_color", t, Color(0.95, 0.88, 0.76))
		theme.set_color("font_disabled_color", t, DISABLED)
		theme.set_font_size("font_size", t, FONT_SIZE)
		## A checkbox is a label with a glyph, not a raised button — the button
		## frame around it is Godot's default and looks wrong here.
		for state in ["normal", "hover", "pressed", "disabled"]:
			theme.set_stylebox(state, t, StyleBoxEmpty.new())
		theme.set_stylebox("focus", t, _focus_ring())


func _focus_ring() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(1)
	sb.border_color = AMBER
	sb.set_content_margin_all(2.0)
	return sb


func _build_sliders_and_bars(theme: Theme) -> void:
	var track := _nine(SLIDER_TRACK, 6, 0)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_icon("grabber", "HSlider", _atlas(SLIDER_GRAB))
	theme.set_icon("grabber_highlight", "HSlider", _atlas(SLIDER_GRAB))

	var vtrack := _nine(SLIDER_TRACK, 6, 0)
	vtrack.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	theme.set_stylebox("slider", "VSlider", vtrack)
	theme.set_icon("grabber", "VSlider", _atlas(SLIDER_GRAB))

	## The pack's resource bars are already used directly by hud.gd against the
	## Classic sheet, so ProgressBar just needs to stop looking like Godot's
	## default grey. Flat, in-palette, no art.
	var bg := StyleBoxFlat.new()
	bg.bg_color = INK
	bg.set_border_width_all(1)
	bg.border_color = BROWN
	theme.set_stylebox("background", "ProgressBar", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = AMBER
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_color("font_color", "ProgressBar", BONE)
	theme.set_font_size("font_size", "ProgressBar", FONT_SIZE)


func _build_separators(theme: Theme) -> void:
	## The divider art has arrow tips at both ends, so the HORIZONTAL margin has to
	## cover them or a stretched separator smears the tip across the whole rule.
	##
	## The vertical margin must be ZERO, and getting that wrong made every HSeparator
	## in the game invisible from 2026-08-07 until 2026-08-09. DIVIDER is 42x3 — a 3px
	## tall strip. `_nine(DIVIDER, 6, 0)` set all four texture margins to 6, so top +
	## bottom claimed 12px of a 3px source and the nine-patch's centre row came out
	## with negative height: the control laid out at its full width and drew nothing.
	## Nothing errored, which is why five scripts (pause menu, level-up, insurance,
	## debug panel, passive-tree debug) shipped separators that were never once seen.
	## There is no detail to protect vertically on a 3px strip, so top/bottom stay 0
	## and the middle row stretches — which is exactly what a rule wants.
	var h := StyleBoxTexture.new()
	h.texture = _sheet
	h.region_rect = DIVIDER
	h.set_texture_margin(SIDE_LEFT, 6.0)
	h.set_texture_margin(SIDE_RIGHT, 6.0)
	h.set_texture_margin(SIDE_TOP, 0.0)
	h.set_texture_margin(SIDE_BOTTOM, 0.0)
	h.set_content_margin(SIDE_LEFT, 0.0)
	h.set_content_margin(SIDE_RIGHT, 0.0)
	## The CONTENT margins are what make it visible at all, which is not obvious.
	## Godot's Separator draws its stylebox into a rect whose height is
	## `style.get_minimum_size().y` — i.e. content_margin_top + content_margin_bottom —
	## and centres that in the control. With both at 0 the draw height is 0, so the
	## separator lays out at full width and paints nothing. Their SUM is the rule's
	## thickness; 3 matches the source strip so the art is drawn 1:1 vertically.
	h.set_content_margin(SIDE_TOP, 3.0)
	h.set_content_margin(SIDE_BOTTOM, 0.0)
	theme.set_stylebox("separator", "HSeparator", h)
	theme.set_constant("separation", "HSeparator", 4)

	var v := StyleBoxFlat.new()
	v.bg_color = BROWN
	v.content_margin_left = 1.0
	theme.set_stylebox("separator", "VSeparator", v)
	theme.set_constant("separation", "VSeparator", 4)


func _build_text_inputs(theme: Theme) -> void:
	## LineEdit / OptionButton / SpinBox borrow the dense panel plate so a field
	## reads as recessed rather than raised — the opposite of a button.
	for t in ["LineEdit", "SpinBox"]:
		theme.set_stylebox("normal", t, _nine(PANEL_R0, PANEL_M0, PANEL_M0 + 1))
		theme.set_stylebox("focus", t, _focus_ring())
		theme.set_color("font_color", t, BONE)
		theme.set_color("font_placeholder_color", t, BONE_DIM)
		theme.set_color("caret_color", t, AMBER)
		theme.set_font_size("font_size", t, FONT_SIZE)

	var x: int = BTN_X0
	theme.set_stylebox("normal", "OptionButton", _btn(x, TINT_NORMAL))
	theme.set_stylebox("hover", "OptionButton", _btn(x, TINT_HOVER))
	theme.set_stylebox("pressed", "OptionButton", _btn(x, TINT_PRESSED))
	theme.set_stylebox("focus", "OptionButton", _btn(x, TINT_FOCUS))
	theme.set_color("font_color", "OptionButton", BONE)
	theme.set_font_size("font_size", "OptionButton", FONT_SIZE)

	## The dropdown itself, or it opens as a bright grey Godot popup over a
	## dark game — the single most jarring unthemed surface in the settings panel.
	theme.set_stylebox("panel", "PopupMenu", _nine(PANEL_R1, PANEL_M1, PANEL_M1))
	theme.set_stylebox("hover", "PopupMenu", _flat(BROWN))
	theme.set_color("font_color", "PopupMenu", BONE)
	theme.set_color("font_hover_color", "PopupMenu", Color(0.95, 0.88, 0.76))
	theme.set_font_size("font_size", "PopupMenu", FONT_SIZE)
	theme.set_icon("checked", "PopupMenu", _atlas(CHK_ON))
	theme.set_icon("unchecked", "PopupMenu", _atlas(CHK_OFF))
	theme.set_icon("radio_checked", "PopupMenu", _atlas(RAD_ON))
	theme.set_icon("radio_unchecked", "PopupMenu", _atlas(RAD_OFF))


func _flat(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	return sb


func _build_scrollbars(theme: Theme) -> void:
	## The pack has no scrollbar art, so these are in-palette flats. They exist
	## because results screens and hub panels scroll, and Godot's default light
	## grey bar is the loudest thing on an otherwise dark screen.
	for t in ["VScrollBar", "HScrollBar"]:
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.35)
		bg.set_corner_radius_all(2)
		bg.anti_aliasing = false   ## rounded StyleBoxFlats default to AA, which feathers a sub-pixel fringe on every edge — off-grid in a 640x360 pixel UI
		theme.set_stylebox("scroll", t, bg)

		var grab := StyleBoxFlat.new()
		grab.bg_color = BROWN
		grab.set_corner_radius_all(2)
		grab.anti_aliasing = false   ## rounded StyleBoxFlats default to AA, which feathers a sub-pixel fringe on every edge — off-grid in a 640x360 pixel UI
		theme.set_stylebox("grabber", t, grab)

		var grab_hi := StyleBoxFlat.new()
		grab_hi.bg_color = BONE_DIM
		grab_hi.set_corner_radius_all(2)
		grab_hi.anti_aliasing = false   ## rounded StyleBoxFlats default to AA, which feathers a sub-pixel fringe on every edge — off-grid in a 640x360 pixel UI
		theme.set_stylebox("grabber_highlight", t, grab_hi)
		theme.set_stylebox("grabber_pressed", t, grab_hi)

	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())


func _build_tabs(theme: Theme) -> void:
	## The settings panel already uses a real TabContainer (AUDIO / DISPLAY / CONTROLS /
	## ACCESSIBILITY), so this is a pure theme change with no per-screen wiring.
	var unselected := _nine(TAB_SHORT, TAB_MARGIN)
	unselected.modulate_color = Color(0.72, 0.72, 0.72)  ## sits back from the active tab
	var selected := _nine(TAB_TALL, TAB_MARGIN)
	var hovered := _nine(TAB_SHORT, TAB_MARGIN)
	hovered.modulate_color = Color(0.9, 0.9, 0.9)

	for t in ["TabContainer", "TabBar"]:
		theme.set_stylebox("tab_selected", t, selected)
		theme.set_stylebox("tab_unselected", t, unselected)
		theme.set_stylebox("tab_hovered", t, hovered)
		theme.set_stylebox("tab_disabled", t, unselected)
		theme.set_color("font_selected_color", t, BONE)
		theme.set_color("font_unselected_color", t, BONE_DIM)
		theme.set_color("font_hovered_color", t, Color(0.95, 0.88, 0.76))
		theme.set_font_size("font_size", t, FONT_SIZE)

	## The body below the tab row is the standard panel plate, so the two read as one object.
	theme.set_stylebox("panel", "TabContainer", _nine(PANEL_R1, PANEL_M1, PANEL_M1 + 2))


func _build_focus(theme: Theme) -> void:
	## Corner-bracket selector, drawn OUTSIDE the control.
	##
	## draw_center is false so it never paints over the button's own plate, and the expand margins
	## push it clear of the edge — a focus ring that sits exactly on the border is invisible
	## against a frame that already has one, which is the failure mode of the flat 2px ring this
	## replaces (ui_nav_utils.apply_focus_ring).
	var sheet: Texture2D = load(SELECTOR_SHEET)
	if sheet == null:
		push_warning("build_ui_theme: selector sheet missing, focus ring left flat")
		return
	var sb := StyleBoxTexture.new()
	sb.texture = sheet
	sb.region_rect = SELECTOR_BRACKETS
	sb.draw_center = false
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, float(SELECTOR_MARGIN))
		sb.set_expand_margin(side, 2.0)
	sb.modulate_color = AMBER
	theme.set_stylebox("focus", "Button", sb)
	for variation: String in PALETTES.keys():
		if variation != "Button":
			theme.set_stylebox("focus", variation, sb)
	theme.set_stylebox("focus", "CheckBox", sb)
	theme.set_stylebox("focus", "OptionButton", sb)
