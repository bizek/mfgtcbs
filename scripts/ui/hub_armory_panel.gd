@tool
extends Control

## Armory panel — dark industrial redesign.
## Shows all weapon slots simultaneously as stacked cards.
## Weapon name click → weapon picker (inline). Mod slot click → mod picker.

signal close_requested

@onready var _base:         HubPanelBase = $PanelBase
@onready var _armory_view:  Control      = $ArmoryView
@onready var _picker_view:  Control      = $ModPickerView

## ── Mod picker nodes (unchanged from original) ───────────────────────────────
@onready var _picker_header:      Label        = $ModPickerView/PickerMargin/PickerVBox/PickerHeader
@onready var _picker_empty_label: Label        = $ModPickerView/PickerMargin/PickerVBox/PickerEmptyLabel
@onready var _picker_cancel_btn:  Button       = $ModPickerView/PickerMargin/PickerVBox/PickerCancelBtn
@onready var _picker_vbox:        VBoxContainer = $ModPickerView/PickerMargin/PickerVBox
@onready var _picker_mod_btns: Array[Button] = [
	$ModPickerView/PickerMargin/PickerVBox/ModPickerRow0/ModPickerBtn0,
	$ModPickerView/PickerMargin/PickerVBox/ModPickerRow1/ModPickerBtn1,
	$ModPickerView/PickerMargin/PickerVBox/ModPickerRow2/ModPickerBtn2,
	$ModPickerView/PickerMargin/PickerVBox/ModPickerRow3/ModPickerBtn3,
]
@onready var _picker_mod_descs: Array[Label] = [
	$ModPickerView/PickerMargin/PickerVBox/ModPickerRow0/ModPickerDesc0,
	$ModPickerView/PickerMargin/PickerVBox/ModPickerRow1/ModPickerDesc1,
	$ModPickerView/PickerMargin/PickerVBox/ModPickerRow2/ModPickerDesc2,
	$ModPickerView/PickerMargin/PickerVBox/ModPickerRow3/ModPickerDesc3,
]

## ── Color palette ────────────────────────────────────────────────────────────
const C_CARD    := Color(0.082, 0.075, 0.063)
const C_CARD_HI := Color(0.102, 0.092, 0.076)
const C_PLATE   := Color(0.055, 0.050, 0.042)

const C_BORDER  := Color(0.165, 0.145, 0.125)
const C_B_HOT   := Color(0.478, 0.255, 0.063)
const C_B_ACT   := Color(0.690, 0.353, 0.082)

const C_AMBER    := Color(0.831, 0.447, 0.102)
const C_AMBER_HI := Color(0.941, 0.565, 0.188)
const C_AMBER_LO := Color(0.353, 0.173, 0.031)

const C_RED     := Color(0.659, 0.118, 0.063)
const C_RED_HI  := Color(0.820, 0.157, 0.063)
const C_RED_LO  := Color(0.200, 0.040, 0.016)

const C_GREEN_HI := Color(0.314, 0.690, 0.188)

const C_T0 := Color(0.800, 0.690, 0.565)
const C_T1 := Color(0.541, 0.408, 0.282)
const C_T2 := Color(0.314, 0.235, 0.157)

const FONT   := HubPanelBase.PIXEL_FONT
const FS_LG  := 21
const FS_MD  := 19
const FS_SM  := 16
const FS_XS  := 13

## ── State ────────────────────────────────────────────────────────────────────
var _pm:              Node = null
var _active_slot:     int  = 1
var _mod_picking:     bool = false
var _mod_target_slot: int  = 0
var _weapon_picking:  bool = false

## Codex overlay
var _codex_panel: CodexGridPanel = null

## Dynamic mod picker scroll container (rebuilt each open)
var _picker_scroll: ScrollContainer = null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_base.close_requested.connect(func(): close_requested.emit())
	_picker_cancel_btn.pressed.connect(func():
		_mod_picking = false
		populate(_pm)
	)
	_style_picker_chrome()
	if Engine.is_editor_hint():
		return
	_build_codex_overlay()
	populate(ProgressionManager)


