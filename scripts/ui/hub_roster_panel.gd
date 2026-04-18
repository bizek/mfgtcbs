@tool
extends Control

## Roster panel — character list (left) + detail view (right).
## Dark industrial redesign matching hub_armory_panel.gd aesthetics.

signal close_requested

@onready var _base: HubPanelBase = $PanelBase

## ── Color palette ─────────────────────────────────────────────────────────────
const C_CARD    := Color(0.082, 0.075, 0.063)
const C_CARD_HI := Color(0.102, 0.092, 0.076)
const C_PLATE   := Color(0.055, 0.050, 0.042)

const C_BORDER  := Color(0.165, 0.145, 0.125)
const C_B_HOT   := Color(0.478, 0.255, 0.063)
const C_B_ACT   := Color(0.690, 0.353, 0.082)

const C_AMBER    := Color(0.831, 0.447, 0.102)
const C_AMBER_HI := Color(0.941, 0.565, 0.188)
const C_AMBER_LO := Color(0.353, 0.173, 0.031)

const C_RED_HI  := Color(0.820, 0.157, 0.063)
const C_GREEN_HI := Color(0.314, 0.690, 0.188)

const C_T0 := Color(0.800, 0.690, 0.565)
const C_T1 := Color(0.541, 0.408, 0.282)
const C_T2 := Color(0.314, 0.235, 0.157)

const FONT  := HubPanelBase.PIXEL_FONT
const FS_LG := 21
const FS_MD := 19
const FS_SM := 16
const FS_XS := 13

## ── Role tags ─────────────────────────────────────────────────────────────────
const CHAR_ROLES: Dictionary = {
	"The Drifter":   "GENERALIST",
	"The Scavenger": "EXTRACTION",
	"The Warden":    "TANK",
	"The Spark":     "GLASS CANNON",
	"The Shade":     "EVASION",
	"The Herald":    "ABILITY",
	"The Cursed":    "EXPERT",
}

## ── Stat bar maxes ────────────────────────────────────────────────────────────
const STAT_MAX_HP    := 200.0
const STAT_MAX_ARMOR := 20.0
const STAT_MAX_SPEED := 300.0

## ── State ─────────────────────────────────────────────────────────────────────
var _pm: Node = null
var _detail_char: String = ""
var _roster_root: Control = null


func _ready() -> void:
	_base.close_requested.connect(func(): close_requested.emit())

	## Remove legacy scene-placed nodes; we rebuild everything from code.
	for child in _base.get_content().get_children():
		child.free()

	_roster_root = Control.new()
	_roster_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_roster_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.get_content().add_child(_roster_root)

	if Engine.is_editor_hint():
		return
	populate(ProgressionManager)


func populate(pm: Node) -> void:
	_pm = pm
	if _detail_char.is_empty():
		_detail_char = pm.selected_character
	_build()


func _build() -> void:
	for child in _roster_root.get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_bottom",  8)
	_roster_root.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	margin.add_child(hbox)

	_build_char_list(hbox)
	_build_detail_pane(hbox)


# ── Character list (left ~40%) ─────────────────────────────────────────────────

func _build_char_list(parent: HBoxContainer) -> void:
	var plate := Panel.new()
	plate.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	plate.size_flags_vertical      = Control.SIZE_EXPAND_FILL
	plate.size_flags_stretch_ratio = 2.0
	var ps := StyleBoxFlat.new()
	ps.bg_color = C_PLATE
	ps.border_color = C_BORDER
	ps.border_width_left = 1; ps.border_width_top = 1
	ps.border_width_right = 1; ps.border_width_bottom = 1
	ps.set_content_margin_all(0)
	plate.add_theme_stylebox_override("panel", ps)
	parent.add_child(plate)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	plate.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(vbox)

	## Header strip
	var hdr_mm := MarginContainer.new()
	hdr_mm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_mm.add_theme_constant_override("margin_left",   8)
	hdr_mm.add_theme_constant_override("margin_top",    6)
	hdr_mm.add_theme_constant_override("margin_right",  8)
	hdr_mm.add_theme_constant_override("margin_bottom", 3)
	vbox.add_child(hdr_mm)
	_lbl(hdr_mm, "ROSTER", FS_XS, C_T2)

	var accent_rule := ColorRect.new()
	accent_rule.custom_minimum_size   = Vector2(0, 1)
	accent_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accent_rule.color = Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.40)
	accent_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(accent_rule)

	for char_id: String in CharacterData.ORDER:
		_build_char_card(vbox, char_id)


