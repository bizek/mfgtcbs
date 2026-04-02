@tool
extends Control

## Armory panel — weapon slot selection and mod management.

signal close_requested

@onready var _base: HubPanelBase = $PanelBase

## ── ArmoryView nodes ─────────────────────────────────────────────────────────
@onready var _armory_view:        Control   = $ArmoryView
@onready var _slot1_tab:          Button    = $ArmoryView/ArmoryMargin/ArmoryVBox/TabRow/Slot1Tab
@onready var _slot2_tab:          Button    = $ArmoryView/ArmoryMargin/ArmoryVBox/TabRow/Slot2Tab
@onready var _slot3_tab:          Button    = $ArmoryView/ArmoryMargin/ArmoryVBox/TabRow/Slot3Tab
@onready var _tab_separator:      ColorRect = $ArmoryView/ArmoryMargin/ArmoryVBox/TabRow/TabSeparator
@onready var _single_slot_header: Label     = $ArmoryView/ArmoryMargin/ArmoryVBox/TabRow/SingleSlotHeader
@onready var _no_weapons_label:   Label     = $ArmoryView/ArmoryMargin/ArmoryVBox/WeaponList/NoWeaponsLabel
@onready var _weapon_btns: Array[Button] = [
	$ArmoryView/ArmoryMargin/ArmoryVBox/WeaponList/WeaponBtn0,
	$ArmoryView/ArmoryMargin/ArmoryVBox/WeaponList/WeaponBtn1,
	$ArmoryView/ArmoryMargin/ArmoryVBox/WeaponList/WeaponBtn2,
	$ArmoryView/ArmoryMargin/ArmoryVBox/WeaponList/WeaponBtn3,
]
@onready var _mods_header:    Label = $ArmoryView/ArmoryMargin/ArmoryVBox/ModsHeader
@onready var _status_label:   Label = $ArmoryView/ArmoryMargin/ArmoryVBox/StatusLabel

## Mod slot triplets: [slot_label, mod_button, remove_button]
@onready var _mod_slot_labels:   Array[Label]  = [
	$ArmoryView/ArmoryMargin/ArmoryVBox/ModSlotList/ModSlotRow0/ModSlot1Label,
	$ArmoryView/ArmoryMargin/ArmoryVBox/ModSlotList/ModSlotRow1/ModSlot2Label,
	$ArmoryView/ArmoryMargin/ArmoryVBox/ModSlotList/ModSlotRow2/ModSlot3Label,
]
@onready var _mod_slot_btns: Array[Button] = [
	$ArmoryView/ArmoryMargin/ArmoryVBox/ModSlotList/ModSlotRow0/ModSlot1Btn,
	$ArmoryView/ArmoryMargin/ArmoryVBox/ModSlotList/ModSlotRow1/ModSlot2Btn,
	$ArmoryView/ArmoryMargin/ArmoryVBox/ModSlotList/ModSlotRow2/ModSlot3Btn,
]
@onready var _mod_slot_remove_btns: Array[Button] = [
	$ArmoryView/ArmoryMargin/ArmoryVBox/ModSlotList/ModSlotRow0/ModSlot1RemoveBtn,
	$ArmoryView/ArmoryMargin/ArmoryVBox/ModSlotList/ModSlotRow1/ModSlot2RemoveBtn,
	$ArmoryView/ArmoryMargin/ArmoryVBox/ModSlotList/ModSlotRow2/ModSlot3RemoveBtn,
]

## ── ModPickerView nodes ───────────────────────────────────────────────────────
@onready var _picker_view:          Control   = $ModPickerView
@onready var _picker_header:        Label     = $ModPickerView/PickerMargin/PickerVBox/PickerHeader
@onready var _picker_empty_label:   Label     = $ModPickerView/PickerMargin/PickerVBox/PickerEmptyLabel
@onready var _picker_cancel_btn:    Button    = $ModPickerView/PickerMargin/PickerVBox/PickerCancelBtn
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

## ── State ────────────────────────────────────────────────────────────────────
var _active_slot:     int  = 1
var _mod_picking:     bool = false
var _mod_target_slot: int  = 0
var _pm:              Node = null

