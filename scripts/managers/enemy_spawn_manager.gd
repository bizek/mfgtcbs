extends Node

## EnemySpawnManager — Wave composition, spawn timing, difficulty scaling.
## All enemy types are spawned from their .tscn scene (for sprites/collision) and
## configured via EnemyDefinition data factories (for stats/behavior).
##
## Phase composition (WAVE_COMPOSITION drives _spawn_single_enemy):
##   Phase 1  →  80% Fodder, 20% Swarmer
##   Phase 2  →  50% Fodder, 40% Swarmer, 6% Brute, 4% Caster
##   Phase 3  →  25% each: Fodder, Swarmer, Brute, Caster
##   Phase 4  →  13% Fodder, 27% Swarmer, 33% Stalker, 27% Guardian  (+Carrier via timer)
##   Phase 5  →  12% Swarmer, 48% Anchor, 10% each of 4 Warped variants  (+Carrier+Herald via timers)
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
@export var guardian_scene:  PackedScene
@export var anchor_scene:    PackedScene

## ── Phase stat multipliers (index = phase_number - 1) ────────────────────────
const PHASE_HP_MULT: Array    = [1.0, 1.5, 2.5, 4.0, 6.0]
const PHASE_DMG_MULT: Array   = [1.0, 1.3, 1.6, 2.0, 2.5]
const PHASE_SPAWN_MULT: Array = [1.0, 1.2, 1.5, 1.8, 2.2]

## ── Per-phase wave composition weights (index = phase_number - 1) ────────────
## Carrier and Herald have dedicated timers that supplement these weights.
## "swarmer" entries spawn as packs of 3–5 (see _spawn_single_enemy).
## All weights per phase must sum to 1.0.
const WAVE_COMPOSITION: Array = [
	## Phase 1 — pure swarm, teach movement
	{"fodder": 0.80, "swarmer": 0.20},
	## Phase 2 — first variety introduced
	{"fodder": 0.50, "swarmer": 0.40, "brute": 0.06, "caster": 0.04},
	## Phase 3 — tanky + ranged threats
	{"fodder": 0.25, "swarmer": 0.25, "brute": 0.25, "caster": 0.25},
	## Phase 4 — specialist-dominant; carrier timer adds ~25% threat on top
	{"fodder": 0.13, "swarmer": 0.27, "stalker": 0.33, "guardian": 0.27},
	## Phase 5 — boss-tier density; herald+carrier timers active; 40% warped variants
	{"swarmer": 0.12, "anchor": 0.48, "warped_fodder": 0.10, "warped_swarmer": 0.10, "warped_brute": 0.10, "warped_caster": 0.10},
]

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

## Cached definitions
var _defs: Dictionary = {}


func _ready() -> void:
	EnemyRegistry.build_all()
	_defs = EnemyRegistry.get_all()


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
				_spawn_enemy_at_edge("carrier", carrier_scene, false)
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
	if not EventBus.on_kill.is_connected(_on_entity_killed_eb):
		EventBus.on_kill.connect(_on_entity_killed_eb)
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

func _on_entity_killed_eb(killer: Node, victim: Node) -> void:
	## EventBus.on_kill signature: (killer, victim) — no position
	if victim.is_in_group("enemies"):
		active_enemies -= 1

## For non-combat despawns (e.g. carrier escaping arena bounds)
func on_enemy_despawned() -> void:
	active_enemies -= 1


## ── Spawn from definition ────────────────────────────────────────────────────

func _spawn_from_def(enemy_id: String, scene: PackedScene, pos: Vector2,
		difficulty: float, can_be_elite: bool) -> Node2D:
	## Instantiate a scene and configure it from an EnemyDefinition.
	if scene == null or active_enemies >= max_enemies:
		return null
	var def: EnemyDefinition = _defs.get(enemy_id)
	var enemy: Node2D = scene.instantiate()
	if def:
		enemy.setup_from_enemy_def(def)
	enemy.global_position = pos
	if enemy.has_method("apply_difficulty_scaling"):
		enemy.apply_difficulty_scaling(difficulty)
	if can_be_elite and randf() < _get_elite_chance():
		if enemy.has_method("apply_elite_modifier"):
			enemy.apply_elite_modifier()
	get_tree().current_scene.add_child(enemy)
	active_enemies += 1
	enemy_spawned.emit(enemy)
	return enemy


## ── Wave composition ───────────────────────────────────────���─────────────────

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

func _pick_enemy_type() -> String:
	var phase_idx: int = clampi(GameManager.phase_number - 1, 0, 4)
	var weights: Dictionary = WAVE_COMPOSITION[phase_idx]
	var roll: float = randf()
	var cumulative: float = 0.0
	for enemy_id: String in weights:
		cumulative += weights[enemy_id]
		if roll < cumulative:
			return enemy_id
	return weights.keys()[-1]

