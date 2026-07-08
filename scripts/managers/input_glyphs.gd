extends Node

## InputGlyphs — tracks whether the player is currently driving the game with
## a joypad or with keyboard/mouse, so UI can show the right button-prompt
## glyphs. Switches the instant a joypad or keyboard/mouse event arrives;
## disconnecting the active controller falls back to keyboard immediately
## (no crash, no stuck glyphs).

signal device_changed(is_joypad: bool)

const AXIS_DEADZONE := 0.35

var using_joypad: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


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


func confirm_glyph() -> String:
	return "Ⓐ" if using_joypad else "Enter"   ## Ⓐ


func back_glyph() -> String:
	return "Ⓑ" if using_joypad else "Esc"     ## Ⓑ


func switch_glyph() -> String:
	return "LB/RB" if using_joypad else "[ / ]"


## Xbox-style face/shoulder button glyphs, keyed by Godot's JoyButton index —
## matches the physical buttons project.godot actually binds (see interact=Y,
## light_attack=RB, heavy_attack=LB in the InputMap).
const _JOY_BUTTON_GLYPHS := {
	JOY_BUTTON_A: "Ⓐ", JOY_BUTTON_B: "Ⓑ", JOY_BUTTON_X: "Ⓧ", JOY_BUTTON_Y: "Ⓨ",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Back",
}

## Looks up the actual bound glyph for an arbitrary action (not just the
## generic confirm/back/switch trio) — reads whatever project.godot or a
## user rebind currently has assigned, so the hint never lies about which
## physical button does the thing.
func action_glyph(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		if using_joypad and event is InputEventJoypadButton:
			return _JOY_BUTTON_GLYPHS.get(event.button_index, "●")
		if not using_joypad and event is InputEventKey:
			return event.as_text_physical_keycode().trim_suffix(" (Physical)")
		if not using_joypad and event is InputEventMouseButton:
			return event.as_text().trim_suffix(" (Physical)")
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
