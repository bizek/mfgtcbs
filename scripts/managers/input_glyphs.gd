extends Node

## InputGlyphs — tracks whether the player is currently driving the game with
## a joypad or with keyboard/mouse, so UI can show the right button-prompt
## glyphs. Switches the instant a joypad or keyboard/mouse event arrives;
## disconnecting the active controller falls back to keyboard immediately
## (no crash, no stuck glyphs).
##
## Glyphs are looked up through per-controller-family glyph sets. Xbox,
## PlayStation and Nintendo all ship, as text glyphs and as sprite art. To
## support another controller type, add a set to _GLYPH_SETS (plus its art to
## _PAD_ART) and teach _refresh_family() to recognise the device name — every
## glyph consumer goes through this file, so nothing else needs to change.
##
## Two parallel APIs, deliberately: hint()/action_glyph() return plain strings
## for Labels, hint_bb()/action_glyph_bb() return BBCode with inline [img] art
## for RichTextLabels. The art path always falls back to the text path, so a
## key with no sprite still prints its name.

signal device_changed(is_joypad: bool)

const AXIS_DEADZONE := 0.35

var using_joypad: bool = false
var _family: String = "xbox"


## One entry per controller family. Each set carries:
##   buttons  — JoyButton index → glyph
##   motions  — "axis:sign" → glyph (triggers and stick directions; sign is
##              "+" / "-", triggers only ever use "+")
##   confirm / back / switch — the generic menu-hint trio
const _GLYPH_SETS := {
	"xbox": {
		"buttons": {
			JOY_BUTTON_A: "Ⓐ", JOY_BUTTON_B: "Ⓑ", JOY_BUTTON_X: "Ⓧ", JOY_BUTTON_Y: "Ⓨ",
			JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
			JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
			JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Back",
			JOY_BUTTON_DPAD_UP: "D-Up", JOY_BUTTON_DPAD_DOWN: "D-Down",
			JOY_BUTTON_DPAD_LEFT: "D-Left", JOY_BUTTON_DPAD_RIGHT: "D-Right",
		},
		"motions": {
			"4:+": "LT", "5:+": "RT",
			"0:-": "LS←", "0:+": "LS→", "1:-": "LS↑", "1:+": "LS↓",
			"2:-": "RS←", "2:+": "RS→", "3:-": "RS↑", "3:+": "RS↓",
		},
		"confirm": "Ⓐ",
		"back": "Ⓑ",
		"switch": "LB/RB",
	},
	"playstation": {
		"buttons": {
			JOY_BUTTON_A: "✕", JOY_BUTTON_B: "○", JOY_BUTTON_X: "□", JOY_BUTTON_Y: "△",
			JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
			JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
			JOY_BUTTON_START: "Options", JOY_BUTTON_BACK: "Share",
			JOY_BUTTON_DPAD_UP: "D-Up", JOY_BUTTON_DPAD_DOWN: "D-Down",
			JOY_BUTTON_DPAD_LEFT: "D-Left", JOY_BUTTON_DPAD_RIGHT: "D-Right",
		},
		"motions": {
			"4:+": "L2", "5:+": "R2",
			"0:-": "LS←", "0:+": "LS→", "1:-": "LS↑", "1:+": "LS↓",
			"2:-": "RS←", "2:+": "RS→", "3:-": "RS↑", "3:+": "RS↓",
		},
		"confirm": "✕",
		"back": "○",
		"switch": "L1/R1",
	},
	## Nintendo's physical face layout is mirrored against Godot's Xbox-shaped
	## JoyButton enum: JOY_BUTTON_A is always the BOTTOM button, which on a Switch
	## pad is labelled B. The swapped labels below are correct, not a typo.
	"nintendo": {
		"buttons": {
			JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X",
			JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R",
			JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
			JOY_BUTTON_START: "+", JOY_BUTTON_BACK: "-",
			JOY_BUTTON_DPAD_UP: "D-Up", JOY_BUTTON_DPAD_DOWN: "D-Down",
			JOY_BUTTON_DPAD_LEFT: "D-Left", JOY_BUTTON_DPAD_RIGHT: "D-Right",
		},
		"motions": {
			"4:+": "ZL", "5:+": "ZR",
			"0:-": "LS←", "0:+": "LS→", "1:-": "LS↑", "1:+": "LS↓",
			"2:-": "RS←", "2:+": "RS→", "3:-": "RS↑", "3:+": "RS↓",
		},
		"confirm": "B",
		"back": "A",
		"switch": "L/R",
	},
}


