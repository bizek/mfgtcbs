class_name PlayerVfxHelper
extends RefCounted
## Stateless weapon visual feedback routines extracted from player.gd.
## All methods are static — no instance required.
## owner: any Node (used as tween host and tree accessor).
## scene_root: receives the spawned visual nodes.

# --- Ember Beam sprite caches ---
static var _ember_sting_texture: Texture2D = null
static var _ember_muzzle_texture: Texture2D = null
static var _ember_impact_frames: SpriteFrames = null

static func _get_ember_sting_texture() -> Texture2D:
	if _ember_sting_texture:
		return _ember_sting_texture
	const PATH := "res://assets/minifantasy/Minifantasy_Spell_Effects_II_v1.0/Spell_Effects_II/Shadow_Magic_School/Sting/Sting.png"
	if not ResourceLoader.exists(PATH):
		return null
	var sheet: Texture2D = load(PATH)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(0, 0, 512, 32)  ## Row 0: eastward sting beam
	atlas.filter_clip = true
	_ember_sting_texture = atlas
	return atlas

static func _get_ember_muzzle_texture() -> Texture2D:
	if _ember_muzzle_texture:
		return _ember_muzzle_texture
	const PATH := "res://assets/minifantasy/Minifantasy_Spell_Effects_II_v1.0/Spell_Effects_II/Shadow_Magic_School/Missile/_Missile_Projectile.png"
	if not ResourceLoader.exists(PATH):
		return null
	_ember_muzzle_texture = load(PATH)
	return _ember_muzzle_texture

static func _get_ember_impact_frames() -> SpriteFrames:
	if _ember_impact_frames:
		return _ember_impact_frames
	const PATH := "res://assets/minifantasy/Minifantasy_Spell_Effects_II_v1.0/Spell_Effects_II/Shadow_Magic_School/Missile/Missile_Impact.png"
	if not ResourceLoader.exists(PATH):
		return null
	var sheet: Texture2D = load(PATH)
	var frames := SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_loop("default", false)
	frames.set_animation_speed("default", 16.0)  ## 8 frames at 16fps — snappy impact burst
	for col in 8:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(col * 16, 0, 16, 16)
		atlas.filter_clip = true
		frames.add_frame("default", atlas)
	_ember_impact_frames = frames
	return frames

