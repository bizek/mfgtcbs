extends Node2D

## Hub — Safe room between runs. Player walks to interactive stations and presses E.

const PIXEL_FONT := preload("res://assets/fonts/m5x7.ttf")
const PLAYER_SPEED := 113.0
const INTERACT_RADIUS := 53.0
const ROOM_W := 640
const ROOM_H := 360
const WALL_T := 19

## Prop sprite data for each station. hframes splits an animation sheet; omit for single-image props.
const _STATION_SPRITES := {
	"launch": {
		"path": "res://assets/minifantasy/Minifantasy_CraftingAndProfessions_v1.0/Minifantasy_CraftingAndProfessions_Assets/Crafting_Professions/Blacksmith/Foundry/Minifantasy_CraftingAndProfessionsFoundryMelting.png",
		"scale": 2.4, "hframes": 8, "frame": 0,
	},
	"armory": {
		"path": "res://assets/minifantasy/Minifantasy_CraftingAndProfessions_v1.0/Minifantasy_CraftingAndProfessions_Assets/Crafting_Professions/Blacksmith/Minifantasy_CraftingAndProfessionsBlacksmithProps.png",
		"scale": 0.68,
	},
	"workshop": {
		"path": "res://assets/minifantasy/Minifantasy_CraftingAndProfessions_v1.0/Minifantasy_CraftingAndProfessions_Assets/Crafting_Professions/Blacksmith/Furnace/Minifantasy_CraftingAndProfessionsFurnaceWorking.png",
		"scale": 1.15, "hframes": 8, "frame": 0,
	},
	"research": {
		"path": "res://assets/minifantasy/Minifantasy_CraftingAndProfessions_v1.0/Minifantasy_CraftingAndProfessions_Assets/Crafting_Professions/Alchemy/Minifantasy_CraftingAndProfessionsLaboratoryProp.png",
		"scale": 1.25,
	},
	"records": {
		"path": "res://assets/minifantasy/Minifantasy_CraftingAndProfessions_v1.0/Minifantasy_CraftingAndProfessions_Assets/Crafting_Professions/Woodwork/Minifantasy_CraftingAndProfessionsWoodworkProps.png",
		"scale": 0.44,
	},
	"roster": {
		"path": "res://assets/minifantasy/Minifantasy_CraftingAndProfessions2_v1.0/Minifantasy_CraftingAndProfessions2_Assets/Crafting_Professions/Leatherwork/Minifantasy_CraftingAndProfessions2LeatherWorkbenchProp.png",
		"scale": 1.3,
	},
}

## Scene paths for each hub overlay panel.
const _PANEL_SCENES := {
	"launch":   "res://scenes/ui/hub_launch_panel.tscn",
	"armory":   "res://scenes/ui/hub_armory_panel.tscn",
	"workshop": "res://scenes/ui/hub_workshop_panel.tscn",
	"records":  "res://scenes/ui/hub_records_panel.tscn",
	"roster":   "res://scenes/ui/hub_roster_panel.tscn",
}

## Script paths for panels that build their UI entirely in code (no .tscn needed).
const _PANEL_SCRIPTS := {
	"research": "res://scripts/ui/hub_research_panel.gd",
}

## Station definitions: id, display name, accent color, world position, visual size, tagline.
## Positions derived from SpriteFusion tile coords * 8px/tile.
const STATIONS: Array[Dictionary] = [
	{"id": "launch",    "name": "DESCEND",    "color": Color(0.20, 0.90, 0.40),
	 "pos": Vector2(380, 96),  "size": Vector2(32, 48), "desc": "begin descent"},
	{"id": "armory",    "name": "ARMORY",     "color": Color(0.90, 0.60, 0.12),
	 "pos": Vector2(560, 268), "size": Vector2(20, 20), "desc": "equip loadout"},
	{"id": "workshop",  "name": "WORKSHOP",   "color": Color(0.68, 0.24, 0.88),
	 "pos": Vector2(616, 276), "size": Vector2(32, 24), "desc": "hub upgrades"},
	{"id": "research",  "name": "RESEARCH",   "color": Color(0.20, 0.85, 0.55),
	 "pos": Vector2(280, 272), "size": Vector2(32, 16), "desc": "blueprints"},
	{"id": "records",   "name": "RECORDS",    "color": Color(0.65, 0.65, 0.72),
	 "pos": Vector2(472, 264), "size": Vector2(56, 48), "desc": "view stats"},
	{"id": "roster",    "name": "ROSTER",     "color": Color(0.45, 0.52, 0.95),
	 "pos": Vector2(408, 160), "size": Vector2(24, 24), "desc": "select character"},
]

