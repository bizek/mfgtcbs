extends Node

## EnemySpawnManager — Wave composition, spawn timing, difficulty scaling.
## New enemy types are gated by GameManager.phase_number:
##   Phase 1  →  Fodder + Swarmers
##   Phase 2+ →  + Brutes (rare) + Casters (pairs)
##   Phase 3+ →  + Carriers (solo) + Stalkers + Heralds
##
## Per-phase HP/damage/spawn multipliers stack on top of time-based difficulty scaling.
## Elite modifier: any basic enemy has a time+phase-scaling chance to spawn as an Elite
##   (2× HP, 1.5× damage, +3 armor, gold glow tint, 2.5× XP).

signal enemy_spawned(enemy: Node)

## ── Scene references — assigned by main_arena.gd in _ready() ─────────────────
@export var fodder_scene:   PackedScene
@export var swarmer_scene:  PackedScene
@export var brute_scene:    PackedScene
@export var caster_scene:   PackedScene
@export var carrier_scene:  PackedScene
@export var stalker_scene:  PackedScene
@export var herald_scene:   PackedScene

## ── Phase stat multipliers (index = phase_number - 1) ────────────────────────
const PHASE_HP_MULT: Array    = [1.0, 1.5, 2.5, 4.0, 6.0]
const PHASE_DMG_MULT: Array   = [1.0, 1.3, 1.6, 2.0, 2.5]
const PHASE_SPAWN_MULT: Array = [1.0, 1.2, 1.5, 1.8, 2.2]

## Roll ramp rates — seconds of elapsed time for probability to scale from base to cap
const BRUTE_ROLL_RAMP: float = 600.0   ## Brute spawn chance ramps over 10 min
const CASTER_ROLL_RAMP: float = 500.0  ## Caster spawn chance ramps over ~8 min

## ── Carrier pacing — 1 per interval early, 2 per interval late ───────────────
const CARRIER_INTERVAL: float = 55.0  ## Seconds between carrier spawns
var _carrier_timer: float = CARRIER_INTERVAL * 0.8  ## First carrier slightly early

## ── Herald pacing — heralds should always arrive with a pack ─────────────────
const HERALD_INTERVAL: float = 65.0
var _herald_timer: float = HERALD_INTERVAL

## ── Core spawn loop ──────────────────────────────────────────────────────────
var spawn_timer: float = 0.0
var base_spawn_interval: float = 2.5
var enemies_per_spawn: int = 3
var max_enemies: int = 150
var active_enemies: int = 0
var arena_bounds: Rect2 = Rect2(-320, -240, 640, 480)
var player_ref: Node2D = null
var spawn_enabled: bool = false

func _process(delta: float) -> void:
	if not spawn_enabled or player_ref == null:
		return
	if GameManager.current_state != GameManager.GameState.RUN_ACTIVE:
		return

	## ── Main wave timer ──────────────────────────────────────────────────────
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_wave()
		var difficulty: float = GameManager.difficulty_multiplier
		var channel_pressure: float = 2.0 if ExtractionManager.is_channeling else 1.0
		spawn_timer = base_spawn_interval / (difficulty * channel_pressure)

	## ── Carrier spawn (solo runs, scarce) ────────────────────────────────────
	if GameManager.phase_number >= 3 and carrier_scene != null:
		_carrier_timer -= delta
		if _carrier_timer <= 0.0:
			var carrier_count: int = 2 if GameManager.phase_number >= 4 else 1
			for _i in range(carrier_count):
				_spawn_enemy_at_edge(carrier_scene, false)
			_carrier_timer = CARRIER_INTERVAL

	## ── Herald spawn (always arrives with a pack) ────────────────────────────
	if GameManager.phase_number >= 3 and herald_scene != null:
		_herald_timer -= delta
		if _herald_timer <= 0.0:
			_spawn_herald_pack()
			_herald_timer = HERALD_INTERVAL

func start_spawning(player: Node2D, bounds: Rect2) -> void:
	player_ref = player
	arena_bounds = bounds
	spawn_enabled = true
	spawn_timer = 3.0  ## Grace period before first wave
	active_enemies = 0
	## Track enemy deaths via combat signal
	if not CombatManager.entity_killed.is_connected(_on_entity_killed):
		CombatManager.entity_killed.connect(_on_entity_killed)
	## Reset carrier/herald pacing on each new phase
	if not GameManager.phase_started.is_connected(_on_phase_started):
		GameManager.phase_started.connect(_on_phase_started)
	_carrier_timer = CARRIER_INTERVAL * 0.8
	_herald_timer  = HERALD_INTERVAL

func stop_spawning() -> void:
	spawn_enabled = false

func _on_phase_started(_phase: int) -> void:
	_carrier_timer = CARRIER_INTERVAL * 0.8
	_herald_timer = HERALD_INTERVAL

func _on_entity_killed(_killer: Node, victim: Node, _pos: Vector2) -> void:
	if victim.is_in_group("enemies"):
		active_enemies -= 1

