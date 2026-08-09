class_name UIIcons
extends RefCounted

## Named access to the Minifantasy UI pack's icon, tag and grid art.
##
## Exists so the rects live in ONE place. Every previous pack consumer (`hud.gd`,
## `input_glyphs.gd`, `game_cursor.gd`, `build_ui_theme.gd`) carries its own copy of the sheet
## path and its own rect literals, which is fine for one or two but does not scale to an icon set
## — a stat row wanting a heart should ask for `UIIcons.heart()`, not know that the heart is at
## (472, 40).
##
## Three of the pack's `_General_UI_Resources` sheets live here: `_Icons`, `_Labels_And_Tags` and
## `Grids`. Everything returns null when its sheet is missing — `assets/minifantasy/` is gitignored
## (licensed pack), so a fresh clone has to degrade to the plain-text/flat-box path rather than
## crash.
##
## ── Where the rects come from ─────────────────────────────────────────────────
## Component-labelled off the sheet's alpha, not eyeballed. The character set sits in the sheet's
## top-right on a 16px horizontal stride in two rows: y=24 starting x=384, and y=40 starting
## x=376 (the second row is offset by 8, which is why a single lattice origin does not describe
## both). Each icon is 8x8.
##
## These icons ship **pre-coloured** — the heart is red, the bolt yellow, the spark cyan — unlike
## the general set, which is greyscale in 8 tint bands. So they need no modulate, and tinting one
## would fight the art.

const ICON_SHEET: String = "res://assets/minifantasy/Minifantasy_UI _Overhaul_v1.0/_Minifantasy_UI_Overhaul_Assets/_General_UI_Resources/Icons/_Icons.png"
const TAG_SHEET: String = "res://assets/minifantasy/Minifantasy_UI _Overhaul_v1.0/_Minifantasy_UI_Overhaul_Assets/_General_UI_Resources/Labels_And_Tags/_Labels_And_Tags.png"

const ICON_SIZE: int = 8

## Character set, row 2 (y=40). The ones the game actually has a use for.
const CHAR_ROW_Y: int = 40
const HEART: int = 472
const SHIELD: int = 424
const SWORDS: int = 392
const HAMMER: int = 440
const BOLT: int = 504
const SPARK: int = 488
const MUSCLE: int = 520
const ARMOUR: int = 408

## Character set, row 1 (y=24).
const TOP_ROW_Y: int = 24
const CHEST: int = 496
const ANVIL: int = 512
const BACKPACK: int = 544
const BOOK: int = 416

## ── General set ───────────────────────────────────────────────────────────────
## A different shape from the character set: a 10-wide x 6-tall block on a 16px lattice starting
## at (16, 16), repeated across 8 tint blocks — 2 columns (x +168) x 4 rows (y +104).
##
## These are **mostly greyscale**, unlike the fully pre-coloured character icons, so they take a
## modulate usefully — `general_node()` has a tint argument for that. "Mostly" is doing real work
## in that sentence: several keep a small colour accent (the monitor's blue screen, the gamepad's
## coloured face buttons, the red/green medical crosses), and a heavy modulate will flatten it.
## Reaching for the sheet's darker tint blocks instead would work too, but modulating one source
## keeps a caller from having to know the tint grid as well as the icon grid.
const GEN_ORIGIN_X: int = 16
const GEN_ORIGIN_Y: int = 16

## (column, row) within that block, so callers never handle raw pixels.
const GEAR: Vector2i = Vector2i(0, 0)
const MONITOR: Vector2i = Vector2i(1, 0)
const SPEAKER: Vector2i = Vector2i(8, 0)
## (9,0) was named SPEAKER_MUTE on first pass. Rendering the block at 7x shows it is the speaker
## with the SECOND wave added, not a muted one — the set has no mute icon.
const SPEAKER_LOUD: Vector2i = Vector2i(9, 0)
const MUSIC_NOTE: Vector2i = Vector2i(6, 0)
const GAMEPAD: Vector2i = Vector2i(0, 1)
const KEYBOARD: Vector2i = Vector2i(2, 1)
const SAVE_DISK: Vector2i = Vector2i(3, 1)
const LOCK: Vector2i = Vector2i(6, 1)
const LOCK_OPEN: Vector2i = Vector2i(7, 1)
const PERSON: Vector2i = Vector2i(0, 2)
const CHART: Vector2i = Vector2i(3, 2)
const TROPHY: Vector2i = Vector2i(6, 2)
const QUESTION: Vector2i = Vector2i(8, 2)
const INFO: Vector2i = Vector2i(9, 2)
const ARROW_RIGHT: Vector2i = Vector2i(0, 3)
const CHECK: Vector2i = Vector2i(8, 3)
const CROSS: Vector2i = Vector2i(9, 3)


