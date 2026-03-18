extends Node

## ExtractionManager — Timed extraction point state and channeling

signal extraction_point_spawned(position: Vector2)
signal extraction_channel_started
signal extraction_channel_progress(percent: float)
signal extraction_complete
signal extraction_interrupted

var extraction_point: Node2D = null
var is_channeling: bool = false
var channel_timer: float = 0.0
var channel_duration: float = 4.0 ## 4 seconds to extract
var extraction_speed_multiplier: float = 1.0

func _process(delta: float) -> void:
	if not is_channeling:
		return
	if GameManager.current_state != GameManager.GameState.RUN_ACTIVE:
		return
	
	channel_timer += delta * extraction_speed_multiplier
	var percent: float = channel_timer / channel_duration
	extraction_channel_progress.emit(percent)
	
	if channel_timer >= channel_duration:
		_complete_extraction()

func start_channel(speed_multiplier: float = 1.0) -> void:
	if is_channeling:
		return
	is_channeling = true
	channel_timer = 0.0
	extraction_speed_multiplier = speed_multiplier
	extraction_channel_started.emit()

func interrupt_channel() -> void:
	if not is_channeling:
		return
	is_channeling = false
	channel_timer = 0.0
	extraction_interrupted.emit()

func _complete_extraction() -> void:
	is_channeling = false
	channel_timer = 0.0
	extraction_complete.emit()
	GameManager.on_extraction_complete()

func reset() -> void:
	is_channeling = false
	channel_timer = 0.0
	extraction_point = null
