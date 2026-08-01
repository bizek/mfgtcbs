extends Node2D

## Hub — Safe room between runs. Player walks to interactive stations and presses E.

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
	"passives": "res://scripts/ui/hub_passives_panel.gd",
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
	{"id": "passives",  "name": "PASSIVES",   "color": Color(0.64, 0.46, 0.93),
	 "pos": Vector2(160, 160), "size": Vector2(24, 24), "desc": "spend passive points"},
]

var _player_body: CharacterBody2D
var _hub_sprite: AnimatedSprite2D = null   ## selected character's idle/walk sprite (null = tinted-block fallback)
var _avatar_holder: Node2D = null          ## parent of the swappable avatar visual (rebuilt on selection change)
var _displayed_char_id: String = ""        ## character currently shown in the hub
var _station_nodes: Array[Node2D] = []
var _station_bg_rects: Array[ColorRect] = []  ## parallel to _station_nodes, for proximity glow
var _map_offset: Vector2 = Vector2.ZERO
var _interact_prompt: RichTextLabel
var _resource_label: Label
var _active_station_id: String = ""
var _panel_layer: CanvasLayer
var _active_panel: Control = null
var _active_panel_id: String = ""
var _glyph_bar: GlyphBar
const _STATION_ORDER: Array[String] = ["launch", "armory", "workshop", "research", "records", "roster", "passives"]

var _torch_flames: Array[ColorRect] = []  ## flame rects for flicker animation
var _flicker_timer: float = 0.0

func _ready() -> void:
	_build_room()
	_build_stations()
	_build_player()
	_build_ui()
	AudioManager.play_music("mus_hub")
	AchievementManager.check_thresholds()

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

	## Holder for the swappable character avatar — rebuilt when roster selection changes.
	_avatar_holder = Node2D.new()
	_player_body.add_child(_avatar_holder)

	add_child(_player_body)
	_apply_player_visual()

## (Re)build the selected character's avatar into _avatar_holder. Called on hub load
## and whenever the roster selection changes (see _close_panel).
func _apply_player_visual() -> void:
	if _avatar_holder == null:
		return
	for c in _avatar_holder.get_children():
		_avatar_holder.remove_child(c)
		c.queue_free()
	_hub_sprite = null

	var char_id: String = ProgressionManager.selected_character
	_displayed_char_id = char_id

	## Character sprite — same data-driven SpriteFrames as the arena player.
	var frames: SpriteFrames = CharacterSpriteFactory.build(char_id)
	if frames != null and frames.has_animation("idle"):
		_hub_sprite = AnimatedSprite2D.new()
		_hub_sprite.sprite_frames = frames
		_hub_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_hub_sprite.position = Vector2(0, -6)   ## lift the 32px frame so feet rest near the body origin
		_hub_sprite.play("idle")
		_avatar_holder.add_child(_hub_sprite)
	else:
		## Fallback: legacy tinted blocks (character has no sprite metadata)
		var char_data: Dictionary = CharacterData.ALL.get(char_id, CharacterData.ALL["The Drifter"])
		var body_vis := ColorRect.new()
		body_vis.color = char_data.get("color_body", Color(0.78, 0.72, 0.58))
		body_vis.size = Vector2(7, 11)
		body_vis.position = Vector2(-3.5, -5.5)
		_avatar_holder.add_child(body_vis)
		var head := ColorRect.new()
		head.color = char_data.get("color_head", Color(0.94, 0.86, 0.68))
		head.size = Vector2(5, 3)
		head.position = Vector2(-2.5, -8.0)
		_avatar_holder.add_child(head)

