@tool
extends Control

## Research Terminal — purchase weapon blueprints to unlock them in future runs.
## Script-only panel; builds its own HubPanelBase at runtime.

signal close_requested

const _PANEL_BASE_SCENE := preload("res://scenes/ui/hub_panel_base.tscn")

## ── Color palette ─────────────────────────────────────────────────────────────
const C_CARD     := Color(0.082, 0.075, 0.063)
const C_BORDER   := Color(0.165, 0.145, 0.125)
const C_AMBER    := Color(0.831, 0.447, 0.102)
const C_AMBER_HI := Color(0.941, 0.565, 0.188)
const C_AMBER_LO := Color(0.353, 0.173, 0.031)
const C_RED_HI   := Color(0.820, 0.157, 0.063)
const C_GREEN_HI := Color(0.314, 0.690, 0.188)
const C_T0       := Color(0.800, 0.690, 0.565)
const C_T2       := Color(0.314, 0.235, 0.157)

const FONT  := HubPanelBase.PIXEL_FONT
const FS_SM := 16
const FS_MD := 19
const FS_XS := 13

## ── State ─────────────────────────────────────────────────────────────────────
var _base:      HubPanelBase  = null
var _pm:        Node          = null
var _card_list: VBoxContainer = null
var _res_label: Label         = null
var _built:     bool          = false


func _ready() -> void:
	_base = _PANEL_BASE_SCENE.instantiate()
	_base.title_text   = "RESEARCH"
	_base.accent_color = C_AMBER
	add_child(_base)
	_base.close_requested.connect(func(): close_requested.emit())
	if Engine.is_editor_hint():
		return
	_build_ui()
	populate(ProgressionManager)


func populate(pm: Node) -> void:
	_pm = pm
	if _built:
		_refresh_cards()


# ── Build scaffolding (called once) ───────────────────────────────────────────

func _build_ui() -> void:
	var content := _base.get_content()

	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_theme_constant_override("margin_left",    10)
	outer.add_theme_constant_override("margin_top",      6)
	outer.add_theme_constant_override("margin_right",   10)
	outer.add_theme_constant_override("margin_bottom",   6)
	content.add_child(outer)

	var root_vbox := VBoxContainer.new()
	root_vbox.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 5)
	outer.add_child(root_vbox)

	## ── Header: label + amber rule + resource count
	var hdr := HBoxContainer.new()
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_theme_constant_override("separation", 5)
	hdr.custom_minimum_size = Vector2(0, 16)
	root_vbox.add_child(hdr)

	_lbl(hdr, "WEAPON RESEARCH", FS_SM, C_T2)

	var amber_rule := ColorRect.new()
	amber_rule.custom_minimum_size   = Vector2(0, 1)
	amber_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amber_rule.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	amber_rule.color                 = Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.60)
	hdr.add_child(amber_rule)

	_res_label = _lbl(hdr, "RES: —", FS_XS, C_T2)

	## ── ScrollContainer fills remaining height
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter           = Control.MOUSE_FILTER_IGNORE
	root_vbox.add_child(scroll)

	_card_list = VBoxContainer.new()
	_card_list.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	_card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_card_list)

	_built = true
	_refresh_cards()


# ── Rebuild weapon cards on every state change ────────────────────────────────

func _refresh_cards() -> void:
	if not _built:
		return
	for child in _card_list.get_children():
		child.queue_free()
	if _pm == null:
		return

	_res_label.text = "RES: %d" % _pm.resources

	for weapon_id: String in WeaponData.ALL:
		var wdata: Dictionary = WeaponData.ALL[weapon_id]
		if wdata.get("unlock_id", "").is_empty():
			continue
		_build_weapon_card(weapon_id, wdata)