func populate(pm: Node) -> void:
	_pm = pm
	if _mod_picking:
		_armory_view.visible = false
		_picker_view.visible = true
		_build_mod_picker()
	else:
		_armory_view.visible = true
		_picker_view.visible = false
		_build_armory()


# ── Armory main view ──────────────────────────────────────────────────────────

func _build_armory() -> void:
	for child in _armory_view.get_children():
		child.queue_free()

	var slot_count: int = 3 if Engine.is_editor_hint() else _pm.starting_weapon_slots()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_top",    33)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_bottom",  8)
	_armory_view.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 5)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	if _weapon_picking:
		_build_weapon_picker(vbox)
		return

	## ── Section header
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 5)
	hdr.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(hdr)

	_lbl(hdr, "EQUIPPED LOADOUT", FS_SM, C_T2)

	var sep_line := ColorRect.new()
	sep_line.custom_minimum_size       = Vector2(0, 1)
	sep_line.size_flags_horizontal     = Control.SIZE_EXPAND_FILL
	sep_line.size_flags_vertical       = Control.SIZE_SHRINK_CENTER
	sep_line.color                     = C_BORDER
	hdr.add_child(sep_line)

	var active_count: int = 0
	for s in range(1, slot_count + 1):
		if not _get_weapon_for_slot(s).is_empty():
			active_count += 1
	_lbl(hdr, "%d/%d SLOTS" % [active_count, slot_count], FS_XS, C_T2)

	## Amber accent rule
	var accent_rule := ColorRect.new()
	accent_rule.custom_minimum_size   = Vector2(0, 1)
	accent_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accent_rule.color                 = Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.40)
	vbox.add_child(accent_rule)

	## ── Weapon cards
	for slot in range(1, slot_count + 1):
		_build_weapon_card(vbox, slot)

	## Push footer down
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	## ── Footer
	_build_footer(vbox)


# ── Weapon card ───────────────────────────────────────────────────────────────