func _ready() -> void:
	_base.close_requested.connect(func(): close_requested.emit())

	## Wire cancel button once — it never changes.
	_picker_cancel_btn.pressed.connect(func():
		_mod_picking = false
		populate(_pm)
	)

	## Wire slot tab buttons once.
	_slot1_tab.pressed.connect(func():
		_active_slot  = 1
		_mod_picking  = false
		populate(_pm)
	)
	_slot2_tab.pressed.connect(func():
		_active_slot  = 2
		_mod_picking  = false
		populate(_pm)
	)
	_slot3_tab.pressed.connect(func():
		_active_slot  = 3
		_mod_picking  = false
		populate(_pm)
	)

	if Engine.is_editor_hint():
		return
	populate(ProgressionManager)

func populate(pm: Node) -> void:
	_pm = pm
	if _mod_picking:
		_armory_view.visible  = false
		_picker_view.visible  = true
		_build_mod_picker()
	else:
		_armory_view.visible  = true
		_picker_view.visible  = false
		_build_armory()

# ── Armory main view ──────────────────────────────────────────────────────────

func _build_armory() -> void:
	var pm          := _pm
	var weapons: Array = pm.unlocked_weapons
	var slot_count: int = pm.starting_weapon_slots()
	var multi_slots: bool = slot_count >= 2

	## Clamp active slot to available slots.
	if _active_slot > slot_count:
		_active_slot = 1

	var active_weapon_id: String
	match _active_slot:
		1: active_weapon_id = pm.selected_weapon
		2: active_weapon_id = pm.selected_weapon_2
		3: active_weapon_id = pm.selected_weapon_3
		_: active_weapon_id = pm.selected_weapon

	## Tab row visibility.
	_slot1_tab.visible          = multi_slots
	_slot2_tab.visible          = multi_slots
	_slot3_tab.visible          = slot_count >= 3
	_tab_separator.visible      = multi_slots
	_single_slot_header.visible = not multi_slots

	## Tab active state styling.
	if multi_slots:
		_style_tab(_slot1_tab, _active_slot == 1)
		_style_tab(_slot2_tab, _active_slot == 2)
	if slot_count >= 3:
		_style_tab(_slot3_tab, _active_slot == 3)

	## Weapon list.
	_no_weapons_label.visible = weapons.is_empty()
	for i in range(_weapon_btns.size()):
		var btn := _weapon_btns[i]
		if i < weapons.size():
			var w_id: String  = str(weapons[i])
			var is_sel: bool  = w_id == active_weapon_id
			btn.visible = true
			btn.text    = ("▶ " if is_sel else "  ") + w_id
			btn.add_theme_color_override("font_color",
					Color(0.95, 0.78, 0.22) if is_sel else Color(0.72, 0.72, 0.78))
			var norm_bg := Color(0.22, 0.14, 0.06, 0.65) if is_sel else Color(0.0, 0.0, 0.0, 0.0)
			_base.style_btn(btn, norm_bg, Color(0.25, 0.20, 0.10, 0.55), 2)
			## Reconnect.
			_disconnect_all(btn.pressed)
			var cap_wid   := w_id
			var cap_slot  := _active_slot
			btn.pressed.connect(func():
				match cap_slot:
					1: _pm.selected_weapon   = cap_wid
					2: _pm.selected_weapon_2 = cap_wid
					3: _pm.selected_weapon_3 = cap_wid
				_pm.save_data()
				_mod_picking = false
				populate(_pm)
			)
		else:
			btn.visible = false

	## Mod slots.
	_mods_header.text = "MODS  (%s)" % active_weapon_id
	var weapon_data: Dictionary = WeaponData.ALL.get(active_weapon_id, {})
	var max_slots: int = weapon_data.get("mod_slots", 1)
	var equipped: Array = pm.get_weapon_mods(active_weapon_id)

	for i in range(_mod_slot_btns.size()):
		var visible_slot := i < max_slots
		_mod_slot_labels[i].visible      = visible_slot
		_mod_slot_btns[i].visible        = visible_slot
		if not visible_slot:
			_mod_slot_remove_btns[i].visible = false
			continue

		var mod_id: String = equipped[i] if i < equipped.size() else ""
		var mod_name: String
		var mod_col: Color
		if not mod_id.is_empty():
			mod_name = ModData.ALL.get(mod_id, {}).get("name", "--- EMPTY ---")
			mod_col  = ModData.ALL.get(mod_id, {}).get("color", Color(0.40, 0.40, 0.45))
		else:
			mod_name = "--- EMPTY ---"
			mod_col  = Color(0.32, 0.32, 0.38)

		_mod_slot_btns[i].text = mod_name
		_mod_slot_btns[i].add_theme_color_override("font_color", mod_col)

		_disconnect_all(_mod_slot_btns[i].pressed)
		var cap_i   := i
		_mod_slot_btns[i].pressed.connect(func():
			_mod_picking     = true
			_mod_target_slot = cap_i
			populate(_pm)
		)

		_mod_slot_remove_btns[i].visible = not mod_id.is_empty()
		if not mod_id.is_empty():
			_disconnect_all(_mod_slot_remove_btns[i].pressed)
			var cap_wid2 := active_weapon_id
			var cap_i2   := i
			_mod_slot_remove_btns[i].pressed.connect(func():
				_pm.remove_weapon_mod(cap_wid2, cap_i2)
				_mod_picking = false
				populate(_pm)
			)

	## Status label.
	if multi_slots:
		var sel_display := active_weapon_id if not active_weapon_id.is_empty() else "\u2014 none \u2014"
		_status_label.text = "Slot %d: %s" % [_active_slot, sel_display]
	else:
		_status_label.text = "Selected: %s" % pm.selected_weapon