## An 8x8 icon from the general (greyscale) set, addressed by its cell.
static func general(cell: Vector2i) -> AtlasTexture:
	return _atlas(GEN_ORIGIN_X + cell.x * 16, GEN_ORIGIN_Y + cell.y * 16)

## Cache: an AtlasTexture per rect. Without this every stat row on every roster redraw allocates
## a fresh AtlasTexture over the same 8x8 region.
static var _cache: Dictionary = {}
static var _sheet: Texture2D = null


static func _atlas(x: int, y: int) -> AtlasTexture:
	var key: int = x * 10000 + y
	if _cache.has(key):
		return _cache[key]
	if _sheet == null:
		if not ResourceLoader.exists(ICON_SHEET):
			return null
		_sheet = load(ICON_SHEET)
	var a := AtlasTexture.new()
	a.atlas = _sheet
	a.region = Rect2(x, y, ICON_SIZE, ICON_SIZE)
	## Without filter_clip an AtlasTexture bleeds a pixel of the neighbouring icon, and on a sheet
	## packed at a 16px stride with 8px art that neighbour is only 8px away.
	a.filter_clip = true
	_cache[key] = a
	return a


## An 8x8 icon from the character set's second row (heart, shield, swords, bolt, ...).
static func stat(x: int) -> AtlasTexture:
	return _atlas(x, CHAR_ROW_Y)


## An 8x8 icon from the character set's first row (chest, anvil, backpack, ...).
static func item(x: int) -> AtlasTexture:
	return _atlas(x, TOP_ROW_Y)


## A ready-to-add TextureRect for an icon, sized and centred for a text row.
## Returns null when the sheet is missing, so callers can simply skip adding it.
static func node(x: int, y: int = CHAR_ROW_Y) -> TextureRect:
	return _wrap(_atlas(x, y), Color.WHITE)


## Same, for a general-set cell, optionally tinted (the general set is greyscale).
static func general_node(cell: Vector2i, tint: Color = Color.WHITE) -> TextureRect:
	return _wrap(general(cell), tint)


## ── Labels & tags ─────────────────────────────────────────────────────────────
## The sheet ships TWO designs over one shared 8-colour ramp, and both have a horizontal and a
## vertical variant. Component-labelled off the alpha, not eyeballed:
##
##   pill    48x12 horizontal from y=82   (vertical 12x48 at y=16)
##   ribbon  48x14 horizontal from y=305  (vertical 14x48 at y=240)
##
## Both horizontal sets run x=16 plain / x=176 white-outlined, 8 colours on a 16px vertical stride.
## Colours sampled from the fill, not read off a render — and the two designs use the SAME ramp in
## the same order, so one index addresses both:
##   orange #d6812d · gold #e7b14a · green #4e9f4c · blue #5064c2
##   purple #af50c2 · red #c25050 · tan #cf9b5d · cream #faddb4
enum Tag { ORANGE, GOLD, GREEN, BLUE, PURPLE, RED, TAN, CREAM }

const TAG_X: int = 16          ## plain; the white-outlined copies sit at x=176
const TAG_W: int = 48
const TAG_STRIDE: int = 16
const PILL_Y0: int = 82
const PILL_H: int = 12
const RIBBON_Y0: int = 305
const RIBBON_H: int = 14

## Four of the five game rarities land on a near-exact match, which is why this maps cleanly.
## `common` has no grey in the set and takes the cream, which reads as "plain" next to the others
## and is the right role for it.
const RARITY_TAG: Dictionary = {
	"common": Tag.CREAM, "uncommon": Tag.GREEN, "rare": Tag.BLUE,
	"epic": Tag.PURPLE, "legendary": Tag.GOLD,
}
## Ink colour for text sitting ON a tag. The fills are mid-to-light, so the label has to go
## dark — bone-on-gold is unreadable at 16px.
const TAG_INK: Color = Color(0.12, 0.09, 0.07)

