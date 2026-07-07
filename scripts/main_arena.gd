extends Node2D

## MainArena — Root scene. Wires all systems together and manages run lifecycle.
## Uses CombatOrchestrator for engine subsystem management (damage pipeline,
## status effects, projectiles, VFX, displacement, combat feedback).
## Extraction logic is delegated to handler classes in scripts/extraction/.

const ARENA_HALF_W: float = 800.0
const ARENA_HALF_H: float = 600.0

const LootDropScene      = preload("res://scenes/pickups/loot_drop.tscn")
const WeaponPickupScript = preload("res://scripts/pickups/weapon_pickup.gd")
const ModPickupScript    = preload("res://scripts/pickups/mod_pickup.gd")

## Engine orchestrator — owns all combat subsystems
var orchestrator: CombatOrchestrator = null

@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var level_up_screen: CanvasLayer = $LevelUpScreen
@onready var game_over_screen: CanvasLayer = $GameOverScreen
@onready var extraction_success_screen: CanvasLayer = $ExtractionSuccessScreen
@onready var arena_floor: TextureRect = $ArenaFloor

## Extraction handlers
var _timed: TimedExtraction = null
var _guarded: GuardedExtraction = null
var _locked: LockedExtraction = null
var _sacrifice: SacrificeExtraction = null

var arena_generator: ArenaGenerator = null
var _camera: Camera2D = null
var _active_channeling_type: String = ""
var _debug_all_extractions_active: bool = false

## ── Game-feel: hit-stop / screen shake tuning (each independently toggleable) ──
const HITSTOP_ENABLED: bool = true
const SHAKE_ENABLED: bool = true
const HITSTOP_TIME_SCALE: float = 0.0       ## true freeze; nothing in the codebase divides by delta
const HITSTOP_CRIT_FRAMES: int = 2          ## player crit
const HITSTOP_ELITE_KILL_FRAMES: int = 3    ## elite kill
const HITSTOP_BOSS_KILL_FRAMES: int = 4     ## miniboss/final-boss kill
const HITSTOP_FINISHER_FRAMES: int = 6      ## combo finisher landing — strongest in the game (design-audit D6)
var _hitstop_locks: int = 0

const SHAKE_SMALL_INTENSITY: float = 2.0    ## player takes damage
const SHAKE_SMALL_DURATION: float = 0.10
const SHAKE_MEDIUM_INTENSITY: float = 6.0   ## AoE/explosive kill
const SHAKE_MEDIUM_DURATION: float = 0.18
const SHAKE_LARGE_INTENSITY: float = 10.0   ## boss telegraph impact
const SHAKE_LARGE_DURATION: float = 0.30
const SHAKE_FINISHER_INTENSITY: float = 14.0 ## combo finisher landing
const SHAKE_FINISHER_DURATION: float = 0.35
const SHAKE_MAX_INTENSITY: float = 14.0     ## hard cap — chained explosions can't compound past this
var _active_shake_intensity: float = 0.0
var _shake_tween: Tween = null

## Extraction fanfare — must fit inside GameManager.EXTRACTION_FANFARE_DELAY
const EXTRACTION_FLASH_DURATION: float = 0.30
const EXTRACTION_ZOOM_IN_DURATION: float = 0.14
const EXTRACTION_ZOOM_OUT_DURATION: float = 0.22
const EXTRACTION_ZOOM_PUNCH: float = 1.10

## LDtk mode — set when use_ldtk_level_1 flag is active
var _using_ldtk: bool = false
var _using_descent: bool = false
var _ldtk_loader: LdtkLoader = null
var _ldtk_director: LdtkLevelDirector = null
var _ldtk_exit: LdtkExitZone = null
var _block_manager: BlockManager = null
var _depth_tracker: DepthTracker = null
var _event_spawn_manager: EventSpawnManager = null
var _depth_canvas_mod: CanvasModulate = null

## Descent climax — boss gate at the Portal block
var _portal_block_index: int = -1
var _descent_boss_spawn_pos: Vector2 = Vector2.ZERO
var _descent_boss_spawned: bool = false


