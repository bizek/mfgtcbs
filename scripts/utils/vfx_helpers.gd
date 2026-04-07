class_name VFXHelpers

## VFXHelpers — Static utility methods for common visual effects.
## Avoids duplicating particle burst and expanding ring code across files.

## Creates a one-shot burst of particles at the given position and adds it to the scene.
## Auto-frees after the particles finish.
static func spawn_burst(
		scene_root: Node,
		pos: Vector2,
		color: Color,
		amount: int = 12,
		lifetime: float = 0.35,
		speed_min: float = 40.0,
		speed_max: float = 100.0,
		scale_min: float = 2.0,
		scale_max: float = 5.0,
		gravity: Vector2 = Vector2(0.0, -10.0)
	) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.gravity = gravity
	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max
	p.color = color
	scene_root.add_child(p)
	p.emitting = true
	## Auto-cleanup after particles finish
	scene_root.get_tree().create_timer(lifetime + 0.5).timeout.connect(
		func(): if is_instance_valid(p): p.queue_free()
	)
	return p

## Creates an expanding ring that fades out — used for death bursts, explosions, void blasts.
static func spawn_expanding_ring(
		scene_root: Node,
		pos: Vector2,
		color: Color,
		radius: float = 24.0,
		expand_scale: float = 1.5,
		duration: float = 0.25
	) -> void:
	var ring := ColorRect.new()
	ring.color = color
	ring.size = Vector2(radius * 2.0, radius * 2.0)
	ring.position = pos - Vector2(radius, radius)
	scene_root.add_child(ring)
	var t := ring.create_tween()
	t.tween_property(ring, "scale", Vector2(expand_scale, expand_scale), duration).set_trans(Tween.TRANS_EXPO)
	t.parallel().tween_property(ring, "modulate:a", 0.0, duration)
	t.tween_callback(ring.queue_free)
