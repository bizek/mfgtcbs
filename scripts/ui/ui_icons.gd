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
	var tex := _atlas(x, y)
	if tex == null:
		return null
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr
