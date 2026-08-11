@tool
extends Control

## Armory panel — dark industrial redesign.
## Shows all weapon slots simultaneously as stacked cards.
## Weapon name click → weapon picker (inline). Mod slot click → mod picker.

signal close_requested

## Preloaded under a local alias rather than the bare class_name — see hub_roster_panel.gd.
const Icons := preload("res://scripts/ui/ui_icons.gd")

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

const FS_LG  := 16
const FS_MD  := 16
const FS_SM  := 16
const FS_XS  := 16

## ── State ────────────────────────────────────────────────────────────────────
var _pm:              Node = null
var _active_slot:     int  = 1
var _weapon_picking:  bool = false
## Mod picker — inline like the weapon picker, edits the current character. The separate
## per-weapon mod picker retired 2026-08-08 along with the generic layer; this is the only one.
var _class_mod_picking:     bool = false
var _class_mod_target_slot: int  = 0

## Codex overlay
var _codex_panel: CodexGridPanel = null

## Dynamic mod picker scroll container (rebuilt each open)
var _picker_scroll: ScrollContainer = null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_base.close_requested.connect(func(): close_requested.emit())
	_picker_cancel_btn.pressed.connect(func():
		_class_mod_picking = false
		populate(_pm)
	)
	_style_picker_chrome()
	if Engine.is_editor_hint():
		return
	_build_codex_overlay()
	## No populate() here — hub._open_panel() calls it the moment it adds us to the tree,
	## so a self-populate built the whole panel TWICE on every open. (Ben 2026-07-30.)


func populate(pm: Node) -> void:
	_pm = pm
	_armory_view.visible = true
	_picker_view.visible = false
	_build_armory()
	## Every populate() frees and rebuilds the visible view — controller focus
	## dies with the freed nodes, so re-land it.
	UINav.refocus_if_lost(self)


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

	if _class_mod_picking:
		_build_class_mod_picker(vbox)
		return

	## ── Section header
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 5)
	hdr.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(hdr)

	var loadout_label: String = "EQUIPPED LOADOUT"
	if not Engine.is_editor_hint() and _pm != null:
		var cid: String = str(_pm.selected_character)
		loadout_label = "LOADOUT - %s" % str(CharacterData.ALL.get(cid, {}).get("display_name", cid))
	_lbl(hdr, loadout_label, FS_SM, C_T2)

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

	## ── Class-mod card (task 31): per-character combo mods, independent of the weapon slots
	if not Engine.is_editor_hint():
		_build_class_mod_card(vbox)

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
	name_btn.text                = weapon_id.to_upper() if has_weapon else "[ NO WEAPON - CLICK TO ASSIGN ]"
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_btn.alignment           = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.focus_mode          = Control.FOCUS_ALL
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

		_stat_bar(sr, "DMG", dmg_n, C_RED_HI,   Icons.node(Icons.SWORDS))
		_stat_bar(sr, "SPD", spd_n, C_AMBER,   Icons.node(Icons.BOLT))
		_stat_bar(sr, "RNG", rng_n, C_GREEN_HI, Icons.general_node(Icons.ARROW_RIGHT, C_GREEN_HI))

	## Row 3 was the per-weapon mod slots. Mods moved onto the CHARACTER 2026-08-08 (one
	## class-locked roster, three slots) — see _build_class_mod_card below, which is now the only
	## place mods are equipped. Weapons keep their intrinsic modifiers and purple unique.


# ── Stat bar builder ──────────────────────────────────────────────────────────