func _ready() -> void:
	# Build engine status effect definitions
	StatusFactory.build_all()

	# Create engine orchestrator
	orchestrator = CombatOrchestrator.new()
	orchestrator.name = "CombatOrchestrator"
	add_child(orchestrator)

	# Register player with engine
	orchestrator.register_player(player)

	# Assign enemy scenes to EnemySpawnManager
	EnemySpawnManager.fodder_scene   = preload("res://scenes/enemies/fodder.tscn")
	EnemySpawnManager.swarmer_scene  = preload("res://scenes/enemies/swarmer.tscn")
	EnemySpawnManager.brute_scene    = preload("res://scenes/enemies/brute.tscn")
	EnemySpawnManager.caster_scene   = preload("res://scenes/enemies/caster.tscn")
	EnemySpawnManager.carrier_scene  = preload("res://scenes/enemies/carrier.tscn")
	EnemySpawnManager.stalker_scene  = preload("res://scenes/enemies/stalker.tscn")
	EnemySpawnManager.herald_scene   = preload("res://scenes/enemies/herald.tscn")
	EnemySpawnManager.guardian_scene = preload("res://scenes/enemies/guardian.tscn")

	# Configure level-specific spawn pool (must happen before start_spawning)
	EnemySpawnManager.configure_level(GameManager.current_level)

	# Camera
	_camera = Camera2D.new()
	_camera.zoom = Vector2(1, 1)
	_camera.position_smoothing_enabled = false
	_camera.limit_left = int(-ARENA_HALF_W)
	_camera.limit_right = int(ARENA_HALF_W)
	_camera.limit_top = int(-ARENA_HALF_H)
	_camera.limit_bottom = int(ARENA_HALF_H)
	player.add_child(_camera)

	# Listen to EventBus for loot drops and screen shake (replaces old CombatManager signals)
	EventBus.on_kill.connect(_on_entity_killed)
	EventBus.on_crit.connect(_on_player_crit)
	EventBus.on_hit_dealt.connect(_on_hit_dealt_for_feel)
	EventBus.on_finisher_hit.connect(_on_finisher_hit)

	# Wire UI to player
	hud.setup(player)
	level_up_screen.setup(player)

	# Instability aura VFX — child of player so it follows movement
	var aura_script = load("res://scripts/entities/instability_aura.gd")
	if aura_script:
		var aura := Node2D.new()
		aura.set_script(aura_script)
		player.add_child(aura)

	# Extraction signals
	GameManager.extraction_window_opened.connect(_on_extraction_window_opened)
	GameManager.extraction_window_closed.connect(_on_extraction_window_closed)
	ExtractionManager.extraction_complete.connect(_on_any_extraction_complete)
	ExtractionManager.extraction_interrupted.connect(_on_any_extraction_interrupted)
	GameManager.phase_started.connect(_on_phase_advanced)

	# Wall collision layers (used by both paths)
	for wall_name in ["WallTop", "WallBottom", "WallLeft", "WallRight"]:
		var wall := get_node_or_null(wall_name)
		if wall is StaticBody2D:
			wall.collision_layer = 3
			wall.collision_mask = 0

	# Level setup — LDtk descent, LDtk single-level, or procedural
	_using_ldtk = GameManager.debug_mode and GameManager.use_ldtk_level_1 \
			and GameManager.current_level == 1
	_using_descent = _using_ldtk and GameManager.use_descent_mode
	if _using_descent:
		await _setup_ldtk_descent()
	elif _using_ldtk:
		_setup_ldtk_level()
	else:
		_setup_floor()
		arena_generator = ArenaGenerator.new()
		add_child(arena_generator)
		arena_generator.generate(2025)

	# Pause menu (ESC)
	var PauseMenuScript := preload("res://scripts/ui/pause_menu.gd")
	var pause_menu: CanvasLayer = PauseMenuScript.new()
	add_child(pause_menu)

	# Insurance panel ([I] key — requires insurance_license Workshop upgrade)
	var InsurancePanelScript := preload("res://scripts/ui/insurance_panel.gd")
	var insurance_panel: CanvasLayer = InsurancePanelScript.new()
	add_child(insurance_panel)

	# Debug panel + entity inspector
	if GameManager.debug_mode:
		var DebugPanelScript := preload("res://scripts/ui/debug_panel.gd")
		var debug_panel: CanvasLayer = DebugPanelScript.new()
		add_child(debug_panel)
		debug_panel.setup(player)
		pause_menu._debug_panel_ref = debug_panel

		var InspectorScript := preload("res://scripts/ui/entity_inspector.gd")
		var entity_inspector: CanvasLayer = InspectorScript.new()
		add_child(entity_inspector)

		var ReportManagerScript := preload("res://scripts/systems/run_report_manager.gd")
		var run_report: Node = ReportManagerScript.new()
		run_report.name = "RunReportManager"
		add_child(run_report)
		run_report.setup(player, _depth_tracker)

	# Start run
	GameManager.start_run()

	if _using_descent:
		## Descent mode: BlockManager already registered spawn zones.
		var descent_bounds := Rect2(0.0, 0.0, _block_manager.level_width, _block_manager.total_height)
		EnemySpawnManager.start_spawning(player, descent_bounds)
	elif _using_ldtk:
		## LDtk mode: extraction zones come from the level, exit zone already wired.
		## Do not call _setup_extraction_zones() — that code assumes ArenaGenerator.
		var ldtk_bounds: Rect2 = Rect2(0.0, 0.0,
				float(_ldtk_loader.get_meta("px_wid", ARENA_HALF_W * 2.0)),
				float(_ldtk_loader.get_meta("px_hei", ARENA_HALF_H * 2.0)))
		EnemySpawnManager.start_spawning(player, ldtk_bounds)
	else:
		_setup_extraction_zones()
		var bounds := Rect2(-ARENA_HALF_W, -ARENA_HALF_H, ARENA_HALF_W * 2.0, ARENA_HALF_H * 2.0)
		EnemySpawnManager.start_spawning(player, bounds)


