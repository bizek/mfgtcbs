extends Node2D

## Hub — Safe room between runs. Player walks to interactive stations and presses E.

const PIXEL_FONT := preload("res://assets/fonts/m5x7.ttf")
const PLAYER_SPEED := 85.0
const INTERACT_RADIUS := 40.0
const ROOM_W := 480
const ROOM_H := 270
const WALL_T := 14

## Layout constants — all panels share these so numbers stay consistent.
const PANEL_W    := 340       ## Panel width (px)
const PANEL_H    := 220       ## Panel height (px)
const PANEL_X    := 70        ## Panel left edge
const PANEL_Y    := 25        ## Panel top edge
const TITLE_H    := 22        ## Title bar height
const ROW_GAP    := 18        ## Vertical spacing between rows
const LABEL_W    := 310       ## Label width inside panel
const LABEL_H    := 20        ## Label height (clip box)
const FONT_TITLE := 16        ## Panel title font size
const FONT_BODY  := 14        ## Standard body text
const FONT_DIM   := 12        ## Dim / secondary text

## Station definitions: id, display name, accent color, world position, visual size, tagline.
const STATIONS: Array[Dictionary] = [
	{"id": "launch",   "name": "LAUNCH PAD", "color": Color(0.20, 0.90, 0.40),
	 "pos": Vector2(240, 88), "size": Vector2(110, 44), "desc": "begin descent"},
	{"id": "armory",   "name": "ARMORY",     "color": Color(0.90, 0.60, 0.12),
	 "pos": Vector2(82, 158), "size": Vector2(96, 42), "desc": "equip loadout"},
	{"id": "workshop", "name": "WORKSHOP",   "color": Color(0.68, 0.24, 0.88),
	 "pos": Vector2(398, 158), "size": Vector2(100, 42), "desc": "hub upgrades"},
	{"id": "records",  "name": "RECORDS",    "color": Color(0.65, 0.65, 0.72),
	 "pos": Vector2(140, 228), "size": Vector2(100, 42), "desc": "view stats"},
	{"id": "roster",   "name": "ROSTER",     "color": Color(0.45, 0.52, 0.95),
	 "pos": Vector2(330, 228), "size": Vector2(130, 42), "desc": "select character"},
]

var _player_body: CharacterBody2D
var _station_nodes: Array[Node2D] = []
var _interact_prompt: Label
var _resource_label: Label
var _active_station_id: String = ""
var _panel_layer: CanvasLayer
var _active_panel: Control = null

## Armory slot currently being configured (1 or 2).
var _armory_slot: int = 1

func _ready() -> void:
	_build_room()
	_apply_visual_tier()
	_build_stations()
	_build_player()
	_build_ui()

# ── Room ──────────────────────────────────────────────────────────────────────

func _build_room() -> void:
	## Floor base
	var floor_rect := ColorRect.new()
	floor_rect.color = Color(0.11, 0.12, 0.14)
	floor_rect.size = Vector2(ROOM_W, ROOM_H)
	add_child(floor_rect)

	## Subtle pixel grid
	for x in range(0, ROOM_W, 16):
		var line := ColorRect.new()
		line.color = Color(0.135, 0.148, 0.165)
		line.position = Vector2(x, 0)
		line.size = Vector2(1, ROOM_H)
		add_child(line)
	for y in range(0, ROOM_H, 16):
		var line := ColorRect.new()
		line.color = Color(0.135, 0.148, 0.165)
		line.position = Vector2(0, y)
		line.size = Vector2(ROOM_W, 1)
		add_child(line)

	## Walls (static collision + dark visual)
	_add_wall(Vector2(0, 0),                Vector2(ROOM_W, WALL_T))          ## top
	_add_wall(Vector2(0, ROOM_H - WALL_T),  Vector2(ROOM_W, WALL_T))          ## bottom
	_add_wall(Vector2(0, 0),                Vector2(WALL_T, ROOM_H))          ## left
	_add_wall(Vector2(ROOM_W - WALL_T, 0),  Vector2(WALL_T, ROOM_H))          ## right

	## Room title (dim, top-center)
	var title := Label.new()
	title.text = "BASE CAMP"
	title.add_theme_font_override("font", PIXEL_FONT)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.38, 0.40, 0.48))
	title.position = Vector2(ROOM_W * 0.5 - 34, 1)
	add_child(title)

