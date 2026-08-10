extends Node

## GameCursor — the game's mouse pointer. Autoload.
##
## The game's core combat verb is manual cursor aim, and until now it shipped the OS arrow
## (docs/ui_pack_inventory.md gap 2: "No custom mouse cursor is set anywhere"). This replaces it
## with the UI pack's own art: a bracket reticle while playing, the pack's arrow in menus.
##
## Two things make this more than one set_custom_mouse_cursor call:
##
##  1. SCALE. The game renders at 640x360 and is upscaled to the window, but the hardware cursor
##     is drawn in REAL screen pixels and is not upscaled with it. A raw 16x16 cursor would be a
##     third the apparent size of every other pixel on screen. So the source cell is nearest-
##     neighbour scaled by the same integer factor the viewport is using, recomputed whenever the
##     window changes size.
##  2. STATE. The sheet ships every cursor in four tints. The reticle goes red while an enemy is
##     under it, which is real aiming information rather than decoration.

## 440x72: 27 cursors across (16px cells), 4 tint rows down.
const SHEET: String = "res://assets/minifantasy/Minifantasy_UI _Overhaul_v1.0/_Minifantasy_UI_Overhaul_Assets/_General_UI_Resources/Cursors/_Cursors.png"
const CELL: int = 16

## Column indices into the sheet. Order is fixed by the pack: 4 large arrows, 4 small arrows,
## 4 crosshairs, hand, hand-clicking, melee/ranged/magic attack, then the tool cursors.
const COL_ARROW: int = 0        ## large arrow — menus, hub, anything you click
const COL_RETICLE: int = 8      ## corner-bracket crosshair: an OPEN centre, so it frames what
                                ## you are aiming at instead of covering it. The other three
                                ## (dense diamond, dot cross, star cross) all fill the middle.

## Tint rows. Row 1 (white) is deliberately unused — it is nearly invisible against the cave
## floor, which is most of what the player looks at.
const ROW_DEFAULT: int = 0      ## black outline + tan fill; the readable one
const ROW_RED: int = 2          ## enemy under the reticle
const ROW_GREEN: int = 3        ## unused for now; kept named so the intent is obvious

const BASE_VIEWPORT_WIDTH: float = 640.0

## Hotspot in SOURCE pixels — the point in the cell that "is" the mouse position. It is (8,8)
## for both cursors we use, which is not a coincidence and is not just "the middle":
##   • the reticle's brackets are centred, opaque box x[2..13] y[2..13], so its centre is (8,8);
##   • the arrow is drawn entirely in the cell's BOTTOM-RIGHT quadrant, opaque box x[8..14]
##     y[8..14], so its pointing tip is (8,8) too — the pack leaves the top-left eighth empty
##     precisely so this is the hotspot.
## Both measured off the sheet's alpha, not eyeballed. A (0,0) hotspot would land menu clicks
## 8 source pixels up and left of the arrow tip.
const HOTSPOT: float = 8.0

enum Mode { POINTER, AIM }

## ── Click pop (UI pack gap 2, tail) ──────────────────────────────────────────
## `Cursors/Click_Effects/Click_Effects.png` is 64x208 — 4 columns x 13 rows of 16x16. Rows 0-5
## are a "collapsing in" effect, row 6 is blank, rows 7-12 are "expanding out", each in six
## colours (red, gold, blue, orange, magenta, green). Expanding-out reads as "something went out
## from here", which is what a click confirm wants; gold matches the menus' amber accent.
##
## MENUS ONLY, deliberately (Ben, 2026-08-09). The pack's own timing is 100ms/frame, so a full
## play is 400ms — fine for a button press, and clutter on a light chain that fires several times
## a second. Pointer mode IS the menus: main_menu, hub and every panel call use_pointer(), while
## main_arena calls use_aim(). Gating on the mode rather than on button signals means no screen
## has to remember to opt in, and gameplay can never accidentally opt in.
const CLICK_SHEET: String = "res://assets/minifantasy/Minifantasy_UI _Overhaul_v1.0/_Minifantasy_UI_Overhaul_Assets/_General_UI_Resources/Cursors/Click_Effects/Click_Effects.png"
const CLICK_CELL: int = 16
const CLICK_FRAMES: int = 4
const CLICK_ROW_GOLD: int = 8        ## expanding-out block starts at row 7; +1 = gold
const CLICK_FRAME_TIME: float = 0.1  ## the pack's native rate
## Under SceneTransition (128) so a scene fade covers the pop rather than letting it sit on top.
const CLICK_LAYER: int = 127

var _mode: int = Mode.POINTER
var _hostile: bool = false
var _scale: int = 0                  ## 0 = nothing built yet
var _sheet_image: Image = null
var _cache: Dictionary = {}          ## "col,row,scale" -> ImageTexture
var _applied_key: String = ""        ## last texture actually handed to the OS

var _click_layer: CanvasLayer = null
var _click_rect: TextureRect = null
var _click_frames: Array[AtlasTexture] = []
var _click_frame: int = -1           ## -1 = idle
var _click_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size_changed.connect(_on_window_resized)
	_refresh()
	_build_click_pop()


