extends Node

## Settings — persisted user preferences (audio, display, screen shake,
## controls, accessibility). Separate from ProgressionManager's save; lives
## at user://settings.cfg. Applied on startup before the first scene needs
## them (autoload order).

signal setting_changed(key: String, value: Variant)
signal bindings_changed  ## emitted after any rebind/reset so UI can refresh

const SAVE_PATH := "user://settings.cfg"
const SECTION := "settings"
const SECTION_BINDS := "bindings"

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

## Gameplay actions exposed for rebinding (deliberately excludes ui_* built-ins).
const REBINDABLE_ACTIONS := [
	"move_up", "move_down", "move_left", "move_right",
	"fire", "dash", "interact", "light_attack", "heavy_attack",
	"skill_q", "skill_e",
]

enum TextSize { SMALL, NORMAL, LARGE }
const TEXT_SIZE_SCALE := {
	TextSize.SMALL: 0.85,
	TextSize.NORMAL: 1.0,
	TextSize.LARGE: 1.25,
}

const DEFAULTS := {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"muted": false,
	"fullscreen": false,
	"vsync": true,
	"screen_shake": 1.0,
	"damage_numbers_enabled": true,
	"screen_flash_intensity": 1.0,
	"text_size": TextSize.NORMAL,
	"colorblind_mode": false,
	"auto_aim": false,
}

var master_volume: float = DEFAULTS["master_volume"]
var music_volume: float = DEFAULTS["music_volume"]
var sfx_volume: float = DEFAULTS["sfx_volume"]
var muted: bool = DEFAULTS["muted"]
var fullscreen: bool = DEFAULTS["fullscreen"]
var vsync: bool = DEFAULTS["vsync"]
var screen_shake: float = DEFAULTS["screen_shake"]  ## 0.0-1.0 multiplier read by camera shake / juice pass

## ── Gameplay ───────────────────────────────────────────────────────────────
## Auto-aim: the player stops steering the crosshair entirely — attacks, skills and
## facing all point at the auto-acquired target (player.gd `_update_auto_target`).
## Primarily a controller QoL option; read live, so toggling it mid-run applies at once.
var auto_aim: bool = DEFAULTS["auto_aim"]

## ── Accessibility ──────────────────────────────────────────────────────────
var damage_numbers_enabled: bool = DEFAULTS["damage_numbers_enabled"]
var screen_flash_intensity: float = DEFAULTS["screen_flash_intensity"]  ## 0.0-1.0 multiplier on flash alpha
var text_size: int = DEFAULTS["text_size"]
var colorblind_mode: bool = DEFAULTS["colorblind_mode"]

## ── Controls ────────────────────────────────────────────────────────────────
## action_name -> Array[InputEvent], overrides applied on top of project.godot
## defaults. Only populated for actions the user has actually rebound.
var _action_overrides: Dictionary = {}
## action_name -> Array[InputEvent] captured from project.godot at boot, before
## any override is applied. Used by reset-to-defaults.
var _default_events: Dictionary = {}


func _ready() -> void:
	_capture_default_bindings()
	load_settings()
	_apply_all()
	_apply_binding_overrides()