func _add_wall(pos: Vector2, sz: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = sz
	cs.shape = rs
	cs.position = sz * 0.5
	body.add_child(cs)
	var vis := ColorRect.new()
	vis.color = Color(0.065, 0.075, 0.09)
	vis.size = sz
	body.add_child(vis)
	add_child(body)

# ── Visual Tier ───────────────────────────────────────────────────────────────

## Adds cosmetic decorations based on total resources ever spent.
func _apply_visual_tier() -> void:
	var tier := ProgressionManager.get_hub_tier()
	if tier >= 1:
		## Two upper-corner torches
		_add_torch(Vector2(24, 16))
		_add_torch(Vector2(452, 16))
	if tier >= 2:
		## Two lower side-wall torches
		_add_torch(Vector2(24, 204))
		_add_torch(Vector2(452, 204))
		## Decorative accent strip along the top wall
		var strip := ColorRect.new()
		strip.color = Color(0.42, 0.22, 0.60, 0.28)
		strip.size = Vector2(180, 2)
		strip.position = Vector2(150, 13)
		add_child(strip)
		var strip_hi := ColorRect.new()
		strip_hi.color = Color(0.68, 0.24, 0.88, 0.18)
		strip_hi.size = Vector2(180, 1)
		strip_hi.position = Vector2(150, 12)
		add_child(strip_hi)

func _add_torch(pos: Vector2) -> void:
	## Ambient glow (wide, very dim)
	var glow := ColorRect.new()
	glow.color = Color(0.90, 0.58, 0.08, 0.14)
	glow.size = Vector2(12, 12)
	glow.position = pos + Vector2(-6, -6)
	add_child(glow)
	## Flame
	var flame := ColorRect.new()
	flame.color = Color(1.0, 0.72, 0.16)
	flame.size = Vector2(4, 5)
	flame.position = pos + Vector2(-2, -5)
	add_child(flame)
	## Flame tip (brighter white-yellow)
	var tip := ColorRect.new()
	tip.color = Color(1.0, 0.96, 0.72)
	tip.size = Vector2(2, 2)
	tip.position = pos + Vector2(-1, -5)
	add_child(tip)
	## Wall mount
	var mount := ColorRect.new()
	mount.color = Color(0.22, 0.20, 0.18)
	mount.size = Vector2(4, 4)
	mount.position = pos + Vector2(-2, 0)
	add_child(mount)

# ── Stations ──────────────────────────────────────────────────────────────────

func _build_stations() -> void:
	for s in STATIONS:
		var root := Node2D.new()
		root.name = "Station_" + s["id"]
		root.position = s["pos"]
		root.set_meta("station_id", s["id"])

		var sz: Vector2 = s["size"]
		var col: Color = s["color"]

		## Dark backing panel
		var bg := ColorRect.new()
		bg.color = Color(col.r * 0.20, col.g * 0.20, col.b * 0.20)
		bg.size = sz
		bg.position = -sz * 0.5
		root.add_child(bg)

		## Top accent bar
		var bar_t := ColorRect.new()
		bar_t.color = col
		bar_t.size = Vector2(sz.x, 2)
		bar_t.position = Vector2(-sz.x * 0.5, -sz.y * 0.5)
		root.add_child(bar_t)

		## Bottom dim bar
		var bar_b := ColorRect.new()
		bar_b.color = Color(col.r * 0.4, col.g * 0.4, col.b * 0.4)
		bar_b.size = Vector2(sz.x, 1)
		bar_b.position = Vector2(-sz.x * 0.5, sz.y * 0.5 - 1)
		root.add_child(bar_b)

		## Station name
		var name_lbl := Label.new()
		name_lbl.text = s["name"]
		name_lbl.add_theme_font_override("font", PIXEL_FONT)
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", col)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.clip_contents = true
		name_lbl.size = sz
		name_lbl.position = -sz * 0.5 + Vector2(0, 5)
		root.add_child(name_lbl)

		## Description tagline
		var desc_lbl := Label.new()
		desc_lbl.text = s["desc"]
		desc_lbl.add_theme_font_override("font", PIXEL_FONT)
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.82))
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.clip_contents = true
		desc_lbl.size = sz
		desc_lbl.position = -sz * 0.5 + Vector2(0, 24)
		root.add_child(desc_lbl)

		add_child(root)
		_station_nodes.append(root)

