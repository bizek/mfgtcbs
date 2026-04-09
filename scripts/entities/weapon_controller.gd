extends Node
class_name WeaponController

## WeaponController — Handles all weapon firing behaviors, projectile spawning,
## mod application, orbit orb management, and combat visual effects.
## Delegates stat lookups back to the owning player node.

const OrbitOrbScript := preload("res://scripts/entities/orbit_orb.gd")

var player: CharacterBody2D = null
var projectile_scene: PackedScene = null
var weapon_data: Dictionary = {}
var weapon_id: String = ""
var active_mods: Array = []
var fire_timer: float = 0.0
var _orbit_orbs: Array = []
var _sustained_fire_timer: float = 0.0

## ── Setup ────────────────────────────────────────────────────────────────────

func setup(p_player: CharacterBody2D, p_weapon_data: Dictionary, p_weapon_id: String, p_proj_scene: PackedScene) -> void:
	player = p_player
	weapon_data = p_weapon_data
	weapon_id = p_weapon_id
	projectile_scene = p_proj_scene

	_sustained_fire_timer = 0.0
	if weapon_data.get("behavior") == "orbit":
		call_deferred("_setup_orbit_orbs")

func set_mods(mods: Array) -> void:
	active_mods = mods

## ── Tick (called from player._physics_process) ──────────────────────────────

func tick(delta: float) -> void:
	_update_accel_timer(delta)
	fire_timer -= delta
	if fire_timer <= 0.0:
		_fire_weapon()
		fire_timer = 1.0 / _get_effective_attack_speed()

func _update_accel_timer(delta: float) -> void:
	if not "accelerating" in active_mods:
		return
	var params: Dictionary = ModData.ALL["accelerating"]["params"]
	var ramp_time: float = params.get("ramp_time", 3.0)
	if _get_nearest_enemy() != null:
		_sustained_fire_timer = minf(_sustained_fire_timer + delta, ramp_time)
	else:
		_sustained_fire_timer = maxf(_sustained_fire_timer - delta, 0.0)

func _get_effective_attack_speed() -> float:
	var base_speed: float = player.get_stat("attack_speed")
	if not "accelerating" in active_mods:
		return base_speed
	var params: Dictionary = ModData.ALL["accelerating"]["params"]
	var max_bonus: float = params.get("max_bonus", 0.5)
	var ramp_time: float = params.get("ramp_time", 3.0)
	var accel_bonus: float = clampf(_sustained_fire_timer / ramp_time, 0.0, 1.0) * max_bonus
	return base_speed * (1.0 + accel_bonus)

## ── Weapon dispatch ──────────────────────────────────────────────────────────

func _fire_weapon() -> void:
	match weapon_data.get("behavior", "projectile"):
		"projectile": _fire_projectile_weapon()
		"spread":     _fire_spread_weapon()
		"beam":       _fire_beam_weapon()
		"orbit":      pass
		"artillery":  _fire_artillery_weapon()
		"melee":      _fire_melee_weapon()

# ─── Behavior: Projectile ────────────────────────────────────────────────────

func _fire_projectile_weapon() -> void:
	var nearest := _get_nearest_enemy()
	if nearest == null:
		return
	var direction: Vector2 = (nearest.global_position - player.global_position).normalized()
	var proj_count: int    = int(player.get_stat("projectile_count"))
	var spread_deg: float  = weapon_data.get("spread_angle", 10.0)
	_fire_spread_pattern(direction, proj_count, spread_deg)

# ─── Behavior: Spread ────────────────────────────────────────────────────────

func _fire_spread_weapon() -> void:
	var nearest := _get_nearest_enemy()
	if nearest == null:
		return
	var direction: Vector2 = (nearest.global_position - player.global_position).normalized()
	var proj_count: int    = weapon_data.get("projectile_count", 5)
	var total_spread: float = weapon_data.get("spread_angle", 52.0)
	_fire_spread_pattern(direction, proj_count, total_spread)

