@tool
extends Control

## Settings panel — Audio (volume sliders + mute) and Display (fullscreen,
## vsync, screen shake) tabs. Script-only panel; builds its own HubPanelBase
## at runtime, matching the hub_research_panel.gd pattern.
##
## Rebinding + accessibility (task 12) get their own TabContainer tabs later;
## this layout (one VBox of rows per tab, wrapped in a ScrollContainer) is
## built so those tabs slot in without restructuring.

signal close_requested

const _PANEL_BASE_SCENE := preload("res://scenes/ui/hub_panel_base.tscn")

## ── Color palette (matches hub_research_panel.gd / hub_armory_panel.gd) ──────
const C_CARD     := Color(0.082, 0.075, 0.063)
const C_BORDER   := Color(0.165, 0.145, 0.125)
const C_AMBER    := Color(0.831, 0.447, 0.102)
const C_AMBER_HI := Color(0.941, 0.565, 0.188)
const C_AMBER_LO := Color(0.353, 0.173, 0.031)
const C_T0       := Color(0.800, 0.690, 0.565)
const C_T2       := Color(0.314, 0.235, 0.157)

const FONT  := HubPanelBase.PIXEL_FONT
const FS_SM := 16
const FS_MD := 19
const FS_XS := 14

const LABEL_W := 160.0
const VALUE_W := 56.0

## Friendly display names for rebindable actions (falls back to the raw
## action name if not listed here).
const ACTION_LABELS := {
	"move_up": "Move Up",
	"move_down": "Move Down",
	"move_left": "Move Left",
	"move_right": "Move Right",
	"fire": "Fire",
	"dash": "Dash",
	"interact": "Interact",
	"light_attack": "Light Attack",
	"heavy_attack": "Heavy Attack",
	"skill_q": "Skill (Q)",
	"skill_e": "Skill (E)",
}

const C_WARN := Color(0.85, 0.25, 0.2)

var _base: HubPanelBase = null
var _listening_action: String = ""  ## non-empty while capturing a rebind
var _bind_buttons: Dictionary = {}  ## action -> Button (updates label on rebind)
var _conflict_row: HBoxContainer = null
var _pending_conflict: Dictionary = {}  ## {action, event, conflict_action}
var _tabs: TabContainer = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left   = 60.0
	offset_top    = 4.0
	offset_right  = 580.0
	offset_bottom = 356.0

	_base = _PANEL_BASE_SCENE.instantiate()
	_base.title_text   = "SETTINGS"
	_base.accent_color  = C_AMBER
	_base.set_anchors_preset(Control.PRESET_FULL_RECT)
	## HubPanelBase.tscn ships with its own PANEL_W/PANEL_H offsets baked in
	## (offset_right=400, offset_bottom=267); set_anchors_preset(FULL_RECT)
	## doesn't clear those, so without this the base panel balloons past this
	## Control's real rect instead of matching it — invisible while every tab
	## was short, but it clips/overflows once a tab (Controls) grows past the
	## stale 400x267 footprint.
	_base.offset_left   = 0.0
	_base.offset_top    = 0.0
	_base.offset_right  = 0.0
	_base.offset_bottom = 0.0
	add_child(_base)
	_base.close_requested.connect(func(): close_requested.emit())

	if Engine.is_editor_hint():
		return
	_build_ui()


## No-op — kept so this panel can be opened through hub.gd's panel system
## (which calls populate(ProgressionManager) on every panel it instances)
## without special-casing settings.
func populate(_pm: Node) -> void:
	pass


