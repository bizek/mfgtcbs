extends Node2D

## MainArena — Prototype root scene. Wires all systems together and manages run lifecycle.

const ARENA_HALF_W: float = 800.0
const ARENA_HALF_H: float = 600.0

const DamageNumberClass  = preload("res://scripts/ui/damage_number.gd")
const LootDropScene      = preload("res://scenes/pickups/loot_drop.tscn")
const WeaponPickupScript = preload("res://scripts/pickups/weapon_pickup.gd")
const ModPickupScript    = preload("res://scripts/pickups/mod_pickup.gd")

@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var level_up_screen: CanvasLayer = $LevelUpScreen
@onready var game_over_screen: CanvasLayer = $GameOverScreen
@onready var extraction_success_screen: CanvasLayer = $ExtractionSuccessScreen
@onready var arena_floor: TextureRect = $ArenaFloor

## ── Timed extraction (existing) ──────────────────────────────────────────────
var extraction_zone: Node2D = null
var arena_generator: ArenaGenerator = null
var _camera: Camera2D = null
var _extraction_pulse_tween: Tween = null

## ── Guarded extraction state machine ─────────────────────────────────────────
## States: "inactive" | "guarded" | "active" | "respawning"
var guarded_zone: Node2D = null        ## Persistent visual marker at GUARDED_POSITION
var guardian_enemy: Node2D = null      ## Current live guardian enemy (or null)
var guarded_state: String = "inactive"
var guarded_window_timer: float = 0.0  ## Counts down from 25 when active
var guarded_respawn_timer: float = 0.0 ## Counts down from 45 when respawning
var guarded_spawn_count: int = 0       ## 0 = first guardian, +1 each respawn
var _guarded_active_pulse: Tween = null

## ── Locked extraction ─────────────────────────────────────────────────────────
var locked_zone: Node2D = null         ## Persistent locked-visual marker
var _locked_channeling: bool = false   ## True while 2s fast channel is in progress

## ── Sacrifice extraction ──────────────────────────────────────────────────────
var sacrifice_zone: Node2D = null      ## Persistent sacrifice marker
var _sacrifice_ui_open: bool = false   ## True while sacrifice selection screen is showing
var _sacrifice_layer: CanvasLayer = null

## ── Which extraction type is currently being channeled ───────────────────────
var _active_channeling_type: String = ""

## ── Phase-gate: whether non-timed extractions are currently active ────────────
## Overridden to true by debug "Activate All Extractions" button.
var _debug_all_extractions_active: bool = false

func _ready() -> void:
	## Assign enemy scenes to EnemySpawnManager (autoload has @export vars, set programmatically)
	EnemySpawnManager.fodder_scene   = preload("res://scenes/enemies/fodder.tscn")
	EnemySpawnManager.swarmer_scene  = preload("res://scenes/enemies/swarmer.tscn")
	EnemySpawnManager.brute_scene    = preload("res://scenes/enemies/brute.tscn")
	EnemySpawnManager.caster_scene   = preload("res://scenes/enemies/caster.tscn")
	EnemySpawnManager.carrier_scene  = preload("res://scenes/enemies/carrier.tscn")
	EnemySpawnManager.stalker_scene  = preload("res://scenes/enemies/stalker.tscn")
	EnemySpawnManager.herald_scene   = preload("res://scenes/enemies/herald.tscn")

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
	ExtractionManager.extraction_complete.connect(_on_any_extraction_complete)
	ExtractionManager.extraction_interrupted.connect(_on_any_extraction_interrupted)

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

	## Start the run — sets phase_number = 1 and resets state
	GameManager.start_run()

	## Spawn persistent extraction point markers + initial guardian if phase allows
	## (must be AFTER start_run so phase_number and keystone flags are reset)
	_setup_persistent_extraction_points()

	var bounds := Rect2(-ARENA_HALF_W, -ARENA_HALF_H, ARENA_HALF_W * 2.0, ARENA_HALF_H * 2.0)
	EnemySpawnManager.start_spawning(player, bounds)

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.RUN_ACTIVE:
		return

	## ── Guarded state machine timers ─────────────────────────────────────────
	if guarded_state == "active":
		guarded_window_timer -= delta
		_update_guarded_zone_label()
		if guarded_window_timer <= 0.0:
			_close_guarded_window()

	if guarded_state == "respawning":
		guarded_respawn_timer -= delta
		_update_guarded_zone_label()
		if guarded_respawn_timer <= 0.0:
			_respawn_guardian()

	## ── Broadcast guardian HP for HUD health bar ─────────────────────────────
	_tick_guardian_health_bar()

	## ── Extraction zone proximity checks ─────────────────────────────────────
	if not _sacrifice_ui_open:
		_check_extraction_zones()

