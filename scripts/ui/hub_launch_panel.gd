@tool
extends Control

## Launch Pad panel — shows current loadout and hosts the BEGIN DESCENT button.

signal close_requested

const _FONT := HubPanelBase.PIXEL_FONT
const _FS_LG := 21
const _FS_MD := 19
const _FS_SM := 16
const _FS_XS := 13

@onready var _base:    HubPanelBase = $PanelBase
@onready var _content: Control      = $PanelBase/ContentContainer

func _ready() -> void:
	_base.close_requested.connect(func(): close_requested.emit())
	if Engine.is_editor_hint():
		return
	populate(ProgressionManager)


func populate(pm: Node) -> void:
	for child in _content.get_children():
		child.queue_free()

	var char_id: String       = pm.selected_character
	var char_data: Dictionary = CharacterData.ALL.get(char_id, CharacterData.ALL["The Drifter"])
	var char_col: Color       = char_data.get("color", Color(0.92, 0.86, 0.60))
	var slot_count: int       = pm.starting_weapon_slots() if char_id == "The Drifter" else 1

	## ── Root layout ──────────────────────────────────────────────────────────
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("margin_left",   10)
	root.add_theme_constant_override("margin_top",     8)
	root.add_theme_constant_override("margin_right",  10)
	root.add_theme_constant_override("margin_bottom",  8)
	_content.add_child(root)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	root.add_child(vbox)

	## ── Loadout card ─────────────────────────────────────────────────────────
	var card := Panel.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cs := StyleBoxFlat.new()
	cs.bg_color            = Color(0.082, 0.075, 0.063)
	cs.border_color        = Color(0.165, 0.145, 0.125)
	cs.border_width_left   = 1
	cs.border_width_top    = 1
	cs.border_width_right  = 1
	cs.border_width_bottom = 1
	cs.set_content_margin_all(0)
	card.add_theme_stylebox_override("panel", cs)
	vbox.add_child(card)

	var cm := MarginContainer.new()
	cm.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	cm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cm.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	cm.add_theme_constant_override("margin_left",   8)
	cm.add_theme_constant_override("margin_top",    6)
	cm.add_theme_constant_override("margin_right",  8)
	cm.add_theme_constant_override("margin_bottom", 6)
	card.add_child(cm)

	var inner := VBoxContainer.new()
	inner.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 5)
	cm.add_child(inner)

	## ── Section header ───────────────────────────────────────────────────────
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 5)
	inner.add_child(hdr)

	_lbl(hdr, "DEPLOYMENT BRIEF", _FS_SM, Color(0.314, 0.235, 0.157))

	var amber_rule := ColorRect.new()
	amber_rule.custom_minimum_size   = Vector2(0, 1)
	amber_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amber_rule.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	amber_rule.color                 = Color(0.831, 0.447, 0.102, 0.60)
	hdr.add_child(amber_rule)

	## ── Character row ────────────────────────────────────────────────────────
	_row(inner, "CHARACTER", char_data.get("display_name", char_id), char_col)

	## ── Weapon rows ──────────────────────────────────────────────────────────
	if slot_count >= 2:
		for s in range(1, slot_count + 1):
			var w: String
			match s:
				1: w = pm.selected_weapon
				2: w = pm.selected_weapon_2
				3: w = pm.selected_weapon_3
			if (w as String).is_empty():
				w = "\u2014 none \u2014"
			_row(inner, "SLOT %d" % s, w, Color(0.800, 0.690, 0.565))
	else:
		var starting_weapon: String = char_data.get("starting_weapon", pm.selected_weapon)
		if char_id == "The Drifter":
			starting_weapon = pm.selected_weapon
		_row(inner, "WEAPON", starting_weapon, Color(0.800, 0.690, 0.565))

		if char_id != "The Drifter":
			var passive_desc: String = char_data.get("passive_desc", "")
			if not passive_desc.is_empty():
				_row_passive(inner, "PASSIVE", passive_desc)

	## ── Spacer pushes button to bottom ───────────────────────────────────────
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	## ── Separator ────────────────────────────────────────────────────────────
	var sep := ColorRect.new()
	sep.custom_minimum_size   = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sep.color                 = Color(0.165, 0.145, 0.125)
	vbox.add_child(sep)

	## ── BEGIN DESCENT button ─────────────────────────────────────────────────
	var btn := Button.new()
	btn.text                  = "BEGIN DESCENT"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode            = Control.FOCUS_NONE
	btn.add_theme_font_override("font", _FONT)
	btn.add_theme_font_size_override("font_size", _FS_LG)
	btn.add_theme_color_override("font_color",       Color(0.820, 0.157, 0.063))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.2))
	_style_begin_btn(btn)
	btn.pressed.connect(_start_run)
	vbox.add_child(btn)


func _start_run() -> void:
	get_tree().change_scene_to_file("res://scenes/main_arena.tscn")


func _row(parent: Control, label: String, value: String, val_col: Color) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.custom_minimum_size = Vector2(0, 20)
	parent.add_child(hb)

	var lbl := Label.new()
	lbl.text                = label
	lbl.custom_minimum_size = Vector2(72, 0)
	lbl.add_theme_font_override("font", _FONT)
	lbl.add_theme_font_size_override("font_size", _FS_XS)
	lbl.add_theme_color_override("font_color", Color(0.314, 0.235, 0.157))
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(lbl)

	var val := Label.new()
	val.text                  = value
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.add_theme_font_override("font", _FONT)
	val.add_theme_font_size_override("font_size", _FS_MD)
	val.add_theme_color_override("font_color", val_col)
	val.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	hb.add_child(val)


func _row_passive(parent: Control, label: String, desc: String) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	parent.add_child(hb)

	var lbl := Label.new()
	lbl.text                = label
	lbl.custom_minimum_size = Vector2(72, 0)
	lbl.add_theme_font_override("font", _FONT)
	lbl.add_theme_font_size_override("font_size", _FS_XS)
	lbl.add_theme_color_override("font_color", Color(0.314, 0.235, 0.157))
	lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(lbl)

	var val := Label.new()
	val.text                  = desc
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
	val.add_theme_font_override("font", _FONT)
	val.add_theme_font_size_override("font_size", _FS_XS)
	val.add_theme_color_override("font_color", Color(0.541, 0.408, 0.282))
	hb.add_child(val)


func _style_begin_btn(btn: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		var hot: bool = state in ["hover", "pressed"]
		sb.bg_color            = Color(0.353, 0.173, 0.031) if hot else Color(0.082, 0.075, 0.063)
		sb.border_width_left   = 1
		sb.border_width_top    = 1
		sb.border_width_right  = 1
		sb.border_width_bottom = 1
		sb.border_color        = Color(0.690, 0.353, 0.082)
		sb.set_content_margin(SIDE_TOP,    6)
		sb.set_content_margin(SIDE_BOTTOM, 6)
		sb.set_content_margin(SIDE_LEFT,   8)
		sb.set_content_margin(SIDE_RIGHT,  8)
		btn.add_theme_stylebox_override(state, sb)


func _lbl(parent: Control, text: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _FONT)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(l)
	return l