func _spawn_single_enemy() -> void:
	if player_ref == null:
		return

	var spawn_pos: Vector2 = _get_spawn_position()
	var effective_difficulty: float = _get_effective_difficulty()
	var enemy_id: String = _pick_enemy_type()
	var scene: PackedScene = _get_scene_for_id(enemy_id)

	if scene == null:
		## Scene not yet assigned in editor — fall back to fodder
		if fodder_scene != null:
			_spawn_from_def("fodder", fodder_scene, spawn_pos, effective_difficulty, true)
		return

	if enemy_id == "swarmer":
		var pack_size: int = randi_range(3, 5)
		for _j in range(pack_size):
			if active_enemies >= max_enemies:
				break
			var offset := Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
			_spawn_from_def(enemy_id, scene, spawn_pos + offset, effective_difficulty, true)
	else:
		var can_elite: bool = enemy_id in ["fodder", "brute", "guardian"]
		_spawn_from_def(enemy_id, scene, spawn_pos, effective_difficulty, can_elite)


func _spawn_enemy_at_edge(enemy_id: String, scene: PackedScene, can_be_elite: bool) -> void:
	if active_enemies >= max_enemies:
		return
	var spawn_pos: Vector2 = _get_edge_spawn_position()
	var effective_difficulty: float = _get_effective_difficulty()
	_spawn_from_def(enemy_id, scene, spawn_pos, effective_difficulty, can_be_elite)


## Herald always spawns with a small pack of fodder or swarmers
func _spawn_herald_pack() -> void:
	if active_enemies >= max_enemies or herald_scene == null:
		return
	var effective_difficulty: float = _get_effective_difficulty()
	## Spawn herald first
	_spawn_from_def("herald", herald_scene, _get_spawn_position(),
		effective_difficulty, false)
	## Then 4–6 companions near it
	var pack_scene: PackedScene = swarmer_scene if swarmer_scene != null else fodder_scene
	var pack_id: String = "swarmer" if swarmer_scene != null else "fodder"
	if pack_scene == null:
		return
	var pack_size: int = randi_range(4, 6)
	var base_pos: Vector2 = _get_spawn_position()
	for _i in range(pack_size):
		if active_enemies >= max_enemies:
			break
		var offset := Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
		_spawn_from_def(pack_id, pack_scene, base_pos + offset,
			effective_difficulty, false)


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

## Spawn by enemy_id (data-driven debug spawn)
func debug_spawn_by_id(enemy_id: String, as_elite: bool = false) -> void:
	if player_ref == null:
		return
	var scene: PackedScene = _get_scene_for_id(enemy_id)
	if scene == null:
		return
	var offset := Vector2(randf_range(-80.0, 80.0), randf_range(-80.0, 80.0)).normalized() * 80.0
	var pos: Vector2 = player_ref.global_position + offset
	var enemy: Node2D = _spawn_from_def(enemy_id, scene, pos, 1.0, as_elite)
	if enemy == null:
		return


func _get_scene_for_id(enemy_id: String) -> PackedScene:
	match enemy_id:
		"fodder": return fodder_scene
		"swarmer": return swarmer_scene
		"brute": return brute_scene
		"caster": return caster_scene
		"carrier": return carrier_scene
		"stalker": return stalker_scene
		"herald": return herald_scene
		"guardian": return guardian_scene
		"anchor": return anchor_scene
		## Phase-Warped: reuse base scenes; stats/behavior come from EnemyDefinition
		"warped_fodder": return fodder_scene
		"warped_swarmer": return swarmer_scene
		"warped_brute": return brute_scene
		"warped_caster": return caster_scene
	return null


## ── Difficulty helper ────────────────────────────────────────────────────────

func _get_effective_difficulty() -> float:
	var phase_idx: int = clampi(GameManager.phase_number - 1, 0, 4)
	return GameManager.difficulty_multiplier * GameManager.get_instability_multiplier() * PHASE_HP_MULT[phase_idx]


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

## Elite chance: 5% base, +0.4% every 30 seconds, +3% per phase beyond phase 1,
## +instability tier bonus (up to +20% at Critical), soft cap 50%
func _get_elite_chance() -> float:
	var phase_bonus: float = (GameManager.phase_number - 1) * 0.03
	var instability_bonus: float = GameManager.get_instability_elite_bonus()
	return clampf(0.05 + (GameManager.run_time / 30.0) * 0.004 + phase_bonus + instability_bonus, 0.05, 0.50)
