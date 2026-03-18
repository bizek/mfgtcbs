extends Node2D

## DamageNumber — Floating text showing damage dealt, rises and fades out

func setup(damage: float, is_crit: bool, spawn_pos: Vector2) -> void:
	global_position = spawn_pos + Vector2(randf_range(-8.0, 8.0), -12.0)
	z_index = 10

	var label := Label.new()
	label.text = str(int(damage))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-24.0, -8.0)

	if is_crit:
		label.modulate = Color(1.0, 0.9, 0.1, 1.0)
		label.add_theme_font_size_override("font_size", 14)
	else:
		label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		label.add_theme_font_size_override("font_size", 9)

	add_child(label)

	## Float upward
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", global_position + Vector2(0.0, -28.0), 0.75)
	tween.tween_property(label, "modulate:a", 0.0, 0.75).set_delay(0.25)

	## Auto-free after animation
	await get_tree().create_timer(0.85).timeout
	if is_instance_valid(self):
		queue_free()