## ── Glyph art (Minifantasy UI Overhaul → _General_UI_Resources/Controls) ─────
##
## Regions were measured off the sheets' alpha channel, not eyeballed; the
## survey lives in docs/ui_pack_inventory.md. Two facts drive the layout:
##
##  * Both sheets ship four style variants. We use the **white-outlined**
##    controller set and the **black-outlined light** keycap set, because every
##    surface that shows a prompt is a dark panel and those are the two that
##    keep contrast there.
##  * Controller face buttons are perfectly regular: the three families sit on
##    a 120px vertical stride and pressed states sit 32px to the right, so the
##    face table is derived rather than transcribed. Shoulders, triggers and
##    menu buttons differ in shape per family, so those stay explicit.
##
## Anything without art falls back to the text glyph above — that fallback is
## the contract, so an unmapped key degrades to "Q"/"F5" instead of vanishing.
const PAD_SHEET: String = "res://assets/minifantasy/Minifantasy_UI _Overhaul_v1.0/_Minifantasy_UI_Overhaul_Assets/_General_UI_Resources/Controls/Controller/_Controllers.png"
const KB_SHEET: String = "res://assets/minifantasy/Minifantasy_UI _Overhaul_v1.0/_Minifantasy_UI_Overhaul_Assets/_General_UI_Resources/Controls/Keyboard_Mouse/_Keyboard_And_Mouse.png"

## Vertical stride between controller families on PAD_SHEET.
const _FAMILY_ROW: Dictionary = {"xbox": 0, "playstation": 120, "nintendo": 240}
## Horizontal offset from an unpressed face button to its pressed twin.
const _PRESSED_DX: int = 32

## Irregular per-family art: menu pair, shoulders, triggers (unpressed, pressed).
const _PAD_ART: Dictionary = {
	"xbox": {
		"back":       [Rect2i(344, 72, 8, 8),   Rect2i(376, 72, 8, 8)],
		"start":      [Rect2i(360, 72, 8, 8),   Rect2i(392, 72, 8, 8)],
		"l_shoulder": [Rect2i(408, 80, 16, 8),  Rect2i(456, 80, 16, 8)],
		"r_shoulder": [Rect2i(432, 80, 16, 8),  Rect2i(480, 80, 16, 8)],
		"l_trigger":  [Rect2i(413, 60, 11, 12), Rect2i(461, 60, 11, 12)],
		"r_trigger":  [Rect2i(432, 60, 11, 12), Rect2i(480, 60, 11, 12)],
	},
	"playstation": {
		"back":       [Rect2i(344, 193, 8, 7),   Rect2i(376, 193, 8, 7)],
		"start":      [Rect2i(360, 193, 8, 7),   Rect2i(392, 193, 8, 7)],
		"l_shoulder": [Rect2i(410, 200, 12, 8),  Rect2i(456, 200, 12, 8)],
		"r_shoulder": [Rect2i(434, 200, 12, 8),  Rect2i(480, 200, 12, 8)],
		"l_trigger":  [Rect2i(410, 180, 12, 12), Rect2i(456, 180, 12, 12)],
		"r_trigger":  [Rect2i(434, 180, 12, 12), Rect2i(480, 180, 12, 12)],
	},
	"nintendo": {
		"back":       [Rect2i(344, 314, 8, 4),   Rect2i(376, 314, 8, 4)],
		"start":      [Rect2i(360, 312, 8, 8),   Rect2i(392, 312, 8, 8)],
		"l_shoulder": [Rect2i(408, 321, 16, 7),  Rect2i(456, 321, 16, 7)],
		"r_shoulder": [Rect2i(432, 321, 16, 7),  Rect2i(480, 321, 16, 7)],
		"l_trigger":  [Rect2i(408, 302, 16, 10), Rect2i(456, 302, 16, 10)],
		"r_trigger":  [Rect2i(432, 302, 16, 10), Rect2i(480, 302, 16, 10)],
	},
}