## `icon` is a ready TextureRect rather than a sheet coordinate, so a caller can draw from either
## the pre-coloured character set or the greyscale general set without this function knowing which.
## RNG is exactly why: the character set has no arrow, and a hammer would have been a lie.
func _stat_bar(parent: Control, label: String, norm: float, col: Color,
		icon: TextureRect = null) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.custom_minimum_size   = Vector2(0, 12)
	parent.add_child(hb)

	## Same treatment as the roster's stat rows: pack icon for recognition, word kept for
	## confirmation. DMG / SPD / RNG are not inferable from an 8x8 silhouette alone.
	if icon != null:
		hb.add_child(icon)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(22, 0)
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
	_lbl(hdr_hbox, "SELECT WEAPON - SLOT %02d" % _active_slot, FS_MD, C_AMBER)

	var rule := ColorRect.new()
	rule.custom_minimum_size   = Vector2(0, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.color                 = C_B_ACT
	parent.add_child(rule)

	## Weapon list — class-locked (2026-08-08). A character sees its own three weapons plus the
	## six universal legacies; another class's gear is not listed even when unlocked, because the
	## same stash is shared across the roster and unlocking a blue for one character used to make
	## it equippable by all twelve.
	var weapons: Array  = [] if Engine.is_editor_hint() \
			else WeaponData.equippable_from(_pm.unlocked_weapons, _pm.selected_character)
	var current_id: String = _get_weapon_for_slot(_active_slot)

	if weapons.is_empty():
		_lbl(parent, "No weapons unlocked", FS_MD, C_T2)
	else:
		for w_id: String in weapons:
			var is_sel: bool = w_id == current_id
			var btn := Button.new()
			btn.text               = ("%s  %s" % [("> " if is_sel else "  "), w_id.to_upper()])
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.alignment          = HORIZONTAL_ALIGNMENT_LEFT
			btn.focus_mode         = Control.FOCUS_ALL
			btn.add_theme_font_size_override("font_size", FS_MD)
			btn.add_theme_color_override("font_color", C_AMBER if is_sel else C_T1)
			btn.add_theme_color_override("font_hover_color", C_AMBER_HI)
			_style_btn_flat(btn,
				C_AMBER_LO if is_sel else Color(0, 0, 0, 0),
				C_AMBER_LO)
			var cap_wid: String = w_id
			var cap_slot: int   = _active_slot
			btn.pressed.connect(func():
				_pm.set_character_weapon(_pm.selected_character, cap_slot, cap_wid)
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
	back.text                = "< BACK"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.alignment           = HORIZONTAL_ALIGNMENT_LEFT
	back.focus_mode          = Control.FOCUS_ALL
	back.add_theme_font_size_override("font_size", FS_MD)
	back.add_theme_color_override("font_color", C_T1)
	back.add_theme_color_override("font_hover_color", C_T0)
	_style_btn_flat(back, Color(0, 0, 0, 0), Color(0.18, 0.14, 0.10, 0.60))
	back.pressed.connect(func():
		_weapon_picking = false
		populate(_pm)
	)
	parent.add_child(back)


# ── Class-mod card + picker (task 31) ─────────────────────────────────────────
## Class mods equip per-character (ProgressionManager.character_mods), not per-weapon. This card
## sits below the weapon cards; each slot opens an inline picker of the OWNED class mods that
## belong to the current character's kit. Class mods never touch weapon_mods, so codex combo
## discovery is unaffected.

func _build_class_mod_card(parent: Control) -> void:
	var char_id: String = str(_pm.selected_character)
	var kit_id: String  = ModApplicability.kit_of(char_id)
	if kit_id.is_empty():
		return
	var slots: int      = _pm.class_mod_slots(char_id)
	var equipped: Array = _pm.get_character_mods(char_id)

	## Section rule
	var rule := ColorRect.new()
	rule.custom_minimum_size   = Vector2(0, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.color                 = Color(0.40, 0.30, 0.55, 0.55)   ## violet accent, class layer
	parent.add_child(rule)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 5)
	hdr.custom_minimum_size = Vector2(0, 14)
	parent.add_child(hdr)
	_lbl(hdr, "CLASS MODS", FS_SM, Color(0.62, 0.48, 0.85))
	var owned_ct: int = _owned_class_mod_count(char_id)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(sp)
	_lbl(hdr, "%d OWNED" % owned_ct, FS_XS, C_T2)

	## Slot buttons
	var mr := HBoxContainer.new()
	mr.add_theme_constant_override("separation", 3)
	mr.custom_minimum_size = Vector2(0, 18)
	parent.add_child(mr)

	for mi in range(slots):
		var mod_id: String    = str(equipped[mi]) if mi < equipped.size() else ""
		var has_mod: bool     = not mod_id.is_empty()
		var mdata: Dictionary = ClassModData.ALL.get(mod_id, {}) if has_mod else {}
		var mod_name: String  = mdata.get("name", mod_id) if has_mod else ""
		var mod_col: Color    = mdata.get("color", C_T1) if has_mod else Color(0.40, 0.32, 0.52)

		var mb := Button.new()
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mb.alignment             = HORIZONTAL_ALIGNMENT_LEFT
		mb.focus_mode            = Control.FOCUS_ALL
		mb.add_theme_font_size_override("font_size", FS_XS)
		if has_mod:
			mb.text = "* " + mod_name
			mb.add_theme_color_override("font_color", mod_col)
			mb.add_theme_color_override("font_hover_color", mod_col.lightened(0.3))
		else:
			mb.text = "+ CLASS SLOT"
			mb.add_theme_color_override("font_color", C_T2)
			mb.add_theme_color_override("font_hover_color", C_T1)
		_style_btn_mod(mb, mod_col, has_mod)
		var ci := mi
		mb.pressed.connect(func():
			_class_mod_picking     = true
			_class_mod_target_slot = ci
			populate(_pm)
		)
		mr.add_child(mb)


func _owned_class_mod_count(char_id: String) -> int:
	var n: int = 0
	for mid in _pm.owned_mods:
		if ModApplicability.is_class_mod(mid) and ModApplicability.class_applies(mid, char_id):
			n += 1
	return n


func _build_class_mod_picker(parent: Control) -> void:
	var char_id: String = str(_pm.selected_character)

	## Header
	var hdr_hbox := HBoxContainer.new()
	hdr_hbox.add_theme_constant_override("separation", 5)
	parent.add_child(hdr_hbox)
	_lbl(hdr_hbox, "INSTALL MOD - SLOT %02d" % (_class_mod_target_slot + 1), FS_MD,
		Color(0.62, 0.48, 0.85))

	var rule := ColorRect.new()
	rule.custom_minimum_size   = Vector2(0, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.color                 = Color(0.40, 0.30, 0.55, 0.75)
	parent.add_child(rule)

	## Clear-slot option when the slot is filled
	var equipped: Array = _pm.get_character_mods(char_id)
	var cur: String = str(equipped[_class_mod_target_slot]) if _class_mod_target_slot < equipped.size() else ""
	if not cur.is_empty():
		var clear_btn := Button.new()
		clear_btn.text = "X CLEAR SLOT"
		clear_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clear_btn.add_theme_font_size_override("font_size", FS_SM)
		clear_btn.add_theme_color_override("font_color", C_RED_HI)
		_style_btn_flat(clear_btn, Color(0, 0, 0, 0), C_RED_LO)
		clear_btn.pressed.connect(func():
			_pm.remove_character_mod(char_id, _class_mod_target_slot)
			_class_mod_picking = false
			populate(_pm)
		)
		parent.add_child(clear_btn)

	## Owned class mods for this kit (deduped with counts)
	var counts: Dictionary = {}
	for mid in _pm.owned_mods:
		if ModApplicability.is_class_mod(mid) and ModApplicability.class_applies(mid, char_id):
			counts[mid] = counts.get(mid, 0) + 1
	var mod_ids: Array = counts.keys()
	mod_ids.sort()

	if mod_ids.is_empty():
		_lbl(parent, "No class mods owned for this class.", FS_SM, C_T2)
	else:
		for mod_id: String in mod_ids:
			var mdata: Dictionary = ClassModData.ALL.get(mod_id, {})
			var mod_col: Color    = mdata.get("color", Color.WHITE)
			var count: int        = counts[mod_id]
			var already: bool     = mod_id in equipped

			var row := VBoxContainer.new()
			parent.add_child(row)

			var btn := Button.new()
			var name_txt: String = mdata.get("name", mod_id)
			btn.text = ("* %s  ×%d" % [name_txt, count]) if count > 1 else ("* " + name_txt)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.add_theme_font_size_override("font_size", FS_MD)
			btn.add_theme_color_override("font_color", mod_col if not already else mod_col.darkened(0.35))
			btn.add_theme_color_override("font_hover_color", mod_col.lightened(0.25))
			_style_btn_mod(btn, mod_col, true)

			## Rarity rides in a PILL beside the name, not in the name's colour — the mod's own
			## colour is its identity (fire orange, void purple) and overloading it with rarity
			## would lose one of the two. Same tag art the haul manifest uses, so the two screens
			## say "rare" the same way. Falls back to the bare button when the sheet is missing.
			var tag: Control = Icons.rarity_tag(ClassModData.rarity_of(mod_id))
			if tag != null:
				var name_row := HBoxContainer.new()
				name_row.add_theme_constant_override("separation", 4)
				## The row must be told to fill, and the button must be allowed to SHRINK.
				## Without both, the HBox sizes to the button's full text width and pushes the
				## pill past the panel edge — measured at x=665 in a 640px viewport before this
				## line existed. clip_text lowers the button's minimum so the pill always lands
				## inside, whatever a future mod is called.
				name_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				btn.clip_text = true
				name_row.add_child(btn)
				tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				name_row.add_child(tag)
				row.add_child(name_row)
			else:
				row.add_child(btn)

			var desc: String = mdata.get("desc", "")
			if not desc.is_empty():
				var dl := Label.new()
				dl.text = "  " + desc + ("   [equipped elsewhere]" if already else "")
				dl.add_theme_font_size_override("font_size", FS_XS)
				dl.add_theme_color_override("font_color", C_T2)
				## WRAP. Without this the label's minimum width is the whole sentence, and a
				## Container must honour its children's minimums — so one long description
				## dragged this VBox, its MarginContainer and every row inside it past the
				## panel's right edge. Measured at 655 against a panel ending at 580, and it
				## predates the rarity pill: the pill was simply the first thing far enough
				## right to make the overflow visible.
				dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(dl)

			var cap_mid: String = mod_id
			btn.pressed.connect(func():
				_pm.set_character_mod(char_id, _class_mod_target_slot, cap_mid)
				_discover_evolutions_for(char_id)
				_class_mod_picking = false
				populate(_pm)
			)

	## Spacer + back
	var spc := Control.new()
	spc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(spc)

	var back := Button.new()
	back.text = "< BACK"
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.add_theme_font_size_override("font_size", FS_MD)
	back.add_theme_color_override("font_color", C_T1)
	back.add_theme_color_override("font_hover_color", C_T0)
	_style_btn_flat(back, Color(0, 0, 0, 0), Color(0.18, 0.14, 0.10, 0.60))
	back.pressed.connect(func():
		_class_mod_picking = false
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
		## Mods are per-character since 2026-08-08, so this is one tally, not a per-weapon sum.
		var mod_char: String = str(_pm.selected_character)
		total_slots = _pm.class_mod_slots(mod_char)
		var eq: Array = _pm.get_character_mods(mod_char)
		for mi in range(total_slots):
			if mi < eq.size() and not str(eq[mi]).is_empty():
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
		cb.text = "+ CODEX"
		cb.add_theme_font_size_override("font_size", FS_XS)
		cb.add_theme_color_override("font_color", Color(0.60, 0.42, 0.88))
		cb.add_theme_color_override("font_hover_color", Color(0.82, 0.62, 1.0))
		cb.focus_mode = Control.FOCUS_ALL
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

func _build_codex_overlay() -> void:
	## Near full-screen (viewport is 640x360). The old 460x262 was sized around 9-14px labels; at
	## the project font's real 16 a line box is 23px tall, and the detail column no longer fits in
	## a 262px box without scrolling for every entry.
	_codex_panel          = CodexGridPanel.new()
	_codex_panel.position = Vector2(10.0, 10.0)
	_codex_panel.size     = Vector2(620.0, 340.0)
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
		sb.bg_color = hover_bg if state in ["hover", "pressed", "focus"] else normal_bg
		if state == "focus":
			sb.set_border_width_all(1)
			sb.border_color = C_AMBER_HI
		else:
			sb.set_border_width_all(0)
		sb.set_content_margin_all(2)
		btn.add_theme_stylebox_override(state, sb)


## Mod / weapon slots. The frame is the UI pack's real item slot, taken from the theme's
## SlotButton variation; the RARITY COLOUR stays here, because which mod is socketed is this
## panel's business and not the theme's.
##
## The slot art is a near-black plate inside a bone outline and modulate multiplies, so the fill
## stays dark and only the outline takes the colour — the same trick hub_panel_base uses for panel
## accents. An empty slot is left uncoloured and reads as an empty frame, which is what it is.
##
## Falls back to the old flat box if the theme has no SlotButton (theme unset, or this script
## running before the theme loads), so the armory is never left with unstyled buttons.
func _style_btn_mod(btn: Button, border_col: Color, filled: bool) -> void:
	btn.theme_type_variation = &"SlotButton"
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var hot: bool = state in ["hover", "pressed", "focus"]
		var base: StyleBox = btn.get_theme_stylebox(state, "SlotButton")
		if base is StyleBoxTexture:
			var tex := (base as StyleBoxTexture).duplicate() as StyleBoxTexture
			if state == "focus":
				tex.modulate_color = C_AMBER_HI
			elif filled or hot:
				## Lifted toward white before multiplying, or a mid-saturation rarity colour
				## drags the bone outline down to something that reads as dirt.
				tex.modulate_color = border_col.lerp(Color.WHITE, 0.55)
			btn.add_theme_stylebox_override(state, tex)
			continue

		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(0.10, 0.09, 0.07, 0.90) if hot else (
			C_PLATE if filled else Color(0.055, 0.048, 0.040)
		)
		sb.border_width_left   = 2
		sb.border_width_top    = 0
		sb.border_width_right  = 0
		sb.border_width_bottom = 0
		sb.border_color        = border_col if (filled or hot) else C_BORDER
		if state == "focus":
			sb.border_width_top    = 1
			sb.border_width_right  = 1
			sb.border_width_bottom = 1
			sb.border_color        = C_AMBER_HI
		sb.set_content_margin(SIDE_LEFT,   5)
		sb.set_content_margin(SIDE_RIGHT,  3)
		sb.set_content_margin(SIDE_TOP,    2)
		sb.set_content_margin(SIDE_BOTTOM, 2)
		btn.add_theme_stylebox_override(state, sb)


func _style_picker_chrome() -> void:
	_picker_header.add_theme_font_size_override("font_size", FS_MD)
	_picker_header.add_theme_color_override("font_color", C_AMBER)

	_picker_empty_label.add_theme_font_size_override("font_size", FS_MD)
	_picker_empty_label.add_theme_color_override("font_color", C_T2)

	_picker_cancel_btn.text = "< CANCEL"
	_picker_cancel_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_picker_cancel_btn.add_theme_font_size_override("font_size", FS_MD)
	_picker_cancel_btn.add_theme_color_override("font_color", C_T1)
	_picker_cancel_btn.add_theme_color_override("font_hover_color", C_T0)
	_style_btn_flat(_picker_cancel_btn, Color(0, 0, 0, 0), Color(0.18, 0.14, 0.10, 0.60))

	for btn in _picker_mod_btns:
		btn.add_theme_font_size_override("font_size", FS_MD)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_btn_flat(btn, Color(0, 0, 0, 0), C_AMBER_LO)

	for d in _picker_mod_descs:
		d.add_theme_font_size_override("font_size", FS_XS)
		d.add_theme_color_override("font_color", C_T2)


func _lbl(parent: Control, text: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(l)
	return l


# ── Data helpers ──────────────────────────────────────────────────────────────

func _get_weapon_for_slot(slot: int) -> String:
	if Engine.is_editor_hint() or _pm == null:
		return ""
	## Per-character loadout: the armory edits the currently selected character's weapons.
	return _pm.get_character_weapon(_pm.selected_character, slot)


func _disconnect_all(sig: Signal) -> void:
	for conn in sig.get_connections():
		sig.disconnect(conn.callable)


## Mark every mod evolution this loadout now satisfies as DISCOVERED, so the codex shows what the
## player has assembled the moment they assemble it. REVEALED still requires actually using it in
## a run (ComboEffectResolver). Replaces _discover_combos_for_weapon, which walked per-weapon mod
## pairs against the retired generic interaction matrix.
func _discover_evolutions_for(char_id: String) -> void:
	var kit_id: String = ModApplicability.kit_of(char_id)
	if kit_id.is_empty():
		return
	var equipped: Array = _pm.get_active_class_mods(char_id)
	for evo_id: String in ClassModData.active_evolutions(kit_id, equipped):
		CodexManager.discover_combo(StringName(evo_id))
