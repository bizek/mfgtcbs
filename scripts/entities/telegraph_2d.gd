class_name Telegraph2D
extends Node2D
## Single telegraph wind-up visual. Ad-hoc node (no pool). Spawned by
## TelegraphManager and parented to the current scene so it doesn't move
## with the caster unless configured to follow.

var shape: String = "circle"
var anchor: String = "target_position"
var radius: float = 40.0
var length: float = 120.0
var width: float = 20.0
var cone_angle_rad: float = 0.7853982
var base_color: Color = Color(1.0, 0.25, 0.20, 0.55)
var duration: float = 0.8
var fill_build_up: bool = true

var source: Node2D = null
var target: Node2D = null
var telegraph_id: String = ""

var elapsed: float = 0.0
## Direction the telegraph is facing (radians). For line/cone shapes the
## shape is drawn along +X in local space, so we set rotation directly.
var _facing: float = 0.0


func configure(effect: SpawnTelegraphEffect, src: Node2D, tgt: Node2D) -> void:
	shape = effect.shape
	anchor = effect.anchor
	radius = effect.radius
	length = effect.length
	width = effect.width
	cone_angle_rad = deg_to_rad(effect.cone_angle_deg)
	base_color = effect.color
	duration = max(effect.duration, 0.05)
	fill_build_up = effect.fill_build_up
	source = src
	target = tgt
	telegraph_id = effect.telegraph_id
	z_index = 1  ## draw above floor (0), below nothing — semi-transparency handles layering
	_update_transform()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	_update_transform()
	queue_redraw()


func _update_transform() -> void:
	match anchor:
		"target_position":
			if elapsed == 0.0 and is_instance_valid(target):
				global_position = target.global_position
		"target_follow":
			if is_instance_valid(target):
				global_position = target.global_position
		"source_position":
			if is_instance_valid(source):
				global_position = source.global_position
		"source_forward_line":
			if is_instance_valid(source):
				global_position = source.global_position
			if is_instance_valid(source) and is_instance_valid(target):
				_facing = (target.global_position - source.global_position).angle()
				rotation = _facing


func _draw() -> void:
	var progress: float = clamp(elapsed / duration, 0.0, 1.0)
	var fill_alpha_mult: float = progress if fill_build_up else 1.0

	## Flash pulse in last 0.12s to sell the hit moment
	var pulse: float = 1.0
	var flash_t: float = duration - elapsed
	if flash_t < 0.12:
		pulse = 1.0 + 0.6 * sin(flash_t * 50.0)

	var outline_color := Color(base_color.r, base_color.g, base_color.b, clamp(0.95 * pulse, 0.0, 1.0))
	var fill_color := Color(base_color.r, base_color.g, base_color.b, base_color.a * fill_alpha_mult * pulse)

	match shape:
		"circle":
			draw_circle(Vector2.ZERO, radius, fill_color)
			_draw_circle_outline(Vector2.ZERO, radius, outline_color, 2.0)
		"ring":
			_draw_ring(Vector2.ZERO, radius, 4.0, outline_color, fill_color)
		"line":
			_draw_line_rect(length, width, fill_color, outline_color)
		"cone":
			_draw_cone(length, cone_angle_rad, fill_color, outline_color)


func _draw_circle_outline(center: Vector2, r: float, color: Color, thickness: float) -> void:
	var segments: int = 32
	var prev := center + Vector2(r, 0)
	for i in range(1, segments + 1):
		var a: float = TAU * float(i) / float(segments)
		var next := center + Vector2(cos(a), sin(a)) * r
		draw_line(prev, next, color, thickness)
		prev = next


func _draw_ring(center: Vector2, r: float, band: float, outline: Color, fill: Color) -> void:
	## Outer filled disc minus inner disc (approximated via two circles + ring band).
	draw_arc(center, r + band * 0.5, 0.0, TAU, 40, outline, band, true)
	_draw_circle_outline(center, r, Color(outline.r, outline.g, outline.b, outline.a * 0.5), 1.5)
	## Subtle inner fill halo
	var halo := Color(fill.r, fill.g, fill.b, fill.a * 0.25)
	draw_circle(center, r + band * 0.5, halo)


func _draw_line_rect(len: float, w: float, fill: Color, outline: Color) -> void:
	## Rect extends along +X in local space; width centered on local X-axis.
	var half_w: float = w * 0.5
	var pts := PackedVector2Array([
		Vector2(0, -half_w),
		Vector2(len, -half_w),
		Vector2(len, half_w),
		Vector2(0, half_w),
	])
	draw_colored_polygon(pts, fill)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), outline, 2.0)


func _draw_cone(len: float, half_angle: float, fill: Color, outline: Color) -> void:
	## Cone apex at origin, opens along +X in local space.
	var segments: int = 14
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var a: float = -half_angle + t * (2.0 * half_angle)
		pts.append(Vector2(cos(a), sin(a)) * len)
	draw_colored_polygon(pts, fill)
	## Outline arc + two radii
	var arc_pts := PackedVector2Array()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var a: float = -half_angle + t * (2.0 * half_angle)
		arc_pts.append(Vector2(cos(a), sin(a)) * len)
	draw_polyline(arc_pts, outline, 2.0)
	draw_line(Vector2.ZERO, arc_pts[0], outline, 2.0)
	draw_line(Vector2.ZERO, arc_pts[arc_pts.size() - 1], outline, 2.0)