## Sticks and D-pad are one shared set — the pack draws them identically for all
## three families, so these carry no family offset.
const _STICK_ART: Dictionary = {
	JOY_BUTTON_LEFT_STICK:  Rect2i(34, 146, 12, 12),
	JOY_BUTTON_RIGHT_STICK: Rect2i(98, 146, 12, 12),
}
const _MOTION_ART: Dictionary = {
	"0:-": Rect2i(16, 146, 10, 12), "0:+": Rect2i(54, 145, 10, 12),
	"1:-": Rect2i(34, 128, 12, 10), "1:+": Rect2i(34, 167, 12, 9),
	"2:-": Rect2i(80, 146, 10, 12), "2:+": Rect2i(118, 145, 10, 12),
	"3:-": Rect2i(98, 128, 12, 10), "3:+": Rect2i(98, 167, 12, 9),
}
const _DPAD_ART: Dictionary = {
	JOY_BUTTON_DPAD_UP:    Rect2i(152, 96, 8, 8),
	JOY_BUTTON_DPAD_LEFT:  Rect2i(136, 112, 8, 8),
	JOY_BUTTON_DPAD_RIGHT: Rect2i(168, 112, 8, 8),
	JOY_BUTTON_DPAD_DOWN:  Rect2i(152, 128, 8, 8),
}

## ── Keycap art ──────────────────────────────────────────────────────────────
## The spread grid on KB_SHEET is a clean lattice, so keys are addressed by
## (row, col) instead of 40-odd transcribed rects. Regular caps are 7x8 at
## x = 40 + 16*col, y = 72 + 16*row. Wide caps (Tab/Shift/Ctrl/Alt/Space) are
## 15x8 pinned to x = 16 on their row. Pressed caps are the same grid +160px in
## y. The sheet has no Esc, F-keys or punctuation — those take the text path.
const _KB_ORIGIN: Vector2i = Vector2i(40, 72)
const _KB_STRIDE: Vector2i = Vector2i(16, 16)
const _KB_PRESSED_DY: int = 160
const _KB_CAP: Vector2i = Vector2i(7, 8)
const _KB_WIDE_X: int = 16
const _KB_WIDE: Vector2i = Vector2i(15, 8)

