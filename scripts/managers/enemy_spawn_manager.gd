extends Node

## EnemySpawnManager — Wave composition, spawn timing, difficulty scaling

signal enemy_spawned(enemy: Node)

@export var fodder_scene: PackedScene
@export var swarmer_scene: PackedScene

var spawn_timer: float = 0.0
var base_spawn_interval: float = 2.5 ## Seconds between spawn waves at difficulty 1.0
var enemies_per_spawn: int = 3 ## Base enemies per wave at difficulty 1.0
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
		## Spawn interval decreases with difficulty; halves while player is channeling extraction
		var difficulty: float = GameManager.difficulty_multiplier
		var channel_pressure: float = 2.0 if ExtractionManager.is_channeling else 1.0
		spawn_timer = base_spawn_interval / (difficulty * channel_pressure)

func start_spawning(player: Node2D, bounds: Rect2) -> void:
	player_ref = player
	arena_bounds = bounds
	spawn_enabled = true
	spawn_timer = 3.0 ## Grace period before first wave
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

	## Combined difficulty: time-based scaling × instability tier multiplier
	var effective_difficulty: float = GameManager.difficulty_multiplier * GameManager.get_instability_multiplier()

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
				enemy.apply_difficulty_scaling(effective_difficulty)
			get_tree().current_scene.add_child(enemy)
			active_enemies += 1
			enemy_spawned.emit(enemy)
	elif fodder_scene != null:
		var enemy: Node2D = fodder_scene.instantiate()
		enemy.global_position = spawn_pos
		if enemy.has_method("apply_difficulty_scaling"):
			enemy.apply_difficulty_scaling(effective_difficulty)
		get_tree().current_scene.add_child(enemy)
		active_enemies += 1
		enemy_spawned.emit(enemy)

func _get_spawn_position() -> Vector2:
	## Spawn just outside the visible viewport around the player,
	## then clamp inside the arena walls so enemies never get stuck outside.
	## Viewport-relative spawn radius keeps enemies always close to the screen edge.
	const SPAWN_RADIUS: float = 340.0 ## ~half viewport diagonal at zoom 1, 1152x648
	const INNER_MARGIN: float = 20.0  ## Keep this far from arena wall edges

	var center: Vector2 = player_ref.global_position if player_ref else Vector2.ZERO

	## Pick a random angle and place on a circle just outside view
	var angle: float = randf() * TAU
	var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * SPAWN_RADIUS

	## Clamp inside arena walls with a small inward margin
	var safe_bounds := Rect2(
		arena_bounds.position + Vector2(INNER_MARGIN, INNER_MARGIN),
		arena_bounds.size - Vector2(INNER_MARGIN * 2.0, INNER_MARGIN * 2.0)
	)
	pos.x = clampf(pos.x, safe_bounds.position.x, safe_bounds.end.x)
	pos.y = clampf(pos.y, safe_bounds.position.y, safe_bounds.end.y)

	return pos
