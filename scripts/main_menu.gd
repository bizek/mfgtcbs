extends Control

## Main Menu — title screen. Boots first; Continue/New Game route into the game.
## New player (no save) skips the hub entirely on New Game — first boot fast path (D4).
## Returning player (save exists) keeps menu -> hub via Continue.

const PIXEL_FONT := preload("res://assets/fonts/m5x7.ttf")

const C_CARD    := Color(0.082, 0.075, 0.063)
const C_CARD_HI := Color(0.102, 0.092, 0.076)
const C_BORDER  := Color(0.165, 0.145, 0.125)
const C_B_ACT   := Color(0.690, 0.353, 0.082)

const C_AMBER    := Color(0.831, 0.447, 0.102)
const C_AMBER_HI := Color(0.941, 0.565, 0.188)
const C_AMBER_LO := Color(0.353, 0.173, 0.031)

const C_RED    := Color(0.659, 0.118, 0.063)
const C_RED_HI := Color(0.820, 0.157, 0.063)

const C_T0 := Color(0.800, 0.690, 0.565)
const C_T1 := Color(0.541, 0.408, 0.282)
const C_T2 := Color(0.314, 0.235, 0.157)

const FS_TITLE := 40
const FS_SUB   := 16
const FS_BTN   := 20
const FS_XS    := 14

var _menu_buttons: Array[Button] = []
var _confirm_overlay: Control = null
var _toast_label: Label = null
var _toast_timer: float = 0.0

func _ready() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	_build_background()
	_build_title()
	_build_button_panel()
	_build_version_label()
	_build_toast()
	## Title shares the hub track — the crossfade into the hub is then a no-op.
	AudioManager.play_music("mus_hub")
	var tree_panel := preload("res://scripts/ui/passive_tree_debug_panel.gd").new()
	add_child(tree_panel)

func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_label.visible = false

# ── Background ──────────────────────────────────────────────────────────────

func _build_background() -> void:
	var map_scene := load("res://assets/Maps/Base Camp/Map.tscn") as PackedScene
	if map_scene:
		var map_inst := map_scene.instantiate()
		add_child(map_inst)
		move_child(map_inst, 0)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.02, 0.018, 0.014, 0.80)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

# ── Title ───────────────────────────────────────────────────────────────────

func _build_title() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	vbox.position = Vector2(0, 44)
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	var title := Label.new()
	title.text = "EXTRACTION SURVIVORS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", PIXEL_FONT)
	title.add_theme_font_size_override("font_size", FS_TITLE)
	title.add_theme_color_override("font_color", C_AMBER)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "descend. loot. extract."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.add_theme_font_override("font", PIXEL_FONT)
	subtitle.add_theme_font_size_override("font_size", FS_SUB)
	subtitle.add_theme_color_override("font_color", C_T1)
	vbox.add_child(subtitle)

# ── Button panel ────────────────────────────────────────────────────────────

func _build_button_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -100.0
	panel.offset_right = 100.0
	panel.offset_top = -95.0
	panel.offset_bottom = 95.0
	panel.custom_minimum_size = Vector2(200, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_CARD
	sb.border_color = C_BORDER
	sb.set_border_width_all(1)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var has_save: bool = ProgressionManager.has_save()

	var continue_btn := _make_button("CONTINUE", C_AMBER, C_AMBER_HI)
	continue_btn.visible = has_save
	continue_btn.pressed.connect(_on_continue_pressed)
	vbox.add_child(continue_btn)
	if has_save:
		_menu_buttons.append(continue_btn)

	var new_game_btn := _make_button("NEW GAME", C_T0, C_AMBER_HI)
	new_game_btn.pressed.connect(_on_new_game_pressed)
	vbox.add_child(new_game_btn)
	_menu_buttons.append(new_game_btn)

	var settings_btn := _make_button("SETTINGS", C_T0, C_AMBER_HI)
	settings_btn.pressed.connect(_on_settings_pressed)
	vbox.add_child(settings_btn)
	_menu_buttons.append(settings_btn)

	var credits_btn := _make_button("CREDITS", C_T0, C_AMBER_HI)
	credits_btn.pressed.connect(_on_credits_pressed)
	vbox.add_child(credits_btn)
	_menu_buttons.append(credits_btn)

	var quit_btn := _make_button("QUIT", C_T0, C_RED_HI)
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)
	_menu_buttons.append(quit_btn)

	_wire_focus_chain()
	_menu_buttons[0].grab_focus()