func _on_any_extraction_complete() -> void:
	## Reset channel state for the next extraction attempt
	_active_channeling_type = ""
	ExtractionManager.channel_duration = 4.0
	_locked_channeling = false

func _on_any_extraction_interrupted() -> void:
	ExtractionManager.channel_duration = 4.0

func _on_extraction_window_opened() -> void:
	var pos: Vector2 = arena_generator.get_extraction_position() if arena_generator else Vector2.ZERO
	_spawn_extraction_zone(pos)

func _on_extraction_window_closed() -> void:
	if _active_channeling_type == "timed":
		ExtractionManager.interrupt_channel()
		_active_channeling_type = ""
	if _extraction_pulse_tween != null:
		_extraction_pulse_tween.kill()
		_extraction_pulse_tween = null
	if extraction_zone != null and is_instance_valid(extraction_zone):
		extraction_zone.queue_free()
		extraction_zone = null

# ═══════════════════════════════════════════════════════════════════════════════
# PERSISTENT EXTRACTION POINTS SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_persistent_extraction_points() -> void:
	var phase: int = GameManager.phase_number

	## Guarded — build the zone marker. Guardian spawns when phase 3+ or debug active.
	if arena_generator:
		guarded_zone = _build_guarded_zone_node(arena_generator.get_guarded_position())
		add_child(guarded_zone)
		locked_zone = _build_locked_zone_node(arena_generator.get_locked_position())
		add_child(locked_zone)
		sacrifice_zone = _build_sacrifice_zone_node(arena_generator.get_sacrifice_position())
		add_child(sacrifice_zone)

	## Spawn guardian if in the right phase or debug is on
	if phase >= 3 or _debug_all_extractions_active:
		_activate_guarded_extraction()

	## Sacrifice activates at phase 2+
	if phase >= 2 or _debug_all_extractions_active:
		_activate_sacrifice_extraction()

	## Locked activates at phase 3+ (it's always visible but keystone unlocks it)
	## Nothing extra needed — it's always "available" once visible, keyed to player having keystone

## ── Guarded Extraction ────────────────────────────────────────────────────────

func _build_guarded_zone_node(pos: Vector2) -> Node2D:
	## Permanent visual base for the guarded extraction point.
	## State (GUARDED / ACTIVE / RESPAWNING) is shown via label + color changes.
	var node := Node2D.new()
	node.name = "GuardedZone"
	node.global_position = pos

	## Dim fill (darkens/brightens with state)
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = Color(0.50, 0.05, 0.05, 0.18)
	fill.size = Vector2(96.0, 96.0)
	fill.position = Vector2(-48.0, -48.0)
	node.add_child(fill)

	## Border
	var bc := Color(0.75, 0.10, 0.10, 0.45)
	var bw: float = 96.0
	var bt: float = 3.0
	for side in 4:
		var b := ColorRect.new()
		b.color = bc
		match side:
			0: b.size = Vector2(bw, bt); b.position = Vector2(-bw * 0.5, -bw * 0.5)
			1: b.size = Vector2(bw, bt); b.position = Vector2(-bw * 0.5,  bw * 0.5 - bt)
			2: b.size = Vector2(bt, bw); b.position = Vector2(-bw * 0.5, -bw * 0.5)
			3: b.size = Vector2(bt, bw); b.position = Vector2( bw * 0.5 - bt, -bw * 0.5)
		node.add_child(b)

	## State label above zone
	var lbl := Label.new()
	lbl.name = "StateLabel"
	lbl.text = "GUARDED"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-52.0, -80.0)
	lbl.modulate = Color(0.80, 0.20, 0.15, 0.55)
	lbl.add_theme_font_size_override("font_size", 9)
	node.add_child(lbl)

	return node