# ── Player ────────────────────────────────────────────────────────────────────

func _build_player() -> void:
	_player_body = CharacterBody2D.new()
	_player_body.name = "HubPlayer"
	_player_body.collision_layer = 2
	_player_body.collision_mask = 1
	_player_body.position = Vector2(240, 212)

	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(7, 11)
	cs.shape = rs
	_player_body.add_child(cs)

	## Body (tan placeholder)
	var body_vis := ColorRect.new()
	body_vis.color = Color(0.78, 0.72, 0.58)
	body_vis.size = Vector2(7, 11)
	body_vis.position = Vector2(-3.5, -5.5)
	_player_body.add_child(body_vis)

	## Head
	var head := ColorRect.new()
	head.color = Color(0.94, 0.86, 0.68)
	head.size = Vector2(5, 3)
	head.position = Vector2(-2.5, -8.0)
	_player_body.add_child(head)

	add_child(_player_body)

# ── UI ────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_panel_layer = CanvasLayer.new()
	_panel_layer.layer = 10
	add_child(_panel_layer)

	## Interact prompt (floats above player)
	_interact_prompt = Label.new()
	_interact_prompt.text = "[ E ]  interact"
	_interact_prompt.add_theme_font_override("font", PIXEL_FONT)
	_interact_prompt.add_theme_font_size_override("font_size", 12)
	_interact_prompt.add_theme_color_override("font_color", Color(0.95, 0.92, 0.50))
	_interact_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_prompt.size = Vector2(130, 16)
	_interact_prompt.visible = false
	_panel_layer.add_child(_interact_prompt)

	## Resource counter (top-right) — prominent HUD element
	var res_bg := ColorRect.new()
	res_bg.color = Color(0.055, 0.065, 0.085, 0.92)
	res_bg.size = Vector2(148, 20)
	res_bg.position = Vector2(328, 2)
	_panel_layer.add_child(res_bg)

	var res_accent := ColorRect.new()
	res_accent.color = Color(0.90, 0.80, 0.30)
	res_accent.size = Vector2(148, 1)
	res_accent.position = Vector2(328, 2)
	_panel_layer.add_child(res_accent)

	_resource_label = Label.new()
	_resource_label.add_theme_font_override("font", PIXEL_FONT)
	_resource_label.add_theme_font_size_override("font_size", 14)
	_resource_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.32))
	_resource_label.position = Vector2(332, 4)
	_resource_label.text = "RESOURCES: %d" % ProgressionManager.resources
	_panel_layer.add_child(_resource_label)

	ProgressionManager.resources_changed.connect(_on_resources_changed)

func _on_resources_changed(amount: int) -> void:
	_resource_label.text = "RESOURCES: %d" % amount

# ── Main loop ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _active_panel != null:
		return
	_handle_movement(delta)
	_update_proximity()
	_handle_interact()