func _capture_default_bindings() -> void:
	for action in REBINDABLE_ACTIONS:
		if InputMap.has_action(action):
			_default_events[action] = InputMap.action_get_events(action).duplicate()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		_reset_to_defaults()
		return

	master_volume = cfg.get_value(SECTION, "master_volume", DEFAULTS["master_volume"])
	music_volume  = cfg.get_value(SECTION, "music_volume", DEFAULTS["music_volume"])
	sfx_volume    = cfg.get_value(SECTION, "sfx_volume", DEFAULTS["sfx_volume"])
	muted         = cfg.get_value(SECTION, "muted", DEFAULTS["muted"])
	fullscreen    = cfg.get_value(SECTION, "fullscreen", DEFAULTS["fullscreen"])
	vsync         = cfg.get_value(SECTION, "vsync", DEFAULTS["vsync"])
	screen_shake  = cfg.get_value(SECTION, "screen_shake", DEFAULTS["screen_shake"])

	damage_numbers_enabled = cfg.get_value(SECTION, "damage_numbers_enabled", DEFAULTS["damage_numbers_enabled"])
	screen_flash_intensity = cfg.get_value(SECTION, "screen_flash_intensity", DEFAULTS["screen_flash_intensity"])
	text_size               = cfg.get_value(SECTION, "text_size", DEFAULTS["text_size"])
	colorblind_mode          = cfg.get_value(SECTION, "colorblind_mode", DEFAULTS["colorblind_mode"])
	auto_aim                 = cfg.get_value(SECTION, "auto_aim", DEFAULTS["auto_aim"])

	master_volume = clampf(master_volume, 0.0, 1.0)
	music_volume  = clampf(music_volume, 0.0, 1.0)
	sfx_volume    = clampf(sfx_volume, 0.0, 1.0)
	screen_shake  = clampf(screen_shake, 0.0, 1.0)
	screen_flash_intensity = clampf(screen_flash_intensity, 0.0, 1.0)
	if not TEXT_SIZE_SCALE.has(text_size):
		text_size = TextSize.NORMAL

	_action_overrides.clear()
	for action in REBINDABLE_ACTIONS:
		var key := "bind_%s" % action
		if cfg.has_section_key(SECTION_BINDS, key):
			var packed: Array = cfg.get_value(SECTION_BINDS, key, [])
			var events: Array[InputEvent] = []
			for e in packed:
				if e is InputEvent:
					events.append(e)
			if not events.is_empty():
				_action_overrides[action] = events


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "master_volume", master_volume)
	cfg.set_value(SECTION, "music_volume", music_volume)
	cfg.set_value(SECTION, "sfx_volume", sfx_volume)
	cfg.set_value(SECTION, "muted", muted)
	cfg.set_value(SECTION, "fullscreen", fullscreen)
	cfg.set_value(SECTION, "vsync", vsync)
	cfg.set_value(SECTION, "screen_shake", screen_shake)
	cfg.set_value(SECTION, "damage_numbers_enabled", damage_numbers_enabled)
	cfg.set_value(SECTION, "screen_flash_intensity", screen_flash_intensity)
	cfg.set_value(SECTION, "text_size", text_size)
	cfg.set_value(SECTION, "colorblind_mode", colorblind_mode)
	cfg.set_value(SECTION, "auto_aim", auto_aim)

	for action in _action_overrides:
		var events: Array = _action_overrides[action]
		cfg.set_value(SECTION_BINDS, "bind_%s" % action, events)

	cfg.save(SAVE_PATH)


func _reset_to_defaults() -> void:
	master_volume = DEFAULTS["master_volume"]
	music_volume  = DEFAULTS["music_volume"]
	sfx_volume    = DEFAULTS["sfx_volume"]
	muted         = DEFAULTS["muted"]
	fullscreen    = DEFAULTS["fullscreen"]
	vsync         = DEFAULTS["vsync"]
	screen_shake  = DEFAULTS["screen_shake"]
	damage_numbers_enabled = DEFAULTS["damage_numbers_enabled"]
	screen_flash_intensity = DEFAULTS["screen_flash_intensity"]
	text_size               = DEFAULTS["text_size"]
	colorblind_mode          = DEFAULTS["colorblind_mode"]
	auto_aim                 = DEFAULTS["auto_aim"]
	_action_overrides.clear()


func _apply_all() -> void:
	_apply_bus_volume(BUS_MASTER, master_volume)
	_apply_bus_volume(BUS_MUSIC, music_volume)
	_apply_bus_volume(BUS_SFX, sfx_volume)
	_apply_mute()
	_apply_fullscreen()
	_apply_vsync()


func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(linear) if linear > 0.0 else -80.0)


func _apply_mute() -> void:
	var idx := AudioServer.get_bus_index(BUS_MASTER)
	if idx != -1:
		AudioServer.set_bus_mute(idx, muted)


func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _apply_vsync() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)