func _activate_guarded_extraction() -> void:
	guarded_state = "guarded"
	_spawn_guardian()

func _spawn_guardian() -> void:
	if guardian_enemy != null and is_instance_valid(guardian_enemy):
		return  ## Already alive

	var GuardianScript = load("res://scripts/entities/enemy_guardian.gd")
	if GuardianScript == null:
		push_error("MainArena: enemy_guardian.gd not found")
		return

	var g: CharacterBody2D = CharacterBody2D.new()
	g.set_script(GuardianScript)
	g.phase_multiplier = float(GameManager.phase_number)
	g.spawn_count = guarded_spawn_count

	if arena_generator:
		g.global_position = arena_generator.get_guarded_position()
	EnemySpawnManager.active_enemies += 1
	g.guardian_killed.connect(_on_guardian_killed)
	add_child(g)
	guardian_enemy = g

	_update_guarded_zone_label()

func _on_guardian_killed() -> void:
	guardian_enemy = null
	guarded_spawn_count += 1
	_activate_guarded_window()

func _activate_guarded_window() -> void:
	guarded_state = "active"
	guarded_window_timer = 25.0
	_update_guarded_zone_label()

	## Make the zone bright green like the timed portal
	if guarded_zone:
		var fill := guarded_zone.get_node_or_null("Fill")
		if fill:
			fill.color = Color(0.0, 0.88, 0.28, 0.55)
		## Pulse the zone
		_guarded_active_pulse = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		_guarded_active_pulse.tween_property(guarded_zone, "scale", Vector2(1.06, 1.06), 0.5)
		_guarded_active_pulse.tween_property(guarded_zone, "scale", Vector2(1.0, 1.0), 0.5)

func _close_guarded_window() -> void:
	guarded_state = "respawning"
	guarded_respawn_timer = 45.0
	if _guarded_active_pulse:
		_guarded_active_pulse.kill()
		_guarded_active_pulse = null
	guarded_zone.scale = Vector2(1.0, 1.0)

	## Interrupt if player was channeling this
	if _active_channeling_type == "guarded":
		ExtractionManager.interrupt_channel()
		_active_channeling_type = ""

	## Reset fill to dim state
	if guarded_zone:
		var fill := guarded_zone.get_node_or_null("Fill")
		if fill:
			fill.color = Color(0.50, 0.05, 0.05, 0.18)

	_update_guarded_zone_label()

func _respawn_guardian() -> void:
	guarded_state = "guarded"
	_spawn_guardian()
	_update_guarded_zone_label()

func _update_guarded_zone_label() -> void:
	if guarded_zone == null:
		return
	var lbl := guarded_zone.get_node_or_null("StateLabel")
	if lbl == null:
		return
	match guarded_state:
		"inactive":
			lbl.text = "GUARDED (PHASE 3+)"
			lbl.modulate = Color(0.60, 0.18, 0.15, 0.40)
		"guarded":
			lbl.text = "GUARDED"
			lbl.modulate = Color(0.85, 0.20, 0.15, 0.60)
		"active":
			var t: int = int(ceilf(guarded_window_timer))
			lbl.text = "EXTRACT  %ds" % t
			lbl.modulate = Color(0.15, 1.0, 0.5, 1.0)
		"respawning":
			var t: int = int(ceilf(guarded_respawn_timer))
			lbl.text = "RESPAWNING  %ds" % t
			lbl.modulate = Color(0.80, 0.50, 0.15, 0.70)

## ── Locked Extraction ─────────────────────────────────────────────────────────