## Shared spread calculation — used by both projectile and spread behaviors.
func _fire_spread_pattern(direction: Vector2, proj_count: int, spread_deg: float) -> void:
	for i in range(proj_count):
		var offset: float = 0.0
		if proj_count > 1:
			offset = deg_to_rad(-spread_deg * 0.5 + spread_deg * float(i) / float(proj_count - 1))
		_spawn_projectile(direction.rotated(offset))

# ─── Behavior: Beam ──────────────────────────────────────────────────────────

func _fire_beam_weapon() -> void:
	var nearest := _get_nearest_enemy()
	if nearest == null:
		return
	var max_range: float = weapon_data.get("range", 285.0)
	if player.global_position.distance_to(nearest.global_position) > max_range:
		return
	CombatManager.resolve_hit(
		player, nearest,
		player.get_stat("damage"), player.get_stat("crit_chance"), player.get_stat("crit_multiplier")
	)
	_apply_direct_hit_mods(nearest, player.get_stat("damage"))
	_spawn_beam_flash(nearest.global_position)

func _spawn_beam_flash(target_pos: Vector2) -> void:
	var tint: Color = weapon_data.get("tint", Color(1.0, 0.42, 0.08))
	var scene_root: Node = get_tree().current_scene

	var line := Line2D.new()
	line.top_level = true
	line.add_point(player.global_position)
	line.add_point(target_pos)
	line.width         = 3.5
	line.default_color = Color(tint.r, tint.g, tint.b, 0.92)

	var glow := Line2D.new()
	glow.top_level = true
	glow.add_point(player.global_position)
	glow.add_point(target_pos)
	glow.width         = 7.0
	glow.default_color = Color(tint.r, tint.g, tint.b, 0.22)

	scene_root.add_child(glow)
	scene_root.add_child(line)

	var t := player.create_tween()
	t.tween_property(line, "modulate:a", 0.0, 0.06)
	t.tween_callback(line.queue_free)
	var t2 := player.create_tween()
	t2.tween_property(glow, "modulate:a", 0.0, 0.06)
	t2.tween_callback(glow.queue_free)

# ─── Behavior: Melee ─────────────────────────────────────────────────────────

