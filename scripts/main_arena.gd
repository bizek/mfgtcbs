extends Node2D

## MainArena — Prototype root scene. Wires all systems together and manages run lifecycle.
## Extraction logic is delegated to handler classes in scripts/extraction/.

const ARENA_HALF_W: float = 800.0
const ARENA_HALF_H: float = 600.0

const LootDropScene      = preload("res://scenes/pickups/loot_drop.tscn")
const WeaponPickupScript = preload("res://scripts/pickups/weapon_pickup.gd")
const ModPickupScript    = preload("res://scripts/pickups/mod_pickup.gd")

## Pooled combat feedback — replaces per-hit DamageNumber node instantiation
var combat_feedback: CombatFeedbackManager = null

## Spatial grid for fast proximity queries (replaces per-frame group iteration)
var enemy_grid: SpatialGrid = SpatialGrid.new()

@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var level_up_screen: CanvasLayer = $LevelUpScreen
@onready var game_over_screen: CanvasLayer = $GameOverScreen
@onready var extraction_success_screen: CanvasLayer = $ExtractionSuccessScreen
@onready var arena_floor: TextureRect = $ArenaFloor

## ── Extraction handlers ──────────────────────────────────────────────────────
var _timed: TimedExtraction = null
var _guarded: GuardedExtraction = null
var _locked: LockedExtraction = null
var _sacrifice: SacrificeExtraction = null

var arena_generator: ArenaGenerator = null
var _camera: Camera2D = null

## Which extraction type is currently being channeled
var _active_channeling_type: String = ""

## Phase-gate: whether non-timed extractions are currently active
## Overridden to true by debug "Activate All Extractions" button.
var _debug_all_extractions_active: bool = false

func _ready() -> void:
	## Assign enemy scenes to EnemySpawnManager
	EnemySpawnManager.fodder_scene   = preload("res://scenes/enemies/fodder.tscn")
	EnemySpawnManager.swarmer_scene  = preload("res://scenes/enemies/swarmer.tscn")
	EnemySpawnManager.brute_scene    = preload("res://scenes/enemies/brute.tscn")
	EnemySpawnManager.caster_scene   = preload("res://scenes/enemies/caster.tscn")
	EnemySpawnManager.carrier_scene  = preload("res://scenes/enemies/carrier.tscn")
	EnemySpawnManager.stalker_scene  = preload("res://scenes/enemies/stalker.tscn")
	EnemySpawnManager.herald_scene   = preload("res://scenes/enemies/herald.tscn")

	## Camera
	_camera = Camera2D.new()
	_camera.zoom = Vector2(1, 1)
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 10.0
	_camera.limit_left = int(-ARENA_HALF_W)
	_camera.limit_right = int(ARENA_HALF_W)
	_camera.limit_top = int(-ARENA_HALF_H)
	_camera.limit_bottom = int(ARENA_HALF_H)
	player.add_child(_camera)

	## Connect combat signals for screen shake and loot drops
	CombatManager.entity_killed.connect(_on_entity_killed)

	## Pooled damage numbers — auto-connects to CombatManager.damage_dealt
	combat_feedback = CombatFeedbackManager.new()
	add_child(combat_feedback)

	## Wire UI to player
	hud.setup(player)
	level_up_screen.setup(player)

	## Connect extraction signals
	GameManager.extraction_window_opened.connect(_on_extraction_window_opened)
	GameManager.extraction_window_closed.connect(_on_extraction_window_closed)
	ExtractionManager.extraction_complete.connect(_on_any_extraction_complete)
	ExtractionManager.extraction_interrupted.connect(_on_any_extraction_interrupted)
	GameManager.phase_started.connect(_on_phase_advanced)

	## Tile the floor
	_setup_floor()

	## Fix wall collision layers
	for wall_name in ["WallTop", "WallBottom", "WallLeft", "WallRight"]:
		var wall := get_node_or_null(wall_name)
		if wall is StaticBody2D:
			wall.collision_layer = 3
			wall.collision_mask = 0

	## Generate arena layout
	arena_generator = ArenaGenerator.new()
	add_child(arena_generator)
	arena_generator.generate(2025)

	## Debug panel
	if GameManager.debug_mode:
		var DebugPanelScript := preload("res://scripts/ui/debug_panel.gd")
		var debug_panel: CanvasLayer = DebugPanelScript.new()
		add_child(debug_panel)
		debug_panel.setup(player)

	## Give the player a reference to the spatial grid for targeting queries
	player.enemy_grid = enemy_grid

	## Start run
	GameManager.start_run()

	## Setup extraction zones (must be AFTER start_run)
	_setup_extraction_zones()

	var bounds := Rect2(-ARENA_HALF_W, -ARENA_HALF_H, ARENA_HALF_W * 2.0, ARENA_HALF_H * 2.0)
	EnemySpawnManager.start_spawning(player, bounds)

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.RUN_ACTIVE:
		return

	if not is_instance_valid(player):
		return

	## Rebuild spatial grid once per frame for all proximity queries
	enemy_grid.rebuild(get_tree().get_nodes_in_group("enemies"))

	var ppos: Vector2 = player.global_position

	## Tick guarded extraction state machine
	if _guarded:
		_guarded.tick(delta, ppos)

	## Proximity checks (skip while sacrifice UI is open)
	if _sacrifice == null or not _sacrifice.is_ui_open():
		_check_extraction_zones(ppos)