# ── Typed setters (apply immediately + persist + notify) ──────────────────────

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(BUS_MASTER, master_volume)
	save_settings()
	setting_changed.emit("master_volume", master_volume)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(BUS_MUSIC, music_volume)
	save_settings()
	setting_changed.emit("music_volume", music_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(BUS_SFX, sfx_volume)
	save_settings()
	setting_changed.emit("sfx_volume", sfx_volume)


func set_muted(value: bool) -> void:
	muted = value
	_apply_mute()
	save_settings()
	setting_changed.emit("muted", muted)


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_fullscreen()
	save_settings()
	setting_changed.emit("fullscreen", fullscreen)


func set_vsync(value: bool) -> void:
	vsync = value
	_apply_vsync()
	save_settings()
	setting_changed.emit("vsync", vsync)


func set_screen_shake(value: float) -> void:
	screen_shake = clampf(value, 0.0, 1.0)
	save_settings()
	setting_changed.emit("screen_shake", screen_shake)


# ── Accessibility setters ──────────────────────────────────────────────────────

func set_damage_numbers_enabled(value: bool) -> void:
	damage_numbers_enabled = value
	save_settings()
	setting_changed.emit("damage_numbers_enabled", damage_numbers_enabled)


func set_screen_flash_intensity(value: float) -> void:
	screen_flash_intensity = clampf(value, 0.0, 1.0)
	save_settings()
	setting_changed.emit("screen_flash_intensity", screen_flash_intensity)


func set_text_size(value: int) -> void:
	if not TEXT_SIZE_SCALE.has(value):
		return
	text_size = value
	save_settings()
	setting_changed.emit("text_size", text_size)


## Multiplier to apply to any HUD/UI font_size before add_theme_font_size_override.
func get_text_scale() -> float:
	return TEXT_SIZE_SCALE[text_size]


## ── Gameplay setters ──────────────────────────────────────────────────────────

func set_auto_aim(value: bool) -> void:
	auto_aim = value
	save_settings()
	setting_changed.emit("auto_aim", auto_aim)


func set_colorblind_mode(value: bool) -> void:
	colorblind_mode = value
	save_settings()
	setting_changed.emit("colorblind_mode", colorblind_mode)


# ── Controls rebinding ──────────────────────────────────────────────────────────

## Returns the InputEvents currently bound to `action` (override if present,
## else the project.godot default).
func get_action_events(action: String) -> Array[InputEvent]:
	if _action_overrides.has(action):
		var events: Array[InputEvent] = []
		for e in _action_overrides[action]:
			events.append(e)
		return events
	return InputMap.action_get_events(action)


## Returns the action (other than `except_action`) that already uses an event
## equivalent to `event`, or "" if none. Used for conflict detection.
func find_conflicting_action(event: InputEvent, except_action: String) -> String:
	for action in REBINDABLE_ACTIONS:
		if action == except_action:
			continue
		for bound in get_action_events(action):
			if _events_match(bound, event):
				return action
	return ""


func _events_match(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode and a.keycode == b.keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)
	return false


## Which binding slot an event occupies: "pad" for joypad buttons/motions,
## "kb" for keyboard/mouse. Each action holds one binding per device class,
## and rebinding one class never touches the other.
static func device_class(event: InputEvent) -> String:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return "pad"
	return "kb"


## Events of `action` belonging to one device class ("kb" or "pad").
func get_action_events_for_class(action: String, cls: String) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	for e in get_action_events(action):
		if device_class(e) == cls:
			out.append(e)
	return out


## Rebinds `action`'s slot for the event's device class, preserving the other
## class's bindings (a controller rebind must never wipe the keyboard key, and
## vice versa). Does NOT check for conflicts — caller (UI) resolves those via
## find_conflicting_action() first and calls remove_matching_events() on the
## loser if the user chooses to swap.
func rebind_action(action: String, event: InputEvent) -> void:
	if not action in REBINDABLE_ACTIONS:
		return
	var cls := device_class(event)
	var kept: Array[InputEvent] = []
	for e in get_action_events(action):
		if device_class(e) != cls:
			kept.append(e)
	kept.append(event)
	_action_overrides[action] = kept
	_apply_binding_overrides()
	save_settings()
	bindings_changed.emit()


## Removes just the events equivalent to `event` from `action` (used when
## swapping a conflicting binding away — the loser keeps its other-device
## bindings rather than being cleared outright).
func remove_matching_events(action: String, event: InputEvent) -> void:
	if not action in REBINDABLE_ACTIONS:
		return
	var kept: Array[InputEvent] = []
	for e in get_action_events(action):
		if not _events_match(e, event):
			kept.append(e)
	_action_overrides[action] = kept
	_apply_binding_overrides()
	save_settings()
	bindings_changed.emit()


## Removes all events from `action`.
func clear_binding(action: String) -> void:
	if not action in REBINDABLE_ACTIONS:
		return
	_action_overrides[action] = []
	_apply_binding_overrides()
	save_settings()
	bindings_changed.emit()


func reset_bindings_to_defaults() -> void:
	_action_overrides.clear()
	_apply_binding_overrides()
	save_settings()
	bindings_changed.emit()


func _apply_binding_overrides() -> void:
	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		var events: Array = _action_overrides.get(action, _default_events.get(action, []))
		for e in events:
			InputMap.action_add_event(action, e)
