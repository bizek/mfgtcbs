class_name PlayerVfxHelper
extends RefCounted
## Stateless weapon visual feedback routines extracted from player.gd.
## All methods are static — no instance required.
## owner: any Node (used as tween host and tree accessor).
## scene_root: receives the spawned visual nodes.


static func spawn_beam_flash(owner: Node, scene_root: Node, from: Vector2, to: Vector2, tint: Color) -> void:
	var line := Line2D.new()
	line.top_level     = true
	line.default_color = Color(tint.r, tint.g, tint.b, 0.92)
	line.width         = 3.5
	line.add_point(from)
	line.add_point(to)

	var glow := Line2D.new()
	glow.top_level     = true
	glow.default_color = Color(tint.r, tint.g, tint.b, 0.22)
	glow.width         = 7.0
	glow.add_point(from)
	glow.add_point(to)

	scene_root.add_child(glow)
	scene_root.add_child(line)

	var t := owner.create_tween()
	t.tween_property(line, "modulate:a", 0.0, 0.06)
	t.tween_callback(line.queue_free)
	var t2 := owner.create_tween()
	t2.tween_property(glow, "modulate:a", 0.0, 0.06)
	t2.tween_callback(glow.queue_free)


static func spawn_melee_arc(owner: Node, scene_root: Node, center: Vector2, angle: float, range_px: float, arc_half: float, tint: Color) -> void:
	const SEGMENTS: int = 12

	var points: PackedVector2Array = []
	points.append(Vector2.ZERO)
	for i in range(SEGMENTS + 1):
		var a: float = angle - arc_half + (float(i) / float(SEGMENTS)) * arc_half * 2.0
		points.append(Vector2(cos(a), sin(a)) * range_px)

	var poly := Polygon2D.new()
	poly.polygon         = points
	poly.color           = Color(tint.r, tint.g, tint.b, 0.48)
	poly.global_position = center
	scene_root.add_child(poly)

	var edge := Line2D.new()
	edge.top_level     = true
	edge.width         = 3.0
	edge.default_color = Color(tint.r, tint.g, tint.b, 0.85)
	for i in range(SEGMENTS + 1):
		var a: float = angle - arc_half + (float(i) / float(SEGMENTS)) * arc_half * 2.0
		edge.add_point(center + Vector2(cos(a), sin(a)) * range_px)
	scene_root.add_child(edge)

	var t := owner.create_tween()
	t.tween_property(poly, "modulate:a", 0.0, 0.13)
	t.tween_callback(poly.queue_free)
	var t2 := owner.create_tween()
	t2.tween_property(edge, "modulate:a", 0.0, 0.13)
	t2.tween_callback(edge.queue_free)


static func spawn_artillery_marker(owner: Node, scene_root: Node, pos: Vector2, radius: float, fuse: float, tint: Color) -> void:
	var marker := Node2D.new()
	marker.global_position = pos
	scene_root.add_child(marker)

	var preview := ColorRect.new()
	preview.color    = Color(tint.r, tint.g, tint.b, 0.18)
	preview.size     = Vector2(radius * 2.0, radius * 2.0)
	preview.position = Vector2(-radius, -radius)
	marker.add_child(preview)

	# Border: 4 edge rects
	var bd: float  = radius * 2.0
	var bt: float  = 2.0
	var bc: Color  = Color(tint.r, tint.g, tint.b, 0.72)
	var border_rects: Array = [
		[Vector2(bd, bt),  Vector2(-radius, -radius)],
		[Vector2(bd, bt),  Vector2(-radius, radius - bt)],
		[Vector2(bt, bd),  Vector2(-radius, -radius)],
		[Vector2(bt, bd),  Vector2(radius - bt, -radius)],
	]
	for rect_data in border_rects:
		var b := ColorRect.new()
		b.color    = bc
		b.size     = rect_data[0]
		b.position = rect_data[1]
		marker.add_child(b)

	var dot := ColorRect.new()
	dot.color    = Color(tint.r + 0.3, tint.g + 0.1, tint.b + 0.3, 1.0)
	dot.size     = Vector2(7.0, 7.0)
	dot.position = Vector2(-3.5, -3.5)
	marker.add_child(dot)

	var warn := owner.create_tween().set_loops(int(fuse * 6.0))
	warn.tween_property(preview, "modulate:a", 0.15, fuse / 12.0)
	warn.tween_property(preview, "modulate:a", 1.0,  fuse / 12.0)

	owner.get_tree().create_timer(fuse).timeout.connect(func():
		if is_instance_valid(marker):
			spawn_artillery_burst(owner, scene_root, pos, radius, tint)
			marker.queue_free()
	)


static func spawn_artillery_burst(owner: Node, scene_root: Node, pos: Vector2, radius: float, tint: Color) -> void:
	var ring := ColorRect.new()
	ring.color    = Color(tint.r, tint.g, tint.b, 0.55)
	ring.size     = Vector2(radius * 2.0, radius * 2.0)
	ring.position = pos - Vector2(radius, radius)
	scene_root.add_child(ring)

	var rt := owner.create_tween()
	rt.tween_property(ring, "scale", Vector2(1.5, 1.5), 0.22).set_trans(Tween.TRANS_EXPO)
	rt.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
	rt.tween_callback(ring.queue_free)

	var particles := CPUParticles2D.new()
	particles.global_position      = pos
	particles.amount               = 20
	particles.lifetime             = 0.6
	particles.one_shot             = true
	particles.explosiveness        = 0.95
	particles.direction            = Vector2.ZERO
	particles.spread               = 180.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 200.0
	particles.gravity              = Vector2.ZERO
	particles.scale_amount_min     = 3.0
	particles.scale_amount_max     = 8.0
	particles.color                = tint
	scene_root.add_child(particles)
	particles.emitting = true
	owner.get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(particles): particles.queue_free()
	)