func _build_locked_zone_node(pos: Vector2) -> Node2D:
	var node := Node2D.new()
	node.name = "LockedZone"
	node.global_position = pos

	## Dark purple fill
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = Color(0.28, 0.04, 0.50, 0.22)
	fill.size = Vector2(96.0, 96.0)
	fill.position = Vector2(-48.0, -48.0)
	node.add_child(fill)

	## Thick purple border (chains feel)
	var bc := Color(0.55, 0.15, 0.80, 0.55)
	var bw: float = 96.0
	var bt: float = 4.0
	for side in 4:
		var b := ColorRect.new()
		b.color = bc
		match side:
			0: b.size = Vector2(bw, bt); b.position = Vector2(-bw * 0.5, -bw * 0.5)
			1: b.size = Vector2(bw, bt); b.position = Vector2(-bw * 0.5,  bw * 0.5 - bt)
			2: b.size = Vector2(bt, bw); b.position = Vector2(-bw * 0.5, -bw * 0.5)
			3: b.size = Vector2(bt, bw); b.position = Vector2( bw * 0.5 - bt, -bw * 0.5)
		node.add_child(b)

	## Chain bars
	for i in range(3):
		var bar := ColorRect.new()
		bar.color = Color(0.45, 0.10, 0.65, 0.55)
		bar.size = Vector2(80.0, 3.0)
		bar.position = Vector2(-40.0, -18.0 + i * 18.0)
		bar.rotation = deg_to_rad(28.0 + i * 6.0)
		node.add_child(bar)

	## State label
	var lbl := Label.new()
	lbl.name = "StateLabel"
	lbl.text = "LOCKED  [need KEY]"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-62.0, -80.0)
	lbl.modulate = Color(0.70, 0.30, 0.95, 0.55)
	lbl.add_theme_font_size_override("font_size", 9)
	node.add_child(lbl)

	return node

func _unlock_locked_zone() -> void:
	## Called when player enters locked zone while holding keystone
	if _locked_channeling or GameManager.current_state != GameManager.GameState.RUN_ACTIVE:
		return
	_locked_channeling = true
	GameManager.player_has_keystone = false  ## Consume the key
	GameManager.active_extraction_type = "locked"

	## Fast 2-second channel
	ExtractionManager.channel_duration = 2.0
	_active_channeling_type = "locked"
	var speed: float = player.get_stat("extraction_speed") if player.has_method("get_stat") else 1.0
	ExtractionManager.start_channel(speed)

	## Update label
	if locked_zone:
		var lbl := locked_zone.get_node_or_null("StateLabel")
		if lbl:
			lbl.text = "UNLOCKING..."
			lbl.modulate = Color(1.0, 0.88, 0.18, 1.0)
		var fill := locked_zone.get_node_or_null("Fill")
		if fill:
			fill.color = Color(0.82, 0.72, 0.08, 0.50)

## ── Sacrifice Extraction ──────────────────────────────────────────────────────

func _build_sacrifice_zone_node(pos: Vector2) -> Node2D:
	var node := Node2D.new()
	node.name = "SacrificeZone"
	node.global_position = pos

	## Ominous blood-red fill, larger outer aura
	var aura := ColorRect.new()
	aura.name = "Aura"
	aura.color = Color(0.55, 0.02, 0.04, 0.12)
	aura.size = Vector2(130.0, 130.0)
	aura.position = Vector2(-65.0, -65.0)
	node.add_child(aura)

	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = Color(0.50, 0.02, 0.05, 0.28)
	fill.size = Vector2(96.0, 96.0)
	fill.position = Vector2(-48.0, -48.0)
	node.add_child(fill)

	## Dark crimson border
	var bc := Color(0.80, 0.06, 0.08, 0.60)
	var bw: float = 96.0
	var bt: float = 3.0
	for side in 4:
		var b := ColorRect.new()
		b.color = bc
		match side:
			0: b.size = Vector2(bw, bt); b.position = Vector2(-bw * 0.5, -bw * 0.5)
			1: b.size = Vector2(bw, bt); b.position = Vector2(-bw * 0.5,  bw * 0.5 - bt)
			2: b.size = Vector2(bt, bw); b.position = Vector2(-bw * 0.5, -bw * 0.5)
			3: b.size = Vector2(bt, bw); b.position = Vector2( bw * 0.5 - bt, -bw * 0.5)
		node.add_child(b)

	## Label
	var lbl := Label.new()
	lbl.name = "StateLabel"
	lbl.text = "SACRIFICE"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-36.0, -80.0)
	lbl.modulate = Color(0.90, 0.14, 0.14, 0.60)
	lbl.add_theme_font_size_override("font_size", 9)
	node.add_child(lbl)

	## Persistent slow particle drip
	var p := CPUParticles2D.new()
	p.amount = 10
	p.lifetime = 1.4
	p.one_shot = false
	p.explosiveness = 0.0
	p.direction = Vector2(0.0, -1.0)
	p.spread = 80.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 20.0
	p.gravity = Vector2(0.0, -6.0)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color = Color(0.70, 0.04, 0.04, 0.65)
	p.emitting = true
	node.add_child(p)

	## Aura slow pulse
	var pulse := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	pulse.tween_property(aura, "modulate:a", 0.25, 1.8)
	pulse.tween_property(aura, "modulate:a", 1.0, 1.8)

	return node