func _build_char_card(parent: VBoxContainer, char_id: String) -> void:
	var cdata: Dictionary = CharacterData.ALL[char_id]
	var char_col: Color   = cdata.get("color", Color.WHITE)
	var is_owned: bool    = _pm.has_character(char_id)
	var is_active: bool   = _pm.selected_character == char_id
	var is_detail: bool   = _detail_char == char_id

	var card := Button.new()
	card.custom_minimum_size   = Vector2(0, 26)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode            = Control.FOCUS_NONE

	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		var is_hot: bool = state in ["hover", "pressed"]
		sb.bg_color     = C_CARD_HI if (is_detail or is_hot) else C_CARD
		sb.border_color = C_B_ACT if is_detail else (C_B_HOT if is_hot else C_BORDER)
		sb.border_width_left = 1; sb.border_width_top = 1
		sb.border_width_right = 1; sb.border_width_bottom = 1
		sb.set_content_margin_all(0)
		card.add_theme_stylebox_override(state, sb)
	parent.add_child(card)

	## [3px strip | content margin]
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var strip := ColorRect.new()
	strip.custom_minimum_size = Vector2(3, 0)
	strip.color = char_col if is_detail else C_BORDER
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(strip)

	var cm := MarginContainer.new()
	cm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cm.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	cm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cm.add_theme_constant_override("margin_left",   5)
	cm.add_theme_constant_override("margin_top",    3)
	cm.add_theme_constant_override("margin_right",  5)
	cm.add_theme_constant_override("margin_bottom", 3)
	row.add_child(cm)

	var content_row := HBoxContainer.new()
	content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 4)
	content_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cm.add_child(content_row)

	var dot := Label.new()
	dot.text = "●"
	dot.add_theme_font_override("font", FONT)
	dot.add_theme_font_size_override("font_size", FS_XS)
	dot.add_theme_color_override("font_color",
		char_col if is_owned else Color(char_col.r * 0.35, char_col.g * 0.35, char_col.b * 0.35))
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_row.add_child(dot)

	var name_lbl := Label.new()
	name_lbl.text = cdata.get("display_name", char_id)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_override("font", FONT)
	name_lbl.add_theme_font_size_override("font_size", FS_MD)
	name_lbl.add_theme_color_override("font_color", char_col if is_owned else C_T2)
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_row.add_child(name_lbl)

	if is_active:
		var act_lbl := Label.new()
		act_lbl.text = "▶"
		act_lbl.add_theme_font_override("font", FONT)
		act_lbl.add_theme_font_size_override("font_size", FS_XS)
		act_lbl.add_theme_color_override("font_color", char_col)
		act_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		act_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_row.add_child(act_lbl)

	var cid := char_id
	card.pressed.connect(func():
		_detail_char = cid
		_build()
	)


# ── Detail pane (right ~60%) ───────────────────────────────────────────────────