func _handle_movement(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_up"):    dir.y -= 1
	if Input.is_action_pressed("move_down"):  dir.y += 1
	if Input.is_action_pressed("move_left"):  dir.x -= 1
	if Input.is_action_pressed("move_right"): dir.x += 1
	_player_body.velocity = dir.normalized() * PLAYER_SPEED
	_player_body.move_and_slide()

func _update_proximity() -> void:
	var nearest_id: String = ""
	var nearest_dist: float = INTERACT_RADIUS
	for station in _station_nodes:
		var dist: float = _player_body.position.distance_to(station.position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_id = station.get_meta("station_id")

	_active_station_id = nearest_id
	if nearest_id.is_empty():
		_interact_prompt.visible = false
	else:
		_interact_prompt.visible = true
		_interact_prompt.position = _player_body.position + Vector2(-65, -28)

func _handle_interact() -> void:
	if Input.is_action_just_pressed("interact") and not _active_station_id.is_empty():
		_open_panel(_active_station_id)

# ── Panel system ──────────────────────────────────────────────────────────────

func _open_panel(station_id: String) -> void:
	if _active_panel != null:
		_active_panel.queue_free()
		_active_panel = null
	match station_id:
		"launch":   _active_panel = _make_launch_panel()
		"armory":   _active_panel = _make_armory_panel()
		"workshop": _active_panel = _make_workshop_panel()
		"records":  _active_panel = _make_records_panel()
		"roster":   _active_panel = _make_roster_panel()
	if _active_panel:
		_panel_layer.add_child(_active_panel)
		_interact_prompt.visible = false

func _close_panel() -> void:
	if _active_panel:
		_active_panel.queue_free()
		_active_panel = null

## Shared panel base: dark panel with title bar and X button.
func _make_panel_base(title_text: String, accent: Color) -> Panel:
	var panel := Panel.new()
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.position = Vector2(PANEL_X, PANEL_Y)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.075, 0.10, 0.97)
	style.border_color = accent
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)

	## Title bar background
	var title_bg := ColorRect.new()
	title_bg.color = Color(accent.r * 0.25, accent.g * 0.25, accent.b * 0.25)
	title_bg.size = Vector2(PANEL_W, TITLE_H)
	panel.add_child(title_bg)

	## Title text
	var title_lbl := Label.new()
	title_lbl.text = title_text
	title_lbl.add_theme_font_override("font", PIXEL_FONT)
	title_lbl.add_theme_font_size_override("font_size", FONT_TITLE)
	title_lbl.add_theme_color_override("font_color", accent)
	title_lbl.position = Vector2(10, 3)
	panel.add_child(title_lbl)

	## Close button (top-right corner)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.size = Vector2(22, TITLE_H)
	close_btn.position = Vector2(PANEL_W - 22, 0)
	close_btn.add_theme_font_override("font", PIXEL_FONT)
	close_btn.add_theme_font_size_override("font_size", FONT_BODY)
	close_btn.pressed.connect(_close_panel)
	panel.add_child(close_btn)

	return panel

## Adds a text label row at (12, y) with configurable colour and font size.
func _add_row(parent: Control, text: String, y: float,
		color: Color = Color(0.82, 0.82, 0.87), font_size: int = FONT_BODY) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", PIXEL_FONT)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = Vector2(12, y)
	lbl.size = Vector2(LABEL_W, LABEL_H)
	parent.add_child(lbl)

## Adds a clickable weapon-selection button row. Returns the button.
func _add_weapon_btn(parent: Control, weapon_name: String, y: float,
		is_selected: bool, slot: int) -> Button:
	var btn := Button.new()
	var prefix := "▶ " if is_selected else "  "
	btn.text = prefix + weapon_name
	btn.size = Vector2(LABEL_W - 2, 18)
	btn.position = Vector2(12, y)
	btn.add_theme_font_override("font", PIXEL_FONT)
	btn.add_theme_font_size_override("font_size", FONT_BODY)
	var col := Color(0.95, 0.78, 0.22) if is_selected else Color(0.72, 0.72, 0.78)
	btn.add_theme_color_override("font_color", col)
	btn.pressed.connect(func():
		if slot == 1:
			ProgressionManager.selected_weapon = weapon_name
		else:
			ProgressionManager.selected_weapon_2 = weapon_name
		ProgressionManager.save_data()
		_open_panel("armory")  ## Refresh panel
	)
	parent.add_child(btn)
	return btn