func _activate_sacrifice_extraction() -> void:
	## Sacrifice is always visible; this just confirms it's "open for business"
	if sacrifice_zone:
		var lbl := sacrifice_zone.get_node_or_null("StateLabel")
		if lbl:
			lbl.modulate = Color(0.90, 0.14, 0.14, 0.80)

func _can_sacrifice() -> bool:
	## Phase 2+ OR debug active
	return GameManager.phase_number >= 2 or _debug_all_extractions_active

func _has_sacrifice_items() -> bool:
	return not GameManager.collected_weapons.is_empty() \
		or not GameManager.collected_mods.is_empty() \
		or GameManager.loot_carried > 0.0

## ── Zone proximity checks ─────────────────────────────────────────────────────

func _check_extraction_zones() -> void:
	if not is_instance_valid(player):
		return
	var ppos: Vector2 = player.global_position
	var speed: float = player.get_stat("extraction_speed") if player.has_method("get_stat") else 1.0

	## ── Timed extraction ─────────────────────────────────────────────────────
	if extraction_zone != null and is_instance_valid(extraction_zone):
		var in_zone: bool = ppos.distance_to(extraction_zone.global_position) <= 40.0
		if in_zone and not ExtractionManager.is_channeling:
			GameManager.active_extraction_type = "timed"
			ExtractionManager.channel_duration = 4.0
			_active_channeling_type = "timed"
			ExtractionManager.start_channel(speed)
			return
		elif not in_zone and ExtractionManager.is_channeling and _active_channeling_type == "timed":
			ExtractionManager.interrupt_channel()
			_active_channeling_type = ""
		if in_zone:
			return

	## ── Guarded extraction ───────────────────────────────────────────────────
	if guarded_zone != null and is_instance_valid(guarded_zone) and guarded_state == "active":
		var in_zone: bool = ppos.distance_to(guarded_zone.global_position) <= 40.0
		if in_zone and not ExtractionManager.is_channeling:
			GameManager.active_extraction_type = "guarded"
			ExtractionManager.channel_duration = 4.0
			_active_channeling_type = "guarded"
			ExtractionManager.start_channel(speed)
			return
		elif not in_zone and ExtractionManager.is_channeling and _active_channeling_type == "guarded":
			ExtractionManager.interrupt_channel()
			_active_channeling_type = ""
		if in_zone:
			return

	## ── Locked extraction ────────────────────────────────────────────────────
	var locked_phase_ok: bool = GameManager.phase_number >= 3 or _debug_all_extractions_active
	if locked_zone != null and is_instance_valid(locked_zone) and locked_phase_ok:
		var in_zone: bool = ppos.distance_to(locked_zone.global_position) <= 40.0
		if in_zone and GameManager.player_has_keystone and not ExtractionManager.is_channeling and not _locked_channeling:
			_unlock_locked_zone()
			return
		elif not in_zone and ExtractionManager.is_channeling and _active_channeling_type == "locked":
			ExtractionManager.interrupt_channel()
			_active_channeling_type = ""
			_locked_channeling = false
			ExtractionManager.channel_duration = 4.0
			## Refund the keystone since channel was interrupted
			GameManager.player_has_keystone = true
			if locked_zone:
				var lbl := locked_zone.get_node_or_null("StateLabel")
				if lbl:
					lbl.text = "LOCKED  [need KEY]"
					lbl.modulate = Color(0.70, 0.30, 0.95, 0.55)
				var fill := locked_zone.get_node_or_null("Fill")
				if fill:
					fill.color = Color(0.28, 0.04, 0.50, 0.22)

	## ── Sacrifice extraction ─────────────────────────────────────────────────
	if sacrifice_zone != null and is_instance_valid(sacrifice_zone) and _can_sacrifice():
		var in_zone: bool = ppos.distance_to(sacrifice_zone.global_position) <= 44.0
		if in_zone and not _sacrifice_ui_open and not ExtractionManager.is_channeling:
			if _has_sacrifice_items():
				_open_sacrifice_ui()