func _build_weapon_card(weapon_id: String, wdata: Dictionary) -> void:
	var cost:     int    = wdata.get("blueprint_cost", 0)
	var display:  String = wdata.get("display_name", weapon_id)
	var desc:     String = wdata.get("description", "")
	var behavior: String = wdata.get("behavior", "")
	var owned:      bool = weapon_id in _pm.unlocked_weapons
	var can_afford: bool = (not owned) and (_pm.resources >= cost)

	var strip_col: Color = C_GREEN_HI if owned else (C_AMBER_HI if can_afford else C_BORDER)

	## Card Panel
	var card := Panel.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size   = Vector2(0, 52)
	var cs := StyleBoxFlat.new()
	cs.bg_color            = C_CARD
	cs.border_color        = C_BORDER
	cs.border_width_left   = 1
	cs.border_width_top    = 1
	cs.border_width_right  = 1
	cs.border_width_bottom = 1
	cs.set_content_margin_all(0)
	card.add_theme_stylebox_override("panel", cs)
	_card_list.add_child(card)

	## [3px strip | left content (expand) | right panel]
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	card.add_child(hbox)

	var strip := ColorRect.new()
	strip.custom_minimum_size = Vector2(3, 0)
	strip.color               = strip_col
	hbox.add_child(strip)

	## Left: name + behavior tag + description
	var lm := MarginContainer.new()
	lm.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	lm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lm.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	lm.add_theme_constant_override("margin_left",   6)
	lm.add_theme_constant_override("margin_top",    5)
	lm.add_theme_constant_override("margin_right",  4)
	lm.add_theme_constant_override("margin_bottom", 5)
	hbox.add_child(lm)

	var lv := VBoxContainer.new()
	lv.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 2)
	lm.add_child(lv)

	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_theme_constant_override("separation", 5)
	lv.add_child(name_row)

	_lbl(name_row, display.to_upper(), FS_MD, C_T0)
	if not behavior.is_empty():
		_lbl(name_row, "[%s]" % behavior.to_upper(), FS_XS, C_T2)

	var dl := Label.new()
	dl.text                  = desc
	dl.clip_text             = true
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dl.add_theme_font_override("font", FONT)
	dl.add_theme_font_size_override("font_size", FS_XS)
	dl.add_theme_color_override("font_color", C_T2)
	lv.add_child(dl)

	## Right: cost label + BUY/OWNED button, vertically centered
	var rm := MarginContainer.new()
	rm.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	rm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rm.add_theme_constant_override("margin_left",   4)
	rm.add_theme_constant_override("margin_top",    4)
	rm.add_theme_constant_override("margin_right",  6)
	rm.add_theme_constant_override("margin_bottom", 4)
	hbox.add_child(rm)

	var rv := VBoxContainer.new()
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rv.add_theme_constant_override("separation", 2)
	rm.add_child(rv)

	var cost_lbl := Label.new()
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_lbl.add_theme_font_override("font", FONT)
	cost_lbl.add_theme_font_size_override("font_size", FS_XS)
	if owned:
		cost_lbl.text = ""
	else:
		cost_lbl.text = "%d RES" % cost
		cost_lbl.add_theme_color_override("font_color",
			C_RED_HI if not can_afford else C_T2)
	rv.add_child(cost_lbl)

	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment  = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", FS_XS)

	if owned:
		btn.text     = "OWNED"
		btn.disabled = true
		btn.add_theme_color_override("font_color", C_GREEN_HI)
		_style_btn_flat(btn, Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	elif can_afford:
		btn.text     = "BUY"
		btn.disabled = false
		btn.add_theme_color_override("font_color",       C_AMBER)
		btn.add_theme_color_override("font_hover_color", C_AMBER_HI)
		_style_btn_flat(btn, Color(0, 0, 0, 0), C_AMBER_LO)
		var cap_id := weapon_id
		btn.pressed.connect(func():
			if _pm.purchase_weapon_blueprint(cap_id):
				_refresh_cards()
		)
	else:
		btn.text     = "BUY"
		btn.disabled = true
		btn.add_theme_color_override("font_color", C_RED_HI)
		_style_btn_flat(btn, Color(0, 0, 0, 0), Color(0, 0, 0, 0))

	rv.add_child(btn)


# ── Style helpers ─────────────────────────────────────────────────────────────

func _style_btn_flat(btn: Button, normal_bg: Color, hover_bg: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = hover_bg if state in ["hover", "pressed"] else normal_bg
		sb.set_border_width_all(0)
		sb.set_content_margin_all(2)
		btn.add_theme_stylebox_override(state, sb)


func _lbl(parent: Control, text: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(l)
	return l