func _build_detail_pane(parent: HBoxContainer) -> void:
	var ddata: Dictionary = CharacterData.ALL.get(_detail_char,
		CharacterData.ALL["The Drifter"])
	var char_col: Color = ddata.get("color", Color.WHITE)
	var is_owned: bool  = _pm.has_character(_detail_char)
	var is_active: bool = _pm.selected_character == _detail_char
	var d_cost: int     = ddata.get("unlock_cost", 0)

	var plate := Panel.new()
	plate.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	plate.size_flags_vertical      = Control.SIZE_EXPAND_FILL
	plate.size_flags_stretch_ratio = 3.0
	var ps := StyleBoxFlat.new()
	ps.bg_color = C_PLATE
	ps.border_color = C_BORDER
	ps.border_width_left = 1; ps.border_width_top = 1
	ps.border_width_right = 1; ps.border_width_bottom = 1
	ps.set_content_margin_all(0)
	plate.add_theme_stylebox_override("panel", ps)
	parent.add_child(plate)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_top",     8)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_bottom",  8)
	plate.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	## ── Header ───────────────────────────────────────────────────────────────
	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 6)
	hdr_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hdr_row)

	_lbl(hdr_row, ddata.get("display_name", _detail_char), FS_LG,
		char_col if is_owned else char_col.darkened(0.55))

	var hdr_spacer := Control.new()
	hdr_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_row.add_child(hdr_spacer)

	_lbl(hdr_row, CHAR_ROLES.get(_detail_char, "OPERATIVE"), FS_XS, C_T2)

	var hdr_rule := ColorRect.new()
	hdr_rule.custom_minimum_size   = Vector2(0, 1)
	hdr_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_rule.color = Color(char_col.r, char_col.g, char_col.b, 0.35)
	hdr_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hdr_rule)

	## ── Stats ────────────────────────────────────────────────────────────────
	_lbl(vbox, "STATS", FS_XS, C_T2)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 3)
	stats_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(stats_vbox)

	var hp_val: float  = ddata.get("base_hp",         100.0)
	var arm_val: float = ddata.get("base_armor",         0.0)
	var spd_val: float = ddata.get("base_move_speed",  200.0)

	_stat_row(stats_vbox, "HP",    int(hp_val),  hp_val  / STAT_MAX_HP,    C_RED_HI)
	_stat_row(stats_vbox, "ARMOR", int(arm_val), arm_val / STAT_MAX_ARMOR, C_AMBER)
	_stat_row(stats_vbox, "SPEED", int(spd_val), spd_val / STAT_MAX_SPEED, C_GREEN_HI)

	## Starting weapon
	var wpn_row := HBoxContainer.new()
	wpn_row.add_theme_constant_override("separation", 5)
	vbox.add_child(wpn_row)
	_lbl(wpn_row, "WEAPON", FS_XS, C_T2)
	_lbl(wpn_row, ddata.get("starting_weapon", "?"), FS_SM, C_T1)

	## ── Passive ──────────────────────────────────────────────────────────────
	var pass_sep := ColorRect.new()
	pass_sep.custom_minimum_size   = Vector2(0, 1)
	pass_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass_sep.color = C_BORDER
	pass_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(pass_sep)

	_lbl(vbox, "PASSIVE", FS_XS, C_T2)

	var p_lbl := Label.new()
	p_lbl.text = ddata.get("passive_desc", "None.")
	p_lbl.add_theme_font_override("font", FONT)
	p_lbl.add_theme_font_size_override("font_size", FS_SM)
	p_lbl.add_theme_color_override("font_color", C_T1 if is_owned else C_T2)
	p_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(p_lbl)

	## ── Spacer ───────────────────────────────────────────────────────────────
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	## ── Footer ───────────────────────────────────────────────────────────────
	var foot_sep := ColorRect.new()
	foot_sep.custom_minimum_size   = Vector2(0, 1)
	foot_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot_sep.color = C_BORDER
	foot_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(foot_sep)

	var foot_row := HBoxContainer.new()
	foot_row.add_theme_constant_override("separation", 6)
	vbox.add_child(foot_row)

	var res_vb := VBoxContainer.new()
	res_vb.add_theme_constant_override("separation", 1)
	res_vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot_row.add_child(res_vb)
	_lbl(res_vb, "RESOURCES", FS_XS, C_T2)
	_lbl(res_vb, str(_pm.resources), FS_SM, C_T0)

	var foot_spacer := Control.new()
	foot_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot_row.add_child(foot_spacer)

	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", FS_MD)

	if is_active:
		btn.text     = "◆ ACTIVE"
		btn.disabled = true
		btn.add_theme_color_override("font_color", C_GREEN_HI)
		_style_btn_flat(btn,
			Color(C_GREEN_HI.r * 0.10, C_GREEN_HI.g * 0.16, C_GREEN_HI.b * 0.06, 0.70),
			Color(C_GREEN_HI.r * 0.10, C_GREEN_HI.g * 0.16, C_GREEN_HI.b * 0.06, 0.70))
	elif is_owned:
		btn.text     = "SELECT"
		btn.disabled = false
		btn.add_theme_color_override("font_color",       C_AMBER)
		btn.add_theme_color_override("font_hover_color", C_AMBER_HI)
		_style_btn_flat(btn, C_AMBER_LO,
			Color(C_AMBER_LO.r * 1.8, C_AMBER_LO.g * 1.6, C_AMBER_LO.b * 1.0, 0.90))
		var sel_id := _detail_char
		btn.pressed.connect(func():
			_pm.select_character(sel_id)
			_build()
		)
	elif _pm.resources >= d_cost:
		btn.text     = "BUY  %d" % d_cost
		btn.disabled = false
		btn.add_theme_color_override("font_color",       C_GREEN_HI)
		btn.add_theme_color_override("font_hover_color", C_GREEN_HI.lightened(0.30))
		_style_btn_flat(btn,
			Color(C_GREEN_HI.r * 0.08, C_GREEN_HI.g * 0.14, C_GREEN_HI.b * 0.05, 0.70),
			Color(C_GREEN_HI.r * 0.14, C_GREEN_HI.g * 0.22, C_GREEN_HI.b * 0.08, 0.90))
		var buy_id := _detail_char
		btn.pressed.connect(func():
			if _pm.purchase_character(buy_id):
				_build()
		)
	else:
		btn.text     = "LOCKED  %d" % d_cost
		btn.disabled = true
		btn.add_theme_color_override("font_color", C_T2)
		_style_btn_flat(btn,
			Color(0.08, 0.07, 0.06, 0.50), Color(0.08, 0.07, 0.06, 0.50))

	foot_row.add_child(btn)