## keycode → Vector2i(col, row) on the regular-cap lattice.
const _KB_CELL: Dictionary = {
	KEY_1: Vector2i(0, 0), KEY_2: Vector2i(1, 0), KEY_3: Vector2i(2, 0),
	KEY_4: Vector2i(3, 0), KEY_5: Vector2i(4, 0), KEY_6: Vector2i(5, 0),
	KEY_7: Vector2i(6, 0), KEY_8: Vector2i(7, 0), KEY_9: Vector2i(8, 0),
	KEY_0: Vector2i(9, 0),
	KEY_Q: Vector2i(0, 1), KEY_W: Vector2i(1, 1), KEY_E: Vector2i(2, 1),
	KEY_R: Vector2i(3, 1), KEY_T: Vector2i(4, 1), KEY_Y: Vector2i(5, 1),
	KEY_U: Vector2i(6, 1), KEY_I: Vector2i(7, 1), KEY_O: Vector2i(8, 1),
	KEY_P: Vector2i(9, 1),
	KEY_A: Vector2i(0, 2), KEY_S: Vector2i(1, 2), KEY_D: Vector2i(2, 2),
	KEY_F: Vector2i(3, 2), KEY_G: Vector2i(4, 2), KEY_H: Vector2i(5, 2),
	KEY_J: Vector2i(6, 2), KEY_K: Vector2i(7, 2), KEY_L: Vector2i(8, 2),
	KEY_Z: Vector2i(0, 3), KEY_X: Vector2i(1, 3), KEY_C: Vector2i(2, 3),
	KEY_V: Vector2i(3, 3), KEY_B: Vector2i(4, 3), KEY_N: Vector2i(5, 3),
	KEY_M: Vector2i(6, 3),
}
## keycode → row index on the wide-cap column.
const _KB_WIDE_ROW: Dictionary = {
	KEY_TAB: 0, KEY_SHIFT: 1, KEY_CTRL: 2, KEY_ALT: 3, KEY_SPACE: 4,
}
## Keys that sit outside both lattices.
const _KB_LOOSE: Dictionary = {
	KEY_BACKSPACE: Rect2i(200, 72, 15, 8),
	KEY_ENTER: Rect2i(200, 99, 15, 13),
	KEY_KP_ENTER: Rect2i(200, 99, 15, 13),
	KEY_UP: Rect2i(232, 120, 7, 8),
	KEY_LEFT: Rect2i(224, 136, 7, 8),
	KEY_DOWN: Rect2i(232, 136, 7, 8),
	KEY_RIGHT: Rect2i(240, 136, 7, 8),
}
## Compact mouse glyphs — 7x8, so they line up with the keycaps.
const _MOUSE_ART: Dictionary = {
	MOUSE_BUTTON_LEFT: Rect2i(105, 336, 7, 8),
	MOUSE_BUTTON_RIGHT: Rect2i(121, 336, 7, 8),
	MOUSE_BUTTON_MIDDLE: Rect2i(137, 336, 7, 8),
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_refresh_family()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_set_device(true)
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) >= AXIS_DEADZONE:
			_set_device(true)
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		_set_device(false)


func _set_device(is_joypad: bool) -> void:
	if using_joypad == is_joypad:
		return
	using_joypad = is_joypad
	device_changed.emit(using_joypad)


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	## Unplugging the only controller mid-run must not leave joypad glyphs
	## (or a focus reliant on it) stranded — fall back to keyboard/mouse.
	if not connected and Input.get_connected_joypads().is_empty():
		_set_device(false)
	else:
		_refresh_family()
		if using_joypad:
			## Family may have changed (swapped controllers) — reprompt.
			device_changed.emit(true)


## Picks the glyph family from the first connected joypad's reported name.
## Xbox is the fallback for anything unrecognised, since its labels are the
## ones Godot's own JoyButton enum is named after.
func _refresh_family() -> void:
	_family = "xbox"
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return
	var joy_name := Input.get_joy_name(pads[0]).to_lower()
	if _GLYPH_SETS.has("playstation") and ("ps5" in joy_name or "ps4" in joy_name \
			or "dualsense" in joy_name or "dualshock" in joy_name or "sony" in joy_name):
		_family = "playstation"
	elif _GLYPH_SETS.has("nintendo") and ("nintendo" in joy_name or "switch" in joy_name \
			or "joy-con" in joy_name):
		_family = "nintendo"


func _glyphs() -> Dictionary:
	return _GLYPH_SETS[_family]


## ── Glyph art lookup ────────────────────────────────────────────────────────
## Every region getter returns an EMPTY Rect2i when the input has no art, and
## every caller treats that as "use the text glyph". Nothing here can make a
## prompt disappear — worst case it renders the same string it renders today.