## Drawn INSIDE the viewport, not scaled like the cursor art above: a CanvasLayer lives in the
## 640x360 design space and is upscaled with the rest of the game for free. The hardware cursor
## is the only thing that needs the manual integer scale.
func _build_click_pop() -> void:
	if not ResourceLoader.exists(CLICK_SHEET):
		return
	var sheet: Texture2D = load(CLICK_SHEET)
	if sheet == null:
		return
	for i in range(CLICK_FRAMES):
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * CLICK_CELL, CLICK_ROW_GOLD * CLICK_CELL, CLICK_CELL, CLICK_CELL)
		at.filter_clip = true
		_click_frames.append(at)

	_click_layer = CanvasLayer.new()
	_click_layer.layer = CLICK_LAYER
	add_child(_click_layer)

	_click_rect = TextureRect.new()
	_click_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_click_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_click_rect.visible = false
	_click_layer.add_child(_click_rect)


func _unhandled_input(event: InputEvent) -> void:
	if _mode != Mode.POINTER or _click_rect == null:
		return
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_play_click_pop()


func _play_click_pop() -> void:
	if _click_frames.is_empty():
		return
	## Restart rather than queue: a second click means the first pop is stale.
	_click_frame = 0
	_click_timer = 0.0
	_click_rect.texture = _click_frames[0]
	_click_rect.position = get_viewport().get_mouse_position() - Vector2(CLICK_CELL, CLICK_CELL) * 0.5
	_click_rect.visible = true


func _process(delta: float) -> void:
	if _click_frame < 0:
		return
	_click_timer += delta
	if _click_timer < CLICK_FRAME_TIME:
		return
	_click_timer -= CLICK_FRAME_TIME
	_click_frame += 1
	if _click_frame >= CLICK_FRAMES:
		_click_frame = -1
		_click_rect.visible = false
		return
	_click_rect.texture = _click_frames[_click_frame]


## Menus, hub, anything you point and click at.
func use_pointer() -> void:
	if _mode == Mode.POINTER:
		return
	_mode = Mode.POINTER
	_refresh()


## Gameplay — the aiming reticle.
func use_aim() -> void:
	if _mode == Mode.AIM:
		return
	_mode = Mode.AIM
	_refresh()


## Called by the player each frame while aiming. Cheap: only touches the OS when the state
## actually flips, so a steady hand costs one bool compare per frame.
func set_hostile(hostile: bool) -> void:
	if _hostile == hostile:
		return
	_hostile = hostile
	_refresh()


## Restore the OS cursor (used if the custom art fails to load).
func use_system() -> void:
	Input.set_custom_mouse_cursor(null)
	_applied_key = ""


func _on_window_resized() -> void:
	_refresh()


func _refresh() -> void:
	var want_scale: int = _current_scale()
	if want_scale != _scale:
		_scale = want_scale
		_cache.clear()
		_applied_key = ""

	var col: int = COL_RETICLE if _mode == Mode.AIM else COL_ARROW
	var row: int = ROW_DEFAULT
	if _mode == Mode.AIM and _hostile:
		row = ROW_RED

	var key: String = "%d,%d,%d" % [col, row, _scale]
	if key == _applied_key:
		return
	var tex: ImageTexture = _texture_for(col, row)
	if tex == null:
		use_system()
		return
	_applied_key = key
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2(HOTSPOT, HOTSPOT) * _scale)


## Integer upscale factor the viewport is currently being drawn at, so the cursor's pixels are
## the same size as the game's. Clamped to >= 1 so a window smaller than the base viewport still
## gets a usable cursor rather than a zero-sized one.
func _current_scale() -> int:
	var win_w: float = float(DisplayServer.window_get_size().x)
	return maxi(1, int(floor(win_w / BASE_VIEWPORT_WIDTH)))


func _texture_for(col: int, row: int) -> ImageTexture:
	var key: String = "%d,%d,%d" % [col, row, _scale]
	if _cache.has(key):
		return _cache[key]

	if _sheet_image == null:
		var sheet: Texture2D = load(SHEET) as Texture2D
		if sheet == null:
			push_warning("[GameCursor] Cursor sheet missing: %s" % SHEET)
			return null
		_sheet_image = sheet.get_image()
	if _sheet_image == null:
		return null

	var src := Rect2i(col * CELL, row * CELL, CELL, CELL)
	if not Rect2i(Vector2i.ZERO, _sheet_image.get_size()).encloses(src):
		push_warning("[GameCursor] Cell (%d,%d) is outside the sheet" % [col, row])
		return null

	var cell := Image.create(CELL, CELL, false, _sheet_image.get_format())
	cell.blit_rect(_sheet_image, src, Vector2i.ZERO)
	## INTERPOLATE_NEAREST is the whole point — anything else turns pixel art to mush.
	cell.resize(CELL * _scale, CELL * _scale, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(cell)
	_cache[key] = tex
	return tex