func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.RUN_ACTIVE:
		return
	if not is_instance_valid(player):
		return

	# Register any new enemies with the orchestrator
	_register_new_enemies()

	# Tick engine orchestrator (rebuilds grid, ticks components, processes ground zones)
	orchestrator.tick(delta)

	var ppos: Vector2 = player.global_position

	# Tick guarded extraction
	if _guarded:
		_guarded.tick(delta, ppos)

	# Extraction proximity checks
	if _sacrifice == null or not _sacrifice.is_ui_open():
		_check_extraction_zones(ppos)

	# Depth atmosphere — lerp world modulate darker as player descends
	if _depth_canvas_mod != null and _depth_tracker != null:
		var t: float = _depth_tracker.depth_progress
		_depth_canvas_mod.color = Color(
			lerpf(1.0, 0.30, t),
			lerpf(1.0, 0.25, t),
			lerpf(1.0, 0.40, t))


func _register_new_enemies() -> void:
	## Register enemies that haven't been registered with the orchestrator yet.
	## Enemies self-add to the "enemies" group in _ready().
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy.get("combat_manager") == null or enemy.combat_manager == null:
			orchestrator.register_enemy(enemy)


# ═══════════════════════════════════════════════════════════════════════════════
# EXTRACTION ZONE SETUP & PROXIMITY
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_ldtk_level() -> void:
	## Load Level_0 from the Caves biome LDtk project and wire all subsystems.
	const LDTK_PATH: String = "res://assets/Maps/Levels/Level 1 - Caves.ldtk"
	const LEVEL_ID: String = "Level_0"

	_ldtk_loader = LdtkLoader.new()
	_ldtk_loader.name = "LdtkLoader"
	add_child(_ldtk_loader)

	var result: Dictionary = _ldtk_loader.load_level(LDTK_PATH, LEVEL_ID)
	if not result.ok:
		push_error("[MainArena] LDtk load failed: " + str(result.errors))
		## Fall back to ArenaGenerator so the game is still runnable.
		_using_ldtk = false
		_setup_floor()
		arena_generator = ArenaGenerator.new()
		add_child(arena_generator)
		arena_generator.generate(2025)
		return

	for w in result.warnings:
		push_warning("[MainArena/LDtk] " + w)

	## Store level dimensions for start_spawning bounds (read via meta in _ready tail).
	_ldtk_loader.set_meta("px_wid", result.pxWid)
	_ldtk_loader.set_meta("px_hei", result.pxHei)

	## Hide the old tiled ArenaFloor — LDtk tile layers provide the floor now.
	if arena_floor:
		arena_floor.visible = false

	## Hide arena border ColorRects (visual overlays, not the physics walls).
	for border_name: String in ["ArenaBorderTop", "ArenaBorderBottom", "ArenaBorderLeft", "ArenaBorderRight"]:
		var border := get_node_or_null(border_name)
		if border != null:
			border.visible = false

	## Disable old boundary physics walls — LDtk collision tiles replace them.
	for wall_name: String in ["WallTop", "WallBottom", "WallLeft", "WallRight"]:
		var wall := get_node_or_null(wall_name)
		if wall is StaticBody2D:
			(wall as StaticBody2D).collision_layer = 0

	## Move player to the level-authored spawn point.
	if not is_nan(result.player_spawn_pos.x):
		player.global_position = result.player_spawn_pos

	## Camera limits: level strip instead of the fixed ±800×±600.
	if _camera != null:
		_camera.limit_left   = 0
		_camera.limit_right  = result.pxWid
		_camera.limit_top    = 0
		_camera.limit_bottom = result.pxHei

	## Register LDtk spawn zones with EnemySpawnManager.
	EnemySpawnManager.clear_spawn_zones()
	for sz in result.spawn_zones:
		EnemySpawnManager.register_spawn_zone(
			sz.rect,
			sz.phase,
			sz.density,
			sz.enemy_pool_override,
			sz.min_distance_from_player
		)

	## LevelDirector — PreBoss kill quota, boss-seal, exit-unlock signals.
	_ldtk_director = LdtkLevelDirector.new()
	_ldtk_director.name = "LdtkLevelDirector"
	add_child(_ldtk_director)
	_ldtk_director.boss_should_spawn.connect(_on_ldtk_boss_should_spawn)
	_ldtk_director.exit_should_unlock.connect(_on_ldtk_exit_should_unlock)
	_ldtk_director.activate(result.regions, result.boss_id, result.boss_spawn_pos, player)

	## Exit zone — proximity channeling trigger for the LevelExit point.
	if not is_nan(result.level_exit_pos.x):
		_ldtk_exit = LdtkExitZone.new()
		_ldtk_exit.name = "LdtkExitZone"
		add_child(_ldtk_exit)
		## boss_id == "" → unlocks immediately (boss-less level).
		_ldtk_exit.setup(result.level_exit_pos, result.boss_id == "")


