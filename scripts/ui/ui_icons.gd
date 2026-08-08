class_name UIIcons
extends RefCounted

## Named access to the Minifantasy UI pack's icon and tag art.
##
## Exists so the rects live in ONE place. Every previous pack consumer (`hud.gd`,
## `input_glyphs.gd`, `game_cursor.gd`, `build_ui_theme.gd`) carries its own copy of the sheet
## path and its own rect literals, which is fine for one or two but does not scale to an icon set
## — a stat row wanting a heart should ask for `UIIcons.heart()`, not know that the heart is at
## (472, 40).
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
const SPEAKER_MUTE: Vector2i = Vector2i(9, 0)
const MUSIC_NOTE: Vector2i = Vector2i(6, 0)
const GAMEPAD: Vector2i = Vector2i(0, 1)
const KEYBOARD: Vector2i = Vector2i(2, 1)
const SAVE_DISK: Vector2i = Vector2i(3, 1)
const PERSON: Vector2i = Vector2i(0, 2)
const CHART: Vector2i = Vector2i(3, 2)
const TROPHY: Vector2i = Vector2i(6, 2)
const INFO: Vector2i = Vector2i(9, 2)
const ARROW_RIGHT: Vector2i = Vector2i(0, 3)


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


## ── Rarity tags ───────────────────────────────────────────────────────────────
## Labels_And_Tags horizontal pill, 48x12, x=16 plain / x=176 white-outlined, on a 16px vertical
## stride from y=82. Eight colours, sampled rather than read off a render:
##   82 orange #d6812d · 98 gold #e7b14a · 114 green #4e9f4c · 130 blue #5064c2
##   146 purple #af50c2 · 162 red #c25050 · 178 tan #cf9b5d · 194 cream #faddb4
##
## Four of the five game rarities land on a near-exact match, which is why this maps cleanly:
## uncommon→green, rare→blue, epic→purple, legendary→gold. `common` has no grey in the set and
## takes the cream, which reads as "plain" next to the others and is the right role for it.
const TAG_PILL_X: int = 16
const TAG_PILL_W: int = 48
const TAG_PILL_H: int = 12
const RARITY_TAG_Y: Dictionary = {
	"common": 194, "uncommon": 114, "rare": 130, "epic": 146, "legendary": 98,
}
## Ink colour for text sitting ON a pill. The pills are mid-to-light fills, so the label has to go
## dark — bone-on-gold is unreadable at 16px.
const TAG_INK: Color = Color(0.12, 0.09, 0.07)

static var _tag_sheet: Texture2D = null


## A rarity pill with its name inside, ready to drop into a row. Returns null if the sheet is
## missing so a caller can fall back to plain bracket text.
static func rarity_tag(rarity: String, text: String = "") -> Control:
	if not RARITY_TAG_Y.has(rarity):
		return null
	if _tag_sheet == null:
		if not ResourceLoader.exists(TAG_SHEET):
			return null
		_tag_sheet = load(TAG_SHEET)

	var sb := StyleBoxTexture.new()
	sb.texture = _tag_sheet
	sb.region_rect = Rect2(TAG_PILL_X, RARITY_TAG_Y[rarity], TAG_PILL_W, TAG_PILL_H)
	## The cap is the rounded end; only the flat middle may stretch, or the pill goes oval.
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		sb.set_texture_margin(side, 6.0)
		sb.set_content_margin(side, 5.0)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		sb.set_texture_margin(side, 5.0)
		sb.set_content_margin(side, 0.0)

	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl := Label.new()
	lbl.text = (text if text != "" else rarity).to_upper()
	lbl.add_theme_color_override("font_color", TAG_INK)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(lbl)
	return pc


static func _wrap(tex: AtlasTexture, tint: Color) -> TextureRect:
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