static var _tag_sheet: Texture2D = null


static func _tags() -> Texture2D:
	if _tag_sheet == null and ResourceLoader.exists(TAG_SHEET):
		_tag_sheet = load(TAG_SHEET)
	return _tag_sheet


## A pill tag carrying a word, an 8x8 icon, or both. Returns null if the sheet is missing so a
## caller can fall back to plain bracket text.
##
## An icon is the answer when there is no room for a word and no glyph for the idea: m5x7 has NO
## star (`level_up_screen.gd` documents ★ silently falling back to a vector font), so "mastered"
## in a 58px slot becomes a trophy on a gold pill rather than a blurry ★.
static func pill(colour: int, text: String = "", icon: Texture2D = null) -> Control:
	var sheet := _tags()
	if sheet == null:
		return null

	var sb := StyleBoxTexture.new()
	sb.texture = sheet
	sb.region_rect = Rect2(TAG_X, PILL_Y0 + TAG_STRIDE * colour, TAG_W, PILL_H)
	## The cap is the rounded end; only the flat middle may stretch, or the pill goes oval.
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		sb.set_texture_margin(side, 6.0)
		sb.set_content_margin(side, 5.0)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		sb.set_texture_margin(side, 5.0)
		sb.set_content_margin(side, 0.0)

	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", sb)
	## Floor the height at the art's own 12px. An ICON pill would otherwise be 8 tall — its
	## content's height — and the two 5px rounded caps have nowhere to go in 8px, so they collide
	## into a bowtie with no flat middle. Measured on screen; a word pill is 23 and unaffected.
	pc.custom_minimum_size = Vector2(0.0, PILL_H)
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(row)

	if icon != null:
		var tr := _wrap(icon, TAG_INK)
		if tr != null:
			row.add_child(tr)
	if text != "":
		row.add_child(_tag_label(text))
	return pc


## A rarity pill with its name inside, ready to drop into a row.
static func rarity_tag(rarity: String, text: String = "") -> Control:
	if not RARITY_TAG.has(rarity):
		return null
	return pill(RARITY_TAG[rarity], (text if text != "" else rarity))


## The pack's other tag design — a banner with a notched top and a fringed bottom edge.
##
## Used at its AUTHORED 48x14 and never nine-patched: the fringe runs `######.......####.......`
## on an uneven period, so a stretched or tiled middle smears it into mush. A "NEW" badge is a
## fixed-size object anyway, which is exactly what this art is. Returns null if the sheet is
## missing.
static func ribbon(colour: int, text: String) -> Control:
	var sheet := _tags()
	if sheet == null:
		return null

	var root := Control.new()
	root.custom_minimum_size = Vector2(TAG_W, RIBBON_H)
	root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## The label's own minimum height is 16 at font 16; clipping keeps it from bleeding past a
	## 14px banner instead of growing it and stretching the art.
	root.clip_contents = true

	var art := AtlasTexture.new()
	art.atlas = sheet
	art.region = Rect2(TAG_X, RIBBON_Y0 + TAG_STRIDE * colour, TAG_W, RIBBON_H)
	art.filter_clip = true

	var tr := TextureRect.new()
	tr.texture = art
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr)

	var lbl := _tag_label(text)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	## The banner's bottom row is fringe and its top row is notched, so the word is centred on the
	## solid band between them rather than on the art's full height. -4 measured on screen: at -2
	## the baseline still sat on the fringe.
	lbl.offset_bottom = -4.0
	root.add_child(lbl)
	return root


static func _tag_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text.to_upper()
	lbl.add_theme_color_override("font_color", TAG_INK)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


## ── Grid frames ───────────────────────────────────────────────────────────────
## `Grids.png` is 1360x496 = 5 tint COLUMNS on a 272px stride x 5 line-style ROWS on a 96px
## stride, the blocks starting at y=16. Every block carries an IDENTICAL alpha layout — verified
## by comparing the 25 blocks pixel for pixel, not by eye — so one set of offsets addresses all of
## them and only the colour and the line pattern change.
##
## The five line styles, in sheet order: solid · short dash · dotted · long dash · woven double.
##
## The five tints are LINE colours, not fills, measured off the solid box edge:
##   0 #77431d brown · 1 #9a7357 tan · 2 #494949 grey · 3 #000000 black · 4 #ffffff white
## Only white is useful here. On a near-black descent panel the brown and black variants vanish,
## and white is the one that can carry an arbitrary accent colour through a modulate — which is
## presumably why the artist shipped it. Every helper below reads tint 4 and tints it.
const GRID_SHEET: String = "res://assets/minifantasy/Minifantasy_UI _Overhaul_v1.0/_Minifantasy_UI_Overhaul_Assets/_General_UI_Resources/Grids/Grids.png"

