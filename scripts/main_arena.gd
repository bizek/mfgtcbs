extends Node2D

## MainArena — Prototype root scene. Wires all systems together and manages run lifecycle.

const ARENA_HALF_W: float = 800.0
const ARENA_HALF_H: float = 600.0

const DamageNumberClass = preload("res://scripts/ui/damage_number.gd")

@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var level_up_screen: CanvasLayer = $LevelUpScreen
@onready var game_over_screen: CanvasLayer = $GameOverScreen
@onready var extraction_success_screen: CanvasLayer = $ExtractionSuccessScreen
@onready var arena_floor: TextureRect = $ArenaFloor

var extraction_zone: Node2D = null
var arena_generator: ArenaGenerator = null
var _camera: Camera2D = null

func _ready() -> void:
	## Assign enemy scenes to EnemySpawnManager (autoload has @export vars, set programmatically)
	EnemySpawnManager.fodder_scene = preload("res://scenes/enemies/fodder.tscn")
	EnemySpawnManager.swarmer_scene = preload("res://scenes/enemies/swarmer.tscn")

	## Add Camera2D to player so view follows them
	_camera = Camera2D.new()
	_camera.zoom = Vector2(2, 2)
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

	## Build procedural dungeon floor (varied tiles, no repetition)
	_build_floor()

	## Generate arena layout: wall collision, obstacles, spawn hints, extraction marker
	arena_generator = ArenaGenerator.new()
	add_child(arena_generator)
	arena_generator.generate(2025)

	## Decorate arena with torches along the walls
	_spawn_torches()

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
	if extraction_zone != null and is_instance_valid(extraction_zone):
		extraction_zone.queue_free()
		extraction_zone = null

func _spawn_extraction_zone(pos: Vector2) -> void:
	if extraction_zone != null:
		return

	extraction_zone = Node2D.new()
	extraction_zone.name = "ExtractionZone"
	extraction_zone.global_position = pos

	## Green filled rect visual
	var visual := ColorRect.new()
	visual.color = Color(0.0, 0.9, 0.3, 0.35)
	visual.size = Vector2(80.0, 80.0)
	visual.position = Vector2(-40.0, -40.0)
	extraction_zone.add_child(visual)

	## Border rect (outline effect)
	var border := ColorRect.new()
	border.color = Color(0.0, 1.0, 0.4, 0.8)
	border.size = Vector2(80.0, 4.0)
	border.position = Vector2(-40.0, -40.0)
	extraction_zone.add_child(border)

	## Label above the zone
	var label := Label.new()
	label.text = "EXTRACT HERE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-60.0, -70.0)
	label.modulate = Color(0.0, 1.0, 0.4, 1.0)
	extraction_zone.add_child(label)

	add_child(extraction_zone)
	ExtractionManager.extraction_point = extraction_zone

func _spawn_torches() -> void:
	var torch_tex: Texture2D = load("res://assets/environment/Torch.png")
	if torch_tex == null:
		return

	## Build shared SpriteFrames (4 frames at 32x24 each)
	var frames := SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_speed("default", 8.0)
	frames.set_animation_loop("default", true)
	for i in range(4):
		var atlas := AtlasTexture.new()
		atlas.atlas = torch_tex
		atlas.region = Rect2(i * 32, 0, 32, 24)
		frames.add_frame("default", atlas)

	## Torch positions — midpoints and near-corners of each wall, slightly inset
	var positions: Array[Vector2] = [
		Vector2(-700, -590), Vector2(-350, -590), Vector2(0, -590),
		Vector2(350, -590), Vector2(700, -590),
		Vector2(-700,  590), Vector2(-350,  590), Vector2(0,  590),
		Vector2(350,  590), Vector2(700,  590),
		Vector2(-790, -400), Vector2(-790,    0), Vector2(-790,  400),
		Vector2( 790, -400), Vector2( 790,    0), Vector2( 790,  400),
	]

	for pos in positions:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.play("default")
		sprite.position = pos
		## Offset random start frame so torches don't all flicker in sync
		sprite.frame = randi() % 4
		add_child(sprite)

func _on_entity_killed(_killer: Node, victim: Node, _pos: Vector2) -> void:
	if victim.is_in_group("enemies"):
		_shake_camera(3.0, 0.12)

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

func _build_floor() -> void:
	var tileset_img := Image.load_from_file("res://assets/environment/DungeonTileset.png")
	if tileset_img == null:
		return
	tileset_img.convert(Image.FORMAT_RGBA8)

	const TILE: int = 16
	const W: int = 1600
	const H: int = 1200
	## How many tiles wide the stone-wall border is on each side
	const WALL_BORDER: int = 3

	## Row 1 cols 7–9 (xy in tileset): fully-opaque grey stone — used for wall border
	## Identified via pixel analysis: all 256/256 opaque, avg ~(92, 102, 103)
	var wall_tiles: Array[Vector2i] = [
		Vector2i(112, 16), Vector2i(128, 16), Vector2i(144, 16),
	]
	## Row 4 cols 2–4: fully-opaque dark stone floor — 256/256 opaque, avg ~(46, 46, 46)
	var floor_solid: Array[Vector2i] = [
		Vector2i(32, 64), Vector2i(48, 64), Vector2i(64, 64),
	]
	## Row 3 cols 2–3: 75%-opaque stone — composites darker over base, adds crack variation
	var floor_cracks: Array[Vector2i] = [
		Vector2i(32, 48), Vector2i(48, 48),
	]

	var floor_img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	## Fill with very dark dungeon base — shows through semi-transparent tile edges
	floor_img.fill(Color8(12, 9, 7))

	var rng := RandomNumberGenerator.new()
	rng.seed = 2025

	var gcols: int = W / TILE  ## 100
	var grows: int = H / TILE  ## 75

	for row in range(grows):
		for col in range(gcols):
			## Distance (in tiles) from the nearest edge
			var d: int = mini(mini(col, gcols - 1 - col), mini(row, grows - 1 - row))
			var src: Vector2i
			if d < WALL_BORDER:
				## Stone wall border — clearly distinct from floor
				src = wall_tiles[rng.randi() % wall_tiles.size()]
			else:
				## Interior floor — solid tiles with occasional darker crack variants
				var roll: int = rng.randi() % 100
				if roll < 85:
					src = floor_solid[rng.randi() % floor_solid.size()]
				else:
					src = floor_cracks[rng.randi() % floor_cracks.size()]
			floor_img.blit_rect(tileset_img, Rect2i(src.x, src.y, TILE, TILE), Vector2i(col * TILE, row * TILE))

	arena_floor.texture = ImageTexture.create_from_image(floor_img)
	arena_floor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