# ── Stat row with value + bar ──────────────────────────────────────────────────

func _stat_row(parent: Control, label: String, value: int,
		norm: float, col: Color) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.custom_minimum_size   = Vector2(0, 14)
	parent.add_child(hb)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(36, 0)
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", FS_XS)
	lbl.add_theme_color_override("font_color", C_T2)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.text = str(value)
	val_lbl.custom_minimum_size = Vector2(28, 0)
	val_lbl.add_theme_font_override("font", FONT)
	val_lbl.add_theme_font_size_override("font_size", FS_XS)
	val_lbl.add_theme_color_override("font_color", C_T0)
	val_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(val_lbl)

	var track := Control.new()
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.custom_minimum_size   = Vector2(0, 12)
	track.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	hb.add_child(track)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.anchor_top    = 0.25
	bg.anchor_bottom = 0.75
	bg.color = Color(0.10, 0.085, 0.070)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(bg)

	var n: float = clampf(norm, 0.0, 1.0)
	if n > 0.01:
		var fill := ColorRect.new()
		fill.anchor_left   = 0.0
		fill.anchor_right  = n
		fill.anchor_top    = 0.25
		fill.anchor_bottom = 0.75
		fill.color = col.darkened(0.25)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(fill)

		var tip := ColorRect.new()
		tip.anchor_left   = maxf(0.0, n - 0.06)
		tip.anchor_right  = n
		tip.anchor_top    = 0.25
		tip.anchor_bottom = 0.75
		tip.color = col
		tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(tip)


# ── Style helpers ──────────────────────────────────────────────────────────────

func _style_btn_flat(btn: Button, normal_bg: Color, hover_bg: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = hover_bg if state in ["hover", "pressed"] else normal_bg
		sb.set_border_width_all(0)
		sb.set_content_margin_all(3)
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