func _make_button(label: String, normal_col: Color, hover_col: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(180, 28)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_override("font", PIXEL_FONT)
	btn.add_theme_font_size_override("font_size", FS_BTN)
	btn.add_theme_color_override("font_color", normal_col)
	btn.add_theme_color_override("font_hover_color", hover_col)
	btn.add_theme_color_override("font_focus_color", hover_col)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = C_CARD_HI if state in ["hover", "pressed"] else Color(0, 0, 0, 0)
		sb.set_content_margin_all(4)
		btn.add_theme_stylebox_override(state, sb)
	var focus_sb := StyleBoxFlat.new()
	focus_sb.bg_color = C_CARD_HI
	focus_sb.border_color = C_B_ACT
	focus_sb.set_border_width_all(1)
	focus_sb.set_content_margin_all(4)
	btn.add_theme_stylebox_override("focus", focus_sb)
	return btn

func _wire_focus_chain() -> void:
	var n := _menu_buttons.size()
	for i in range(n):
		var next_btn: Button = _menu_buttons[(i + 1) % n]
		var prev_btn: Button = _menu_buttons[(i - 1 + n) % n]
		_menu_buttons[i].focus_neighbor_bottom = _menu_buttons[i].get_path_to(next_btn)
		_menu_buttons[i].focus_neighbor_top = _menu_buttons[i].get_path_to(prev_btn)
		_menu_buttons[i].focus_next = _menu_buttons[i].get_path_to(next_btn)
		_menu_buttons[i].focus_previous = _menu_buttons[i].get_path_to(prev_btn)

# ── Version label ───────────────────────────────────────────────────────────

func _build_version_label() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
	var lbl := Label.new()
	lbl.text = "v%s" % version
	lbl.add_theme_font_override("font", PIXEL_FONT)
	lbl.add_theme_font_size_override("font_size", FS_XS)
	lbl.add_theme_color_override("font_color", C_T2)
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	lbl.position = Vector2(-40, -16)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)

# ── Toast (stub notices for unbuilt panels) ─────────────────────────────────

func _build_toast() -> void:
	_toast_label = Label.new()
	_toast_label.add_theme_font_override("font", PIXEL_FONT)
	_toast_label.add_theme_font_size_override("font_size", FS_XS)
	_toast_label.add_theme_color_override("font_color", C_T1)
	_toast_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_toast_label.position = Vector2(0, -34)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.visible = false
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_label)

func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.visible = true
	_toast_timer = 1.6

# ── Button handlers ─────────────────────────────────────────────────────────

func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/hub.tscn")

func _on_new_game_pressed() -> void:
	if ProgressionManager.has_save():
		_show_confirm_dialog()
	else:
		_start_new_game()

func _on_settings_pressed() -> void:
	if ResourceLoader.exists("res://scripts/ui/settings_panel.gd"):
		var panel: Control = (load("res://scripts/ui/settings_panel.gd") as GDScript).new()
		panel.close_requested.connect(func():
			panel.queue_free()
			_menu_buttons[0].grab_focus.call_deferred()
		)
		add_child(panel)
		UINav.focus_first(panel)
	else:
		_show_toast("Settings — coming soon")

func _on_credits_pressed() -> void:
	if ResourceLoader.exists("res://scenes/credits.tscn"):
		get_tree().change_scene_to_file("res://scenes/credits.tscn")
	else:
		_show_toast("Credits — coming soon")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _start_new_game() -> void:
	ProgressionManager.reset_save()
	get_tree().change_scene_to_file("res://scenes/main_arena.tscn")

# ── New Game overwrite confirmation ─────────────────────────────────────────

func _show_confirm_dialog() -> void:
	if _confirm_overlay:
		return

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0, 0, 0, 0.65)
	add_child(scrim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -150.0
	panel.offset_right = 150.0
	panel.offset_top = -50.0
	panel.offset_bottom = 50.0
	panel.custom_minimum_size = Vector2(300, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_CARD
	sb.border_color = C_RED
	sb.set_border_width_all(1)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	scrim.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var msg := Label.new()
	msg.text = "Starting a new game will erase\nyour current save. Continue?"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_override("font", PIXEL_FONT)
	msg.add_theme_font_size_override("font_size", FS_XS)
	msg.add_theme_color_override("font_color", C_T0)
	vbox.add_child(msg)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var cancel_btn := _make_button("CANCEL", C_T0, C_AMBER_HI)
	cancel_btn.custom_minimum_size = Vector2(90, 26)
	cancel_btn.pressed.connect(_on_confirm_cancel)
	btn_row.add_child(cancel_btn)

	var confirm_btn := _make_button("ERASE & START", C_RED, C_RED_HI)
	confirm_btn.custom_minimum_size = Vector2(90, 26)
	confirm_btn.pressed.connect(_on_confirm_erase)
	btn_row.add_child(confirm_btn)

	_confirm_overlay = scrim
	cancel_btn.grab_focus()

func _on_confirm_cancel() -> void:
	if _confirm_overlay:
		_confirm_overlay.queue_free()
		_confirm_overlay = null
	_menu_buttons[0].grab_focus()

func _on_confirm_erase() -> void:
	if _confirm_overlay:
		_confirm_overlay.queue_free()
		_confirm_overlay = null
	_start_new_game()
