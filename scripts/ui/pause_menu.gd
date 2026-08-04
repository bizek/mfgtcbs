extends CanvasLayer


## PauseMenu — ESC / controller Start opens/closes. Shows Resume, Settings, Abandon Run,
## and (in debug mode) the Debug Panel toggle.
## process_mode = ALWAYS so it runs while tree is paused.

const SettingsPanelScript := preload("res://scripts/ui/settings_panel.gd")

var _panel: ColorRect
var _debug_panel_ref: Node = null  ## Set by main_arena if debug mode is on
var _settings_panel: Control = null
var _resume_btn: Button = null
var _abandon_btn: Button = null
## Abandon is two presses, not one: the button re-labels itself into a confirmation and only the
## SECOND press ends the run. A single mis-click on the pause menu must never cost a descent.
var _abandon_armed: bool = false

func _ready() -> void:
	layer = 126  ## Below debug panel (127), above game
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or event.is_echo():
		return

	## Don't open during game-over, extraction success, or level-up screens
	var state := GameManager.current_state
	if state == GameManager.GameState.GAME_OVER \
			or state == GameManager.GameState.EXTRACTION_SUCCESS \
			or state == GameManager.GameState.LEVEL_UP:
		return

	## Only pause/unpause during active run or extracting
	if state != GameManager.GameState.RUN_ACTIVE \
			and state != GameManager.GameState.EXTRACTING:
		return

	if _settings_panel and _settings_panel.visible:
		_close_settings()
	else:
		_toggle_pause()
	get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	if _panel.visible:
		_close()
	else:
		_open()


func _open() -> void:
	AudioManager.play_ui("sfx_ui_panel_open")
	_panel.visible = true
	GameManager.set_paused(true)
	UINav.focus_first(_panel)


func _close() -> void:
	AudioManager.play_ui("sfx_ui_panel_close")
	_panel.visible = false
	_disarm_abandon()   ## never leave a primed Abandon waiting behind a closed menu
	GameManager.set_paused(false)


func _build_menu() -> void:
	## Semi-transparent full-screen backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.45)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP  ## Block clicks to game
	add_child(backdrop)

	## Centered panel
	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pc.grow_vertical = Control.GROW_DIRECTION_BOTH
	backdrop.add_child(pc)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.12, 0.95)
	bg.set_corner_radius_all(4)
	bg.set_content_margin_all(12.0)
	pc.add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(120.0, 0.0)
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pc.add_child(vbox)

	## Title
	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 16)
	_apply_pixel_font(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(1.0, 1.0, 1.0)
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	## Resume button
	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.add_theme_font_size_override("font_size", 16)
	_apply_pixel_font(resume_btn)
	resume_btn.pressed.connect(_close)
	UINav.apply_focus_ring(resume_btn)
	vbox.add_child(resume_btn)

	## Settings button
	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.add_theme_font_size_override("font_size", 16)
	_apply_pixel_font(settings_btn)
	settings_btn.pressed.connect(func():
		AudioManager.play_ui("sfx_ui_click")
		_open_settings())
	UINav.apply_focus_ring(settings_btn)
	vbox.add_child(settings_btn)

	## Abandon Run — leave a descent early and settle it like a death (Ben 2026-08-01). Red so it
	## never reads as a neutral option, and armed by a second press (see _on_abandon_pressed).
	var abandon_btn := Button.new()
	abandon_btn.text = "Abandon Run"
	abandon_btn.add_theme_font_size_override("font_size", 16)
	_apply_pixel_font(abandon_btn)
	abandon_btn.add_theme_color_override("font_color", Color(1.0, 0.42, 0.36))
	abandon_btn.pressed.connect(_on_abandon_pressed)
	UINav.apply_focus_ring(abandon_btn)
	vbox.add_child(abandon_btn)
	_abandon_btn = abandon_btn

	## Debug panel button (only if debug mode)
	if GameManager.debug_mode:
		var debug_btn := Button.new()
		debug_btn.text = "Debug Panel"
		debug_btn.add_theme_font_size_override("font_size", 16)
		_apply_pixel_font(debug_btn)
		debug_btn.pressed.connect(_toggle_debug_panel)
		UINav.apply_focus_ring(debug_btn)
		vbox.add_child(debug_btn)

	## Glyph hint bar — replaces the static "[ESC] to close" label so it
	## reflects keyboard or controller depending on what's active.
	var glyph_bar := GlyphBar.build([["confirm", "Select"], ["back", "Close"]])
	vbox.add_child(glyph_bar)

	_panel = backdrop
	_panel.visible = false
	_resume_btn = resume_btn


## First press arms and re-labels; second press ends the run. GameManager.abandon_run() settles it
## exactly like a death (25% salvage, mid-run gear rolled back) and the game-over screen — which is
## already listening for run_abandoned — takes over from there, so the tree stays paused until the
## player picks "Return to Hub" and the run's stats are recorded the same way they always are.
func _on_abandon_pressed() -> void:
	if not _abandon_armed:
		_abandon_armed = true
		AudioManager.play_ui("sfx_ui_click")
		_abandon_btn.text = "Confirm — lose your haul?"
		return
	_disarm_abandon()
	_panel.visible = false
	GameManager.abandon_run()


func _disarm_abandon() -> void:
	_abandon_armed = false
	if _abandon_btn:
		_abandon_btn.text = "Abandon Run"


func _toggle_debug_panel() -> void:
	if _debug_panel_ref and _debug_panel_ref.has_method("_toggle_panel"):
		_debug_panel_ref._toggle_panel()


func _open_settings() -> void:
	_panel.visible = false
	if _settings_panel == null:
		_settings_panel = SettingsPanelScript.new()
		_settings_panel.close_requested.connect(_close_settings)
		add_child(_settings_panel)
	_settings_panel.visible = true
	UINav.focus_first(_settings_panel)


func _close_settings() -> void:
	if _settings_panel:
		_settings_panel.visible = false
	_panel.visible = true
	if _resume_btn:
		_resume_btn.grab_focus.call_deferred()


## ── Pixel font ────────────────────────────────────────────────────────────────
## Every site in this file set a font_size but no FONT, so the text rendered in Godot's default
## vector font — antialiased at 640x360, then nearest-upscaled 3x into mush. It is the same bug
## game_over_screen.gd shipped with, and a font_size override on its own does nothing to fix it.
const PIXEL_FONT_PATH: String = "res://assets/fonts/m5x7.ttf"


func _apply_pixel_font(c: Control) -> void:
	if not ResourceLoader.exists(PIXEL_FONT_PATH):
		return
	c.add_theme_font_override("font", load(PIXEL_FONT_PATH))