# ── Panel implementations ──────────────────────────────────────────────────────

func _make_launch_panel() -> Panel:
	var col := Color(0.20, 0.90, 0.40)
	var panel := _make_panel_base("LAUNCH PAD", col)
	var pm := ProgressionManager

	## Content rows — ROW_GAP spacing, starting just below title bar
	var y := float(TITLE_H + 8)
	_add_row(panel, "Ready to descend.", y, Color(0.62, 0.70, 0.66))
	y += ROW_GAP + 2
	_add_row(panel, "Character:   The Drifter", y)
	y += ROW_GAP

	if pm.starting_weapon_slots() >= 2:
		_add_row(panel, "Slot 1:      %s" % pm.selected_weapon, y)
		y += ROW_GAP
		var w2 := pm.selected_weapon_2 if not pm.selected_weapon_2.is_empty() else "— none —"
		_add_row(panel, "Slot 2:      %s" % w2, y)
		y += ROW_GAP
	else:
		_add_row(panel, "Weapon:      %s" % pm.selected_weapon, y)
		y += ROW_GAP

	_add_row(panel, "─────────────────────────────────────", y, Color(0.20, 0.23, 0.26))
	y += ROW_GAP - 4
	_add_row(panel, "Loot collected during a run is at risk.", y, Color(0.52, 0.52, 0.57), FONT_DIM)
	y += ROW_GAP - 2
	_add_row(panel, "Extract to keep it. Die and lose it all.", y, Color(0.52, 0.52, 0.57), FONT_DIM)

	var btn := Button.new()
	btn.text = "BEGIN DESCENT"
	btn.size = Vector2(160, 24)
	btn.position = Vector2((PANEL_W - 160) / 2, PANEL_H - 34)
	btn.add_theme_font_override("font", PIXEL_FONT)
	btn.add_theme_font_size_override("font_size", FONT_BODY)
	btn.pressed.connect(_start_run)
	panel.add_child(btn)

	return panel