var _player_body: CharacterBody2D
var _station_nodes: Array[Node2D] = []
var _station_bg_rects: Array[ColorRect] = []  ## parallel to _station_nodes, for proximity glow
var _map_offset: Vector2 = Vector2.ZERO
var _interact_prompt: Label
var _resource_label: Label
var _active_station_id: String = ""
var _panel_layer: CanvasLayer
var _active_panel: Control = null

var _torch_flames: Array[ColorRect] = []  ## flame rects for flicker animation
var _flicker_timer: float = 0.0

func _ready() -> void:
	_build_room()
	_build_stations()
	_build_player()
	_build_ui()

# ── Room ──────────────────────────────────────────────────────────────────────

func _build_room() -> void:
	## Tilemap background — loaded first so it sits behind all overlays
	var map_scene := load("res://assets/Maps/Base Camp/Map.tscn") as PackedScene
	if map_scene:
		var map_inst := map_scene.instantiate()
		add_child(map_inst)
		_map_offset = map_inst.position
		var arch_layer := map_inst.get_node_or_null("Layer_8_2")
		if arch_layer:
			arch_layer.z_index = 1

	## Invisible collision walls keep the player inside the viewport
	_add_wall(Vector2(0, 0),                Vector2(ROOM_W, WALL_T))
	_add_wall(Vector2(0, ROOM_H - WALL_T),  Vector2(ROOM_W, WALL_T))
	_add_wall(Vector2(0, 0),                Vector2(WALL_T, ROOM_H))
	_add_wall(Vector2(ROOM_W - WALL_T, 0),  Vector2(WALL_T, ROOM_H))

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
	add_child(body)

func _add_vignette() -> void:
	## Dark corner overlays for atmospheric depth — drawn last so they sit on top
	var corners: Array = [
		[Vector2(0,           0           ), Vector2(100, 75)],
		[Vector2(ROOM_W - 100, 0           ), Vector2(100, 75)],
		[Vector2(0,           ROOM_H - 75 ), Vector2(100, 75)],
		[Vector2(ROOM_W - 100, ROOM_H - 75 ), Vector2(100, 75)],
	]
	for c in corners:
		var v := ColorRect.new()
		v.color = Color(0.0, 0.0, 0.0, 0.28)
		v.position = c[0]
		v.size = c[1]
		add_child(v)

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
	_torch_flames.append(flame)
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

		root.position += _map_offset
		var sz: Vector2 = s["size"]
		var col: Color = s["color"]

		## Proximity glow overlay — invisible by default, tints on approach
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0)
		bg.size = sz
		bg.position = -sz * 0.5
		root.add_child(bg)
		_station_bg_rects.append(bg)

		add_child(root)
		_station_nodes.append(root)

func _add_corner_brackets(root: Node2D, sz: Vector2, col: Color) -> void:
	const ARM := 7   ## bracket arm length in px
	const THK := 1   ## bracket line thickness
	var dim_col := Color(col.r * 0.55, col.g * 0.55, col.b * 0.55)
	## Each corner: [top-left of bracket box, flip_x, flip_y]
	var corners: Array = [
		[Vector2(-sz.x * 0.5 - 2, -sz.y * 0.5 - 2), false, false],
		[Vector2( sz.x * 0.5 - ARM + 2, -sz.y * 0.5 - 2), true,  false],
		[Vector2(-sz.x * 0.5 - 2,  sz.y * 0.5 - ARM + 2), false, true ],
		[Vector2( sz.x * 0.5 - ARM + 2,  sz.y * 0.5 - ARM + 2), true,  true ],
	]
	for c in corners:
		var cx: float = c[0].x
		var cy: float = c[0].y
		## Horizontal arm
		var h := ColorRect.new()
		h.color = dim_col
		h.size = Vector2(ARM, THK)
		h.position = Vector2(cx, cy if not c[2] else cy + ARM - THK)
		root.add_child(h)
		## Vertical arm
		var v := ColorRect.new()
		v.color = dim_col
		v.size = Vector2(THK, ARM)
		v.position = Vector2(cx if not c[1] else cx + ARM - THK, cy)
		root.add_child(v)

