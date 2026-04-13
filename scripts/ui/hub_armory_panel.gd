@tool
extends Control

## Armory panel — weapon slot selection and mod management.

signal close_requested

@onready var _base: HubPanelBase = $PanelBase

## Codex overlay (built in _ready, added to parent CanvasLayer so it sits on top)
var _codex_panel: CodexGridPanel = null
var _codex_btn: Button = null

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

	## Build and attach the codex overlay.
	_build_codex_overlay()

	populate(ProgressionManager)


func _build_codex_overlay() -> void:
	## Codex toggle button — added to ArmoryView so it's part of the armory chrome.
	_codex_btn = Button.new()
	_codex_btn.text = "\u25c6 CODEX"
	_codex_btn.position = Vector2(192, 218)
	_codex_btn.size = Vector2(86, 14)
	_codex_btn.add_theme_font_override("font", HubPanelBase.PIXEL_FONT)
	_codex_btn.add_theme_font_size_override("font_size", 10)
	_codex_btn.add_theme_color_override("font_color", Color(0.60, 0.42, 0.88))
	_codex_btn.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = (Color(0.22, 0.12, 0.40, 0.65)
			if state in ["hover", "pressed"] else Color(0.10, 0.06, 0.20, 0.50))
		sb.set_border_width_all(1)
		sb.border_color = Color(0.45, 0.25, 0.78, 0.60)
		sb.set_content_margin_all(2)
		_codex_btn.add_theme_stylebox_override(state, sb)
	_codex_btn.pressed.connect(_on_codex_btn_pressed)
	$ArmoryView.add_child(_codex_btn)

	## Codex panel — lives as a sibling on the same CanvasLayer so it covers
	## the full 480×270 viewport on top of the armory panel.
	_codex_panel = CodexGridPanel.new()
	_codex_panel.position = Vector2(10.0, 4.0)
	_codex_panel.size     = Vector2(460.0, 262.0)
	_codex_panel.visible  = false
	_codex_panel.close_requested.connect(func():
		_codex_panel.visible = false
		_codex_btn.add_theme_color_override("font_color", Color(0.60, 0.42, 0.88))
	)
	_codex_panel.entry_hovered.connect(_on_codex_entry_hovered)
	get_parent().add_child(_codex_panel)


func _on_codex_btn_pressed() -> void:
	_codex_panel.visible = not _codex_panel.visible
	var active_col := Color(0.82, 0.62, 1.0) if _codex_panel.visible else Color(0.60, 0.42, 0.88)
	_codex_btn.add_theme_color_override("font_color", active_col)


func _on_codex_entry_hovered(_combo_id: StringName) -> void:
	## Entry hover is informational; reactive preview is driven by mod-picker hover.
	pass

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

	## Count how many slots are actually filled (non-empty) within the allowed range.
	var filled_count: int = 0
	for k in range(max_slots):
		if k < equipped.size() and not (equipped[k] as String).is_empty():
			filled_count += 1
	var weapon_full: bool = filled_count >= max_slots

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

		## Disable empty-slot buttons when the weapon is already at mod capacity.
		_mod_slot_btns[i].disabled = mod_id.is_empty() and weapon_full

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

	## Status label — show capacity when full, otherwise show selection info.
	if weapon_full:
		_status_label.text = "Mod slots full  (%d/%d)" % [filled_count, max_slots]
	elif multi_slots:
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

	## Guard: refuse if the target slot exceeds this weapon's mod capacity.
	var max_slots: int = WeaponData.ALL.get(weapon_id, {}).get("mod_slots", 1)
	if _mod_target_slot >= max_slots:
		_picker_header.text = "NO MOD SLOTS  (%s)" % weapon_id
		_picker_empty_label.visible = true
		_picker_empty_label.text    = "This weapon has no more mod slots."
		for btn in _picker_mod_btns:
			btn.visible = false
		for desc in _picker_mod_descs:
			desc.visible = false
		return

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
				_discover_combos_for_weapon(cap_wid)
				if _codex_panel != null:
					_codex_panel.set_hover_highlight("")
				_mod_picking = false
				populate(_pm)
			)
			## Reactive preview: highlight relevant codex cell on hover.
			_disconnect_all(_picker_mod_btns[i].mouse_entered)
			_disconnect_all(_picker_mod_btns[i].mouse_exited)
			var cap_equipped: Array = _pm.get_weapon_mods(weapon_id).duplicate()
			_picker_mod_btns[i].mouse_entered.connect(func():
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
			_picker_mod_btns[i].mouse_exited.connect(func():
				if _codex_panel != null:
					_codex_panel.set_hover_highlight("")
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


## Discover all valid combos for the mods currently on a weapon.
## Called after any mod equip so CodexManager stays in sync.
func _discover_combos_for_weapon(weapon_id: String) -> void:
	var equipped: Array = _pm.get_weapon_mods(weapon_id)
	if equipped.size() < 2:
		return

	## Check all 2-mod pairs.
	for i in equipped.size():
		for j in range(i + 1, equipped.size()):
			var pairs := CodexManager.get_combos_for_mod_pair(
				StringName(equipped[i]), StringName(equipped[j]))
			for entry: CodexEntry in pairs:
				CodexManager.discover_combo(entry.combo.combo_id)

	## Check all 3-mod triples when 3 mods are equipped.
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