## Face-button anchors before the family row offset is applied.
const _FACE_XY: Dictionary = {
	JOY_BUTTON_Y: Vector2i(288, 64),   ## top
	JOY_BUTTON_X: Vector2i(280, 72),   ## left
	JOY_BUTTON_B: Vector2i(296, 72),   ## right
	JOY_BUTTON_A: Vector2i(288, 80),   ## bottom
}
const _FACE_SIZE: Vector2i = Vector2i(7, 8)
const _SHOULDER_OF: Dictionary = {
	JOY_BUTTON_LEFT_SHOULDER: "l_shoulder", JOY_BUTTON_RIGHT_SHOULDER: "r_shoulder",
	JOY_BUTTON_BACK: "back", JOY_BUTTON_START: "start",
}


## Region for a joypad button in the active family, or an empty Rect2i.
func pad_region(button: int, pressed: bool = false) -> Rect2i:
	var row: int = _FAMILY_ROW.get(_family, 0)
	if _FACE_XY.has(button):
		var xy: Vector2i = _FACE_XY[button]
		var x: int = xy.x + (_PRESSED_DX if pressed else 0)
		return Rect2i(x, xy.y + row, _FACE_SIZE.x, _FACE_SIZE.y)
	if _SHOULDER_OF.has(button):
		var pair: Array = _PAD_ART[_family][_SHOULDER_OF[button]]
		return pair[1] if pressed else pair[0]
	if _DPAD_ART.has(button):
		return _DPAD_ART[button]
	if _STICK_ART.has(button):
		return _STICK_ART[button]
	return Rect2i()


## Region for a stick direction or trigger ("axis:sign"), or an empty Rect2i.
func motion_region(motion_key: String, pressed: bool = false) -> Rect2i:
	if motion_key == "4:+" or motion_key == "5:+":
		var side: String = "l_trigger" if motion_key == "4:+" else "r_trigger"
		var pair: Array = _PAD_ART[_family][side]
		return pair[1] if pressed else pair[0]
	return _MOTION_ART.get(motion_key, Rect2i())


## Region for a keycap, or an empty Rect2i when the sheet has no cap for it
## (Esc, F-keys and punctuation are genuinely absent — they take the text path).
func key_region(keycode: int, pressed: bool = false) -> Rect2i:
	var dy: int = _KB_PRESSED_DY if pressed else 0
	if _KB_CELL.has(keycode):
		var cell: Vector2i = _KB_CELL[keycode]
		return Rect2i(_KB_ORIGIN.x + cell.x * _KB_STRIDE.x,
				_KB_ORIGIN.y + cell.y * _KB_STRIDE.y + dy, _KB_CAP.x, _KB_CAP.y)
	if _KB_WIDE_ROW.has(keycode):
		var r: int = _KB_WIDE_ROW[keycode]
		return Rect2i(_KB_WIDE_X, _KB_ORIGIN.y + r * _KB_STRIDE.y + dy, _KB_WIDE.x, _KB_WIDE.y)
	if _KB_LOOSE.has(keycode):
		var loose: Rect2i = _KB_LOOSE[keycode]
		return Rect2i(loose.position.x, loose.position.y + dy, loose.size.x, loose.size.y)
	return Rect2i()


func mouse_region(button: int) -> Rect2i:
	return _MOUSE_ART.get(button, Rect2i())


## An AtlasTexture for any region, for consumers that want a TextureRect rather
## than inline BBCode. Returns null for an empty region.
func glyph_texture(sheet: String, region: Rect2i) -> AtlasTexture:
	if region.size == Vector2i.ZERO:
		return null
	var tex := AtlasTexture.new()
	tex.atlas = load(sheet)
	tex.region = Rect2(region)
	return tex