## LB/RB cycle tabs — a TabContainer's tab strip isn't reachable by plain
## D-pad focus navigation, so this is the controller path. Bound to
## menu_switch_prev/next (joypad-only, see project.godot) rather than
## light_attack/heavy_attack, which are also bound to mouse buttons 1/2 and
## would otherwise flip tabs on every unrelated click in this panel.
func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree() or _tabs == null:
		return
	if _listening_action != "":
		return  ## rebind capture owns input right now
	if event.is_action_pressed("menu_switch_prev"):
		_tabs.current_tab = (_tabs.current_tab - 1 + _tabs.get_tab_count()) % _tabs.get_tab_count()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_switch_next"):
		_tabs.current_tab = (_tabs.current_tab + 1) % _tabs.get_tab_count()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var content := _base.get_content()

	var tabs := TabContainer.new()
	tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	tabs.offset_left   = 6.0
	tabs.offset_top    = 4.0
	tabs.offset_right  = -6.0
	tabs.offset_bottom = -18.0
	tabs.add_theme_font_override("font", FONT)
	tabs.add_theme_font_size_override("font_size", FS_SM)
	tabs.add_theme_color_override("font_selected_color", C_AMBER_HI)
	tabs.add_theme_color_override("font_unselected_color", C_T2)
	content.add_child(tabs)
	_tabs = tabs

	tabs.add_child(_build_audio_tab())
	tabs.add_child(_build_display_tab())
	tabs.add_child(_build_controls_tab())
	tabs.add_child(_build_accessibility_tab())

	var footer_hbox := HBoxContainer.new()
	footer_hbox.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer_hbox.offset_top = -14.0
	footer_hbox.alignment = BoxContainer.ALIGNMENT_END
	footer_hbox.add_theme_constant_override("separation", 8)
	content.add_child(footer_hbox)

	var version: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
	var version_lbl := Label.new()
	version_lbl.text = "v%s" % version
	version_lbl.add_theme_font_override("font", FONT)
	version_lbl.add_theme_font_size_override("font_size", FS_XS)
	version_lbl.add_theme_color_override("font_color", C_T2)
	footer_hbox.add_child(version_lbl)

	var glyph_bar := GlyphBar.build([["confirm", "Adjust"], ["back", "Close"], ["switch", "Switch Tab"]])
	var glyph_spacer := Control.new()
	glyph_spacer.custom_minimum_size = Vector2(0, 0)
	glyph_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hbox.add_child(glyph_spacer)
	footer_hbox.add_child(glyph_bar)


func _build_scroll_vbox(tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	## ScrollContainer otherwise reports its minimum size as its full content
	## size, which balloons the whole TabContainer/panel instead of clipping —
	## pin it small so tall tabs (Controls) actually scroll within the panel.
	scroll.custom_minimum_size = Vector2(0, 10)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)
	return vbox


func _build_audio_tab() -> Control:
	var vbox := _build_scroll_vbox("AUDIO")

	_slider_row(vbox, "Master Volume", Settings.master_volume,
		func(v: float): Settings.set_master_volume(v))
	_slider_row(vbox, "Music Volume", Settings.music_volume,
		func(v: float): Settings.set_music_volume(v))
	_slider_row(vbox, "SFX Volume", Settings.sfx_volume,
		func(v: float): Settings.set_sfx_volume(v))
	_checkbox_row(vbox, "Mute All", Settings.muted,
		func(v: bool): Settings.set_muted(v))

	UINav.wire_scroll_follow(vbox.get_parent() as ScrollContainer)
	return vbox.get_parent()


func _build_display_tab() -> Control:
	var vbox := _build_scroll_vbox("DISPLAY")

	_checkbox_row(vbox, "Fullscreen", Settings.fullscreen,
		func(v: bool): Settings.set_fullscreen(v))
	_checkbox_row(vbox, "Vsync", Settings.vsync,
		func(v: bool): Settings.set_vsync(v))
	_slider_row(vbox, "Screen Shake", Settings.screen_shake,
		func(v: float): Settings.set_screen_shake(v))

	UINav.wire_scroll_follow(vbox.get_parent() as ScrollContainer)
	return vbox.get_parent()


