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

	# Floor
	_setup_floor()

	# Wall collision layers
	for wall_name in ["WallTop", "WallBottom", "WallLeft", "WallRight"]:
		var wall := get_node_or_null(wall_name)
		if wall is StaticBody2D:
			wall.collision_layer = 3
			wall.collision_mask = 0

	# Arena generator
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