## For non-combat despawns (e.g. carrier escaping arena bounds)
func on_enemy_despawned() -> void:
	active_enemies -= 1

## ── Wave composition ─────────────────────────────────────────────────────────

func _spawn_wave() -> void:
	if active_enemies >= max_enemies:
		return

	var difficulty: float = GameManager.difficulty_multiplier
	var phase_idx: int = clampi(GameManager.phase_number - 1, 0, 4)
	var count: int = mini(int(enemies_per_spawn * difficulty * PHASE_SPAWN_MULT[phase_idx]), max_enemies - active_enemies)

	for _i in range(count):
		if active_enemies >= max_enemies:
			break
		_spawn_single_enemy()

	## Phase 2+: occasional Brute (1–2 per wave, rare roll)
	if GameManager.phase_number >= 2 and brute_scene != null:
		var brute_roll: float = clampf(0.12 + GameManager.run_time / BRUTE_ROLL_RAMP, 0.12, 0.35)
		if randf() < brute_roll:
			var brute_count: int = randi_range(1, 2)
			for _b in range(brute_count):
				if active_enemies < max_enemies:
					_spawn_enemy_at_spawn_pos(brute_scene, true)

	## Phase 2+: occasional Caster pair
	if GameManager.phase_number >= 2 and caster_scene != null:
		var caster_roll: float = clampf(0.15 + GameManager.run_time / CASTER_ROLL_RAMP, 0.15, 0.40)
		if randf() < caster_roll:
			for _c in range(2):  ## Casters always spawn in pairs
				if active_enemies < max_enemies:
					_spawn_enemy_at_spawn_pos(caster_scene, false)

	## Phase 3+: Stalker (solo, slow roll)
	if GameManager.phase_number >= 3 and stalker_scene != null:
		var stalker_roll: float = clampf(0.10 + GameManager.run_time / 400.0, 0.10, 0.28)
		if randf() < stalker_roll:
			if active_enemies < max_enemies:
				_spawn_enemy_at_spawn_pos(stalker_scene, false)

func _spawn_single_enemy() -> void:
	if player_ref == null:
		return

	var swarmer_chance: float = clampf(0.1 + (GameManager.difficulty_multiplier - 1.0) * 0.15, 0.1, 0.5)
	var spawn_pos: Vector2 = _get_spawn_position()
	var phase_idx: int = clampi(GameManager.phase_number - 1, 0, 4)
	var effective_difficulty: float = GameManager.difficulty_multiplier * GameManager.get_instability_multiplier() * PHASE_HP_MULT[phase_idx]
	var elite_chance: float = _get_elite_chance()

	if randf() < swarmer_chance and swarmer_scene != null:
		## Pack of 3–5 swarmers
		var pack_size: int = randi_range(3, 5)
		for _j in range(pack_size):
			if active_enemies >= max_enemies:
				break
			var enemy: Node2D = swarmer_scene.instantiate()
			var offset := Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
			enemy.global_position = spawn_pos + offset
			enemy.apply_difficulty_scaling(effective_difficulty)
			if randf() < elite_chance and enemy.has_method("apply_elite_modifier"):
				enemy.apply_elite_modifier()
			get_tree().current_scene.add_child(enemy)
			active_enemies += 1
			enemy_spawned.emit(enemy)
	elif fodder_scene != null:
		var enemy: Node2D = fodder_scene.instantiate()
		enemy.global_position = spawn_pos
		enemy.apply_difficulty_scaling(effective_difficulty)
		if randf() < elite_chance and enemy.has_method("apply_elite_modifier"):
			enemy.apply_elite_modifier()
		get_tree().current_scene.add_child(enemy)
		active_enemies += 1
		enemy_spawned.emit(enemy)

func _spawn_enemy_at_spawn_pos(scene: PackedScene, can_be_elite: bool) -> void:
	var spawn_pos: Vector2 = _get_spawn_position()
	var phase_idx: int = clampi(GameManager.phase_number - 1, 0, 4)
	var effective_difficulty: float = GameManager.difficulty_multiplier * GameManager.get_instability_multiplier() * PHASE_HP_MULT[phase_idx]
	var enemy: Node2D = scene.instantiate()
	enemy.global_position = spawn_pos
	if enemy.has_method("apply_difficulty_scaling"):
		enemy.apply_difficulty_scaling(effective_difficulty)
	if can_be_elite and randf() < _get_elite_chance() and enemy.has_method("apply_elite_modifier"):
		enemy.apply_elite_modifier()
	get_tree().current_scene.add_child(enemy)
	active_enemies += 1
	enemy_spawned.emit(enemy)

