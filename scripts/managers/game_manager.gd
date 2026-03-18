extends Node

## GameManager — Game state machine, phase transitions, run lifecycle

signal run_started
signal phase_started(phase_number: int)
signal phase_timer_updated(time_remaining: float)
signal extraction_window_opened
signal extraction_window_closed
signal player_died
signal extraction_successful
signal game_paused
signal game_unpaused

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
	extraction_successful.emit()

func _open_extraction_window() -> void:
	extraction_window_active = true
	extraction_window_timer = extraction_window_duration
	extraction_window_opened.emit()

func _close_extraction_window() -> void:
	extraction_window_active = false
	extraction_window_closed.emit()
	## After window closes, keep spawning — no more extraction until player dies
