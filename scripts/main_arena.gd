extends Node2D

## MainArena — Prototype root scene. Wires all systems together and manages run lifecycle.

const ARENA_HALF_W: float = 800.0
const ARENA_HALF_H: float = 600.0

const DamageNumberClass  = preload("res://scripts/ui/damage_number.gd")
const LootDropScene      = preload("res://scenes/pickups/loot_drop.tscn")
const WeaponPickupScript = preload("res://scripts/pickups/weapon_pickup.gd")

@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var level_up_screen: CanvasLayer = $LevelUpScreen
@onready var game_over_screen: CanvasLayer = $GameOverScreen
@onready var extraction_success_screen: CanvasLayer = $ExtractionSuccessScreen
@onready var arena_floor: TextureRect = $ArenaFloor

var extraction_zone: Node2D = null
var arena_generator: ArenaGenerator = null
var _camera: Camera2D = null
var _extraction_pulse_tween: Tween = null

func _ready() -> void:
	## Assign enemy scenes to EnemySpawnManager (autoload has @export vars, set programmatically)
	EnemySpawnManager.fodder_scene = preload("res://scenes/enemies/fodder.tscn")
	EnemySpawnManager.swarmer_scene = preload("res://scenes/enemies/swarmer.tscn")

	## Add Camera2D to player so view follows them
	_camera = Camera2D.new()
	_camera.zoom = Vector2(1, 1)
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 10.0
	_camera.limit_left = int(-ARENA_HALF_W)
	_camera.limit_right = int(ARENA_HALF_W)
	_camera.limit_top = int(-ARENA_HALF_H)
	_camera.limit_bottom = int(ARENA_HALF_H)
	player.add_child(_camera)

	## Connect combat signals for screen shake and damage numbers
	CombatManager.entity_killed.connect(_on_entity_killed)
	CombatManager.damage_dealt.connect(_on_damage_dealt)

	## Wire UI to player
	hud.setup(player)
	level_up_screen.setup(player)

	## Connect extraction window signals
	GameManager.extraction_window_opened.connect(_on_extraction_window_opened)
	GameManager.extraction_window_closed.connect(_on_extraction_window_closed)

	## Tile the floor with a grass tile from the ForgottenPlains pack
	_setup_floor()

	## Fix pre-existing wall nodes — they're on layer 3 by default, which neither
	## player (mask=2) nor enemies (mask=1) detect. Move them to layer 1+2.
	for wall_name in ["WallTop", "WallBottom", "WallLeft", "WallRight"]:
		var wall := get_node_or_null(wall_name)
		if wall is StaticBody2D:
			wall.collision_layer = 3
			wall.collision_mask = 0

	## Generate arena layout: wall collision, obstacles, spawn hints, extraction marker
	arena_generator = ArenaGenerator.new()
	add_child(arena_generator)
	arena_generator.generate(2025)

	## Debug panel — only spawned when debug_mode is enabled
	if GameManager.debug_mode:
		var DebugPanelScript := preload("res://scripts/ui/debug_panel.gd")
		var debug_panel: CanvasLayer = DebugPanelScript.new()
		add_child(debug_panel)
		debug_panel.setup(player)

	## Start the run and enemy spawning
	GameManager.start_run()
	var bounds := Rect2(-ARENA_HALF_W, -ARENA_HALF_H, ARENA_HALF_W * 2.0, ARENA_HALF_H * 2.0)
	EnemySpawnManager.start_spawning(player, bounds)

func _process(_delta: float) -> void:
	## Distance-based extraction zone detection (reliable for initial overlap + runtime)
	if extraction_zone != null and is_instance_valid(extraction_zone) and is_instance_valid(player):
		var dist: float = player.global_position.distance_to(extraction_zone.global_position)
		var in_zone: bool = dist <= 40.0
		if in_zone and not ExtractionManager.is_channeling:
			var speed: float = player.get_stat("extraction_speed") if player.has_method("get_stat") else 1.0
			ExtractionManager.start_channel(speed)
		elif not in_zone and ExtractionManager.is_channeling:
			ExtractionManager.interrupt_channel()

func _on_extraction_window_opened() -> void:
	var pos: Vector2 = arena_generator.get_extraction_position() if arena_generator else Vector2.ZERO
	_spawn_extraction_zone(pos)

func _on_extraction_window_closed() -> void:
	ExtractionManager.interrupt_channel()
	if _extraction_pulse_tween != null:
		_extraction_pulse_tween.kill()
		_extraction_pulse_tween = null
	if extraction_zone != null and is_instance_valid(extraction_zone):
		extraction_zone.queue_free()
		extraction_zone = null