## An AtlasTexture for an action's currently bound input, or null when the pack
## has no art for it. For callers that place glyphs as nodes (a TextureRect in a
## fixed-size slot) rather than inline in text.
func action_glyph_texture(action: String, pressed: bool = false) -> AtlasTexture:
	if not InputMap.has_action(action):
		return null
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and using_joypad:
			return glyph_texture(PAD_SHEET, pad_region(event.button_index, pressed))
		if event is InputEventJoypadMotion and using_joypad:
			var key := "%d:%s" % [event.axis, "-" if event.axis_value < 0.0 else "+"]
			return glyph_texture(PAD_SHEET, motion_region(key, pressed))
		if event is InputEventKey and not using_joypad:
			return glyph_texture(KB_SHEET, key_region(_resolved_keycode(event), pressed))
		if event is InputEventMouseButton and not using_joypad:
			return glyph_texture(KB_SHEET, mouse_region(event.button_index))
	return null


func _bb_img(sheet: String, region: Rect2i) -> String:
	return "[img region=%d,%d,%d,%d]%s[/img]" % [
		region.position.x, region.position.y, region.size.x, region.size.y, sheet]


## BBCode for a single InputEvent — an [img] when the pack has art, otherwise
## the same string event_glyph() would have produced.
func event_glyph_bb(event: InputEvent, joypad: bool, pressed: bool = false) -> String:
	if joypad:
		if event is InputEventJoypadButton:
			var r: Rect2i = pad_region(event.button_index, pressed)
			if r.size != Vector2i.ZERO:
				return _bb_img(PAD_SHEET, r)
		elif event is InputEventJoypadMotion:
			var key := "%d:%s" % [event.axis, "-" if event.axis_value < 0.0 else "+"]
			var mr: Rect2i = motion_region(key, pressed)
			if mr.size != Vector2i.ZERO:
				return _bb_img(PAD_SHEET, mr)
	elif event is InputEventKey:
		var kr: Rect2i = key_region(_resolved_keycode(event), pressed)
		if kr.size != Vector2i.ZERO:
			return _bb_img(KB_SHEET, kr)
	elif event is InputEventMouseButton:
		var mb: Rect2i = mouse_region(event.button_index)
		if mb.size != Vector2i.ZERO:
			return _bb_img(KB_SHEET, mb)
	return _escape_bb(event_glyph(event, joypad))


## The keycode a keycap should be looked up by — mirrors _key_label()'s
## resolution order so art and text never disagree about which key is bound.
func _resolved_keycode(event: InputEventKey) -> int:
	if event.physical_keycode != KEY_NONE:
		return DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)
	if event.keycode != KEY_NONE:
		return event.keycode
	return event.key_label


## Text glyphs are user-facing strings that can contain "[" (e.g. the keyboard
## switch hint "[ / ]"), which would otherwise open a bogus BBCode tag.
func _escape_bb(text: String) -> String:
	return text.replace("[", "[lb]")


## BBCode for an action's currently bound input, art where the pack has it.
func action_glyph_bb(action: String, pressed: bool = false) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		if event_glyph(event, using_joypad) != "":
			return event_glyph_bb(event, using_joypad, pressed)
	return "?"


func confirm_glyph_bb() -> String:
	if not using_joypad:
		return _bb_img(KB_SHEET, key_region(KEY_ENTER))
	return _bb_img(PAD_SHEET, pad_region(JOY_BUTTON_A))


func back_glyph_bb() -> String:
	## Esc has no keycap on the sheet, so the keyboard side stays textual.
	if not using_joypad:
		return _escape_bb(back_glyph())
	return _bb_img(PAD_SHEET, pad_region(JOY_BUTTON_B))


func switch_glyph_bb() -> String:
	return "%s%s" % [
		_bb_img(PAD_SHEET, pad_region(JOY_BUTTON_LEFT_SHOULDER)),
		_bb_img(PAD_SHEET, pad_region(JOY_BUTTON_RIGHT_SHOULDER))]


