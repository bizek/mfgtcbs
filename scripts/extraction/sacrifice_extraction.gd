extends ExtractionZoneBase
class_name SacrificeExtraction

## SacrificeExtraction — Sacrifice one collected item for an instant extraction.
## Opens a UI menu when the player enters the zone with loot. Activates at phase 2+.

signal sacrifice_ui_requested
signal sacrifice_ui_closed

const SACRIFICE_PROXIMITY: float = 44.0

var _ui_open: bool = false
var _sacrifice_layer: CanvasLayer = null

func _init() -> void:
	extraction_type = "sacrifice"
	name = "SacrificeExtraction"

## ── Setup ────────────────────────────────────────────────────────────────────

func build_zone(pos: Vector2) -> void:
	global_position = pos

	## Ominous blood-red aura
	var aura := ColorRect.new()
	aura.name = "Aura"
	aura.color = Color(0.55, 0.02, 0.04, 0.12)
	aura.size = Vector2(130.0, 130.0)
	aura.position = Vector2(-65.0, -65.0)
	add_child(aura)

	## Inner fill
	_build_fill(self, Color(0.50, 0.02, 0.05, 0.28))

	## Dark crimson border
	_build_border(self, Color(0.80, 0.06, 0.08, 0.60))

	## Label
	_build_state_label(self, "SACRIFICE", Color(0.90, 0.14, 0.14, 0.60), -36.0)

	## Persistent particle drip
	var p := CPUParticles2D.new()
	p.amount = 10
	p.lifetime = 1.4
	p.one_shot = false
	p.explosiveness = 0.0
	p.direction = Vector2(0.0, -1.0)
	p.spread = 80.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 20.0
	p.gravity = Vector2(0.0, -6.0)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color = Color(0.70, 0.04, 0.04, 0.65)
	p.emitting = true
	add_child(p)

	## Aura slow pulse
	var pulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	pulse.tween_property(aura, "modulate:a", 0.25, 1.8)
	pulse.tween_property(aura, "modulate:a", 1.0, 1.8)

func activate_label() -> void:
	if _state_label:
		_state_label.modulate = Color(0.90, 0.14, 0.14, 0.80)

## ── Proximity handling ───────────────────────────────────────────────────────

func check_proximity(player_pos: Vector2) -> bool:
	return player_pos.distance_to(global_position) <= SACRIFICE_PROXIMITY

func try_open_ui(player_pos: Vector2) -> bool:
	if _ui_open or ExtractionManager.is_channeling:
		return false
	if not check_proximity(player_pos):
		return false
	if not _has_sacrifice_items():
		return false
	if not GameManager.is_extraction_allowed():
		return false
	_open_ui()
	return true

func is_ui_open() -> bool:
	return _ui_open

## ── Sacrifice UI ─────────────────────────────────────────────────────────────

func _open_ui() -> void:
	if _ui_open:
		return
	_ui_open = true
	GameManager.set_paused(true)

	_sacrifice_layer = CanvasLayer.new()
	_sacrifice_layer.layer = 60
	_sacrifice_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(_sacrifice_layer)

	var panel := _build_panel()
	_sacrifice_layer.add_child(panel)
	sacrifice_ui_requested.emit()

func close_ui() -> void:
	_ui_open = false
	GameManager.set_paused(false)
	if _sacrifice_layer:
		_sacrifice_layer.queue_free()
		_sacrifice_layer = null
	sacrifice_ui_closed.emit()

func _has_sacrifice_items() -> bool:
	return not GameManager.collected_weapons.is_empty() \
		or not GameManager.collected_mods.is_empty() \
		or GameManager.loot_carried > 0.0

func _on_item_selected(item_key: String) -> void:
	if item_key == "all_loot":
		GameManager.sacrifice_all_loot()
	elif item_key.begins_with("mod_"):
		var mod_id: String = item_key.substr(4)
		GameManager.sacrifice_mod(mod_id)
	else:
		GameManager.sacrifice_weapon(item_key)

	close_ui()
	GameManager.active_extraction_type = "sacrifice"
	GameManager.on_extraction_complete()

## ── Panel building ───────────────────────────────────────────────────────────