func _make_armory_panel() -> Panel:
	var col := Color(0.90, 0.60, 0.12)
	var panel := _make_panel_base("ARMORY", col)
	var pm := ProgressionManager
	var weapons: Array = pm.unlocked_weapons
	var two_slots: bool = pm.starting_weapon_slots() >= 2

	if weapons.is_empty():
		var y := float(TITLE_H + 8)
		_add_row(panel, "No weapons collected yet.", y, Color(0.42, 0.42, 0.48))
		y += ROW_GAP + 2
		_add_row(panel, "Extract weapons from runs to", y, Color(0.42, 0.42, 0.48))
		y += ROW_GAP
		_add_row(panel, "build your collection.", y, Color(0.42, 0.42, 0.48))
		y += ROW_GAP + 6
		_add_row(panel, "─────────────────────────────────────", y, Color(0.20, 0.23, 0.26))
		y += ROW_GAP - 4
		_add_row(panel, "Active: Standard Sidearm", y, col)
		return panel

	if two_slots:
		## Slot selector tab buttons
		var tab_y := float(TITLE_H + 4)
		var slot1_btn := Button.new()
		slot1_btn.text = "[ SLOT 1 ]" if _armory_slot == 1 else "  SLOT 1  "
		slot1_btn.size = Vector2(148, 18)
		slot1_btn.position = Vector2(10, tab_y)
		slot1_btn.add_theme_font_override("font", PIXEL_FONT)
		slot1_btn.add_theme_font_size_override("font_size", FONT_DIM)
		slot1_btn.add_theme_color_override("font_color",
			Color(0.95, 0.78, 0.22) if _armory_slot == 1 else Color(0.55, 0.55, 0.60))
		slot1_btn.pressed.connect(func():
			_armory_slot = 1
			_open_panel("armory")
		)
		panel.add_child(slot1_btn)

		var slot2_btn := Button.new()
		slot2_btn.text = "[ SLOT 2 ]" if _armory_slot == 2 else "  SLOT 2  "
		slot2_btn.size = Vector2(148, 18)
		slot2_btn.position = Vector2(PANEL_W - 158, tab_y)
		slot2_btn.add_theme_font_override("font", PIXEL_FONT)
		slot2_btn.add_theme_font_size_override("font_size", FONT_DIM)
		slot2_btn.add_theme_color_override("font_color",
			Color(0.95, 0.78, 0.22) if _armory_slot == 2 else Color(0.55, 0.55, 0.60))
		slot2_btn.pressed.connect(func():
			_armory_slot = 2
			_open_panel("armory")
		)
		panel.add_child(slot2_btn)

		var sep_y := tab_y + 22.0
		_add_row(panel, "─────────────────────────────────────", sep_y, Color(0.20, 0.23, 0.26))

		var y := sep_y + ROW_GAP - 4
		var current := pm.selected_weapon if _armory_slot == 1 else pm.selected_weapon_2
		for w in weapons:
			var w_id: String = str(w)
			if y > PANEL_H - 48.0:
				break
			_add_weapon_btn(panel, w_id, y, w_id == current, _armory_slot)
			y += ROW_GAP

		_add_row(panel, "─────────────────────────────────────", PANEL_H - 38.0, Color(0.20, 0.23, 0.26))
		var sel_display := pm.selected_weapon_2 if _armory_slot == 2 else pm.selected_weapon
		if sel_display.is_empty():
			sel_display = "— none —"
		_add_row(panel, "Slot %d: %s" % [_armory_slot, sel_display], PANEL_H - 22.0, col)

	else:
		## Single slot
		var y := float(TITLE_H + 8)
		_add_row(panel, "Starting weapon:", y, Color(0.65, 0.70, 0.68))
		y += ROW_GAP + 2
		for w in weapons:
			var w_id: String = str(w)
			if y > PANEL_H - 48.0:
				break
			_add_weapon_btn(panel, w_id, y, w_id == pm.selected_weapon, 1)
			y += ROW_GAP

		_add_row(panel, "─────────────────────────────────────", PANEL_H - 38.0, Color(0.20, 0.23, 0.26))
		_add_row(panel, "Selected: %s" % pm.selected_weapon, PANEL_H - 22.0, col)

	return panel

func _make_workshop_panel() -> Panel:
	var col := Color(0.68, 0.24, 0.88)
	var panel := _make_panel_base("WORKSHOP", col)
	var pm := ProgressionManager

	var y := float(TITLE_H + 8)
	_add_row(panel, "Permanent hub upgrades.", y, Color(0.60, 0.60, 0.66), FONT_DIM)
	y += ROW_GAP
	_add_row(panel, "─────────────────────────────────────", y, Color(0.20, 0.23, 0.26))
	y += ROW_GAP - 4

	_add_upgrade_row(panel, "insurance_license",
		"Insurance License", "Insure 1 item per run.", y)
	y += ROW_GAP * 2 + 4

	_add_upgrade_row(panel, "armory_expansion",
		"Armory Expansion",  "Start runs with 2 weapons.", y)

	_add_row(panel, "─────────────────────────────────────", PANEL_H - 56.0, Color(0.20, 0.23, 0.26))

	var tier := pm.get_hub_tier()
	var tier_labels := ["Bare (spend 300 to upgrade)", "Torches lit", "Restored"]
	_add_row(panel, "Hub:   %s" % tier_labels[tier], PANEL_H - 42.0, Color(0.55, 0.55, 0.62), FONT_DIM)
	_add_row(panel, "Spent: %d res" % pm.total_resources_spent, PANEL_H - 26.0, Color(0.55, 0.55, 0.62), FONT_DIM)

	return panel

