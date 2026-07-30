extends Node

## InputGlyphs — tracks whether the player is currently driving the game with
## a joypad or with keyboard/mouse, so UI can show the right button-prompt
## glyphs. Switches the instant a joypad or keyboard/mouse event arrives;
## disconnecting the active controller falls back to keyboard immediately
## (no crash, no stuck glyphs).
##
## Glyphs are looked up through per-controller-family glyph sets (Xbox is the
## default and currently the only shipped set). To support another controller
## type, add a set to _GLYPH_SETS and teach _detect_family() to recognise the
## device name — every glyph consumer goes through this file, so nothing else
## needs to change.

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
## Only Xbox glyphs ship today, so everything resolves to "xbox" — the match
## below is the extension point for PlayStation/Switch sets later.
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
		return event.as_text_physical_keycode().trim_suffix(" (Physical)")
	if event is InputEventMouseButton:
		return event.as_text().trim_suffix(" (Physical)")
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