# ── UI ────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_panel_layer = CanvasLayer.new()
	_panel_layer.layer = 10
	add_child(_panel_layer)

	## Interact prompt (floats above player)
	## RichTextLabel so the bound input renders as the pack's keycap/button art;
	## the sprite replaces the old "[ E ]" brackets, and [center] replaces
	## horizontal_alignment (which RichTextLabel does not have).
	_interact_prompt = GlyphBar.rich_prompt(16, Color(0.95, 0.92, 0.50))
	_interact_prompt.text = "[center]%s  interact[/center]" % InputGlyphs.action_glyph_bb("interact")
	_interact_prompt.size = Vector2(173, 21)
	_interact_prompt.visible = false
	_panel_layer.add_child(_interact_prompt)

	## Bottom-of-screen controller/keyboard hint bar — shared across roaming
	## and every panel so players always see how to interact/close/switch.
	_glyph_bar = GlyphBar.build([])
	_glyph_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_glyph_bar.offset_top = -14.0
	_glyph_bar.offset_bottom = 0.0
	_panel_layer.add_child(_glyph_bar)
	InputGlyphs.device_changed.connect(func(_v: bool): _refresh_glyph_bar())

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
		_handle_panel_switch()
		return
	_handle_movement(delta)
	_update_proximity()
	_handle_interact()
	_handle_panel_switch()

func _flicker_torches() -> void:
	for flame in _torch_flames:
		var v := randf_range(0.80, 1.0)
		flame.color = Color(1.0, 0.72 * v, 0.14 * v)

func _handle_movement(delta: float) -> void:
	## Same analog path as the arena player so hub movement doesn't feel like a different game.
	var dir := MoveInput.get_move_vector()
	_player_body.velocity = dir * PLAYER_SPEED
	_player_body.move_and_slide()

	## Drive the character sprite: walk while moving, idle when still, flip on horizontal input.
	if _hub_sprite:
		if dir.x != 0:
			_hub_sprite.flip_h = dir.x < 0
		if dir.length_squared() > 0:
			if _hub_sprite.animation != &"walk" and _hub_sprite.sprite_frames.has_animation("walk"):
				_hub_sprite.play("walk")
		elif _hub_sprite.animation != &"idle":
			_hub_sprite.play("idle")

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
				_interact_prompt.text = "[center]%s  %s[/center]" % [InputGlyphs.action_glyph_bb("interact"), s["name"]]
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
	_refresh_glyph_bar()

func _handle_interact() -> void:
	if Input.is_action_just_pressed("interact") and not _active_station_id.is_empty():
		_open_panel(_active_station_id)

## Shoulder-button (LB/RB) station switching — the discoverable controller-
## friendly alternative to walking between stations. Works both while roaming
## (jumps straight to a panel without walking) and while a panel is already
## open (swaps it for the next one). Bound to menu_switch_prev/next, which are
## joypad-only (see project.godot) — deliberately NOT light_attack/heavy_attack,
## since those are also bound to mouse buttons 1/2 and would otherwise fire a
## panel switch on every unrelated mouse click in the hub.
func _handle_panel_switch() -> void:
	if Input.is_action_just_pressed("menu_switch_prev"):
		_switch_panel(-1)
	elif Input.is_action_just_pressed("menu_switch_next"):
		_switch_panel(1)

func _switch_panel(direction: int) -> void:
	var current_id: String = _active_panel_id if _active_panel != null else _active_station_id
	var idx: int = _STATION_ORDER.find(current_id)
	var next_idx: int = (idx + direction + _STATION_ORDER.size()) % _STATION_ORDER.size() if idx != -1 else 0
	_close_panel()
	_open_panel(_STATION_ORDER[next_idx])

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
	_active_panel_id = station_id
	_interact_prompt.visible = false
	## Prefer the panel's real first content control over hub_panel_base's
	## CloseButton fallback, now that populate() has built the actual rows.
	UINav.focus_first(panel)
	_refresh_glyph_bar()

func _close_panel() -> void:
	if _active_panel:
		_active_panel.queue_free()
		_active_panel = null
		_active_panel_id = ""
	## Roster selection may have changed the character — refresh the hub avatar.
	if _displayed_char_id != ProgressionManager.selected_character:
		_apply_player_visual()
	_refresh_glyph_bar()

func _refresh_glyph_bar() -> void:
	if _glyph_bar == null:
		return
	if _active_panel != null:
		_glyph_bar.set_pairs([["confirm", "Select"], ["back", "Close"], ["switch", "Switch Panel"]])
	elif not _active_station_id.is_empty():
		_glyph_bar.set_pairs([["interact", "Interact"], ["switch", "Jump to Panel"]])
	else:
		_glyph_bar.set_pairs([])
