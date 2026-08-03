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
## Latched on completion until the next run. The player is still standing in
## the zone during GameManager's post-extraction fanfare delay, and every zone
## type would happily restart the channel in that window — a channel that can
## never finish once the state leaves RUN_ACTIVE, leaving the channel-hum loop
## playing across the success screen and the whole next run.
var _completed_this_run: bool = false

func _ready() -> void:
	GameManager.run_started.connect(reset)
	## Any lost run, not just a death — abandoning mid-channel must not carry a live channel forward.
	GameManager.run_failed.connect(func(_abandoned: bool): interrupt_channel())

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
	if is_channeling or _completed_this_run:
		return
	if not GameManager.is_extraction_allowed():
		return
	is_channeling = true
	channel_timer = 0.0
	extraction_speed_multiplier = speed_multiplier
	extraction_channel_started.emit()

## Extract IMMEDIATELY, with no channel — the gateway portal's exit (Ben 2026-08-02: "soon as
## the player touches the actual portal, it should be loading screen back to hub").
##
## Every other extraction in the game channels for 4 seconds. This one deliberately does not:
## the gateway opens across the block and the run to reach it through the horde IS the tension.
## A channel on top would be a second tax on a player who has already made the hard part.
##
## Carries the same guards as start_channel() — a completed run can't re-extract, and the
## final-boss gate still applies. Returns false when refused so the caller can stay quiet.
func extract_now() -> bool:
	if _completed_this_run:
		return false
	if not GameManager.is_extraction_allowed():
		return false
	is_channeling = false
	channel_timer = 0.0
	_completed_this_run = true
	extraction_complete.emit()
	return true


func interrupt_channel() -> void:
	if not is_channeling:
		return
	is_channeling = false
	channel_timer = 0.0
	extraction_interrupted.emit()

func _complete_extraction() -> void:
	is_channeling = false
	channel_timer = 0.0
	_completed_this_run = true
	extraction_complete.emit()

func reset() -> void:
	is_channeling = false
	channel_timer = 0.0
	channel_duration = 4.0
	extraction_point = null
	_completed_this_run = false