func _setup_ldtk_descent() -> void:
	## Build a block-based vertical descent for the current level.
	## Sequence: [Entry] + [8 shuffled inner] + [Portal] = 10 total.
	## Entry and Portal are fixed; inner slots shuffle from the normal pool.
	const LDTK_PATH: String = "res://assets/Maps/Levels/Level 1 - Caves.ldtk"
	const BLOCK_COUNT: int = 10  ## Entry + 8 shuffled inner (Merchant at ~50%) + Portal

	## Fixed bookend blocks — never shuffled
	const ENTRY_BLOCK_ID: String = "Block_Caves_00_Entry"
	const PORTAL_BLOCK_ID: String = "Block_Caves_09_Portal"

	## Inner shuffled pool (add more variants here as they're authored;
	## 10+ are compiled from blocks/caves/*.block — see docs/block_sketch_workflow.md)
	var normal_block_ids: Array[String] = [
		"Block_Caves_01_Open",
		"Block_Caves_02_Pillars",
		"Block_Caves_03_Choke",
		"Block_Caves_04_Split",
		"Block_Caves_10_ChokeA",
		"Block_Caves_11_ChokeB",
		"Block_Caves_12_PillarsB",
		"Block_Caves_13_SplitB",
		"Block_Caves_14_OpenB",
		"Block_Caves_15_Gauntlet",
	]
	const MERCHANT_BLOCK_ID: String = "Block_Caves_05_Merchant"

	_block_manager = BlockManager.new()
	_block_manager.name = "BlockManager"
	add_child(_block_manager)

	var result: Dictionary = await _block_manager.build_descent(
		LDTK_PATH, BLOCK_COUNT, normal_block_ids,
		ENTRY_BLOCK_ID, PORTAL_BLOCK_ID, MERCHANT_BLOCK_ID, 0.5)

	if not result.ok:
		push_error("[MainArena] Descent build failed: %s" % str(result.errors))
		_using_descent = false
		_using_ldtk = false
		_setup_floor()
		arena_generator = ArenaGenerator.new()
		add_child(arena_generator)
		arena_generator.generate(2025)
		return

	for w: String in result.warnings:
		push_warning("[MainArena/Descent] %s" % w)

	## Hide arena floor and borders — blocks provide the visuals.
	if arena_floor:
		arena_floor.visible = false
	for border_name: String in ["ArenaBorderTop", "ArenaBorderBottom", "ArenaBorderLeft", "ArenaBorderRight"]:
		var border := get_node_or_null(border_name)
		if border != null:
			border.visible = false
	for wall_name: String in ["WallTop", "WallBottom", "WallLeft", "WallRight"]:
		var wall := get_node_or_null(wall_name)
		if wall is StaticBody2D:
			(wall as StaticBody2D).collision_layer = 0

	## Player spawn
	player.global_position = result.player_spawn

	## Camera limits for the full descent
	if _camera != null:
		_camera.limit_left = 0
		_camera.limit_right = int(result.level_width)
		_camera.limit_top = 0
		_camera.limit_bottom = int(result.total_height)

	## Expand projectile bounds to cover the full descent world
	if orchestrator and orchestrator.projectile_manager:
		orchestrator.projectile_manager.set_world_bounds(
			Vector2(-50.0, -50.0),
			Vector2(result.level_width + 50.0, result.total_height + 50.0))

	## Register spawn zones with EnemySpawnManager
	_block_manager.register_spawn_zones_with(EnemySpawnManager)

	## Exit zone at the portal position (bottom of descent).
	## Locked until the descent boss is defeated — reaching the Portal block
	## triggers the boss, and its death unlocks extraction (hard gate).
	_ldtk_exit = LdtkExitZone.new()
	_ldtk_exit.name = "LdtkExitZone"
	add_child(_ldtk_exit)
	_ldtk_exit.setup(result.portal_pos, false)

	## Boss climax — spawn The Heart of the Deep when the player reaches the
	## Portal block (last block). The boss spawns in the block above the exit so
	## the player has the descent column above as dodge room for its nova.
	_portal_block_index = int(result.block_count) - 1
	if not _block_manager.block_bounds.is_empty() and _portal_block_index >= 0:
		var portal_bounds: Rect2 = _block_manager.block_bounds[_portal_block_index]
		_descent_boss_spawn_pos = Vector2(
			result.level_width * 0.5,
			portal_bounds.position.y + portal_bounds.size.y * 0.4)
	_descent_boss_spawned = false
	GameManager.final_boss_defeated.connect(_on_descent_boss_defeated)

	## Depth tracker — reads block bounds, drives HUD depth meter
	_depth_tracker = DepthTracker.new()
	_depth_tracker.name = "DepthTracker"
	add_child(_depth_tracker)
	_depth_tracker.setup(_block_manager, player)
	_depth_tracker.block_entered.connect(_on_descent_block_entered)
	hud.setup_depth_tracker(_depth_tracker)

	## Event spawn manager — places Merchant and SummonAltar at block anchors
	_event_spawn_manager = EventSpawnManager.new()
	_event_spawn_manager.name = "EventSpawnManager"
	add_child(_event_spawn_manager)
	_event_spawn_manager.setup(_block_manager, player, self)
	hud.set_depth_event_ticks(_event_spawn_manager.get_event_depths())

	## Depth atmosphere — world darkens as player descends (CanvasLayer HUD is unaffected).
	_depth_canvas_mod = CanvasModulate.new()
	_depth_canvas_mod.name = "DepthCanvasModulate"
	_depth_canvas_mod.color = Color(1.0, 1.0, 1.0)
	add_child(_depth_canvas_mod)