func _build_controls_tab() -> Control:
	var vbox := _build_scroll_vbox("CONTROLS")
	_bind_buttons.clear()

	for action in Settings.REBINDABLE_ACTIONS:
		_bind_row(vbox, action)

	_conflict_row = HBoxContainer.new()
	_conflict_row.visible = false
	_conflict_row.add_theme_constant_override("separation", 8)
	vbox.add_child(_conflict_row)

	var reset_row := HBoxContainer.new()
	reset_row.custom_minimum_size = Vector2(0, 26)
	vbox.add_child(reset_row)
	var reset_btn := Button.new()
	reset_btn.text = "Reset to Defaults"
	reset_btn.add_theme_font_override("font", FONT)
	reset_btn.add_theme_font_size_override("font_size", FS_SM)
	_base.style_btn(reset_btn, C_CARD, C_AMBER_LO)
	reset_row.add_child(reset_btn)
	reset_btn.pressed.connect(func():
		_cancel_listening()
		Settings.reset_bindings_to_defaults()
		_refresh_bind_buttons()
	)

	UINav.wire_scroll_follow(vbox.get_parent() as ScrollContainer)
	return vbox.get_parent()


func _bind_row(parent: Control, action: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 24)
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	_lbl(row, ACTION_LABELS.get(action, action), FS_SM, C_T0, LABEL_W)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(160, 0)
	btn.text = _binding_text(action)
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", FS_SM)
	_base.style_btn(btn, C_CARD, C_AMBER_LO)
	row.add_child(btn)
	_bind_buttons[action] = btn

	btn.pressed.connect(func(): _start_listening(action))


func _start_listening(action: String) -> void:
	if _listening_action != "":
		return
	_listening_action = action
	_bind_buttons[action].text = "Press any key... (Esc cancels)"


func _cancel_listening() -> void:
	if _listening_action != "":
		_bind_buttons[_listening_action].text = _binding_text(_listening_action)
	_listening_action = ""
	_hide_conflict_row()


## Uses _input (not _unhandled_input) so the capture fires before GUI
## controls (buttons under the cursor) can swallow the click/keypress.
func _input(event: InputEvent) -> void:
	if _listening_action == "":
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_listening()
		get_viewport().set_input_as_handled()
		return

	var captured: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		captured = event
	elif event is InputEventMouseButton and event.pressed:
		captured = event
	elif event is InputEventJoypadButton and event.pressed:
		captured = event

	if captured == null:
		return

	get_viewport().set_input_as_handled()
	var action := _listening_action
	var conflict := Settings.find_conflicting_action(captured, action)
	if conflict != "":
		_show_conflict(action, captured, conflict)
	else:
		_commit_bind(action, captured)


func _commit_bind(action: String, event: InputEvent) -> void:
	Settings.rebind_action(action, event)
	_listening_action = ""
	_hide_conflict_row()
	_refresh_bind_buttons()


func _show_conflict(action: String, event: InputEvent, conflict_action: String) -> void:
	_listening_action = ""  ## stop capturing so the Swap/Cancel click reaches the buttons
	_pending_conflict = {"action": action, "event": event, "conflict_action": conflict_action}
	_bind_buttons[action].text = _binding_text(action)

	for child in _conflict_row.get_children():
		child.queue_free()

	var msg := "%s already used by %s" % [
		event.as_text(), ACTION_LABELS.get(conflict_action, conflict_action)
	]
	var lbl := _lbl(_conflict_row, msg, FS_XS, C_WARN)
	lbl.custom_minimum_size = Vector2(280, 0)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD

	var swap_btn := Button.new()
	swap_btn.text = "Swap"
	swap_btn.add_theme_font_override("font", FONT)
	swap_btn.add_theme_font_size_override("font_size", FS_XS)
	_base.style_btn(swap_btn, C_CARD, C_AMBER_LO)
	_conflict_row.add_child(swap_btn)
	swap_btn.pressed.connect(func():
		Settings.clear_binding(conflict_action)
		_commit_bind(action, event)
	)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.add_theme_font_override("font", FONT)
	cancel_btn.add_theme_font_size_override("font_size", FS_XS)
	_base.style_btn(cancel_btn, C_CARD, C_AMBER_LO)
	_conflict_row.add_child(cancel_btn)
	cancel_btn.pressed.connect(func():
		_listening_action = ""
		_hide_conflict_row()
	)

	_conflict_row.visible = true


