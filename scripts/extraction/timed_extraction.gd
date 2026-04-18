extends ExtractionZoneBase
class_name TimedExtraction

## TimedExtraction — The default portal that opens after the phase timer expires.
## Supports Extraction Intel I (pre-spawn ghost at low opacity).

var _pulse_tween: Tween = null
var _window_open: bool = false

func _init() -> void:
	extraction_type = "timed"
	name = "TimedExtraction"

## ── Public API ───────────────────────────────────────────────────────────────

func spawn_zone(pos: Vector2) -> void:
	global_position = pos
	_build_visuals()

func spawn_ghost(pos: Vector2) -> void:
	## Extraction Intel I — show zone at low opacity before window opens
	spawn_zone(pos)
	modulate = Color(1.0, 1.0, 1.0, 0.28)

func open_window() -> void:
	_window_open = true
	active = true
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	_start_pulse()

func close_window() -> void:
	_window_open = false
	active = false
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	queue_free()

func is_window_open() -> bool:
	return _window_open

## ── Proximity handling ───────────────────────────────────────────────────────

func try_start_channel(player_pos: Vector2) -> bool:
	if not active or not _window_open:
		return false
	if not check_proximity(player_pos):
		return false
	if ExtractionManager.is_channeling:
		return false
	if not GameManager.is_extraction_allowed():
		return false
	GameManager.active_extraction_type = "timed"
	ExtractionManager.channel_duration = ProgressionManager.get_channel_duration()
	ExtractionManager.start_channel(1.0)
	return true

func try_interrupt_channel(player_pos: Vector2) -> bool:
	if not check_proximity(player_pos):
		ExtractionManager.interrupt_channel()
		return true
	return false

## ── Visuals ──────────────────────────────────────────────────────────────────

func _build_visuals() -> void:
	## Far outer beacon
	var beacon := ColorRect.new()
	beacon.name = "BeaconRing"
	beacon.color = Color(0.0, 1.0, 0.35, 0.1)
	beacon.size = Vector2(200.0, 200.0)
	beacon.position = Vector2(-100.0, -100.0)
	add_child(beacon)

	## Outer glow
	var outer := ColorRect.new()
	outer.name = "OuterGlow"
	outer.color = Color(0.0, 1.0, 0.35, 0.28)
	outer.size = Vector2(160.0, 160.0)
	outer.position = Vector2(-80.0, -80.0)
	add_child(outer)

	## Inner fill
	_build_fill(self, Color(0.0, 0.88, 0.28, 0.55))

	## Border
	_build_border(self, Color(0.1, 1.0, 0.5, 1.0), 4.0)

	## Label
	var label := Label.new()
	label.name = "Label"
	label.text = "EXTRACT HERE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-64.0, -96.0)
	label.modulate = Color(0.15, 1.0, 0.5, 1.0)
	var font_settings := LabelSettings.new()
	font_settings.font = load("res://assets/fonts/m5x7.ttf")
	font_settings.font_size = 21
	font_settings.outline_size = 1
	font_settings.outline_color = Color(0.0, 0.0, 0.0, 0.9)
	label.label_settings = font_settings
	add_child(label)

	ExtractionManager.extraction_point = self

func _start_pulse() -> void:
	var fill_node := get_node_or_null("Fill")
	var outer := get_node_or_null("OuterGlow")
	var beacon := get_node_or_null("BeaconRing")
	var lbl := get_node_or_null("Label")

	## Fill heartbeat
	_pulse_tween = create_tween().set_loops()
	if fill_node:
		_pulse_tween.tween_property(fill_node, "modulate:a", 0.35, 0.55)
		_pulse_tween.tween_property(fill_node, "modulate:a", 1.0, 0.55)

	## Outer glow pulse
	if outer:
		var outer_tween := create_tween().set_loops()
		outer_tween.tween_property(outer, "modulate:a", 0.15, 0.8)
		outer_tween.tween_property(outer, "modulate:a", 1.0, 0.8)

	## Beacon ring
	if beacon:
		var beacon_tween := create_tween().set_loops()
		beacon_tween.tween_property(beacon, "modulate:a", 0.05, 1.2)
		beacon_tween.tween_property(beacon, "modulate:a", 0.7, 1.2)

	## Scale heartbeat
	var scale_tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	scale_tween.tween_property(self, "scale", Vector2(1.06, 1.06), 0.5)
	scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5)

	## Label bob
	if lbl:
		var lbl_tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		lbl_tween.tween_property(lbl, "position:y", -102.0, 0.8)
		lbl_tween.tween_property(lbl, "position:y", -96.0, 0.8)