func _build_weapon_card(parent: Control, slot: int) -> void:
	var weapon_id: String     = _get_weapon_for_slot(slot)
	var wdata: Dictionary     = WeaponData.ALL.get(weapon_id, {})
	var is_active: bool       = slot == _active_slot
	var has_weapon: bool      = not weapon_id.is_empty()
	var equipped: Array       = [] if Engine.is_editor_hint() else _pm.get_weapon_mods(weapon_id)
	var max_mod_slots: int    = wdata.get("mod_slots", 1) if has_weapon else 3

	## Card outer Panel
	var card := Panel.new()
	card.custom_minimum_size     = Vector2(0, 72)
	card.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	var cs := StyleBoxFlat.new()
	cs.bg_color          = C_CARD_HI if is_active else C_CARD
	cs.border_color      = C_B_ACT if is_active else C_BORDER
	cs.border_width_left   = 1
	cs.border_width_top    = 1
	cs.border_width_right  = 1
	cs.border_width_bottom = 1
	cs.set_content_margin_all(0)
	card.add_theme_stylebox_override("panel", cs)
	parent.add_child(card)

	## Layout: [4px strip | content]
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	card.add_child(row)

	## Active strip
	var strip := ColorRect.new()
	strip.custom_minimum_size = Vector2(4, 0)
	strip.color = C_AMBER if is_active else C_BORDER
	row.add_child(strip)

	## Content area with inner margin
	var cm := MarginContainer.new()
	cm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cm.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	cm.add_theme_constant_override("margin_left",   6)
	cm.add_theme_constant_override("margin_top",    4)
	cm.add_theme_constant_override("margin_right",  6)
	cm.add_theme_constant_override("margin_bottom", 4)
	row.add_child(cm)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 3)
	cm.add_child(content)

	## ── Row 1: slot tag + weapon name + behavior tag
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 5)
	name_row.custom_minimum_size = Vector2(0, 20)
	content.add_child(name_row)

	_lbl(name_row, "S%02d" % slot, FS_XS, C_T2)

	var name_btn := Button.new()
	name_btn.text                = weapon_id.to_upper() if has_weapon else "[ NO WEAPON — CLICK TO ASSIGN ]"
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_btn.alignment           = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.focus_mode          = Control.FOCUS_NONE
	name_btn.add_theme_font_override("font", FONT)
	name_btn.add_theme_font_size_override("font_size", FS_MD)
	name_btn.add_theme_color_override("font_color", C_T0 if has_weapon else C_T2)
	name_btn.add_theme_color_override("font_hover_color", C_AMBER_HI)
	_style_btn_flat(name_btn, Color(0, 0, 0, 0), C_AMBER_LO)
	name_row.add_child(name_btn)

	if has_weapon:
		var bhv: String = wdata.get("behavior", "")
		if not bhv.is_empty():
			_lbl(name_row, "[%s]" % bhv.to_upper(), FS_XS, C_T2)

	## Wire weapon picker
	var cap_slot := slot
	name_btn.pressed.connect(func():
		_active_slot    = cap_slot
		_weapon_picking = true
		populate(_pm)
	)

	## ── Row 2: stat bars
	if has_weapon:
		var sr := HBoxContainer.new()
		sr.add_theme_constant_override("separation", 6)
		sr.custom_minimum_size = Vector2(0, 14)
		content.add_child(sr)

		var dmg_n: float = clampf(wdata.get("damage", 10.0) / 80.0, 0.0, 1.0)
		var spd_n: float = clampf(wdata.get("attack_speed", 1.0) / 12.0, 0.0, 1.0)
		var rng_n: float = clampf(
			wdata.get("range", wdata.get("lifetime", 2.0) * wdata.get("projectile_speed", 300.0)) / 700.0,
			0.0, 1.0)

		_stat_bar(sr, "DMG", dmg_n, C_RED_HI)
		_stat_bar(sr, "SPD", spd_n, C_AMBER)
		_stat_bar(sr, "RNG", rng_n, C_GREEN_HI)

	## ── Row 3: mod slots
	var mr := HBoxContainer.new()
	mr.add_theme_constant_override("separation", 3)
	mr.custom_minimum_size = Vector2(0, 18)
	content.add_child(mr)

	for mi in range(3):
		var in_range: bool    = mi < max_mod_slots
		var mod_id: String    = equipped[mi] if mi < equipped.size() else ""
		var has_mod: bool     = not mod_id.is_empty()
		var mdata: Dictionary = ModData.ALL.get(mod_id, {}) if has_mod else {}
		var mod_name: String  = mdata.get("name", mod_id) if has_mod else ""
		var mod_col: Color    = mdata.get("color", C_T1) if has_mod else C_BORDER

		var mb := Button.new()
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mb.alignment             = HORIZONTAL_ALIGNMENT_LEFT
		mb.focus_mode            = Control.FOCUS_NONE
		mb.visible               = in_range
		mb.add_theme_font_override("font", FONT)
		mb.add_theme_font_size_override("font_size", FS_XS)

		if has_mod:
			mb.text = "■ " + mod_name
			mb.add_theme_color_override("font_color", mod_col)
			mb.add_theme_color_override("font_hover_color", mod_col.lightened(0.3))
		elif in_range:
			mb.text = "+ SLOT"
			mb.add_theme_color_override("font_color", C_T2)
			mb.add_theme_color_override("font_hover_color", C_T1)
		_style_btn_mod(mb, mod_col, has_mod)

		if in_range and has_weapon:
			var cs2 := cap_slot
			var ci   := mi
			mb.pressed.connect(func():
				_active_slot     = cs2
				_mod_picking     = true
				_mod_target_slot = ci
				populate(_pm)
			)
		mr.add_child(mb)


# ── Stat bar builder ──────────────────────────────────────────────────────────