func _on_ldtk_boss_should_spawn(boss_id: String, spawn_pos: Vector2) -> void:
	## Fired by LdtkLevelDirector when the PreBoss kill quota is met.
	## Descent boss spawning uses a separate path (_on_descent_block_entered).
	if EnemyRegistry.get_def(boss_id) == null:
		push_warning("[MainArena] boss_should_spawn: unknown boss_id '%s' — no boss spawned" % boss_id)
		return
	var bounds: Rect2 = _get_level_bounds()
	var clamped_pos := Vector2(
		clampf(spawn_pos.x, bounds.position.x, bounds.end.x),
		clampf(spawn_pos.y, bounds.position.y, bounds.end.y))
	if clamped_pos.distance_to(spawn_pos) > 1.0:
		push_warning("[MainArena] boss_should_spawn: spawn_pos %s outside level bounds — clamped to %s" \
				% [spawn_pos, clamped_pos])
	_boss_intro_beat(boss_id, clamped_pos)
	EnemySpawnManager.spawn_named_boss_at(boss_id, clamped_pos)


## Boss intro beat: camera nudge toward the spawn point + a 3×-scaled name banner (reuses
## HUD's existing flash_text, the same machinery as the final-boss "BOSS INCOMING" flash).
## No spawn-suppression window — EnemySpawnManager has no trivially-reachable pause toggle
## (would need real spawn-manager surgery; skipped per task scope).
func _boss_intro_beat(boss_id: String, spawn_pos: Vector2) -> void:
	var def: EnemyDefinition = EnemyRegistry.get_def(boss_id)
	var display_name: String = def.enemy_name if def and def.enemy_name != "" else boss_id.capitalize()
	if hud and hud.has_method("flash_text"):
		hud.flash_text("BOSS INCOMING — %s" % display_name.to_upper(), Color(1.0, 0.3, 0.25), 1.8)
	if _camera != null and is_instance_valid(_camera) and is_instance_valid(player):
		var dir: Vector2 = spawn_pos - player.global_position
		dir = dir.normalized() if dir.length() > 1.0 else Vector2.ZERO
		var nudge: Vector2 = dir * 14.0
		var nt := create_tween()
		nt.tween_property(_camera, "offset", nudge, 0.25).set_trans(Tween.TRANS_SINE)
		nt.tween_property(_camera, "offset", Vector2.ZERO, 0.35).set_trans(Tween.TRANS_SINE)
	_shake_camera(SHAKE_LARGE_INTENSITY * 0.6, 0.2)


func _get_level_bounds() -> Rect2:
	## Return the playable world rect for the current mode so spawn-position validation
	## uses actual level dimensions rather than the default ±800×±600 arena.
	if _block_manager != null:
		return Rect2(0.0, 0.0, _block_manager.level_width, _block_manager.total_height)
	if _ldtk_loader != null:
		return Rect2(0.0, 0.0,
			float(_ldtk_loader.get_meta("px_wid", ARENA_HALF_W * 2.0)),
			float(_ldtk_loader.get_meta("px_hei", ARENA_HALF_H * 2.0)))
	return Rect2(-ARENA_HALF_W, -ARENA_HALF_H, ARENA_HALF_W * 2.0, ARENA_HALF_H * 2.0)


func _on_ldtk_exit_should_unlock() -> void:
	if _ldtk_exit != null:
		_ldtk_exit.unlock()


func _on_descent_block_entered(block_index: int) -> void:
	## Trigger the descent boss the first time the player reaches the Portal block.
	if _descent_boss_spawned:
		return
	if block_index < _portal_block_index:
		return
	_descent_boss_spawned = true
	EnemySpawnManager.spawn_final_boss_at(_descent_boss_spawn_pos)


func _on_descent_boss_defeated() -> void:
	## Boss death unlocks the portal extraction (hard gate cleared).
	if _ldtk_exit != null:
		_ldtk_exit.unlock()


func _setup_extraction_zones() -> void:
	var phase: int = GameManager.phase_number
	if arena_generator == null:
		return

	_guarded = GuardedExtraction.new()
	_guarded.build_zone(arena_generator.get_guarded_position())
	_guarded.guardian_health_updated.connect(
		func(hp: float, max_hp: float, show: bool):
			GameManager.guardian_state_changed.emit(hp, max_hp, show))
	add_child(_guarded)

	_locked = LockedExtraction.new()
	_locked.build_zone(arena_generator.get_locked_position())
	add_child(_locked)

	_sacrifice = SacrificeExtraction.new()
	_sacrifice.build_zone(arena_generator.get_sacrifice_position())
	add_child(_sacrifice)

	if phase >= 3 or _debug_all_extractions_active:
		_guarded.activate()
	if phase >= 2 or _debug_all_extractions_active:
		_sacrifice.activate_label()

	if ProgressionManager.has_extraction_intel():
		_timed = TimedExtraction.new()
		_timed.spawn_ghost(arena_generator.get_extraction_position())
		add_child(_timed)


