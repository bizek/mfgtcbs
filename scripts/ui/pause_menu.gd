extends CanvasLayer

## PauseMenu — ESC opens/closes. Shows Resume + Debug Panel toggle.
## process_mode = ALWAYS so it runs while tree is paused.

var _panel: ColorRect
var _debug_panel_ref: Node = null  ## Set by main_arena if debug mode is on

func _ready() -> void:
	layer = 126  ## Below debug panel (127), above game
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode != KEY_ESCAPE:
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

	_toggle_pause()
	get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	if _panel.visible:
		_close()
	else:
		_open()


func _open() -> void:
	_panel.visible = true
	GameManager.set_paused(true)


func _close() -> void:
	_panel.visible = false
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
	title.add_theme_font_size_override("font_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(1.0, 1.0, 1.0)
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	## Resume button
	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.add_theme_font_size_override("font_size", 10)
	resume_btn.pressed.connect(_close)
	vbox.add_child(resume_btn)

	## Debug panel button (only if debug mode)
	if GameManager.debug_mode:
		var debug_btn := Button.new()
		debug_btn.text = "Debug Panel"
		debug_btn.add_theme_font_size_override("font_size", 10)
		debug_btn.pressed.connect(_toggle_debug_panel)
		vbox.add_child(debug_btn)

	## ESC hint
	var hint := Label.new()
	hint.text = "[ESC] to close"
	hint.add_theme_font_size_override("font_size", 8)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(0.5, 0.5, 0.5)
	vbox.add_child(hint)

	_panel = backdrop
	_panel.visible = false


func _toggle_debug_panel() -> void:
	if _debug_panel_ref and _debug_panel_ref.has_method("_toggle_panel"):
		_debug_panel_ref._toggle_panel()