## ── Guardian health bar broadcast ────────────────────────────────────────────

func _tick_guardian_health_bar() -> void:
	if guardian_enemy != null and is_instance_valid(guardian_enemy):
		var dist: float = player.global_position.distance_to(guardian_enemy.global_position)
		var show: bool = dist <= 220.0
		GameManager.guardian_state_changed.emit(
			guardian_enemy.hp, guardian_enemy.max_hp, show)
	else:
		GameManager.guardian_state_changed.emit(0.0, 1.0, false)

## ── Debug: activate all extractions ─────────────────────────────────────────

func debug_activate_all_extractions() -> void:
	_debug_all_extractions_active = true
	## Activate guarded if not already
	if guarded_state == "inactive":
		_activate_guarded_extraction()
	## Activate sacrifice
	_activate_sacrifice_extraction()
	## Give player a keystone for locked testing
	if not GameManager.player_has_keystone:
		GameManager.pickup_keystone()

# ═══════════════════════════════════════════════════════════════════════════════
# SACRIFICE UI
# ═══════════════════════════════════════════════════════════════════════════════

func _open_sacrifice_ui() -> void:
	if _sacrifice_ui_open:
		return
	_sacrifice_ui_open = true
	GameManager.set_paused(true)

	_sacrifice_layer = CanvasLayer.new()
	_sacrifice_layer.layer = 60
	_sacrifice_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sacrifice_layer)

	var panel := _build_sacrifice_panel()
	_sacrifice_layer.add_child(panel)

func _close_sacrifice_ui() -> void:
	_sacrifice_ui_open = false
	GameManager.set_paused(false)
	if _sacrifice_layer:
		_sacrifice_layer.queue_free()
		_sacrifice_layer = null

func _build_sacrifice_panel() -> Control:
	const PIXEL_FONT_PATH := "res://assets/fonts/m5x7.ttf"
	const PANEL_W: float = 270.0
	const PANEL_H: float = 220.0
	const VW: float = 480.0
	const VH: float = 270.0

	## Dark background overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.size = Vector2(VW, VH)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS

	var panel := Panel.new()
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.position = Vector2((VW - PANEL_W) * 0.5, (VH - PANEL_H) * 0.5)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.055, 0.07, 0.97)
	style.border_color = Color(0.75, 0.08, 0.10)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)

	## Title bar
	var title_bg := ColorRect.new()
	title_bg.color = Color(0.35, 0.04, 0.05)
	title_bg.size = Vector2(PANEL_W, 22.0)
	panel.add_child(title_bg)

	var pixel_font = load(PIXEL_FONT_PATH) if ResourceLoader.exists(PIXEL_FONT_PATH) else null

	var title_lbl := Label.new()
	title_lbl.text = "SACRIFICE EXTRACTION"
	title_lbl.position = Vector2(8.0, 4.0)
	if pixel_font:
		title_lbl.add_theme_font_override("font", pixel_font)
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.28, 0.28))
	panel.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Choose one item to destroy. Extraction is instant."
	sub_lbl.position = Vector2(8.0, 26.0)
	if pixel_font:
		sub_lbl.add_theme_font_override("font", pixel_font)
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.55))
	sub_lbl.size = Vector2(PANEL_W - 16.0, 16.0)
	panel.add_child(sub_lbl)

	## Scrollable list area
	const LIST_Y: float = 46.0
	const LIST_H: float = 140.0
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(6.0, LIST_Y)
	scroll.size = Vector2(PANEL_W - 12.0, LIST_H)
	scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(PANEL_W - 16.0, 0.0)
	vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(vbox)

	## --- Weapons ---
	for weapon_id in GameManager.collected_weapons:
		var row := _build_sacrifice_row(weapon_id, weapon_id, pixel_font)
		vbox.add_child(row)

	## --- Mods ---
	for mod_id in GameManager.collected_mods:
		var mod_name: String = ModData.ALL.get(mod_id, {}).get("name", mod_id)
		var row := _build_sacrifice_row(mod_name + " (mod)", "mod_" + mod_id, pixel_font)
		vbox.add_child(row)

	## --- Generic loot fallback ---
	if GameManager.collected_weapons.is_empty() and GameManager.collected_mods.is_empty() and GameManager.loot_carried > 0.0:
		var row := _build_sacrifice_row("All resources  (%d)" % int(GameManager.loot_carried), "all_loot", pixel_font)
		vbox.add_child(row)

	if vbox.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "Nothing to sacrifice."
		if pixel_font:
			empty.add_theme_font_override("font", pixel_font)
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.50, 0.50, 0.55))
		vbox.add_child(empty)

	## Cancel button
	var sep := ColorRect.new()
	sep.color = Color(0.28, 0.06, 0.06)
	sep.size = Vector2(PANEL_W, 1.0)
	sep.position = Vector2(0.0, LIST_Y + LIST_H + 4.0)
	panel.add_child(sep)

	var cancel_btn := Button.new()
	cancel_btn.text = "CANCEL — walk away"
	cancel_btn.size = Vector2(PANEL_W - 16.0, 20.0)
	cancel_btn.position = Vector2(8.0, PANEL_H - 26.0)
	cancel_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	if pixel_font:
		cancel_btn.add_theme_font_override("font", pixel_font)
	cancel_btn.add_theme_font_size_override("font_size", 11)
	cancel_btn.add_theme_color_override("font_color", Color(0.60, 0.55, 0.55))
	cancel_btn.pressed.connect(_close_sacrifice_ui)
	panel.add_child(cancel_btn)

	overlay.add_child(panel)
	return overlay

