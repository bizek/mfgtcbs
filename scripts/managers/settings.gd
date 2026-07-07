extends Node

## Settings — persisted user preferences (audio, display, screen shake).
## Separate from ProgressionManager's save; lives at user://settings.cfg.
## Applied on startup before the first scene needs them (autoload order).

signal setting_changed(key: String, value: Variant)

const SAVE_PATH := "user://settings.cfg"
const SECTION := "settings"

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

const DEFAULTS := {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"muted": false,
	"fullscreen": false,
	"vsync": true,
	"screen_shake": 1.0,
}

var master_volume: float = DEFAULTS["master_volume"]
var music_volume: float = DEFAULTS["music_volume"]
var sfx_volume: float = DEFAULTS["sfx_volume"]
var muted: bool = DEFAULTS["muted"]
var fullscreen: bool = DEFAULTS["fullscreen"]
var vsync: bool = DEFAULTS["vsync"]
var screen_shake: float = DEFAULTS["screen_shake"]  ## 0.0-1.0 multiplier read by camera shake / juice pass


func _ready() -> void:
	load_settings()
	_apply_all()


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

	master_volume = clampf(master_volume, 0.0, 1.0)
	music_volume  = clampf(music_volume, 0.0, 1.0)
	sfx_volume    = clampf(sfx_volume, 0.0, 1.0)
	screen_shake  = clampf(screen_shake, 0.0, 1.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "master_volume", master_volume)
	cfg.set_value(SECTION, "music_volume", music_volume)
	cfg.set_value(SECTION, "sfx_volume", sfx_volume)
	cfg.set_value(SECTION, "muted", muted)
	cfg.set_value(SECTION, "fullscreen", fullscreen)
	cfg.set_value(SECTION, "vsync", vsync)
	cfg.set_value(SECTION, "screen_shake", screen_shake)
	cfg.save(SAVE_PATH)


func _reset_to_defaults() -> void:
	master_volume = DEFAULTS["master_volume"]
	music_volume  = DEFAULTS["music_volume"]
	sfx_volume    = DEFAULTS["sfx_volume"]
	muted         = DEFAULTS["muted"]
	fullscreen    = DEFAULTS["fullscreen"]
	vsync         = DEFAULTS["vsync"]
	screen_shake  = DEFAULTS["screen_shake"]


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