func _build_panel() -> Control:
	const PIXEL_FONT_PATH := "res://assets/fonts/m5x7.ttf"
	const PANEL_W: float = 360.0
	const PANEL_H: float = 293.0
	const VW: float = 480.0
	const VH: float = 270.0

	var pixel_font: Font = load(PIXEL_FONT_PATH) if ResourceLoader.exists(PIXEL_FONT_PATH) else null

	## Dark overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.size = Vector2(VW, VH)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS

	var panel := Panel.new()
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.position = Vector2((VW - PANEL_W) * 0.5, (VH - PANEL_H) * 0.5)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.055, 0.07, 0.97)
	style.border_color = Color(0.75, 0.08, 0.10)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)

	## Title bar
	var title_bg := ColorRect.new()
	title_bg.color = Color(0.35, 0.04, 0.05)
	title_bg.size = Vector2(PANEL_W, 22.0)
	panel.add_child(title_bg)

	var title_lbl := Label.new()
	title_lbl.text = "SACRIFICE EXTRACTION"
	title_lbl.position = Vector2(8.0, 4.0)
	if pixel_font:
		title_lbl.add_theme_font_override("font", pixel_font)
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.28, 0.28))
	panel.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Choose one item to destroy. Extraction is instant."
	sub_lbl.position = Vector2(8.0, 26.0)
	if pixel_font:
		sub_lbl.add_theme_font_override("font", pixel_font)
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.55))
	sub_lbl.size = Vector2(PANEL_W - 16.0, 16.0)
	panel.add_child(sub_lbl)

	## Scrollable list
	const LIST_Y: float = 46.0
	const LIST_H: float = 140.0
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(6.0, LIST_Y)
	scroll.size = Vector2(PANEL_W - 12.0, LIST_H)
	scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(PANEL_W - 16.0, 0.0)
	vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(vbox)

	## Weapons
	for weapon_id in GameManager.collected_weapons:
		var row := _build_row(weapon_id, weapon_id, pixel_font)
		vbox.add_child(row)

	## Mods
	for mod_id in GameManager.collected_mods:
		var mod_name: String = ModData.ALL.get(mod_id, {}).get("name", mod_id)
		var row := _build_row(mod_name + " (mod)", "mod_" + mod_id, pixel_font)
		vbox.add_child(row)

	## Generic loot fallback
	if GameManager.collected_weapons.is_empty() and GameManager.collected_mods.is_empty() and GameManager.loot_carried > 0.0:
		var row := _build_row("All resources  (%d)" % int(GameManager.loot_carried), "all_loot", pixel_font)
		vbox.add_child(row)

	if vbox.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "Nothing to sacrifice."
		if pixel_font:
			empty.add_theme_font_override("font", pixel_font)
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", Color(0.50, 0.50, 0.55))
		vbox.add_child(empty)

	## Cancel button
	var sep := ColorRect.new()
	sep.color = Color(0.28, 0.06, 0.06)
	sep.size = Vector2(PANEL_W, 1.0)
	sep.position = Vector2(0.0, LIST_Y + LIST_H + 4.0)
	panel.add_child(sep)

	var cancel_btn := Button.new()
	cancel_btn.text = "CANCEL \u2014 walk away"
	cancel_btn.size = Vector2(PANEL_W - 16.0, 20.0)
	cancel_btn.position = Vector2(8.0, PANEL_H - 26.0)
	cancel_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	if pixel_font:
		cancel_btn.add_theme_font_override("font", pixel_font)
	cancel_btn.add_theme_font_size_override("font_size", 15)
	cancel_btn.add_theme_color_override("font_color", Color(0.60, 0.55, 0.55))
	cancel_btn.pressed.connect(close_ui)
	panel.add_child(cancel_btn)

	overlay.add_child(panel)
	return overlay

func _build_row(display_text: String, item_key: String, pixel_font: Font) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_lbl := Label.new()
	name_lbl.text = display_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if pixel_font:
		name_lbl.add_theme_font_override("font", pixel_font)
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.78))
	row.add_child(name_lbl)

	var btn := Button.new()
	btn.text = "SACRIFICE"
	btn.custom_minimum_size = Vector2(80.0, 18.0)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	if pixel_font:
		btn.add_theme_font_override("font", pixel_font)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.95, 0.28, 0.28))
	var cap_key: String = item_key
	btn.pressed.connect(func(): _on_item_selected(cap_key))
	row.add_child(btn)

	return row