func _check_extraction_zones(ppos: Vector2) -> void:
	if _timed != null and is_instance_valid(_timed) and _timed.is_window_open():
		if _active_channeling_type == "" and _timed.try_start_channel(ppos):
			_active_channeling_type = "timed"
			return
		elif _active_channeling_type == "timed" and not _timed.check_proximity(ppos):
			_timed.try_interrupt_channel(ppos)
			_active_channeling_type = ""
		if _timed.check_proximity(ppos):
			return

	if _guarded != null and _guarded.state == "active":
		if _active_channeling_type == "" and _guarded.try_start_channel(ppos):
			_active_channeling_type = "guarded"
			return
		elif _active_channeling_type == "guarded" and not _guarded.check_proximity(ppos):
			_guarded.try_interrupt_channel(ppos)
			_active_channeling_type = ""
		if _guarded.check_proximity(ppos):
			return

	var locked_phase_ok: bool = GameManager.phase_number >= 3 or _debug_all_extractions_active
	if _locked != null and locked_phase_ok:
		if _active_channeling_type == "" and _locked.try_start_channel(ppos):
			_active_channeling_type = "locked"
			return
		elif _active_channeling_type == "locked" and not _locked.check_proximity(ppos):
			_locked.try_interrupt_channel(ppos)
			_active_channeling_type = ""

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
	_extraction_fanfare()

func _on_any_extraction_interrupted() -> void:
	if _locked:
		_locked.on_extraction_interrupted()
	_active_channeling_type = ""
	ExtractionManager.channel_duration = 4.0

func _on_extraction_window_opened() -> void:
	if _using_ldtk:
		return  ## LDtk mode: exit zone handles exit; skip timed-extraction overlay
	if GameManager.phase_number >= GameManager.MAX_PHASES:
		return
	var pos: Vector2 = arena_generator.get_extraction_position() if arena_generator else Vector2.ZERO
	if _timed != null and is_instance_valid(_timed):
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
	if _guarded:
		_guarded.reset_for_new_phase()
	if _guarded and phase >= 1:
		_guarded.activate()
	if _sacrifice and phase >= 2:
		_sacrifice.activate_label()
	if _timed != null and is_instance_valid(_timed):
		_timed.queue_free()
		_timed = null
	_active_channeling_type = ""
	ExtractionManager.channel_duration = 4.0

func debug_activate_all_extractions() -> void:
	_debug_all_extractions_active = true
	if _guarded and _guarded.state == "inactive":
		_guarded.activate()
	if _sacrifice:
		_sacrifice.activate_label()
	if not GameManager.player_has_keystone:
		GameManager.pickup_keystone()


# ═══════════════════════════════════════════════════════════════════════════════
# LOOT DROPS (now driven by EventBus.on_kill)
# ═══════════════════════════════════════════════════════════════════════════════

func _on_entity_killed(killer: Node, victim: Node) -> void:
	if not victim.is_in_group("enemies"):
		return
	## Boss kills get a heavier shake + a few bonus drops so it feels like a payoff.
	var is_elite_kill: bool = victim.get("is_elite") == true
	var is_explosive_kill: bool = victim.get("status_effect_component") \
			and (victim.status_effect_component.has_status("elite_exploding") \
			or victim.status_effect_component.has_status("void_touched"))
	if victim.is_in_group("final_boss"):
		_shake_camera(12.0, 1.0)
		_request_hitstop(HITSTOP_BOSS_KILL_FRAMES)
	elif victim.is_in_group("bosses"):
		_shake_camera(8.0, 0.6)
		_request_hitstop(HITSTOP_BOSS_KILL_FRAMES)
	elif is_explosive_kill:
		_shake_camera(SHAKE_MEDIUM_INTENSITY, SHAKE_MEDIUM_DURATION)
		if is_elite_kill:
			_request_hitstop(HITSTOP_ELITE_KILL_FRAMES)
	elif is_elite_kill:
		_shake_camera(3.0, 0.12)
		_request_hitstop(HITSTOP_ELITE_KILL_FRAMES)
	else:
		_shake_camera(3.0, 0.12)

	var pos: Vector2 = victim.global_position
	var etype: String = victim.get("enemy_id") if victim.get("enemy_id") else "fodder"
	var is_elite: bool = victim.get("is_elite") == true
	var phase: int = GameManager.phase_number

	## Boss reward payouts.
	if victim.is_in_group("final_boss"):
		## Final boss — signature loot explosion (see _award_final_boss_rewards).
		_award_final_boss_rewards(pos)
		return
	elif victim.is_in_group("bosses"):
		## Miniboss — two bonus drops spread in a small arc around the body.
		for i in range(2):
			var ang: float = TAU * float(i) / 2.0 + randf() * 0.4
			var offset := Vector2(cos(ang), sin(ang)) * 24.0
			var rarity: String = LootTables.roll_rarity(clampi(phase + 1, 1, 5))
			if randf() < 0.5:
				_spawn_weapon_drop(pos + offset, rarity)
			else:
				_spawn_mod_drop(pos + offset, rarity)

	## Keystone drop — elite only, independent roll
	if is_elite and not GameManager.player_has_keystone and randf() < LootTables.KEYSTONE_ELITE_CHANCE:
		_spawn_keystone_drop(pos)

	## Loot Find bonus from player modifiers
	var loot_find_mult: float = 1.0
	if is_instance_valid(player) and player.modifier_component:
		loot_find_mult = 1.0 + player.modifier_component.sum_modifiers("loot_find", "bonus")

	## Roll against enemy loot table
	var rates: Dictionary = LootTables.get_drop_table(etype)
	var resource_chance: float = rates.get("resource", 0.0) * loot_find_mult
	var weapon_mod_chance: float = rates.get("weapon_mod", 0.0) * loot_find_mult

	var roll: float = randf()
	if roll < weapon_mod_chance:
		## 50/50 weapon vs mod
		var rarity: String = LootTables.roll_rarity(phase)
		if randf() < 0.5:
			_spawn_weapon_drop(pos, rarity)
		else:
			_spawn_mod_drop(pos, rarity)
	elif roll < weapon_mod_chance + resource_chance:
		_spawn_loot_drop(pos, phase)