static func _spawn_ember_beam_flash(owner: Node, scene_root: Node, from: Vector2, to: Vector2, tint: Color, beam_index: int = 0) -> void:
	var dir: Vector2   = to - from
	var dist: float    = dir.length()
	var angle: float   = dir.angle()
	var norm: Vector2  = dir / dist
	## Beam launches 10px ahead of player centre so it reads as emerging, not originating
	var beam_from: Vector2 = from + norm * 10.0
	var mid: Vector2       = (beam_from + to) * 0.5

	var key_c: String = "ember_container_" + str(beam_index)
	var key_t: String = "ember_tween_"     + str(beam_index)
	var key_p: String = "ember_prev_to_"   + str(beam_index)

	# --- Persistent beam container ---
	# Reuse the same nodes each tick; only spawn once, then update in place.
	var container: Node2D = owner.get_meta(key_c, null)

	## Target-switch detection: if the beam endpoint jumped significantly the
	## previous target died. Orphan the old container so it fades while the
	## new one builds up, instead of snapping instantly.
	var prev_to: Vector2 = owner.get_meta(key_p, to)
	if is_instance_valid(container) and prev_to.distance_to(to) > 55.0:
		_fade_and_free_container(owner, container, key_t)
		owner.remove_meta(key_c)
		container = null

	owner.set_meta(key_p, to)

	if not is_instance_valid(container):
		container = Node2D.new()
		container.top_level = true
		scene_root.add_child(container)

		## Taper curve: zero at player end, full width by ~18% of beam length.
		## Both glow and core share the same shape.
		var taper := Curve.new()
		taper.add_point(Vector2(0.0,  0.0), 0.0, 5.0)
		taper.add_point(Vector2(0.18, 1.0), 5.0, 0.0)
		taper.add_point(Vector2(1.0,  1.0), 0.0, 0.0)

		## Wide outer glow
		var glow := Line2D.new()
		glow.default_color = Color(tint.r, tint.g, tint.b, 0.45)
		glow.width         = 18.0
		glow.width_curve   = taper
		container.add_child(glow)

		## Sting beam body — additive blend so sprite acts as emitted light
		var sting_tex := _get_ember_sting_texture()
		var beam := Sprite2D.new()
		if sting_tex:
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			beam.material  = mat
			beam.texture   = sting_tex
			beam.centered  = true
			beam.modulate  = Color(tint.r * 1.6, tint.g * 1.6, tint.b * 1.6, 0.9)
		container.add_child(beam)

		## Bright hot core
		var core := Line2D.new()
		core.default_color = Color(1.0, 0.85, 0.45, 0.92)
		core.width         = 2.5
		core.width_curve   = taper
		container.add_child(core)

		owner.set_meta(key_c, container)

	# Update geometry every tick
	container.modulate.a = 1.0

	var glow: Line2D  = container.get_child(0)
	var beam: Sprite2D = container.get_child(1)
	var core: Line2D  = container.get_child(2)

	glow.clear_points()
	glow.add_point(beam_from)
	glow.add_point(to)

	beam.position = mid
	beam.rotation = angle
	beam.scale    = Vector2(beam_from.distance_to(to) / 512.0, 0.7)

	core.clear_points()
	core.add_point(beam_from)
	core.add_point(to)

	# Kill any pending fade tween and restart the grace-period countdown.
	# (Only kills the tween for the *current* container — orphaned containers
	#  get their own self-contained tweens via _fade_and_free_container.)
	var old_tween: Tween = owner.get_meta(key_t, null)
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()

	var captured_container := container
	var fade := owner.create_tween()
	## Grace period slightly longer than fire interval (1/12 ≈ 0.083s) so
	## continuous fire never triggers the fade.
	fade.tween_interval(0.11)
	fade.tween_property(captured_container, "modulate:a", 0.0, 0.14)
	fade.tween_callback(func():
		if is_instance_valid(captured_container):
			captured_container.queue_free()
		if is_instance_valid(owner) and owner.has_meta(key_c):
			owner.remove_meta(key_c)
	)
	owner.set_meta(key_t, fade)

	# --- Per-tick endpoints: muzzle flash + impact sparks ---
	## These are intentionally transient — the flicker at the endpoints
	## adds life without making the beam body pulse.

	var muzzle_tex := _get_ember_muzzle_texture()
	if muzzle_tex:
		var muzzle := Sprite2D.new()
		muzzle.top_level       = true
		muzzle.texture         = muzzle_tex
		muzzle.centered        = true
		muzzle.global_position = from
		muzzle.rotation        = angle
		muzzle.scale           = Vector2(0.45, 0.45)
		muzzle.modulate        = Color(tint.r, tint.g, tint.b, 0.9)
		scene_root.add_child(muzzle)
		var tm := owner.create_tween()
		tm.tween_property(muzzle, "modulate:a", 0.0, 0.07)
		tm.tween_callback(muzzle.queue_free)

	var impact_sf := _get_ember_impact_frames()
	if impact_sf:
		var fx := VfxEffect.create(impact_sf, "default", false, 1)
		fx.position = to
		fx.modulate = Color(tint.r, tint.g, tint.b, 1.0)
		fx.scale    = Vector2(2.5, 2.5)
		scene_root.add_child(fx)


static func spawn_beam_flash(owner: Node, scene_root: Node, from: Vector2, to: Vector2, tint: Color, beam_id: String = "", beam_index: int = 0) -> void:
	if beam_id == "Ember Beam":
		_spawn_ember_beam_flash(owner, scene_root, from, to, tint, beam_index)
		return

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


## Immediately start a self-contained fade on a container and clean its tween
## meta key, so the caller can detach it without the regular tween-kill block
## accidentally cancelling the fade.
static func _fade_and_free_container(owner: Node, container: Node2D, tween_key: String) -> void:
	var old_tween: Tween = owner.get_meta(tween_key, null)
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	if owner.has_meta(tween_key):
		owner.remove_meta(tween_key)
	if not is_instance_valid(container):
		return
	var fade := owner.create_tween()
	fade.tween_property(container, "modulate:a", 0.0, 0.25)
	fade.tween_callback(container.queue_free)


## Fade out and free any persistent beam containers for indices >= active_count.
## Call once per fire tick in player.gd so stale multi-beam containers don't linger.
static func cleanup_stale_beam_containers(owner: Node, active_count: int) -> void:
	var idx: int = active_count
	while true:
		var key_c: String = "ember_container_" + str(idx)
		var key_t: String = "ember_tween_"     + str(idx)
		var key_p: String = "ember_prev_to_"   + str(idx)
		if not owner.has_meta(key_c):
			break
		var container: Node2D = owner.get_meta(key_c)
		_fade_and_free_container(owner, container, key_t)
		owner.remove_meta(key_c)
		if owner.has_meta(key_p):
			owner.remove_meta(key_p)
		idx += 1
