extends ExtractionZoneBase
class_name GuardedExtraction

## GuardedExtraction — Kill the guardian to open a 25-second extraction window.
## Guardian respawns 45 seconds after the window closes. Activates at phase 3+.

signal guardian_health_updated(hp: float, max_hp: float, show_bar: bool)

const WINDOW_DURATION: float = 25.0
const RESPAWN_DELAY: float = 45.0

## States: "inactive" | "guarded" | "active" | "respawning"
var state: String = "inactive"
var guardian_enemy: Node2D = null
var spawn_count: int = 0
var _window_timer: float = 0.0
var _respawn_timer: float = 0.0
var _active_pulse: Tween = null

func _init() -> void:
	extraction_type = "guarded"
	name = "GuardedExtraction"

## ── Setup ────────────────────────────────────────────────────────────────────

func build_zone(pos: Vector2) -> void:
	global_position = pos
	_build_fill(self, Color(0.50, 0.05, 0.05, 0.18))
	_build_border(self, Color(0.75, 0.10, 0.10, 0.45))
	_build_state_label(self, "GUARDED", Color(0.80, 0.20, 0.15, 0.55))

func activate() -> void:
	state = "guarded"
	_spawn_guardian()

## ── Process (called by main_arena) ──────────────────────────────────────────

func tick(delta: float, player_pos: Vector2) -> void:
	if state == "active":
		_window_timer -= delta
		_update_label()
		if _window_timer <= 0.0:
			_close_window()

	if state == "respawning":
		_respawn_timer -= delta
		_update_label()
		if _respawn_timer <= 0.0:
			_respawn_guardian()

	## Broadcast guardian HP for HUD bar
	_tick_guardian_health(player_pos)

## ── Proximity handling ───────────────────────────────────────────────────────

func try_start_channel(player_pos: Vector2) -> bool:
	if state != "active":
		return false
	if not check_proximity(player_pos):
		return false
	if ExtractionManager.is_channeling:
		return false
	GameManager.active_extraction_type = "guarded"
	ExtractionManager.channel_duration = ProgressionManager.get_channel_duration()
	ExtractionManager.start_channel(1.0)
	return true

func try_interrupt_channel(player_pos: Vector2) -> bool:
	if not check_proximity(player_pos):
		ExtractionManager.interrupt_channel()
		return true
	return false

## ── Guardian lifecycle ───────────────────────────────────────────────────────

func _spawn_guardian() -> void:
	if guardian_enemy != null and is_instance_valid(guardian_enemy):
		return

	var GuardianScript = load("res://scripts/entities/enemy_guardian.gd")
	if GuardianScript == null:
		push_error("GuardedExtraction: enemy_guardian.gd not found")
		return

	var g: CharacterBody2D = CharacterBody2D.new()
	g.set_script(GuardianScript)
	g.phase_multiplier = float(GameManager.phase_number)
	g.spawn_count = spawn_count
	g.global_position = global_position
	EnemySpawnManager.active_enemies += 1
	g.guardian_killed.connect(_on_guardian_killed)
	get_tree().current_scene.add_child(g)
	guardian_enemy = g
	_update_label()

func _on_guardian_killed() -> void:
	guardian_enemy = null
	spawn_count += 1
	_open_window()

func _open_window() -> void:
	state = "active"
	active = true
	_window_timer = WINDOW_DURATION
	_update_label()

	## Bright green fill
	if _fill:
		_fill.color = Color(0.0, 0.88, 0.28, 0.55)

	## Pulse
	_active_pulse = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_active_pulse.tween_property(self, "scale", Vector2(1.06, 1.06), 0.5)
	_active_pulse.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5)

func _close_window() -> void:
	state = "respawning"
	active = false
	_respawn_timer = RESPAWN_DELAY

	if _active_pulse:
		_active_pulse.kill()
		_active_pulse = null
	scale = Vector2(1.0, 1.0)

	## Interrupt if player was channeling this
	if ExtractionManager.is_channeling:
		ExtractionManager.interrupt_channel()

	## Reset fill to dim
	if _fill:
		_fill.color = Color(0.50, 0.05, 0.05, 0.18)

	_update_label()

func _respawn_guardian() -> void:
	state = "guarded"
	_spawn_guardian()
	_update_label()

## ── Guardian health broadcast ────────────────────────────────────────────────

func _tick_guardian_health(player_pos: Vector2) -> void:
	if guardian_enemy != null and is_instance_valid(guardian_enemy):
		var dist: float = player_pos.distance_to(guardian_enemy.global_position)
		var show: bool = dist <= 220.0
		guardian_health_updated.emit(guardian_enemy.hp, guardian_enemy.max_hp, show)
	else:
		guardian_health_updated.emit(0.0, 1.0, false)

## ── Label updates ────────────────────────────────────────────────────────────

func _update_label() -> void:
	if _state_label == null:
		return
	match state:
		"inactive":
			_state_label.text = "GUARDED (PHASE 3+)"
			_state_label.modulate = Color(0.60, 0.18, 0.15, 0.40)
		"guarded":
			_state_label.text = "GUARDED"
			_state_label.modulate = Color(0.85, 0.20, 0.15, 0.60)
		"active":
			var t: int = int(ceilf(_window_timer))
			_state_label.text = "EXTRACT  %ds" % t
			_state_label.modulate = Color(0.15, 1.0, 0.5, 1.0)
		"respawning":
			var t: int = int(ceilf(_respawn_timer))
			_state_label.text = "RESPAWNING  %ds" % t
			_state_label.modulate = Color(0.80, 0.50, 0.15, 0.70)