## BBCode twin of hint() — same pairs, same "switch is joypad-only" rule.
func hint_bb(pairs: Array) -> String:
	var parts: Array[String] = []
	for pair in pairs:
		var key: String = pair[0]
		var label: String = pair[1]
		if key == "switch" and not using_joypad:
			continue
		var glyph: String
		match key:
			"confirm": glyph = confirm_glyph_bb()
			"back":    glyph = back_glyph_bb()
			"switch":  glyph = switch_glyph_bb()
			_:         glyph = action_glyph_bb(key)
		parts.append("%s %s" % [glyph, _escape_bb(label)])
	return "   ".join(parts)


func confirm_glyph() -> String:
	return _glyphs()["confirm"] if using_joypad else "Enter"


func back_glyph() -> String:
	return _glyphs()["back"] if using_joypad else "Esc"


func switch_glyph() -> String:
	return _glyphs()["switch"] if using_joypad else "[ / ]"


## Glyph for a single InputEvent, honouring the active device + family.
## Returns "" when the event doesn't belong to the requested device class.
func event_glyph(event: InputEvent, joypad: bool) -> String:
	if joypad:
		if event is InputEventJoypadButton:
			return _glyphs()["buttons"].get(event.button_index, "●")
		if event is InputEventJoypadMotion:
			var key := "%d:%s" % [event.axis, "-" if event.axis_value < 0.0 else "+"]
			return _glyphs()["motions"].get(key, "●")
		return ""
	if event is InputEventKey:
		return _key_label(event)
	if event is InputEventMouseButton:
		return event.as_text().trim_suffix(" (Physical)")
	return ""


## A key's printable label, whichever way the binding was authored.
##
## project.godot MIXES the two styles — skill_q/skill_e carry a physical_keycode, while
## interact/dash carry a logical keycode with physical_keycode left at KEY_NONE — and a user rebind
## can produce either. Asking only for the physical text (as_text_physical_keycode) therefore
## rendered Godot's literal "(unset)" on every logically-bound action: Ben hit it on world interact
## prompts, and the Controls tab showed it too since settings_panel._event_text calls through here
## (Ben 2026-07-30, first play after the controller pass).
##
## Physical bindings are resolved through the OS layout so the label matches the key the player
## actually presses (a physical Q reads "A" on AZERTY) — the same thing as_text_physical_keycode
## does internally, minus the " - Physical" suffix. Returns "" when nothing is bound, which lets
## action_glyph move on to the next event instead of printing a placeholder.
func _key_label(event: InputEventKey) -> String:
	if event.physical_keycode != KEY_NONE:
		return OS.get_keycode_string(
				DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode))
	if event.keycode != KEY_NONE:
		return OS.get_keycode_string(event.keycode)
	if event.key_label != KEY_NONE:
		return OS.get_keycode_string(event.key_label)
	return ""


## Looks up the actual bound glyph for an arbitrary action (not just the
## generic confirm/back/switch trio) — reads whatever project.godot or a
## user rebind currently has assigned, so the hint never lies about which
## physical button does the thing.
func action_glyph(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		var glyph := event_glyph(event, using_joypad)
		if glyph != "":
			return glyph
	return "?"


## Builds a hint string like "Ⓐ Confirm   Ⓑ Back" from pairs of
## [glyph_key, label]. glyph_key is "confirm" / "back" / "switch", or any
## other InputMap action name (looked up via action_glyph).
## "switch" is joypad-only (LB/RB — see menu_switch_prev/next in
## project.godot) with no keyboard/mouse equivalent, so it's omitted entirely
## when a controller isn't the active device rather than showing a fake key hint.
func hint(pairs: Array) -> String:
	var parts: Array[String] = []
	for pair in pairs:
		var key: String = pair[0]
		var label: String = pair[1]
		if key == "switch" and not using_joypad:
			continue
		var glyph: String
		match key:
			"confirm": glyph = confirm_glyph()
			"back":    glyph = back_glyph()
			"switch":  glyph = switch_glyph()
			_:         glyph = action_glyph(key)
		parts.append("%s %s" % [glyph, label])
	return "   ".join(parts)
