class_name LdtkExitZone
extends Area2D

## LdtkExitZone — proximity-triggered exit marker for LDtk levels.
##
## Spawned by MainArena when loading a level via LdtkLoader.
## Calls ExtractionManager.start_channel() when the player stands inside the
## activation radius. The existing extraction-complete flow handles the rest.
##
## Usage:
##   var exit := LdtkExitZone.new()
##   add_child(exit)
##   exit.setup(result.level_exit_pos, result.boss_id == "")

const ACTIVATE_RADIUS: float = 48.0

var _unlocked: bool = false
var _channeling: bool = false


func setup(pos: Vector2, unlock_immediately: bool) -> void:
	global_position = pos
	collision_layer = 0
	collision_mask = 1  ## Detect player (layer 1)
	_unlocked = unlock_immediately
	_build_visuals()
	if unlock_immediately:
		_show_unlocked()


func unlock() -> void:
	if _unlocked:
		return
	_unlocked = true
	_show_unlocked()


func _build_visuals() -> void:
	## Circle shape for proximity detection.
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = ACTIVATE_RADIUS
	col.shape = shape
	add_child(col)

	## Text label visible in-game.
	var lbl := Label.new()
	lbl.name = "ExitLabel"
	lbl.text = "EXIT"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-24.0, -28.0)
	lbl.modulate.a = 0.4  ## Dimmed until unlocked
	add_child(lbl)

	## Visible circle (drawn via the area itself).
	set_modulate(Color(1.0, 0.85, 0.2, 0.4))


func _show_unlocked() -> void:
	var lbl: Label = get_node_or_null("ExitLabel")
	if lbl:
		lbl.modulate.a = 1.0
	set_modulate(Color(1.0, 0.85, 0.2, 1.0))


func _process(_delta: float) -> void:
	if not _unlocked:
		return
	if GameManager.current_state != GameManager.GameState.RUN_ACTIVE:
		return

	var bodies: Array[Node2D] = get_overlapping_bodies()
	var player_inside: bool = false
	for b in bodies:
		if b.is_in_group("player"):
			player_inside = true
			break

	if player_inside and not _channeling and not ExtractionManager.is_channeling:
		_channeling = true
		GameManager.open_extraction_window_immediate()
		ExtractionManager.start_channel()
	elif not player_inside and _channeling:
		_channeling = false
		## Don't interrupt — ExtractionManager handles that via its own proximity check.

	## Reset flag when channel ends (complete or interrupt).
	if _channeling and not ExtractionManager.is_channeling:
		_channeling = false