# ── Mod picker sub-view ───────────────────────────────────────────────────────

func _build_mod_picker() -> void:
	var pm        := _pm
	var weapon_id: String
	match _active_slot:
		1: weapon_id = pm.selected_weapon
		2: weapon_id = pm.selected_weapon_2
		3: weapon_id = pm.selected_weapon_3
		_: weapon_id = pm.selected_weapon

	_picker_header.text = "SELECT MOD  for slot %d  (%s)" % [_mod_target_slot + 1, weapon_id]

	## De-duplicate mods by id with count.
	var counts: Dictionary = {}
	for mid in pm.owned_mods:
		counts[mid] = counts.get(mid, 0) + 1

	var mod_ids: Array = counts.keys()
	_picker_empty_label.visible = mod_ids.is_empty()

	for i in range(_picker_mod_btns.size()):
		if i < mod_ids.size():
			var mod_id: String        = str(mod_ids[i])
			var mod_data: Dictionary  = ModData.ALL.get(mod_id, {})
			var mod_name: String      = mod_data.get("name", mod_id)
			var mod_col: Color        = mod_data.get("color", Color.WHITE)
			var count: int            = counts[mod_id]
			var desc: String          = mod_data.get("desc", "")

			_picker_mod_btns[i].visible = true
			_picker_mod_btns[i].text    = ("%s  \u00d7%d" % [mod_name, count]) if count > 1 else mod_name
			_picker_mod_btns[i].add_theme_color_override("font_color", mod_col)

			_disconnect_all(_picker_mod_btns[i].pressed)
			var cap_mid  := mod_id
			var cap_wid  := weapon_id
			var cap_slot := _mod_target_slot
			_picker_mod_btns[i].pressed.connect(func():
				_pm.set_weapon_mod(cap_wid, cap_slot, cap_mid)
				_mod_picking = false
				populate(_pm)
			)

			if not desc.is_empty():
				_picker_mod_descs[i].visible = true
				_picker_mod_descs[i].text    = "  " + desc
			else:
				_picker_mod_descs[i].visible = false
		else:
			_picker_mod_btns[i].visible  = false
			_picker_mod_descs[i].visible = false

# ── Helpers ───────────────────────────────────────────────────────────────────

func _style_tab(btn: Button, is_active: bool) -> void:
	var slot_num: int
	if btn == _slot1_tab:
		slot_num = 1
	elif btn == _slot2_tab:
		slot_num = 2
	else:
		slot_num = 3
	btn.text = ("[ SLOT %d ]" if is_active else "  SLOT %d  ") % slot_num
	btn.add_theme_color_override("font_color",
			Color(0.95, 0.78, 0.22) if is_active else Color(0.55, 0.55, 0.60))

func _disconnect_all(sig: Signal) -> void:
	for conn in sig.get_connections():
		sig.disconnect(conn.callable)