## Carriers spawn AT the arena edge (not off-screen) so they run across the arena
func _spawn_enemy_at_edge(scene: PackedScene, can_be_elite: bool) -> void:
	if active_enemies >= max_enemies:
		return
	var spawn_pos: Vector2 = _get_edge_spawn_position()
	var phase_idx: int = clampi(GameManager.phase_number - 1, 0, 4)
	var effective_difficulty: float = GameManager.difficulty_multiplier * GameManager.get_instability_multiplier() * PHASE_HP_MULT[phase_idx]
	var enemy: Node2D = scene.instantiate()
	enemy.global_position = spawn_pos
	if enemy.has_method("apply_difficulty_scaling"):
		enemy.apply_difficulty_scaling(effective_difficulty)
	if can_be_elite and randf() < _get_elite_chance() and enemy.has_method("apply_elite_modifier"):
		enemy.apply_elite_modifier()
	get_tree().current_scene.add_child(enemy)
	active_enemies += 1
	enemy_spawned.emit(enemy)

## Herald always spawns with a small pack of fodder or swarmers
func _spawn_herald_pack() -> void:
	if active_enemies >= max_enemies or herald_scene == null:
		return
	## Spawn herald first
	_spawn_enemy_at_spawn_pos(herald_scene, false)
	## Then 4–6 companions near it
	var pack_scene: PackedScene = swarmer_scene if swarmer_scene != null else fodder_scene
	if pack_scene == null:
		return
	var pack_size: int = randi_range(4, 6)
	var base_pos: Vector2 = _get_spawn_position()
	var phase_idx: int = clampi(GameManager.phase_number - 1, 0, 4)
	var effective_difficulty: float = GameManager.difficulty_multiplier * GameManager.get_instability_multiplier() * PHASE_HP_MULT[phase_idx]
	for _i in range(pack_size):
		if active_enemies >= max_enemies:
			break
		var companion: Node2D = pack_scene.instantiate()
		companion.global_position = base_pos + Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
		if companion.has_method("apply_difficulty_scaling"):
			companion.apply_difficulty_scaling(effective_difficulty)
		get_tree().current_scene.add_child(companion)
		active_enemies += 1
		enemy_spawned.emit(companion)

## ── Debug helpers ─────────────────────────────────────────────────────────────

## Spawn a specific enemy type near the player. Used by the debug panel.
func debug_spawn(scene: PackedScene, as_elite: bool = false) -> void:
	if player_ref == null or scene == null:
		return
	var offset := Vector2(randf_range(-80.0, 80.0), randf_range(-80.0, 80.0)).normalized() * 80.0
	var enemy: Node2D = scene.instantiate()
	enemy.global_position = player_ref.global_position + offset
	if as_elite and enemy.has_method("apply_elite_modifier"):
		enemy.apply_elite_modifier()
	get_tree().current_scene.add_child(enemy)
	active_enemies += 1
	enemy_spawned.emit(enemy)

## ── Spawn position helpers ────────────────────────────────────────────────────

func _get_spawn_position() -> Vector2:
	const SPAWN_RADIUS: float = 340.0
	const INNER_MARGIN: float = 20.0
	var center: Vector2 = player_ref.global_position if player_ref else Vector2.ZERO
	var angle: float = randf() * TAU
	var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * SPAWN_RADIUS
	var safe_bounds := Rect2(
		arena_bounds.position + Vector2(INNER_MARGIN, INNER_MARGIN),
		arena_bounds.size - Vector2(INNER_MARGIN * 2.0, INNER_MARGIN * 2.0)
	)
	pos.x = clampf(pos.x, safe_bounds.position.x, safe_bounds.end.x)
	pos.y = clampf(pos.y, safe_bounds.position.y, safe_bounds.end.y)
	return pos

## Edge spawn: pick a random point near one of the 4 arena walls (for Carriers)
func _get_edge_spawn_position() -> Vector2:
	const EDGE_INSET: float = 16.0
	var edge: int = randi() % 4
	var x: float
	var y: float
	match edge:
		0:  ## Top
			x = randf_range(arena_bounds.position.x + 20.0, arena_bounds.end.x - 20.0)
			y = arena_bounds.position.y + EDGE_INSET
		1:  ## Bottom
			x = randf_range(arena_bounds.position.x + 20.0, arena_bounds.end.x - 20.0)
			y = arena_bounds.end.y - EDGE_INSET
		2:  ## Left
			x = arena_bounds.position.x + EDGE_INSET
			y = randf_range(arena_bounds.position.y + 20.0, arena_bounds.end.y - 20.0)
		_:  ## Right
			x = arena_bounds.end.x - EDGE_INSET
			y = randf_range(arena_bounds.position.y + 20.0, arena_bounds.end.y - 20.0)
	return Vector2(x, y)

## Elite chance: 5% base, +0.4% every 30 seconds, +3% per phase beyond phase 1, soft cap 35%
func _get_elite_chance() -> float:
	var phase_bonus: float = (GameManager.phase_number - 1) * 0.03
	return clampf(0.05 + (GameManager.run_time / 30.0) * 0.004 + phase_bonus, 0.05, 0.35)
