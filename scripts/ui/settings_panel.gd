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

var _base: HubPanelBase = null


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


func _build_ui() -> void:
	var content := _base.get_content()

	var tabs := TabContainer.new()
	tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	tabs.offset_left   = 6.0
	tabs.offset_top    = 4.0
	tabs.offset_right  = -6.0
	tabs.offset_bottom = -4.0
	tabs.add_theme_font_override("font", FONT)
	tabs.add_theme_font_size_override("font_size", FS_SM)
	tabs.add_theme_color_override("font_selected_color", C_AMBER_HI)
	tabs.add_theme_color_override("font_unselected_color", C_T2)
	content.add_child(tabs)

	tabs.add_child(_build_audio_tab())
	tabs.add_child(_build_display_tab())


func _build_scroll_vbox(tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO

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

	return vbox.get_parent()


func _build_display_tab() -> Control:
	var vbox := _build_scroll_vbox("DISPLAY")

	_checkbox_row(vbox, "Fullscreen", Settings.fullscreen,
		func(v: bool): Settings.set_fullscreen(v))
	_checkbox_row(vbox, "Vsync", Settings.vsync,
		func(v: bool): Settings.set_vsync(v))
	_slider_row(vbox, "Screen Shake", Settings.screen_shake,
		func(v: float): Settings.set_screen_shake(v))

	return vbox.get_parent()


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