enum Line { SOLID, DASH, DOT, LONG_DASH, WOVEN }

const GRID_COL_STRIDE: int = 272
const GRID_ROW_STRIDE: int = 96
const GRID_BLOCK_Y0: int = 16
const GRID_TINT_WHITE: int = 4

## Offsets inside one block. The two rules are one full 16px period of the pattern, which is what
## makes tiling them exact at any length.
const GRID_BOX_LG: Rect2 = Rect2(26, 10, 28, 28)   ## plain frame, 1px line, rounded corners
const GRID_BOX_SM: Rect2 = Rect2(114, 34, 12, 12)  ## the same frame at cell size
const GRID_CROSS: Rect2  = Rect2(74, 42, 28, 28)   ## frame quartered by a centre cross
const GRID_RULE_H: Rect2 = Rect2(80, 23, 16, 1)
const GRID_RULE_V: Rect2 = Rect2(88, 0, 1, 16)
## Measured and recorded rather than wired: the codex list is one column, so it composes cells and
## rules instead. A real matrix view would want these whole.
const GRID_3X3: Rect2 = Rect2(138, 26, 44, 44)     ## 12px cells, 16px pitch, gaps between
const GRID_5X5: Rect2 = Rect2(196, 20, 56, 56)     ## 12px cells, 11px pitch, shared borders

static var _grid_sheet: Texture2D = null


static func _grids() -> Texture2D:
	if _grid_sheet == null and ResourceLoader.exists(GRID_SHEET):
		_grid_sheet = load(GRID_SHEET)
	return _grid_sheet


## Place a block-local rect into the sheet for a given line style and tint.
static func grid_region(local: Rect2, style: int = Line.SOLID,
		tint: int = GRID_TINT_WHITE) -> Rect2:
	return Rect2(
		local.position + Vector2(GRID_COL_STRIDE * tint, GRID_BLOCK_Y0 + GRID_ROW_STRIDE * style),
		local.size
	)


## A grid cell frame, ready for `add_theme_stylebox_override("panel", ...)`.
##
## TILED on both axes, never stretched. The sheet's own note is that the set is "16x16 sliced", and
## a codex row is ~178px of a 12px cell: interpolating that 8px middle band across it turns a
## dashed edge into a smear and even the solid one into an uneven line. Same finding as the
## armory's item slots. Returns null if the sheet is missing.
static func grid_box(colour: Color = Color.WHITE, small: bool = true,
		style: int = Line.SOLID) -> StyleBoxTexture:
	var sheet := _grids()
	if sheet == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = sheet
	sb.region_rect = grid_region(GRID_BOX_SM if small else GRID_BOX_LG, style)
	var m: float = 2.0 if small else 3.0
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, m)
		sb.set_content_margin(side, m)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.modulate_color = colour
	return sb


## A 1px rule, as a node you can anchor where a `ColorRect` divider used to sit.
##
## A NinePatchRect with every patch margin at 0, so the whole region IS the tiled middle: the rule
## repeats its authored 16px period at any length instead of one dash being stretched the width of
## the panel. Returns null if the sheet is missing.
static func grid_rule(horizontal: bool, colour: Color = Color.WHITE,
		style: int = Line.SOLID) -> NinePatchRect:
	var sheet := _grids()
	if sheet == null:
		return null
	var np := NinePatchRect.new()
	np.texture = sheet
	np.region_rect = grid_region(GRID_RULE_H if horizontal else GRID_RULE_V, style)
	np.patch_margin_left = 0
	np.patch_margin_top = 0
	np.patch_margin_right = 0
	np.patch_margin_bottom = 0
	np.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	np.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	np.modulate = colour
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return np


static func _wrap(tex: Texture2D, tint: Color) -> TextureRect:
	if tex == null:
		return null
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate = tint
	return tr
