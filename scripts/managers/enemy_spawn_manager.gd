extends Node

## EnemySpawnManager — Wave composition, spawn timing, difficulty scaling

signal enemy_spawned(enemy: Node)

@export var fodder_scene: PackedScene
@export var swarmer_scene: PackedScene

var spawn_timer: float = 0.0
var base_spawn_interval: float = 0.8 ## Seconds between spawn waves (was 1.5)
var enemies_per_spawn: int = 5 ## Base enemies per wave (was 3)
var max_enemies: int = 150
var active_enemies: int = 0
var arena_bounds: Rect2 = Rect2(-320, -240, 640, 480) ## Default, set by arena
var player_ref: Node2D = null
var spawn_enabled: bool = false

func _process(delta: float) -> void:
	if not spawn_enabled or player_ref == null:
		return
	if GameManager.current_state != GameManager.GameState.RUN_ACTIVE:
		return

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_wave()
		## Spawn interval decreases with difficulty
		var difficulty: float = GameManager.difficulty_multiplier
		spawn_timer = base_spawn_interval / difficulty

func start_spawning(player: Node2D, bounds: Rect2) -> void:
	player_ref = player
	arena_bounds = bounds
	spawn_enabled = true
	spawn_timer = 1.0 ## First wave after 1 second
	active_enemies = 0

func stop_spawning() -> void:
	spawn_enabled = false

func on_enemy_died() -> void:
	active_enemies -= 1

func _spawn_wave() -> void:
	if active_enemies >= max_enemies:
		return

	var difficulty: float = GameManager.difficulty_multiplier
	var count: int = int(enemies_per_spawn * difficulty)
	count = mini(count, max_enemies - active_enemies)

	for i in range(count):
		if active_enemies >= max_enemies:
			break
		_spawn_single_enemy()

func _spawn_single_enemy() -> void:
	if player_ref == null:
		return

	var swarmer_chance: float = clampf(0.1 + (GameManager.difficulty_multiplier - 1.0) * 0.15, 0.1, 0.5)
	var spawn_pos: Vector2 = _get_spawn_position()

	if randf() < swarmer_chance and swarmer_scene != null:
		## Spawn a pack of 3-5 swarmers in a tight cluster
		var pack_size: int = randi_range(3, 5)
		for j in range(pack_size):
			if active_enemies >= max_enemies:
				break
			var enemy: Node2D = swarmer_scene.instantiate()
			var offset := Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
			enemy.global_position = spawn_pos + offset
			if enemy.has_method("apply_difficulty_scaling"):
				enemy.apply_difficulty_scaling(GameManager.difficulty_multiplier)
			get_tree().current_scene.add_child(enemy)
			active_enemies += 1
			enemy_spawned.emit(enemy)
	elif fodder_scene != null:
		var enemy: Node2D = fodder_scene.instantiate()
		enemy.global_position = spawn_pos
		if enemy.has_method("apply_difficulty_scaling"):
			enemy.apply_difficulty_scaling(GameManager.difficulty_multiplier)
		get_tree().current_scene.add_child(enemy)
		active_enemies += 1
		enemy_spawned.emit(enemy)

func _get_spawn_position() -> Vector2:
	var margin: float = 32.0

	## Pick a random edge
	var side: int = randi_range(0, 3)
	var pos: Vector2
	match side:
		0: ## Top
			pos = Vector2(randf_range(arena_bounds.position.x, arena_bounds.end.x), arena_bounds.position.y - margin)
		1: ## Bottom
			pos = Vector2(randf_range(arena_bounds.position.x, arena_bounds.end.x), arena_bounds.end.y + margin)
		2: ## Left
			pos = Vector2(arena_bounds.position.x - margin, randf_range(arena_bounds.position.y, arena_bounds.end.y))
		3: ## Right
			pos = Vector2(arena_bounds.end.x + margin, randf_range(arena_bounds.position.y, arena_bounds.end.y))

	return pos