func _stat_bar(parent: Control, label: String, norm: float, col: Color) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.custom_minimum_size   = Vector2(0, 12)
	parent.add_child(hb)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(22, 0)
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", FS_XS)
	lbl.add_theme_color_override("font_color", C_T2)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(lbl)

	## Bar track container
	var track := Control.new()
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.custom_minimum_size   = Vector2(0, 12)
	hb.add_child(track)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.anchor_top    = 0.25
	bg.anchor_bottom = 0.75
	bg.color = Color(0.10, 0.085, 0.070)
	track.add_child(bg)

	if norm > 0.01:
		var fill := ColorRect.new()
		fill.anchor_left   = 0.0
		fill.anchor_right  = norm
		fill.anchor_top    = 0.25
		fill.anchor_bottom = 0.75
		fill.color = col.darkened(0.25)
		track.add_child(fill)

		## Bright tip
		var tip := ColorRect.new()
		tip.anchor_left   = maxf(0.0, norm - 0.06)
		tip.anchor_right  = norm
		tip.anchor_top    = 0.25
		tip.anchor_bottom = 0.75
		tip.color = col
		track.add_child(tip)


# ── Weapon picker (inline, replaces card list) ────────────────────────────────

func _build_weapon_picker(parent: Control) -> void:
	## Header
	var hdr_hbox := HBoxContainer.new()
	hdr_hbox.add_theme_constant_override("separation", 5)
	parent.add_child(hdr_hbox)
	_lbl(hdr_hbox, "SELECT WEAPON — SLOT %02d" % _active_slot, FS_MD, C_AMBER)

	var rule := ColorRect.new()
	rule.custom_minimum_size   = Vector2(0, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.color                 = C_B_ACT
	parent.add_child(rule)

	## Weapon list
	var weapons: Array  = [] if Engine.is_editor_hint() else _pm.unlocked_weapons
	var current_id: String = _get_weapon_for_slot(_active_slot)

	if weapons.is_empty():
		_lbl(parent, "No weapons unlocked", FS_MD, C_T2)
	else:
		for w_id: String in weapons:
			var is_sel: bool = w_id == current_id
			var btn := Button.new()
			btn.text               = ("%s  %s" % [("▶ " if is_sel else "  "), w_id.to_upper()])
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.alignment          = HORIZONTAL_ALIGNMENT_LEFT
			btn.focus_mode         = Control.FOCUS_NONE
			btn.add_theme_font_override("font", FONT)
			btn.add_theme_font_size_override("font_size", FS_MD)
			btn.add_theme_color_override("font_color", C_AMBER if is_sel else C_T1)
			btn.add_theme_color_override("font_hover_color", C_AMBER_HI)
			_style_btn_flat(btn,
				C_AMBER_LO if is_sel else Color(0, 0, 0, 0),
				C_AMBER_LO)
			var cap_wid: String = w_id
			var cap_slot: int   = _active_slot
			btn.pressed.connect(func():
				match cap_slot:
					1: _pm.selected_weapon   = cap_wid
					2: _pm.selected_weapon_2 = cap_wid
					3: _pm.selected_weapon_3 = cap_wid
				_pm.save_data()
				_weapon_picking = false
				populate(_pm)
			)
			parent.add_child(btn)

	## Spacer
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(sp)

	## Back button
	var back_rule := ColorRect.new()
	back_rule.custom_minimum_size   = Vector2(0, 1)
	back_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_rule.color                 = C_BORDER
	parent.add_child(back_rule)

	var back := Button.new()
	back.text                = "← BACK"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.alignment           = HORIZONTAL_ALIGNMENT_LEFT
	back.focus_mode          = Control.FOCUS_NONE
	back.add_theme_font_override("font", FONT)
	back.add_theme_font_size_override("font_size", FS_MD)
	back.add_theme_color_override("font_color", C_T1)
	back.add_theme_color_override("font_hover_color", C_T0)
	_style_btn_flat(back, Color(0, 0, 0, 0), Color(0.18, 0.14, 0.10, 0.60))
	back.pressed.connect(func():
		_weapon_picking = false
		populate(_pm)
	)
	parent.add_child(back)


# ── Footer ────────────────────────────────────────────────────────────────────

func _build_footer(parent: Control) -> void:
	var sep := ColorRect.new()
	sep.custom_minimum_size   = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sep.color                 = C_BORDER
	parent.add_child(sep)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.custom_minimum_size = Vector2(0, 18)
	parent.add_child(hbox)

	## Tally mods across all equipped weapons
	var total_mods: int  = 0
	var total_slots: int = 0
	var synergies: int   = 0
	if not Engine.is_editor_hint() and _pm != null:
		var sc: int = _pm.starting_weapon_slots()
		for s in range(1, sc + 1):
			var wid := _get_weapon_for_slot(s)
			if wid.is_empty():
				continue
			var ms: int = WeaponData.ALL.get(wid, {}).get("mod_slots", 1)
			total_slots += ms
			var eq: Array = _pm.get_weapon_mods(wid)
			for mi in range(ms):
				if mi < eq.size() and not (eq[mi] as String).is_empty():
					total_mods += 1
		synergies = CodexManager.entries.values().filter(
			func(e: CodexEntry) -> bool: return e.discovered
		).size()

	_footer_stat(hbox, "MODS",       "%d/%d" % [total_mods, total_slots], C_AMBER)
	_footer_divider(hbox)
	_footer_stat(hbox, "SYNERGIES",  str(synergies),
		C_RED_HI if synergies > 0 else C_T2)

	## Right side: spacer + codex button
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	if _codex_panel != null:
		var cb := Button.new()
		cb.text = "◆ CODEX"
		cb.add_theme_font_override("font", FONT)
		cb.add_theme_font_size_override("font_size", FS_XS)
		cb.add_theme_color_override("font_color", Color(0.60, 0.42, 0.88))
		cb.add_theme_color_override("font_hover_color", Color(0.82, 0.62, 1.0))
		cb.focus_mode = Control.FOCUS_NONE
		_style_btn_flat(cb, Color(0.10, 0.06, 0.20, 0.50), Color(0.22, 0.12, 0.40, 0.65))
		cb.pressed.connect(_on_codex_btn_pressed)
		hbox.add_child(cb)


func _footer_stat(parent: Control, label: String, value: String,
		val_col: Color = C_AMBER) -> void:
	var mm := MarginContainer.new()
	mm.add_theme_constant_override("margin_left",  10)
	mm.add_theme_constant_override("margin_right", 10)
	mm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(mm)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	mm.add_child(vb)
	_lbl(vb, label, FS_XS,  C_T2)
	_lbl(vb, value, FS_SM, val_col)


func _footer_divider(parent: Control) -> void:
	var r := ColorRect.new()
	r.custom_minimum_size  = Vector2(1, 16)
	r.size_flags_vertical  = Control.SIZE_SHRINK_CENTER
	r.color                = C_BORDER
	parent.add_child(r)


# ── Mod picker sub-view ───────────────────────────────────────────────────────

func _build_mod_picker() -> void:
	var pm        := _pm
	var weapon_id: String
	match _active_slot:
		1: weapon_id = pm.selected_weapon
		2: weapon_id = pm.selected_weapon_2
		3: weapon_id = pm.selected_weapon_3
		_: weapon_id = pm.selected_weapon

	# Hide the hardcoded static rows — replaced by dynamic scroll list below
	for btn in _picker_mod_btns: btn.visible = false
	for d   in _picker_mod_descs: d.visible  = false

	# Free previous scroll container if it exists
	if _picker_scroll != null and is_instance_valid(_picker_scroll):
		_picker_scroll.free()
		_picker_scroll = null

	var max_slots: int = WeaponData.ALL.get(weapon_id, {}).get("mod_slots", 1)
	if _mod_target_slot >= max_slots:
		_picker_header.text         = "NO MOD SLOT  (%s)" % weapon_id
		_picker_empty_label.visible = true
		_picker_empty_label.text    = "This weapon has no more mod slots."
		return

	_picker_header.text = "INSTALL MOD  slot %d  /  %s" % [_mod_target_slot + 1, weapon_id]

	var counts: Dictionary = {}
	for mid in pm.owned_mods:
		counts[mid] = counts.get(mid, 0) + 1

	var mod_ids: Array = counts.keys()
	mod_ids.sort()  # Stable alphabetical order so list never shifts unexpectedly
	_picker_empty_label.visible = mod_ids.is_empty()

	if mod_ids.is_empty():
		return

	# Build scrollable list
	_picker_scroll = ScrollContainer.new()
	_picker_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_picker_scroll.mouse_filter = Control.MOUSE_FILTER_PASS

	var scroll_vbox := VBoxContainer.new()
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_vbox.add_theme_constant_override("separation", 3)
	_picker_scroll.add_child(scroll_vbox)

	# Insert before the cancel button so it sits between header and cancel
	_picker_vbox.add_child(_picker_scroll)
	_picker_vbox.move_child(_picker_scroll, _picker_cancel_btn.get_index())

	var cap_equipped: Array = _pm.get_weapon_mods(weapon_id).duplicate()

	for mod_id in mod_ids:
		var mdata: Dictionary = ModData.ALL.get(mod_id, {})
		var mod_name: String  = mdata.get("name", mod_id)
		var mod_col: Color    = mdata.get("color", Color.WHITE)
		var count: int        = counts[mod_id]
		var desc: String      = mdata.get("desc", "")

		var row := VBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scroll_vbox.add_child(row)

		var btn := Button.new()
		btn.text = ("■ %s  ×%d" % [mod_name, count]) if count > 1 else ("■ " + mod_name)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_override("font", FONT)
		btn.add_theme_font_size_override("font_size", FS_MD)
		btn.add_theme_color_override("font_color", mod_col)
		btn.add_theme_color_override("font_hover_color", mod_col.lightened(0.25))
		_style_btn_mod(btn, mod_col, true)
		row.add_child(btn)

		if not desc.is_empty():
			var desc_lbl := Label.new()
			desc_lbl.text = "  " + desc
			desc_lbl.add_theme_font_override("font", FONT)
			desc_lbl.add_theme_font_size_override("font_size", FS_XS)
			desc_lbl.add_theme_color_override("font_color", C_T2)
			desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(desc_lbl)

		var cap_mid:  String = mod_id
		var cap_wid  := weapon_id
		var cap_slot := _mod_target_slot
		btn.pressed.connect(func():
			_pm.set_weapon_mod(cap_wid, cap_slot, cap_mid)
			_discover_combos_for_weapon(cap_wid)
			if _codex_panel != null:
				_codex_panel.set_hover_highlight("")
			_mod_picking = false
			populate(_pm)
		)

		btn.mouse_entered.connect(func():
			if _codex_panel == null or not _codex_panel.visible:
				return
			var highlight: StringName = ""
			for eq_mod in cap_equipped:
				if eq_mod == cap_mid:
					continue
				var pairs := CodexManager.get_combos_for_mod_pair(
					StringName(cap_mid), StringName(eq_mod))
				if not pairs.is_empty():
					highlight = pairs[0].combo.combo_id
					break
			_codex_panel.set_hover_highlight(highlight)
		)
		btn.mouse_exited.connect(func():
			if _codex_panel != null:
				_codex_panel.set_hover_highlight("")
		)


# ── Codex overlay ─────────────────────────────────────────────────────────────

func _build_codex_overlay() -> void:
	_codex_panel          = CodexGridPanel.new()
	_codex_panel.position = Vector2(10.0, 4.0)
	_codex_panel.size     = Vector2(460.0, 262.0)
	_codex_panel.visible  = false
	_codex_panel.close_requested.connect(func(): _codex_panel.visible = false)
	_codex_panel.entry_hovered.connect(func(_cid: StringName): pass)
	get_parent().add_child(_codex_panel)


func _on_codex_btn_pressed() -> void:
	if _codex_panel == null:
		return
	_codex_panel.visible = not _codex_panel.visible


# ── Style helpers ─────────────────────────────────────────────────────────────

func _style_btn_flat(btn: Button, normal_bg: Color, hover_bg: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = hover_bg if state in ["hover", "pressed"] else normal_bg
		sb.set_border_width_all(0)
		sb.set_content_margin_all(2)
		btn.add_theme_stylebox_override(state, sb)


func _style_btn_mod(btn: Button, border_col: Color, filled: bool) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		var hot: bool = state in ["hover", "pressed"]
		sb.bg_color = Color(0.10, 0.09, 0.07, 0.90) if hot else (
			C_PLATE if filled else Color(0.055, 0.048, 0.040)
		)
		sb.border_width_left   = 2
		sb.border_width_top    = 0
		sb.border_width_right  = 0
		sb.border_width_bottom = 0
		sb.border_color        = border_col if (filled or hot) else C_BORDER
		sb.set_content_margin(SIDE_LEFT,   5)
		sb.set_content_margin(SIDE_RIGHT,  3)
		sb.set_content_margin(SIDE_TOP,    2)
		sb.set_content_margin(SIDE_BOTTOM, 2)
		btn.add_theme_stylebox_override(state, sb)


func _style_picker_chrome() -> void:
	_picker_header.add_theme_font_override("font", FONT)
	_picker_header.add_theme_font_size_override("font_size", FS_MD)
	_picker_header.add_theme_color_override("font_color", C_AMBER)

	_picker_empty_label.add_theme_font_override("font", FONT)
	_picker_empty_label.add_theme_font_size_override("font_size", FS_MD)
	_picker_empty_label.add_theme_color_override("font_color", C_T2)

	_picker_cancel_btn.text = "← CANCEL"
	_picker_cancel_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_picker_cancel_btn.add_theme_font_override("font", FONT)
	_picker_cancel_btn.add_theme_font_size_override("font_size", FS_MD)
	_picker_cancel_btn.add_theme_color_override("font_color", C_T1)
	_picker_cancel_btn.add_theme_color_override("font_hover_color", C_T0)
	_style_btn_flat(_picker_cancel_btn, Color(0, 0, 0, 0), Color(0.18, 0.14, 0.10, 0.60))

	for btn in _picker_mod_btns:
		btn.add_theme_font_override("font", FONT)
		btn.add_theme_font_size_override("font_size", FS_MD)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_btn_flat(btn, Color(0, 0, 0, 0), C_AMBER_LO)

	for d in _picker_mod_descs:
		d.add_theme_font_override("font", FONT)
		d.add_theme_font_size_override("font_size", FS_XS)
		d.add_theme_color_override("font_color", C_T2)


func _lbl(parent: Control, text: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(l)
	return l


# ── Data helpers ──────────────────────────────────────────────────────────────

func _get_weapon_for_slot(slot: int) -> String:
	if Engine.is_editor_hint() or _pm == null:
		return ""
	match slot:
		1: return _pm.selected_weapon
		2: return _pm.selected_weapon_2
		3: return _pm.selected_weapon_3
	return ""


func _disconnect_all(sig: Signal) -> void:
	for conn in sig.get_connections():
		sig.disconnect(conn.callable)


func _discover_combos_for_weapon(weapon_id: String) -> void:
	var equipped: Array = _pm.get_weapon_mods(weapon_id)
	if equipped.size() < 2:
		return
	for i in equipped.size():
		for j in range(i + 1, equipped.size()):
			var pairs := CodexManager.get_combos_for_mod_pair(
				StringName(equipped[i]), StringName(equipped[j]))
			for entry: CodexEntry in pairs:
				CodexManager.discover_combo(entry.combo.combo_id)
	if equipped.size() >= 3:
		var equipped_set: Array[StringName] = []
		for m in equipped:
			equipped_set.append(StringName(m))
		for entry: CodexEntry in CodexManager.entries.values():
			if entry.combo.required_mods.size() != 3:
				continue
			var hits := 0
			for req: StringName in entry.combo.required_mods:
				if req in equipped_set:
					hits += 1
			if hits == 3:
				CodexManager.discover_combo(entry.combo.combo_id)