func _build_sacrifice_row(display_text: String, item_key: String, pixel_font) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_lbl := Label.new()
	name_lbl.text = display_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if pixel_font:
		name_lbl.add_theme_font_override("font", pixel_font)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.78))
	row.add_child(name_lbl)

	var btn := Button.new()
	btn.text = "SACRIFICE"
	btn.custom_minimum_size = Vector2(80.0, 18.0)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	if pixel_font:
		btn.add_theme_font_override("font", pixel_font)
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", Color(0.95, 0.28, 0.28))
	var cap_key: String = item_key
	btn.pressed.connect(func(): _on_sacrifice_item_selected(cap_key))
	row.add_child(btn)

	return row

func _on_sacrifice_item_selected(item_key: String) -> void:
	## Remove the item from carried loot
	if item_key == "all_loot":
		GameManager.sacrifice_all_loot()
	elif item_key.begins_with("mod_"):
		var mod_id: String = item_key.substr(4)
		GameManager.sacrifice_mod(mod_id)
	else:
		## It's a weapon ID
		GameManager.sacrifice_weapon(item_key)

	_close_sacrifice_ui()
	GameManager.active_extraction_type = "sacrifice"
	## Instant extraction — no channel needed
	GameManager.on_extraction_complete()

# ═══════════════════════════════════════════════════════════════════════════════
# TIMED EXTRACTION SPAWN (existing logic, now below new methods)
# ═══════════════════════════════════════════════════════════════════════════════

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

		## Mod drops: Elites 20%, Carriers 30% (checked before generic loot)
		var is_carrier: bool = victim.get_script() != null and \
			victim.get_script().resource_path == "res://scripts/entities/enemy_carrier.gd"
		var is_elite: bool   = victim.get("is_elite") == true

		## Keystone drop from elites: 5% chance (only if player doesn't already have one)
		if is_elite and not GameManager.player_has_keystone and randf() < 0.05:
			_spawn_keystone_drop(victim.global_position)

		if is_carrier and randf() < 0.30:
			_spawn_mod_drop(victim.global_position)
			return
		if is_elite and randf() < 0.20:
			_spawn_mod_drop(victim.global_position)
			return

		## 8% chance to drop loot — rarer drops feel more exciting
		if randf() < 0.08:
			_spawn_loot_drop(victim.global_position)
		## 2% chance to drop a weapon — rare and exciting
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