func _hide_conflict_row() -> void:
	if _conflict_row == null:
		return
	_conflict_row.visible = false
	for child in _conflict_row.get_children():
		child.queue_free()
	_pending_conflict.clear()


func _refresh_bind_buttons() -> void:
	for action in _bind_buttons:
		_bind_buttons[action].text = _binding_text(action)


func _binding_text(action: String) -> String:
	var events := Settings.get_action_events(action)
	if events.is_empty():
		return "(unbound)"
	return events[0].as_text().trim_suffix(" (Physical)")


func _build_accessibility_tab() -> Control:
	var vbox := _build_scroll_vbox("ACCESSIBILITY")

	_checkbox_row(vbox, "Damage Numbers", Settings.damage_numbers_enabled,
		func(v: bool): Settings.set_damage_numbers_enabled(v))
	_slider_row(vbox, "Screen Flash Intensity", Settings.screen_flash_intensity,
		func(v: float): Settings.set_screen_flash_intensity(v))
	_text_size_row(vbox)
	_checkbox_row(vbox, "Colorblind Palette", Settings.colorblind_mode,
		func(v: bool): Settings.set_colorblind_mode(v))
	_lbl(vbox, "* Text Size applies on next run/hub reload.", FS_XS, C_T2)

	UINav.wire_scroll_follow(vbox.get_parent() as ScrollContainer)
	return vbox.get_parent()


func _text_size_row(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 24)
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	_lbl(row, "Text Size", FS_SM, C_T0, LABEL_W)

	var opt := OptionButton.new()
	opt.add_theme_font_override("font", FONT)
	opt.add_theme_font_size_override("font_size", FS_SM)
	opt.add_item("Small", Settings.TextSize.SMALL)
	opt.add_item("Normal", Settings.TextSize.NORMAL)
	opt.add_item("Large", Settings.TextSize.LARGE)
	opt.select(opt.get_item_index(Settings.text_size))
	row.add_child(opt)

	opt.item_selected.connect(func(_idx: int):
		Settings.set_text_size(opt.get_selected_id())
	)


## Builds a "Label ── slider ── NN%" row. `initial` and the value passed to
## `on_change` are 0.0-1.0; the slider itself works in 0-100 steps.
func _slider_row(parent: Control, label_text: String, initial: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 24)
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	_lbl(row, label_text, FS_SM, C_T0, LABEL_W)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = roundf(initial * 100.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	_style_slider(slider)
	row.add_child(slider)

	var value_lbl := _lbl(row, "%d%%" % int(slider.value), FS_SM, C_T2, VALUE_W)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	slider.value_changed.connect(func(v: float):
		value_lbl.text = "%d%%" % int(v)
		on_change.call(v / 100.0)
	)


func _checkbox_row(parent: Control, label_text: String, initial: bool, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 24)
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	_lbl(row, label_text, FS_SM, C_T0, LABEL_W)

	var box := CheckBox.new()
	box.button_pressed = initial
	box.add_theme_font_override("font", FONT)
	box.add_theme_font_size_override("font_size", FS_SM)
	box.add_theme_color_override("font_color", C_T0)
	box.add_theme_color_override("font_hover_color", C_AMBER_HI)
	row.add_child(box)

	box.toggled.connect(func(v: bool): on_change.call(v))


func _style_slider(slider: HSlider) -> void:
	var groove := StyleBoxFlat.new()
	groove.bg_color = C_CARD
	groove.border_color = C_BORDER
	groove.set_border_width_all(1)
	groove.content_margin_top = 6
	groove.content_margin_bottom = 6
	slider.add_theme_stylebox_override("slider", groove)

	var fill := StyleBoxFlat.new()
	fill.bg_color = C_AMBER_LO
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)


func _lbl(parent: Control, text: String, font_size: int, color: Color, min_w: float = 0.0) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	if min_w > 0.0:
		lbl.custom_minimum_size = Vector2(min_w, 0)
	parent.add_child(lbl)
	return lbl