## Adds a two-line upgrade entry (name + desc) with a BUY / OWNED button.
func _add_upgrade_row(parent: Control, upgrade_id: String,
		upgrade_name: String, upgrade_desc: String, y: float) -> void:
	var pm := ProgressionManager
	var cost: int = ProgressionManager.UPGRADE_COSTS.get(upgrade_id, 0)
	var owned: bool = pm.has_upgrade(upgrade_id)
	var can_afford: bool = pm.resources >= cost

	## Name + cost text
	var name_col := Color(0.88, 0.88, 0.92) if not owned else Color(0.50, 0.55, 0.52)
	_add_row(parent, "%s  [%d res]" % [upgrade_name, cost], y, name_col)

	## Description on next line
	_add_row(parent, "  %s" % upgrade_desc, y + ROW_GAP, Color(0.45, 0.45, 0.50), FONT_DIM)

	## BUY / OWNED button, right-aligned with the name row
	var btn := Button.new()
	btn.size = Vector2(66, 22)
	btn.position = Vector2(PANEL_W - 78, y - 2)
	btn.add_theme_font_override("font", PIXEL_FONT)
	btn.add_theme_font_size_override("font_size", FONT_DIM)
	if owned:
		btn.text = "OWNED"
		btn.disabled = true
	elif not can_afford:
		btn.text = "BUY"
		btn.disabled = true
	else:
		btn.text = "BUY"
		btn.pressed.connect(func():
			if pm.purchase_upgrade(upgrade_id):
				_open_panel("workshop")  ## Refresh
		)
	parent.add_child(btn)

func _make_records_panel() -> Panel:
	var col := Color(0.65, 0.65, 0.72)
	var panel := _make_panel_base("RECORDS", col)
	var pm := ProgressionManager

	var y := float(TITLE_H + 8)
	_add_row(panel, "Total Runs:          %d" % pm.total_runs, y)
	y += ROW_GAP
	_add_row(panel, "Extractions:         %d" % pm.successful_extractions, y)
	y += ROW_GAP
	_add_row(panel, "Deaths:              %d" % pm.deaths, y)
	y += ROW_GAP
	_add_row(panel, "Total Kills:         %d" % pm.total_kills, y)
	y += ROW_GAP
	_add_row(panel, "Deepest Phase:       %d" % pm.deepest_phase, y)
	y += ROW_GAP
	_add_row(panel, "Most Loot (run):     %d" % int(pm.most_loot_extracted), y)
	y += ROW_GAP + 4
	_add_row(panel, "─────────────────────────────────────", y, Color(0.20, 0.23, 0.26))
	y += ROW_GAP - 4

	var rate: String
	if pm.total_runs > 0:
		rate = "%d%%" % int(float(pm.successful_extractions) / float(pm.total_runs) * 100.0)
	else:
		rate = "—"
	_add_row(panel, "Extraction Rate:     %s" % rate, y, Color(0.65, 0.72, 0.68))

	return panel

func _make_roster_panel() -> Panel:
	var col := Color(0.45, 0.52, 0.95)
	var panel := _make_panel_base("ROSTER", col)

	var y := float(TITLE_H + 8)
	_add_row(panel, "THE DRIFTER", y, Color(0.92, 0.86, 0.60), FONT_TITLE)
	y += ROW_GAP + 4
	_add_row(panel, "[ Active ]", y, col)
	y += ROW_GAP + 4
	_add_row(panel, "Starting weapon:  Standard Sidearm", y, Color(0.58, 0.58, 0.64))
	y += ROW_GAP
	_add_row(panel, "Passive:          None — the baseline.", y, Color(0.58, 0.58, 0.64))
	y += ROW_GAP
	_add_row(panel, "Stats:            Balanced across the board.", y, Color(0.58, 0.58, 0.64))
	y += ROW_GAP + 4
	_add_row(panel, "─────────────────────────────────────", y, Color(0.20, 0.23, 0.26))
	y += ROW_GAP - 4
	_add_row(panel, "More characters unlock as you extract.", y, Color(0.40, 0.40, 0.46), FONT_DIM)
	y += ROW_GAP
	_add_row(panel, "Save resources and return here.", y, Color(0.40, 0.40, 0.46), FONT_DIM)

	return panel

func _start_run() -> void:
	_close_panel()
	get_tree().change_scene_to_file("res://scenes/main_arena.tscn")
