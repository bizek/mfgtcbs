extends Node

## GameManager — Game state machine, phase transitions, run lifecycle

## Debug mode — set true during development, false before shipping.
## Enables F1 panel, F2/F3/F4 hotkeys, and the debug_* helper methods.
var debug_mode: bool = true

signal run_started
signal phase_started(phase_number: int)
signal phase_timer_updated(time_remaining: float)
signal extraction_window_opened
signal extraction_window_closed
signal player_died
signal extraction_successful
signal game_paused
signal game_unpaused
signal loot_changed(new_value: float)
signal instability_changed(new_value: float)

enum GameState {
	MENU,
	RUN_ACTIVE,
	LEVEL_UP,
	EXTRACTING,
	GAME_OVER,
	EXTRACTION_SUCCESS
}

var current_state: GameState = GameState.MENU
var phase_number: int = 1
var phase_timer: float = 0.0
var phase_duration: float = 180.0 ## 3 minutes for prototype single phase
var extraction_window_timer: float = 0.0
var extraction_window_duration: float = 18.0 ## Portal stays open 18 seconds
var extraction_window_active: bool = false
var run_time: float = 0.0
var kills: int = 0
var is_paused: bool = false

## Difficulty scaling — time-based for prototype
var difficulty_multiplier: float = 1.0

## Loot and instability
var loot_carried: float = 0.0
var instability: float = 0.0
var last_run_loot: float = 0.0  ## Preserved after extraction clears loot_carried

## Weapons picked up during this run. Cleared on new run; unlocked in ProgressionManager
## on successful extraction. Lost on death (same risk as other loot).
var collected_weapons: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if current_state != GameState.RUN_ACTIVE:
		return
	
	run_time += delta
	phase_timer += delta
	
	## Update difficulty over time (scales every 30 seconds)
	difficulty_multiplier = 1.0 + (run_time / 30.0) * 0.15
	
	## Check if phase timer reached duration — open extraction window
	if phase_timer >= phase_duration and not extraction_window_active:
		_open_extraction_window()
	
	## Count down extraction window
	if extraction_window_active:
		extraction_window_timer -= delta
		if extraction_window_timer <= 0.0:
			_close_extraction_window()

func start_run() -> void:
	ExtractionManager.reset()
	current_state = GameState.RUN_ACTIVE
	phase_number = 1
	phase_timer = 0.0
	run_time = 0.0
	kills = 0
	difficulty_multiplier = 1.0
	extraction_window_active = false
	is_paused = false
	loot_carried = 0.0
	instability = 0.0
	collected_weapons.clear()
	run_started.emit()
	phase_started.emit(phase_number)

func register_kill() -> void:
	kills += 1

func set_paused(paused: bool) -> void:
	if paused == is_paused:
		return
	is_paused = paused
	get_tree().paused = paused
	if paused:
		game_paused.emit()
	else:
		game_unpaused.emit()

func enter_level_up() -> void:
	current_state = GameState.LEVEL_UP
	set_paused(true)

func exit_level_up() -> void:
	current_state = GameState.RUN_ACTIVE
	set_paused(false)

func on_player_died() -> void:
	current_state = GameState.GAME_OVER
	player_died.emit()

func on_extraction_complete() -> void:
	current_state = GameState.EXTRACTION_SUCCESS
	## Preserve loot value for results screen before clearing
	last_run_loot = loot_carried
	loot_carried = 0.0
	instability = 0.0
	loot_changed.emit(loot_carried)
	instability_changed.emit(instability)
	## Unlock all weapons collected this run
	for weapon_id in collected_weapons:
		ProgressionManager.add_weapon(weapon_id)
	extraction_successful.emit()

func add_loot(value: float) -> void:
	loot_carried += value
	instability = loot_carried  ## Simplified: instability tracks total loot value carried
	loot_changed.emit(loot_carried)
	instability_changed.emit(instability)

## Called when the player picks up a weapon drop during a run.
## Weapon is at risk until extraction — lost on death, unlocked on success.
func add_collected_weapon(weapon_id: String) -> void:
	if weapon_id not in collected_weapons:
		collected_weapons.append(weapon_id)
	## Weapon pickups contribute 30 instability (meaningful risk weight)
	add_loot(30.0)

## Returns enemy HP/damage multiplier based on instability tier.
## Tiers: Stable(0-30)=×1.0, Unsettled(31-70)=×1.15, Volatile(71-120)=×1.3, Critical(121+)=×1.5
func get_instability_multiplier() -> float:
	if instability <= 30.0:
		return 1.0
	elif instability <= 70.0:
		return 1.15
	elif instability <= 120.0:
		return 1.3
	else:
		return 1.5

func _open_extraction_window() -> void:
	extraction_window_active = true
	extraction_window_timer = extraction_window_duration
	extraction_window_opened.emit()

func _close_extraction_window() -> void:
	extraction_window_active = false
	extraction_window_closed.emit()
	## After window closes, keep spawning — no more extraction until player dies

## Debug helpers — only called from DebugPanel when debug_mode is true.
func debug_open_extraction() -> void:
	if extraction_window_active or current_state != GameState.RUN_ACTIVE:
		return
	phase_timer = phase_duration  ## Snap phase timer so window stays open
	_open_extraction_window()