func _fire_melee_weapon() -> void:
	var nearest := _get_nearest_enemy()
	var swing_dir: Vector2 = Vector2.RIGHT
	if nearest != null:
		swing_dir = (nearest.global_position - player.global_position).normalized()

	var range_px: float   = weapon_data.get("range", 55.0)
	var arc_deg: float    = weapon_data.get("arc_degrees", 200.0)
	var arc_half: float   = deg_to_rad(arc_deg * 0.5)
	var center_angle: float = swing_dir.angle()

	var melee_candidates: Array = player.enemy_grid.get_nearby_in_range(player.global_position, range_px) if player.enemy_grid else get_tree().get_nodes_in_group("enemies")
	for enemy in melee_candidates:
		if not is_instance_valid(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - player.global_position
		if to_enemy.length() > range_px:
			continue
		var angle_diff: float = absf(wrapf(to_enemy.angle() - center_angle, -PI, PI))
		if angle_diff > arc_half:
			continue
		CombatManager.resolve_hit(
			player, enemy,
			player.get_stat("damage"), player.get_stat("crit_chance"), player.get_stat("crit_multiplier")
		)
		_apply_direct_hit_mods(enemy, player.get_stat("damage"))

	_spawn_melee_arc(center_angle, range_px, arc_half)

func _spawn_melee_arc(center_angle: float, range_px: float, arc_half: float) -> void:
	var tint: Color  = weapon_data.get("tint", Color(0.48, 0.80, 1.0))
	var segments: int = 12
	var scene_root: Node = get_tree().current_scene

	var points: PackedVector2Array = []
	points.append(Vector2.ZERO)
	for i in range(segments + 1):
		var a: float = center_angle - arc_half + (float(i) / float(segments)) * arc_half * 2.0
		points.append(Vector2(cos(a), sin(a)) * range_px)

	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color   = Color(tint.r, tint.g, tint.b, 0.48)
	scene_root.add_child(poly)
	poly.global_position = player.global_position

	var edge_points: PackedVector2Array = []
	for i in range(segments + 1):
		var a: float = center_angle - arc_half + (float(i) / float(segments)) * arc_half * 2.0
		edge_points.append(Vector2(cos(a), sin(a)) * range_px)

	var edge := Line2D.new()
	edge.top_level = true
	for p in edge_points:
		edge.add_point(poly.global_position + p)
	edge.width         = 3.0
	edge.default_color = Color(tint.r, tint.g, tint.b, 0.85)
	scene_root.add_child(edge)

	var t := player.create_tween()
	t.tween_property(poly, "modulate:a", 0.0, 0.13)
	t.tween_callback(poly.queue_free)
	var t2 := player.create_tween()
	t2.tween_property(edge, "modulate:a", 0.0, 0.13)
	t2.tween_callback(edge.queue_free)

# ─── Behavior: Artillery ─────────────────────────────────────────────────────

func _fire_artillery_weapon() -> void:
	var nearest := _get_nearest_enemy()
	if nearest == null:
		return
	var max_range: float = weapon_data.get("range", 380.0)
	if player.global_position.distance_to(nearest.global_position) > max_range:
		return

	var scatter := Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
	var target_pos: Vector2 = nearest.global_position + scatter
	var aoe_radius: float = weapon_data.get("aoe_radius", 64.0)
	var fuse_time: float  = weapon_data.get("fuse_time", 1.0)
	var tint: Color       = weapon_data.get("tint", Color(0.38, 0.08, 0.62))
	var dmg:     float = player.get_stat("damage")
	var crit_ch: float = player.get_stat("crit_chance")
	var crit_m:  float = player.get_stat("crit_multiplier")
	_spawn_mortar_marker(target_pos, aoe_radius, fuse_time, dmg, crit_ch, crit_m, tint)

func _spawn_mortar_marker(
		pos: Vector2, radius: float, fuse: float,
		dmg: float, crit_ch: float, crit_m: float, tint: Color) -> void:
	var scene_root: Node = get_tree().current_scene

	var marker := Node2D.new()
	marker.global_position = pos
	scene_root.add_child(marker)

	var preview := ColorRect.new()
	preview.color    = Color(tint.r, tint.g, tint.b, 0.18)
	preview.size     = Vector2(radius * 2.0, radius * 2.0)
	preview.position = Vector2(-radius, -radius)
	marker.add_child(preview)

	var bd: float = radius * 2.0
	var bt: float = 2.0
	var bc: Color = Color(tint.r, tint.g, tint.b, 0.72)
	for side in 4:
		var b := ColorRect.new()
		b.color = bc
		match side:
			0: b.size = Vector2(bd, bt); b.position = Vector2(-radius, -radius)
			1: b.size = Vector2(bd, bt); b.position = Vector2(-radius,  radius - bt)
			2: b.size = Vector2(bt, bd); b.position = Vector2(-radius, -radius)
			3: b.size = Vector2(bt, bd); b.position = Vector2( radius - bt, -radius)
		marker.add_child(b)

	var dot := ColorRect.new()
	dot.color    = Color(tint.r + 0.3, tint.g + 0.1, tint.b + 0.3, 1.0)
	dot.size     = Vector2(7.0, 7.0)
	dot.position = Vector2(-3.5, -3.5)
	marker.add_child(dot)

	var warn := player.create_tween().set_loops(int(fuse * 6.0))
	warn.tween_property(preview, "modulate:a", 0.15, fuse / 12.0)
	warn.tween_property(preview, "modulate:a", 1.0,  fuse / 12.0)

	get_tree().create_timer(fuse).timeout.connect(
		func():
			if is_instance_valid(marker):
				_detonate_mortar(pos, radius, dmg, crit_ch, crit_m, tint)
				marker.queue_free()
	)

func _detonate_mortar(
		pos: Vector2, radius: float,
		dmg: float, crit_ch: float, crit_m: float, tint: Color) -> void:
	var scene_root: Node = get_tree().current_scene

	var mortar_targets: Array = player.enemy_grid.get_nearby_in_range(pos, radius) if player.enemy_grid else get_tree().get_nodes_in_group("enemies")
	for enemy in mortar_targets:
		if not is_instance_valid(enemy):
			continue
		if pos.distance_to(enemy.global_position) <= radius:
			CombatManager.resolve_hit(player, enemy, dmg, crit_ch, crit_m)
			if enemy.has_method("apply_status"):
				enemy.apply_status("void_touched", {})
			_apply_direct_hit_mods(enemy, dmg)

	var ring := ColorRect.new()
	ring.color    = Color(tint.r, tint.g, tint.b, 0.55)
	ring.size     = Vector2(radius * 2.0, radius * 2.0)
	ring.position = pos - Vector2(radius, radius)
	scene_root.add_child(ring)

	var rt := player.create_tween()
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
	get_tree().create_timer(1.2).timeout.connect(
		func(): if is_instance_valid(particles): particles.queue_free()
	)

# ─── Mod application ─────────────────────────────────────────────────────────

func apply_mods_to_projectile(proj: Node) -> void:
	for mod_id in active_mods:
		var mod_data: Dictionary = ModData.ALL.get(mod_id, {})
		var params: Dictionary   = mod_data.get("params", {})
		match mod_data.get("effect_type", ""):
			"pierce":
				proj.pierce_count = maxi(proj.pierce_count, params.get("pierce_count", 3))
			"chain":
				proj.mod_chain              = true
				proj.mod_chain_range        = params.get("chain_range", 120.0)
				proj.mod_chain_damage_mult  = params.get("chain_damage_mult", 0.6)
			"explosive":
				proj.mod_explosive          = true
				proj.mod_explosive_radius   = params.get("radius", 40.0)
				proj.mod_explosive_damage_mult = params.get("damage_mult", 0.3)
			"elemental":
				proj.mod_status        = params.get("element", "")
				proj.mod_status_params = params
			"lifesteal":
				proj.mod_lifesteal = params.get("steal_pct", 0.05)
			"size":
				proj.scale_factor *= params.get("size_mult", 1.5)
			"split":
				proj.mod_split             = true
				proj.mod_split_count       = params.get("split_count", 3)
				proj.mod_split_damage_mult = params.get("split_damage_mult", 0.4)
			"gravity":
				proj.mod_gravity       = true
				proj.mod_gravity_pull  = params.get("pull_strength", 300.0)
				proj.mod_gravity_range = params.get("seek_range", 150.0)
			"ricochet":
				proj.mod_ricochet        = true
				proj._bounces_remaining  = params.get("max_bounces", 3)

func _apply_direct_hit_mods(enemy: Node, raw_damage: float) -> void:
	if not is_instance_valid(enemy):
		return
	for mod_id in active_mods:
		var mod_data: Dictionary = ModData.ALL.get(mod_id, {})
		var params: Dictionary   = mod_data.get("params", {})
		match mod_data.get("effect_type", ""):
			"elemental":
				if enemy.has_method("apply_status"):
					enemy.apply_status(params.get("element", ""), params)
			"lifesteal":
				player.heal(raw_damage * params.get("steal_pct", 0.05))
			"chain":
				_do_chain_hit(enemy.global_position, enemy,
					raw_damage * params.get("chain_damage_mult", 0.6),
					params.get("chain_range", 120.0))
			"explosive":
				_do_explosion(enemy.global_position,
					raw_damage * params.get("damage_mult", 0.3),
					params.get("radius", 40.0))
			"dot_applicator":
				if enemy.has_method("apply_status"):
					enemy.apply_status("bleed", params)

func _do_chain_hit(origin: Vector2, origin_enemy: Node, dmg: float, range_px: float) -> void:
	var nearest: Node2D = null
	var nearest_dist: float = range_px
	var chain_candidates: Array = player.enemy_grid.get_nearby_in_range(origin, range_px) if player.enemy_grid else get_tree().get_nodes_in_group("enemies")
	for enemy in chain_candidates:
		if not is_instance_valid(enemy) or enemy == origin_enemy:
			continue
		var dist: float = origin.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	if nearest == null or not nearest.has_method("take_damage"):
		return
	CombatManager.resolve_secondary_hit(player, nearest, dmg)
	var line := Line2D.new()
	line.top_level = true
	line.add_point(origin)
	line.add_point(nearest.global_position)
	line.width = 1.5
	line.default_color = Color(0.35, 0.75, 1.0, 0.75)
	get_tree().current_scene.add_child(line)
	var t := line.create_tween()
	t.tween_property(line, "modulate:a", 0.0, 0.14)
	t.tween_callback(line.queue_free)

func _do_explosion(pos: Vector2, dmg: float, radius: float) -> void:
	var explosion_targets: Array = player.enemy_grid.get_nearby_in_range(pos, radius) if player.enemy_grid else get_tree().get_nodes_in_group("enemies")
	for enemy in explosion_targets:
		if not is_instance_valid(enemy):
			continue
		if pos.distance_to(enemy.global_position) <= radius:
			if enemy.has_method("take_damage"):
				CombatManager.resolve_secondary_hit(player, enemy, dmg)
	var ring := ColorRect.new()
	ring.color    = Color(1.0, 0.48, 0.08, 0.50)
	ring.size     = Vector2(radius * 2.0, radius * 2.0)
	ring.position = pos - Vector2(radius, radius)
	ring.top_level = true
	get_tree().current_scene.add_child(ring)
	var rt := ring.create_tween()
	rt.tween_property(ring, "scale", Vector2(1.6, 1.6), 0.18).set_trans(Tween.TRANS_EXPO)
	rt.parallel().tween_property(ring, "modulate:a", 0.0, 0.18)
	rt.tween_callback(ring.queue_free)

# ─── Orbit orbs ──────────────────────────────────────────────────────────────

func _setup_orbit_orbs() -> void:
	var count: int    = weapon_data.get("orbit_count", 3)
	var radius: float = weapon_data.get("orbit_radius", 64.0)
	var speed: float  = weapon_data.get("orbit_speed", 1.8)
	var tint: Color   = weapon_data.get("tint", Color.WHITE)

	for i in range(count):
		var orb: Area2D = OrbitOrbScript.new()
		orb.player_ref    = player
		orb.orbit_radius  = radius
		orb.orbit_speed   = speed
		orb.orbit_offset  = TAU * float(i) / float(count)
		orb.tint          = tint
		get_tree().current_scene.add_child(orb)
		_orbit_orbs.append(orb)

func cleanup() -> void:
	for orb in _orbit_orbs:
		if is_instance_valid(orb):
			orb.queue_free()
	_orbit_orbs.clear()

# ─── Shared helpers ──────────────────────────────────────────────────────────

func _get_nearest_enemy() -> Node2D:
	if player.enemy_grid:
		return player.enemy_grid.find_nearest(player.global_position)
	## Fallback: linear scan (only if grid isn't wired yet)
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist: float = player.global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest

func _spawn_projectile(direction: Vector2) -> void:
	var proj: Area2D = projectile_scene.instantiate()
	proj.global_position = player.global_position
	proj.direction       = direction
	proj.damage          = player.get_stat("damage")
	proj.crit_chance     = player.get_stat("crit_chance")
	proj.crit_multiplier = player.get_stat("crit_multiplier")
	proj.pierce_count    = int(player.get_stat("pierce"))
	proj.scale_factor    = player.get_stat("projectile_size")
	proj.source          = player

	if weapon_data.has("projectile_speed"):
		proj.speed = weapon_data["projectile_speed"]
	if weapon_data.has("lifetime"):
		proj.lifetime = weapon_data["lifetime"]

	proj.modulate = weapon_data.get("tint", Color.WHITE)
	apply_mods_to_projectile(proj)
	get_tree().current_scene.add_child(proj)
