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

## LDtk mode — set when use_ldtk_level_1 flag is active
var _using_ldtk: bool = false
var _using_descent: bool = false
var _ldtk_loader: LdtkLoader = null
var _ldtk_director: LdtkLevelDirector = null
var _ldtk_exit: LdtkExitZone = null
var _block_manager: BlockManager = null
var _depth_tracker: DepthTracker = null
var _event_spawn_manager: EventSpawnManager = null


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
	const BLOCK_COUNT: int = 6  ## TODO: raise to 10 when all blocks are painted

	## Fixed bookend blocks — never shuffled
	const ENTRY_BLOCK_ID: String = "Block_Caves_00_Entry"
	const PORTAL_BLOCK_ID: String = "Block_Caves_09_Portal"

	## Inner shuffled pool (add more variants here as they're authored)
	var normal_block_ids: Array[String] = [
		"Block_Caves_01_Open",
		"Block_Caves_02_Pillars",
		"Block_Caves_03_Choke",
		"Block_Caves_04_Split",
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

	## Exit zone at the portal position (bottom of descent)
	_ldtk_exit = LdtkExitZone.new()
	_ldtk_exit.name = "LdtkExitZone"
	add_child(_ldtk_exit)
	_ldtk_exit.setup(result.portal_pos, true)

	## Depth tracker — reads block bounds, drives HUD depth meter
	_depth_tracker = DepthTracker.new()
	_depth_tracker.name = "DepthTracker"
	add_child(_depth_tracker)
	_depth_tracker.setup(_block_manager, player)
	hud.setup_depth_tracker(_depth_tracker)

	## Event spawn manager — places Merchant and SummonAltar at block anchors
	_event_spawn_manager = EventSpawnManager.new()
	_event_spawn_manager.name = "EventSpawnManager"
	add_child(_event_spawn_manager)
	_event_spawn_manager.setup(_block_manager, player, self)
	hud.set_depth_event_ticks(_event_spawn_manager.get_event_depths())


func _on_ldtk_boss_should_spawn(boss_id: String, spawn_pos: Vector2) -> void:
	## TODO: instantiate the boss scene at spawn_pos using EnemySpawnManager.
	## For now, just log it; Level_0 is boss-less so this won't fire.
	push_warning("[MainArena] boss_should_spawn: id='%s' pos=%s — boss scene wiring TBD" \
			% [boss_id, spawn_pos])


func _on_ldtk_exit_should_unlock() -> void:
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
	if victim.is_in_group("final_boss"):
		_shake_camera(12.0, 1.0)
	elif victim.is_in_group("bosses"):
		_shake_camera(8.0, 0.6)
	else:
		_shake_camera(3.0, 0.12)

	var pos: Vector2 = victim.global_position
	var etype: String = victim.get("enemy_id") if victim.get("enemy_id") else "fodder"
	var is_elite: bool = victim.get("is_elite") == true
	var phase: int = GameManager.phase_number

	## Bonus drops for bosses — two extras, spread in a small arc around the body.
	if victim.is_in_group("bosses"):
		var bonus_count: int = 3 if victim.is_in_group("final_boss") else 2
		for i in range(bonus_count):
			var ang: float = TAU * float(i) / float(bonus_count) + randf() * 0.4
			var offset := Vector2(cos(ang), sin(ang)) * 24.0
			var rarity_phase: int = clampi(phase + 1, 1, 5)
			var rarity: String = LootTables.roll_rarity(rarity_phase)
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