func _spawn_keystone_drop(pos: Vector2) -> void:
	var KeystoneScript = load("res://scripts/pickups/keystone_pickup.gd")
	if KeystoneScript == null:
		return
	var pickup: Area2D = KeystoneScript.new()
	pickup.global_position = pos
	add_child(pickup)

func _spawn_loot_drop(pos: Vector2, phase: int) -> void:
	var drop: Area2D = LootDropScene.instantiate()
	drop.global_position = pos
	var size: String = LootTables.roll_resource_size(phase)
	drop.value = LootTables.get_resource_value(phase)
	drop.size = size
	add_child(drop)

func _spawn_mod_drop(pos: Vector2, rarity: String = "common") -> void:
	var mod_ids: Array = ModData.ORDER
	if mod_ids.is_empty():
		return
	var mod_id: String = mod_ids[randi() % mod_ids.size()]
	var pickup: Area2D = ModPickupScript.new()
	pickup.mod_id          = mod_id
	pickup.rarity          = rarity
	pickup.global_position = pos
	add_child(pickup)

func _spawn_weapon_drop(pos: Vector2, rarity: String = "common") -> void:
	var droppable: Array = WeaponData.get_droppable_ids()
	if droppable.is_empty():
		return
	var weapon_id: String = droppable[randi() % droppable.size()]
	var pickup: Area2D = WeaponPickupScript.new()
	pickup.weapon_id       = weapon_id
	pickup.rarity          = rarity
	pickup.global_position = pos
	add_child(pickup)

## ── Final boss reward payout ─────────────────────────────────────────────────

const FINAL_BOSS_UNIQUE_MOD: String = "abyssal_pull"
const FINAL_BOSS_SPRAY_COUNT: int = 4
const FINAL_BOSS_CURRENCY_MIN: int = 500
const FINAL_BOSS_CURRENCY_MAX: int = 900

func _award_final_boss_rewards(pos: Vector2) -> void:
	## Signature loot explosion for The Heart of the Deep. Everything is carry-out —
	## the player must survive to the portal and extract to keep any of it.
	##  • A 4-item spray of weapons/mods, rarity scaled by current Instability (risk).
	##  • First clear (unique not yet owned) → guaranteed boss-exclusive unique mod.
	##  • Repeat clears (already own it) → a hefty resource drop instead.
	var inst: float = GameManager.instability

	for i in range(FINAL_BOSS_SPRAY_COUNT):
		var ang: float = TAU * float(i) / float(FINAL_BOSS_SPRAY_COUNT) + randf() * 0.4
		var offset := Vector2(cos(ang), sin(ang)) * 30.0
		var rarity: String = LootTables.roll_rarity_for_instability(inst)
		if randf() < 0.5:
			_spawn_weapon_drop(pos + offset, rarity)
		else:
			_spawn_mod_drop(pos + offset, rarity)

	if _player_owns_mod(FINAL_BOSS_UNIQUE_MOD):
		var amount: int = randi_range(FINAL_BOSS_CURRENCY_MIN, FINAL_BOSS_CURRENCY_MAX)
		_spawn_resource_reward(pos, float(amount))
	else:
		_spawn_specific_mod_drop(pos, FINAL_BOSS_UNIQUE_MOD, "legendary")


func _player_owns_mod(mod_id: String) -> bool:
	## "Owns" = banked in inventory OR currently equipped on a weapon. Equipping moves
	## a mod out of owned_mods into weapon_mods, so both must be checked.
	if ProgressionManager.owned_mods.has(mod_id):
		return true
	for equipped: Variant in ProgressionManager.weapon_mods.values():
		if equipped is Array and (equipped as Array).has(mod_id):
			return true
	return false


func _spawn_specific_mod_drop(pos: Vector2, mod_id: String, rarity: String) -> void:
	if not ModData.ALL.has(mod_id):
		return
	var pickup: Area2D = ModPickupScript.new()
	pickup.mod_id          = mod_id
	pickup.rarity          = rarity
	pickup.global_position = pos
	add_child(pickup)


