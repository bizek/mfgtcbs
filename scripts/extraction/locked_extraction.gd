extends ExtractionZoneBase
class_name LockedExtraction

## LockedExtraction — Requires a keystone to unlock. Fast 2-second channel.
## Keystone is refunded if channel is interrupted. Activates at phase 3+.

var _channeling: bool = false

func _init() -> void:
	extraction_type = "locked"
	name = "LockedExtraction"

## ── Setup ────────────────────────────────────────────────────────────────────

func build_zone(pos: Vector2) -> void:
	global_position = pos

	## Dark purple fill
	_build_fill(self, Color(0.28, 0.04, 0.50, 0.22))

	## Thick purple border
	_build_border(self, Color(0.55, 0.15, 0.80, 0.55), 4.0)

	## Chain bars
	for i in range(3):
		var bar := ColorRect.new()
		bar.color = Color(0.45, 0.10, 0.65, 0.55)
		bar.size = Vector2(80.0, 3.0)
		bar.position = Vector2(-40.0, -18.0 + i * 18.0)
		bar.rotation = deg_to_rad(28.0 + i * 6.0)
		add_child(bar)

	## State label
	_build_state_label(self, "LOCKED  [need KEY]", Color(0.70, 0.30, 0.95, 0.55), -62.0)

## ── Proximity handling ───────────────────────────────────────────────────────

func try_start_channel(player_pos: Vector2) -> bool:
	if not check_proximity(player_pos):
		return false
	if not GameManager.player_has_keystone:
		return false
	if ExtractionManager.is_channeling or _channeling:
		return false
	if GameManager.current_state != GameManager.GameState.RUN_ACTIVE:
		return false
	if not GameManager.is_extraction_allowed():
		return false

	_channeling = true
	GameManager.player_has_keystone = false
	GameManager.active_extraction_type = "locked"
	ExtractionManager.channel_duration = 2.0
	ExtractionManager.start_channel(1.0)

	## Update label to "UNLOCKING..."
	if _state_label:
		_state_label.text = "UNLOCKING..."
		_state_label.modulate = Color(1.0, 0.88, 0.18, 1.0)
	if _fill:
		_fill.color = Color(0.82, 0.72, 0.08, 0.50)
	return true

func try_interrupt_channel(player_pos: Vector2) -> bool:
	if not check_proximity(player_pos):
		ExtractionManager.interrupt_channel()
		_channeling = false
		ExtractionManager.channel_duration = 4.0
		## Refund the keystone
		GameManager.player_has_keystone = true
		_reset_visuals()
		return true
	return false

func on_extraction_complete() -> void:
	_channeling = false

func on_extraction_interrupted() -> void:
	_channeling = false
	ExtractionManager.channel_duration = 4.0

func is_channeling() -> bool:
	return _channeling

## ── Visual reset ─────────────────────────────────────────────────────────────

func _reset_visuals() -> void:
	if _state_label:
		_state_label.text = "LOCKED  [need KEY]"
		_state_label.modulate = Color(0.70, 0.30, 0.95, 0.55)
	if _fill:
		_fill.color = Color(0.28, 0.04, 0.50, 0.22)