# ── Player ────────────────────────────────────────────────────────────────────

func _build_player() -> void:
	_player_body = CharacterBody2D.new()
	_player_body.name = "HubPlayer"
	_player_body.collision_layer = 2
	_player_body.collision_mask = 1
	_player_body.position = Vector2(320, 283)

	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(7, 11)
	cs.shape = rs
	_player_body.add_child(cs)

	## Sprite colors driven by selected character
	var char_id: String = ProgressionManager.selected_character
	var char_data: Dictionary = CharacterData.ALL.get(char_id, CharacterData.ALL["The Drifter"])
	var body_col: Color = char_data.get("color_body", Color(0.78, 0.72, 0.58))
	var head_col: Color = char_data.get("color_head", Color(0.94, 0.86, 0.68))

	## Ground shadow behind sprite
	var shadow := ColorRect.new()
	shadow.color = Color(0.0, 0.0, 0.0, 0.35)
	shadow.size = Vector2(9, 13)
	shadow.position = Vector2(-4.5, -4.5)
	_player_body.add_child(shadow)

	var body_vis := ColorRect.new()
	body_vis.color = body_col
	body_vis.size = Vector2(7, 11)
	body_vis.position = Vector2(-3.5, -5.5)
	_player_body.add_child(body_vis)

	var head := ColorRect.new()
	head.color = head_col
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
	_interact_prompt.add_theme_font_size_override("font_size", 16)
	_interact_prompt.add_theme_color_override("font_color", Color(0.95, 0.92, 0.50))
	_interact_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_prompt.size = Vector2(173, 21)
	_interact_prompt.visible = false
	_panel_layer.add_child(_interact_prompt)

	ProgressionManager.resources_changed.connect(_on_resources_changed)

func _on_resources_changed(_amount: int) -> void:
	pass

# ── Main loop ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_flicker_timer += delta
	if _flicker_timer >= 0.09:
		_flicker_timer = 0.0
		_flicker_torches()
	if _active_panel != null:
		return
	_handle_movement(delta)
	_update_proximity()
	_handle_interact()

func _flicker_torches() -> void:
	for flame in _torch_flames:
		var v := randf_range(0.80, 1.0)
		flame.color = Color(1.0, 0.72 * v, 0.14 * v)

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
		## Show station name in prompt
		for s in STATIONS:
			if s["id"] == nearest_id:
				_interact_prompt.text = "[ E ]  %s" % s["name"]
				break

	## Station proximity glow
	for i in _station_nodes.size():
		if i >= _station_bg_rects.size():
			break
		var s_id: String = _station_nodes[i].get_meta("station_id")
		var col: Color = STATIONS[i]["color"]
		if s_id == nearest_id:
			_station_bg_rects[i].color = Color(col.r, col.g, col.b, 0.22)
		else:
			_station_bg_rects[i].color = Color(0, 0, 0, 0)

func _handle_interact() -> void:
	if Input.is_action_just_pressed("interact") and not _active_station_id.is_empty():
		_open_panel(_active_station_id)

# ── Panel system ──────────────────────────────────────────────────────────────

func _open_panel(station_id: String) -> void:
	if _active_panel != null:
		return
	var panel: Control
	if _PANEL_SCENES.has(station_id):
		panel = load(_PANEL_SCENES[station_id]).instantiate()
	elif _PANEL_SCRIPTS.has(station_id):
		panel = load(_PANEL_SCRIPTS[station_id]).new()
	else:
		return
	_panel_layer.add_child(panel)   ## fires _ready() on panel, sets @onready vars
	panel.populate(ProgressionManager)
	panel.close_requested.connect(_close_panel)
	_active_panel = panel
	_interact_prompt.visible = false

func _close_panel() -> void:
	if _active_panel:
		_active_panel.queue_free()
		_active_panel = null
