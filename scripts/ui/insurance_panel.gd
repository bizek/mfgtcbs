extends CanvasLayer

## InsurancePanel — in-run UI to designate one item as insured.
## Toggle with [I] during a run. Requires the insurance_license Workshop upgrade.
## Lists all at-risk items (collected weapons, collected mods, mid-run equipped mods).
## Pressing "Insure" on an item replaces any previous insured item.

var _panel: ColorRect
var _item_vbox: VBoxContainer
var _rows: Array = []  ## [{item: {id, type, display}, label: Label, btn: Button}]


func _ready() -> void:
	layer = 120  ## Below pause menu (126), above game layer
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	GameManager.insured_item_changed.connect(func(_id: String): _refresh_rows())
	GameManager.loot_changed.connect(func(_v: float): if visible: _rebuild_rows())


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	var state := GameManager.current_state
	var in_run: bool = state == GameManager.GameState.RUN_ACTIVE \
			or state == GameManager.GameState.EXTRACTING

	## Close on ESC if panel is open (before pause menu grabs it)
	if visible and event.keycode == KEY_ESCAPE:
		visible = false
		get_viewport().set_input_as_handled()
		return

	if event.keycode != KEY_I:
		return
	if not in_run:
		return
	if not ProgressionManager.has_upgrade("insurance_license"):
		return

	if visible:
		visible = false
	else:
		_rebuild_rows()
		visible = true
	get_viewport().set_input_as_handled()


func _build_ui() -> void:
	## Full-screen semi-transparent backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	## Centered panel
	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pc.grow_vertical = Control.GROW_DIRECTION_BOTH
	backdrop.add_child(pc)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.12, 0.95)
	bg.set_corner_radius_all(4)
	bg.set_content_margin_all(12.0)
	pc.add_theme_stylebox_override("panel", bg)

	var outer := VBoxContainer.new()
	outer.custom_minimum_size = Vector2(240.0, 0.0)
	outer.add_theme_constant_override("separation", 6)
	pc.add_child(outer)

	var title := Label.new()
	title.text = "INSURANCE"
	title.add_theme_font_size_override("font_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)

	var sep := HSeparator.new()
	outer.add_child(sep)

	var sub_lbl := Label.new()
	sub_lbl.text = "Insure one item — it survives on death."
	sub_lbl.add_theme_font_size_override("font_size", 8)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.modulate = Color(0.65, 0.65, 0.72)
	outer.add_child(sub_lbl)

	_item_vbox = VBoxContainer.new()
	_item_vbox.add_theme_constant_override("separation", 4)
	outer.add_child(_item_vbox)

	var hint := Label.new()
	hint.text = "[I] or [ESC] to close"
	hint.add_theme_font_size_override("font_size", 8)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(0.5, 0.5, 0.5)
	outer.add_child(hint)

	_panel = backdrop


func _rebuild_rows() -> void:
	for child in _item_vbox.get_children():
		child.queue_free()
	_rows.clear()

	var items: Array = []

	for w in GameManager.collected_weapons:
		var display: String = WeaponData.ALL.get(w, {}).get("display_name", w)
		items.append({"id": w, "type": "weapon", "display": "[Weapon] " + display})

	for m in GameManager.collected_mods:
		items.append({"id": m, "type": "mod", "display": "[Mod] " + m})

	for weapon_id in GameManager.run_equipped_mods:
		for slot in GameManager.run_equipped_mods[weapon_id]:
			var mod_id: String = GameManager.run_equipped_mods[weapon_id][slot]
			var w_display: String = WeaponData.ALL.get(weapon_id, {}).get("display_name", weapon_id)
			items.append({
				"id": mod_id,
				"type": "equipped_mod",
				"display": "[Mod] %s on %s" % [mod_id, w_display]
			})

	if items.is_empty():
		var empty := Label.new()
		empty.text = "No items at risk this run."
		empty.add_theme_font_size_override("font_size", 9)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.modulate = Color(0.55, 0.55, 0.62)
		_item_vbox.add_child(empty)
		return

	for item in items:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		_item_vbox.add_child(hbox)

		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)

		var btn := Button.new()
		btn.add_theme_font_size_override("font_size", 9)
		btn.custom_minimum_size = Vector2(64.0, 0.0)
		hbox.add_child(btn)

		var cap_id: String = item["id"]
		btn.pressed.connect(func(): GameManager.set_insured_item(cap_id))

		_rows.append({"item": item, "label": lbl, "btn": btn})

	_refresh_rows()


func _refresh_rows() -> void:
	var insured: String = GameManager.insured_item
	for row in _rows:
		var item: Dictionary = row["item"]
		var lbl: Label = row["label"]
		var btn: Button = row["btn"]
		var is_insured: bool = (item["id"] == insured)

		if is_insured:
			lbl.text = "[★] " + item["display"]
			lbl.modulate = Color(1.0, 0.88, 0.22)
			btn.text = "INSURED"
			btn.disabled = true
		else:
			lbl.text = item["display"]
			lbl.modulate = Color(0.82, 0.82, 0.87)
			btn.text = "Insure"
			btn.disabled = false