# ═══════════════════════════════════════════════════════════════════════════════
# EXTRACTION ZONE SETUP & PROXIMITY
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_extraction_zones() -> void:
	var phase: int = GameManager.phase_number

	if arena_generator == null:
		return

	## Guarded extraction zone
	_guarded = GuardedExtraction.new()
	_guarded.build_zone(arena_generator.get_guarded_position())
	_guarded.guardian_health_updated.connect(
		func(hp: float, max_hp: float, show: bool):
			GameManager.guardian_state_changed.emit(hp, max_hp, show))
	add_child(_guarded)

	## Locked extraction zone
	_locked = LockedExtraction.new()
	_locked.build_zone(arena_generator.get_locked_position())
	add_child(_locked)

	## Sacrifice extraction zone
	_sacrifice = SacrificeExtraction.new()
	_sacrifice.build_zone(arena_generator.get_sacrifice_position())
	add_child(_sacrifice)

	## Activate based on current phase
	if phase >= 3 or _debug_all_extractions_active:
		_guarded.activate()

	if phase >= 2 or _debug_all_extractions_active:
		_sacrifice.activate_label()

	## Extraction Intel I — pre-spawn timed zone ghost
	if ProgressionManager.has_extraction_intel():
		_timed = TimedExtraction.new()
		_timed.spawn_ghost(arena_generator.get_extraction_position())
		add_child(_timed)

func _check_extraction_zones(ppos: Vector2) -> void:
	## Timed extraction
	if _timed != null and is_instance_valid(_timed) and _timed.is_window_open():
		if _active_channeling_type == "" and _timed.try_start_channel(ppos):
			_active_channeling_type = "timed"
			return
		elif _active_channeling_type == "timed" and not _timed.check_proximity(ppos):
			_timed.try_interrupt_channel(ppos)
			_active_channeling_type = ""
		if _timed.check_proximity(ppos):
			return

	## Guarded extraction
	if _guarded != null and _guarded.state == "active":
		if _active_channeling_type == "" and _guarded.try_start_channel(ppos):
			_active_channeling_type = "guarded"
			return
		elif _active_channeling_type == "guarded" and not _guarded.check_proximity(ppos):
			_guarded.try_interrupt_channel(ppos)
			_active_channeling_type = ""
		if _guarded.check_proximity(ppos):
			return

	## Locked extraction
	var locked_phase_ok: bool = GameManager.phase_number >= 3 or _debug_all_extractions_active
	if _locked != null and locked_phase_ok:
		if _active_channeling_type == "" and _locked.try_start_channel(ppos):
			_active_channeling_type = "locked"
			return
		elif _active_channeling_type == "locked" and not _locked.check_proximity(ppos):
			_locked.try_interrupt_channel(ppos)
			_active_channeling_type = ""

	## Sacrifice extraction
	var sacrifice_ok: bool = GameManager.phase_number >= 2 or _debug_all_extractions_active
	if _sacrifice != null and sacrifice_ok:
		_sacrifice.try_open_ui(ppos)

# ═══════════════════════════════════════════════════════════════════════════════
# EXTRACTION SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════════════════════

func _on_any_extraction_complete() -> void:
	if _locked:
		_locked.on_extraction_complete()
	_active_channeling_type = ""
	ExtractionManager.channel_duration = 4.0

func _on_any_extraction_interrupted() -> void:
	if _locked:
		_locked.on_extraction_interrupted()
	_active_channeling_type = ""
	ExtractionManager.channel_duration = 4.0

func _on_extraction_window_opened() -> void:
	if GameManager.phase_number >= GameManager.MAX_PHASES:
		return  ## Phase 5 has no timed extraction — player must use Guarded, Locked, or Sacrifice
	var pos: Vector2 = arena_generator.get_extraction_position() if arena_generator else Vector2.ZERO
	if _timed != null and is_instance_valid(_timed):
		## Ghost was pre-spawned by Extraction Intel I — open window
		_timed.open_window()
	else:
		_timed = TimedExtraction.new()
		_timed.spawn_zone(pos)
		add_child(_timed)
		_timed.open_window()