func _spawn_extraction_zone(pos: Vector2) -> void:
	if extraction_zone != null:
		return

	extraction_zone = Node2D.new()
	extraction_zone.name = "ExtractionZone"
	extraction_zone.global_position = pos

	## Far outer beacon — very faint large ring visible from across the arena
	var beacon := ColorRect.new()
	beacon.name = "BeaconRing"
	beacon.color = Color(0.0, 1.0, 0.35, 0.1)
	beacon.size = Vector2(200.0, 200.0)
	beacon.position = Vector2(-100.0, -100.0)
	extraction_zone.add_child(beacon)

	## Outer glow — large soft ring at low alpha
	var outer := ColorRect.new()
	outer.name = "OuterGlow"
	outer.color = Color(0.0, 1.0, 0.35, 0.28)
	outer.size = Vector2(160.0, 160.0)
	outer.position = Vector2(-80.0, -80.0)
	extraction_zone.add_child(outer)

	## Inner fill
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = Color(0.0, 0.88, 0.28, 0.55)
	fill.size = Vector2(96.0, 96.0)
	fill.position = Vector2(-48.0, -48.0)
	extraction_zone.add_child(fill)

	## Bright border (4 sides, 4px thick)
	var border_color := Color(0.1, 1.0, 0.5, 1.0)
	var bw: float = 96.0
	var bt: float = 4.0
	for side in 4:
		var b := ColorRect.new()
		b.color = border_color
		match side:
			0: b.size = Vector2(bw, bt); b.position = Vector2(-bw * 0.5, -bw * 0.5)
			1: b.size = Vector2(bw, bt); b.position = Vector2(-bw * 0.5, bw * 0.5 - bt)
			2: b.size = Vector2(bt, bw); b.position = Vector2(-bw * 0.5, -bw * 0.5)
			3: b.size = Vector2(bt, bw); b.position = Vector2(bw * 0.5 - bt, -bw * 0.5)
		extraction_zone.add_child(b)

	## "EXTRACT HERE" label above the zone — pixel font at correct size
	var label := Label.new()
	label.name = "Label"
	label.text = "EXTRACT HERE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-64.0, -96.0)
	label.modulate = Color(0.15, 1.0, 0.5, 1.0)
	var font_settings := LabelSettings.new()
	font_settings.font = load("res://assets/fonts/m5x7.ttf")
	font_settings.font_size = 16
	font_settings.outline_size = 1
	font_settings.outline_color = Color(0.0, 0.0, 0.0, 0.9)
	label.label_settings = font_settings
	extraction_zone.add_child(label)

	add_child(extraction_zone)
	ExtractionManager.extraction_point = extraction_zone

	## Start looping pulse animation on fill and outer glow
	_start_extraction_pulse()

func _start_extraction_pulse() -> void:
	if extraction_zone == null:
		return
	var fill := extraction_zone.get_node_or_null("Fill")
	var outer := extraction_zone.get_node_or_null("OuterGlow")
	var beacon := extraction_zone.get_node_or_null("BeaconRing")
	var lbl := extraction_zone.get_node_or_null("Label")

	## Fill heartbeat — stronger alpha swing
	_extraction_pulse_tween = create_tween().set_loops()
	if fill:
		_extraction_pulse_tween.tween_property(fill, "modulate:a", 0.35, 0.55)
		_extraction_pulse_tween.tween_property(fill, "modulate:a", 1.0, 0.55)

	## Outer glow pulse — deep range
	if outer:
		var outer_tween := create_tween().set_loops()
		outer_tween.tween_property(outer, "modulate:a", 0.15, 0.8)
		outer_tween.tween_property(outer, "modulate:a", 1.0, 0.8)

	## Beacon ring — slow drift in/out
	if beacon:
		var beacon_tween := create_tween().set_loops()
		beacon_tween.tween_property(beacon, "modulate:a", 0.05, 1.2)
		beacon_tween.tween_property(beacon, "modulate:a", 0.7, 1.2)

	## Scale heartbeat on entire zone — subtle but readable
	var scale_tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	scale_tween.tween_property(extraction_zone, "scale", Vector2(1.06, 1.06), 0.5)
	scale_tween.tween_property(extraction_zone, "scale", Vector2(1.0, 1.0), 0.5)

	## Label bobs slightly
	if lbl:
		var lbl_tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		lbl_tween.tween_property(lbl, "position:y", -102.0, 0.8)
		lbl_tween.tween_property(lbl, "position:y", -96.0, 0.8)

func _setup_floor() -> void:
	## Use the Hellscape premade ground layer as the arena floor.
	## Stretched to fill the arena at pixel-art nearest-neighbor — no tiling needed.
	const FLOOR_PATH: String = "res://assets/minifantasy/Minifantasy_Hellscape_v1.0/Minifantasy_Hellscape_Assets/_Premade Scene/Separate Layers/Premade_l-ground.png"
	var source := Image.load_from_file(FLOOR_PATH)
	if source == null:
		push_warning("ArenaFloor: Hellscape ground not found — floor will be blank.")
		return

	arena_floor.texture = ImageTexture.create_from_image(source)
	arena_floor.stretch_mode = TextureRect.STRETCH_SCALE
	arena_floor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _on_entity_killed(_killer: Node, victim: Node, _pos: Vector2) -> void:
	if victim.is_in_group("enemies"):
		_shake_camera(3.0, 0.12)
		## 8% chance to drop loot — rarer drops feel more exciting
		if randf() < 0.08:
			_spawn_loot_drop(victim.global_position)
		## 2% chance to drop a weapon — rare and exciting
		elif randf() < 0.02:
			_spawn_weapon_drop(victim.global_position)

func _spawn_loot_drop(pos: Vector2) -> void:
	var drop: Area2D = LootDropScene.instantiate()
	drop.global_position = pos
	drop.value = randf_range(6.0, 18.0)
	add_child(drop)

func _spawn_weapon_drop(pos: Vector2) -> void:
	var droppable: Array = WeaponData.get_droppable_ids()
	if droppable.is_empty():
		return
	var weapon_id: String = droppable[randi() % droppable.size()]

	var pickup: Area2D = WeaponPickupScript.new()
	pickup.weapon_id       = weapon_id
	pickup.global_position = pos
	add_child(pickup)

func _on_damage_dealt(_attacker: Node, defender: Node, amount: float, was_crit: bool) -> void:
	if is_instance_valid(defender) and defender.is_in_group("enemies"):
		var dmg_num: Node2D = DamageNumberClass.new()
		add_child(dmg_num)
		dmg_num.setup(amount, was_crit, defender.global_position)

func _shake_camera(intensity: float = 3.0, duration: float = 0.12) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	var shake_offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	var tween := create_tween()
	tween.tween_property(_camera, "offset", shake_offset, duration * 0.25)
	tween.tween_property(_camera, "offset", Vector2.ZERO, duration * 0.75)