func _spawn_resource_reward(pos: Vector2, amount: float) -> void:
	var drop: Area2D = LootDropScene.instantiate()
	drop.global_position = pos
	drop.value = amount
	drop.size = "large"
	add_child(drop)


func _shake_camera(intensity: float = 3.0, duration: float = 0.12) -> void:
	if not SHAKE_ENABLED:
		return
	if _camera == null or not is_instance_valid(_camera):
		return
	if get_tree().paused:
		return
	## Cap so chained explosions can't compound past the strongest tier, and never let a
	## weaker shake interrupt/restart a stronger one already playing.
	var capped: float = minf(intensity, SHAKE_MAX_INTENSITY) * Settings.screen_shake
	if capped <= 0.0:
		return
	if _shake_tween != null and _shake_tween.is_valid() and capped <= _active_shake_intensity:
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_active_shake_intensity = capped
	var shake_offset := Vector2(randf_range(-capped, capped), randf_range(-capped, capped))
	_shake_tween = create_tween()
	_shake_tween.tween_property(_camera, "offset", shake_offset, duration * 0.25)
	_shake_tween.tween_property(_camera, "offset", Vector2.ZERO, duration * 0.75)
	_shake_tween.tween_callback(func(): _active_shake_intensity = 0.0)


## ── Hit-stop: brief Engine.time_scale freeze. Lock-counted so overlapping requests (e.g. a
## crit landing during a finisher) don't restore early; _exit_tree is a safety net against a
## scene change interrupting the countdown and leaving time_scale stuck at 0.
func _request_hitstop(frames: int) -> void:
	if not HITSTOP_ENABLED or frames <= 0:
		return
	if get_tree().paused:
		return
	Engine.time_scale = HITSTOP_TIME_SCALE
	_hitstop_locks += 1
	var duration: float = float(frames) / 60.0
	## ignore_time_scale=true — must tick in real time while time_scale is dipped to 0.
	var timer := get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(_on_hitstop_expired)


func _on_hitstop_expired() -> void:
	_hitstop_locks = maxi(_hitstop_locks - 1, 0)
	if _hitstop_locks == 0:
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _on_player_crit(source, _target, _hit_data) -> void:
	if source == player:
		_request_hitstop(HITSTOP_CRIT_FRAMES)


func _on_hit_dealt_for_feel(_source, target, _hit_data) -> void:
	## Small shake when the player takes damage.
	if target == player:
		_shake_camera(SHAKE_SMALL_INTENSITY, SHAKE_SMALL_DURATION)


func _on_finisher_hit(_entity: Node2D) -> void:
	## P1 (design-audit D6): the finisher landing in a crowd is the pitch moment — strongest
	## hit-stop + shake in the game.
	_request_hitstop(HITSTOP_FINISHER_FRAMES)
	_shake_camera(SHAKE_FINISHER_INTENSITY, SHAKE_FINISHER_DURATION)


## Public hook for boss telegraph impacts (large shake). Called by choreography/telegraph code
## when a boss attack's hit lands.
func on_boss_telegraph_impact() -> void:
	_shake_camera(SHAKE_LARGE_INTENSITY, SHAKE_LARGE_DURATION)


func _extraction_fanfare() -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	var flash_alpha: float = 0.55 * Settings.screen_flash_intensity
	if flash_alpha > 0.0:
		var flash := ColorRect.new()
		flash.color = Color(1.0, 1.0, 1.0, flash_alpha)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.z_index = 100
		flash.process_mode = Node.PROCESS_MODE_ALWAYS
		hud.add_child(flash)
		var ft := create_tween()
		ft.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		ft.tween_property(flash, "modulate:a", 0.0, EXTRACTION_FLASH_DURATION)
		ft.tween_callback(flash.queue_free)
	var base_zoom: Vector2 = _camera.zoom
	var zt := create_tween()
	zt.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	zt.tween_property(_camera, "zoom", base_zoom * EXTRACTION_ZOOM_PUNCH, EXTRACTION_ZOOM_IN_DURATION) \
			.set_trans(Tween.TRANS_SINE)
	zt.tween_property(_camera, "zoom", base_zoom, EXTRACTION_ZOOM_OUT_DURATION).set_trans(Tween.TRANS_SINE)


# ═══════════════════════════════════════════════════════════════════════════════
# FLOOR SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_floor() -> void:
	var floor_path: String = LevelData.get_floor_path(GameManager.current_level)
	if floor_path.is_empty():
		## Fallback: Hellscape ground (used until each level has its own floor)
		floor_path = "res://assets/minifantasy/Minifantasy_Hellscape_v1.0/Minifantasy_Hellscape_Assets/_Premade Scene/Separate Layers/Premade_l-ground.png"
	var source := Image.load_from_file(ProjectSettings.globalize_path(floor_path))
	if source == null:
		push_warning("ArenaFloor: floor texture not found for level %d (%s) — floor will be blank." \
				% [GameManager.current_level, floor_path])
		return
	arena_floor.texture = ImageTexture.create_from_image(source)
	arena_floor.stretch_mode = TextureRect.STRETCH_SCALE
	arena_floor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