func _on_extraction_window_closed() -> void:
	if _active_channeling_type == "timed":
		ExtractionManager.interrupt_channel()
		_active_channeling_type = ""
	if _timed != null and is_instance_valid(_timed):
		_timed.close_window()
		_timed = null

func _on_phase_advanced(phase: int) -> void:
	## Reset and reactivate guarded zone so a fresh guardian guards each phase
	if _guarded:
		_guarded.reset_for_new_phase()
	if _guarded and phase >= 1:
		_guarded.activate()

	## Sacrifice becomes available from phase 2 onwards
	if _sacrifice and phase >= 2:
		_sacrifice.activate_label()

	## Any lingering timed portal from the previous phase (e.g. pre-spawned ghost)
	## is freed here. The new timed portal spawns when the next window opens.
	if _timed != null and is_instance_valid(_timed):
		_timed.queue_free()
		_timed = null

	## Clear channeling state so no stale extraction carries across the phase boundary
	_active_channeling_type = ""
	ExtractionManager.channel_duration = 4.0

## ── Debug: activate all extractions ─────────────────────────────────────────

func debug_activate_all_extractions() -> void:
	_debug_all_extractions_active = true
	if _guarded and _guarded.state == "inactive":
		_guarded.activate()
	if _sacrifice:
		_sacrifice.activate_label()
	if not GameManager.player_has_keystone:
		GameManager.pickup_keystone()

# ═══════════════════════════════════════════════════════════════════════════════
# LOOT DROPS
# ═══════════════════════════════════════════════════════════════════════════════

func _on_entity_killed(_killer: Node, victim: Node, _pos: Vector2) -> void:
	if victim.is_in_group("enemies"):
		_shake_camera(3.0, 0.12)

		var is_carrier: bool = victim.is_in_group("carriers")
		var is_elite: bool   = victim.get("is_elite") == true

		## Keystone drop from elites: 5% chance
		if is_elite and not GameManager.player_has_keystone and randf() < 0.05:
			_spawn_keystone_drop(victim.global_position)

		if is_carrier and randf() < 0.30:
			_spawn_mod_drop(victim.global_position)
			return
		if is_elite and randf() < 0.20:
			_spawn_mod_drop(victim.global_position)
			return

		if randf() < 0.08:
			_spawn_loot_drop(victim.global_position)
		elif randf() < 0.02:
			_spawn_weapon_drop(victim.global_position)

func _spawn_keystone_drop(pos: Vector2) -> void:
	var KeystoneScript = load("res://scripts/pickups/keystone_pickup.gd")
	if KeystoneScript == null:
		return
	var pickup: Area2D = KeystoneScript.new()
	pickup.global_position = pos
	add_child(pickup)

func _spawn_loot_drop(pos: Vector2) -> void:
	var drop: Area2D = LootDropScene.instantiate()
	drop.global_position = pos
	drop.value = randf_range(6.0, 18.0)
	add_child(drop)

func _spawn_mod_drop(pos: Vector2) -> void:
	var mod_ids: Array = ModData.ORDER
	if mod_ids.is_empty():
		return
	var mod_id: String = mod_ids[randi() % mod_ids.size()]
	var pickup: Area2D = ModPickupScript.new()
	pickup.mod_id          = mod_id
	pickup.global_position = pos
	add_child(pickup)

func _spawn_weapon_drop(pos: Vector2) -> void:
	var droppable: Array = WeaponData.get_droppable_ids()
	if droppable.is_empty():
		return
	var weapon_id: String = droppable[randi() % droppable.size()]
	var pickup: Area2D = WeaponPickupScript.new()
	pickup.weapon_id       = weapon_id
	pickup.global_position = pos
	add_child(pickup)

func _shake_camera(intensity: float = 3.0, duration: float = 0.12) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	var shake_offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	var tween := create_tween()
	tween.tween_property(_camera, "offset", shake_offset, duration * 0.25)
	tween.tween_property(_camera, "offset", Vector2.ZERO, duration * 0.75)

# ═══════════════════════════════════════════════════════════════════════════════
# FLOOR SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_floor() -> void:
	const FLOOR_PATH: String = "res://assets/minifantasy/Minifantasy_Hellscape_v1.0/Minifantasy_Hellscape_Assets/_Premade Scene/Separate Layers/Premade_l-ground.png"
	var source := Image.load_from_file(FLOOR_PATH)
	if source == null:
		push_warning("ArenaFloor: Hellscape ground not found — floor will be blank.")
		return
	arena_floor.texture = ImageTexture.create_from_image(source)
	arena_floor.stretch_mode = TextureRect.STRETCH_SCALE
	arena_floor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
