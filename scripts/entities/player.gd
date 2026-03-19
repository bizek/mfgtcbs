extends CharacterBody2D

## Player — Movement, auto-fire weapon system, stats, health, leveling.
## Reads the equipped weapon from ProgressionManager at run start and dispatches
## to a behavior-specific fire method each attack tick.

signal health_changed(current: float, maximum: float)
signal xp_changed(current: float, needed: float)
signal leveled_up(new_level: int)
signal died

const OrbitOrbScript := preload("res://scripts/entities/orbit_orb.gd")

## Base stats (The Drifter) — damage/attack_speed overridden by weapon at _ready
var stats: Dictionary = {
	"max_hp":          100.0,
	"hp":              100.0,
	"armor":           0.0,
	"move_speed":      180.0,
	"damage":          18.0,
	"attack_speed":    1.0,
	"crit_chance":     0.05,
	"crit_multiplier": 1.5,
	"pickup_radius":   50.0,
	"projectile_count": 1,
	"pierce":          0,
	"projectile_size": 1.0,
	"extraction_speed": 1.0,
}

## Stat modifiers accumulated from upgrades
var flat_mods: Dictionary = {}
var percent_mods: Dictionary = {}

## XP and leveling
var xp: float = 0.0
var level: int = 1
var xp_base: float = 10.0
var xp_growth: float = 0.3

## Weapon system
var fire_timer: float = 0.0
var projectile_scene: PackedScene
var _weapon_data: Dictionary = {}     ## active weapon definition from WeaponData.ALL
var _orbit_orbs: Array = []           ## spawned orb nodes (Lightning Orb only)

## State
var _is_dead: bool = false
var god_mode: bool = false  ## Debug: player takes no damage when true

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var pickup_area: Area2D = $PickupCollector
@onready var pickup_shape: CollisionShape2D = $PickupCollector/CollisionShape

func _ready() -> void:
	add_to_group("player")
	projectile_scene = preload("res://scenes/projectile.tscn")
	_load_equipped_weapon()
	_update_pickup_radius()
	health_changed.emit(stats.hp, get_stat("max_hp"))
	pickup_area.area_entered.connect(_on_pickup_area_entered)

# ─── Weapon loading ────────────────────────────────────────────────────────────

func _load_equipped_weapon() -> void:
	var weapon_id: String = ProgressionManager.selected_weapon
	if weapon_id.is_empty():
		weapon_id = "Standard Sidearm"

	_weapon_data = WeaponData.ALL.get(weapon_id, WeaponData.ALL["Standard Sidearm"])

	## Override base stats from weapon data so upgrades apply on top correctly
	stats["damage"]          = _weapon_data.get("damage",          18.0)
	stats["attack_speed"]    = _weapon_data.get("attack_speed",     1.0)
	stats["projectile_count"] = _weapon_data.get("projectile_count", 1)

	## Behaviour-specific setup
	if _weapon_data.get("behavior") == "orbit":
		## Orbs are created deferred so get_tree().current_scene is ready
		call_deferred("_setup_orbit_orbs")

func _setup_orbit_orbs() -> void:
	var count: int   = _weapon_data.get("orbit_count",  3)
	var radius: float = _weapon_data.get("orbit_radius", 64.0)
	var speed: float  = _weapon_data.get("orbit_speed",  1.8)
	var tint: Color   = _weapon_data.get("tint",         Color.WHITE)

	for i in range(count):
		var orb: Area2D = OrbitOrbScript.new()
		orb.player_ref    = self
		orb.orbit_radius  = radius
		orb.orbit_speed   = speed
		orb.orbit_offset  = TAU * float(i) / float(count)
		orb.tint          = tint
		get_tree().current_scene.add_child(orb)
		_orbit_orbs.append(orb)

# ─── Main loop ─────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	## Movement
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up",   "move_down")
	).normalized()

	var target_velocity: Vector2 = input_dir * get_stat("move_speed")
	velocity = velocity.move_toward(target_velocity, 2600.0 * delta)
	move_and_slide()

	if sprite:
		if input_dir.x != 0:
			sprite.flip_h = input_dir.x < 0
		if input_dir.length_squared() > 0:
			sprite.play("walk")
		else:
			sprite.play("idle")

	## Auto-fire tick
	fire_timer -= delta
	if fire_timer <= 0.0:
		_fire_weapon()
		fire_timer = 1.0 / get_stat("attack_speed")

# ─── Stat helpers ──────────────────────────────────────────────────────────────

func get_stat(stat_name: String) -> float:
	var base: float = stats.get(stat_name, 0.0)
	var flat: float = flat_mods.get(stat_name, 0.0)
	var pct:  float = percent_mods.get(stat_name, 0.0)
	return (base + flat) * (1.0 + pct)

func get_armor() -> float:
	return get_stat("armor")

func is_dead() -> bool:
	return _is_dead

# ─── Health ────────────────────────────────────────────────────────────────────

func take_damage(amount: float) -> void:
	if _is_dead or god_mode:
		return
	stats.hp -= amount
	health_changed.emit(stats.hp, get_stat("max_hp"))

	sprite.modulate = Color.RED
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

	if stats.hp <= 0.0:
		stats.hp = 0.0
		_die()

func heal(amount: float) -> void:
	if _is_dead:
		return
	stats.hp = minf(stats.hp + amount, get_stat("max_hp"))
	health_changed.emit(stats.hp, get_stat("max_hp"))

# ─── XP / leveling ────────────────────────────────────────────────────────────

func add_xp(amount: float) -> void:
	if _is_dead:
		return
	xp += amount
	var xp_needed := _xp_to_next_level()
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		leveled_up.emit(level)
		xp_needed = _xp_to_next_level()
	xp_changed.emit(xp, _xp_to_next_level())

func _xp_to_next_level() -> float:
	return xp_base * (1.0 + (level - 1) * xp_growth)

# ─── Upgrade application ──────────────────────────────────────────────────────

func apply_stat_upgrade(upgrade: Dictionary) -> void:
	var stat_name: String = upgrade.stat
	var value: float      = upgrade.value
	if upgrade.type == "flat":
		flat_mods[stat_name] = flat_mods.get(stat_name, 0.0) + value
		if stat_name == "max_hp":
			heal(value)
	elif upgrade.type == "percent":
		percent_mods[stat_name] = percent_mods.get(stat_name, 0.0) + value

	if stat_name == "pickup_radius":
		_update_pickup_radius()

# ─── Weapon dispatch ──────────────────────────────────────────────────────────

func _fire_weapon() -> void:
	match _weapon_data.get("behavior", "projectile"):
		"projectile": _fire_projectile_weapon()
		"spread":     _fire_spread_weapon()
		"beam":       _fire_beam_weapon()
		"orbit":      pass  ## Orbs handle themselves — no fire logic needed
		"artillery":  _fire_artillery_weapon()
		"melee":      _fire_melee_weapon()

# ─── Behavior: Projectile (Standard Sidearm) ──────────────────────────────────

func _fire_projectile_weapon() -> void:
	var nearest := _get_nearest_enemy()
	if nearest == null:
		return

	var direction: Vector2 = (nearest.global_position - global_position).normalized()
	var proj_count: int    = int(get_stat("projectile_count"))
	var spread_deg: float  = _weapon_data.get("spread_angle", 10.0)

	for i in range(proj_count):
		var offset: float = 0.0
		if proj_count > 1:
			offset = deg_to_rad(-spread_deg * 0.5 + spread_deg * float(i) / float(proj_count - 1))
		_spawn_projectile(direction.rotated(offset))

# ─── Behavior: Spread (Frost Scattergun) ─────────────────────────────────────

func _fire_spread_weapon() -> void:
	var nearest := _get_nearest_enemy()
	if nearest == null:
		return

	var direction: Vector2 = (nearest.global_position - global_position).normalized()
	var proj_count: int    = _weapon_data.get("projectile_count", 5)
	var total_spread: float = _weapon_data.get("spread_angle", 52.0)

	for i in range(proj_count):
		var offset: float = deg_to_rad(
			-total_spread * 0.5 + total_spread * float(i) / float(proj_count - 1)
		)
		_spawn_projectile(direction.rotated(offset))

# ─── Behavior: Beam (Ember Beam) ─────────────────────────────────────────────

func _fire_beam_weapon() -> void:
	var nearest := _get_nearest_enemy()
	if nearest == null:
		return

	var max_range: float = _weapon_data.get("range", 285.0)
	if global_position.distance_to(nearest.global_position) > max_range:
		return

	CombatManager.resolve_hit(
		self, nearest,
		get_stat("damage"), get_stat("crit_chance"), get_stat("crit_multiplier")
	)

	_spawn_beam_flash(nearest.global_position)

func _spawn_beam_flash(target_pos: Vector2) -> void:
	var tint: Color = _weapon_data.get("tint", Color(1.0, 0.42, 0.08))

	var line := Line2D.new()
	line.top_level = true          ## ignore parent transform
	line.add_point(global_position)
	line.add_point(target_pos)
	line.width          = 3.5
	line.default_color  = Color(tint.r, tint.g, tint.b, 0.92)

	## Faint outer glow line
	var glow := Line2D.new()
	glow.top_level = true
	glow.add_point(global_position)
	glow.add_point(target_pos)
	glow.width          = 7.0
	glow.default_color  = Color(tint.r, tint.g, tint.b, 0.22)

	get_tree().current_scene.add_child(glow)
	get_tree().current_scene.add_child(line)

	var t := create_tween()
	t.tween_property(line, "modulate:a",  0.0, 0.06)
	t.tween_callback(line.queue_free)
	var t2 := create_tween()
	t2.tween_property(glow, "modulate:a", 0.0, 0.06)
	t2.tween_callback(glow.queue_free)

# ─── Behavior: Melee (Plasma Blade) ──────────────────────────────────────────

func _fire_melee_weapon() -> void:
	var nearest := _get_nearest_enemy()
	## Swing toward nearest enemy, or default rightward if arena is clear
	var swing_dir: Vector2 = Vector2.RIGHT
	if nearest != null:
		swing_dir = (nearest.global_position - global_position).normalized()

	var range_px: float   = _weapon_data.get("range",       55.0)
	var arc_deg: float    = _weapon_data.get("arc_degrees", 200.0)
	var arc_half: float   = deg_to_rad(arc_deg * 0.5)
	var center_angle: float = swing_dir.angle()

	## Damage all enemies inside the swing arc
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - global_position
		if to_enemy.length() > range_px:
			continue
		## Signed angle between swing direction and enemy direction
		var angle_diff: float = absf(wrapf(to_enemy.angle() - center_angle, -PI, PI))
		if angle_diff > arc_half:
			continue
		CombatManager.resolve_hit(
			self, enemy,
			get_stat("damage"), get_stat("crit_chance"), get_stat("crit_multiplier")
		)

	_spawn_melee_arc(center_angle, range_px, arc_half)

func _spawn_melee_arc(center_angle: float, range_px: float, arc_half: float) -> void:
	var tint: Color  = _weapon_data.get("tint", Color(0.48, 0.80, 1.0))
	var segments: int = 12

	var points: PackedVector2Array = []
	points.append(Vector2.ZERO)   ## player centre in local space
	for i in range(segments + 1):
		var a: float = center_angle - arc_half + (float(i) / float(segments)) * arc_half * 2.0
		points.append(Vector2(cos(a), sin(a)) * range_px)

	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color   = Color(tint.r, tint.g, tint.b, 0.48)
	get_tree().current_scene.add_child(poly)
	poly.global_position = global_position   ## must set after add_child

	## Inner brighter edge along the arc perimeter
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
	get_tree().current_scene.add_child(edge)

	## Fade both out
	var t := create_tween()
	t.tween_property(poly,  "modulate:a", 0.0, 0.13)
	t.tween_callback(poly.queue_free)
	var t2 := create_tween()
	t2.tween_property(edge, "modulate:a", 0.0, 0.13)
	t2.tween_callback(edge.queue_free)

# ─── Behavior: Artillery (Void Mortar) ───────────────────────────────────────

func _fire_artillery_weapon() -> void:
	var nearest := _get_nearest_enemy()
	if nearest == null:
		return

	var max_range: float = _weapon_data.get("range", 380.0)
	if global_position.distance_to(nearest.global_position) > max_range:
		return

	## Land the shell near (but not exactly on) the enemy
	var scatter := Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
	var target_pos: Vector2 = nearest.global_position + scatter

	var aoe_radius: float = _weapon_data.get("aoe_radius", 64.0)
	var fuse_time: float  = _weapon_data.get("fuse_time",   1.0)
	var tint: Color       = _weapon_data.get("tint",        Color(0.38, 0.08, 0.62))

	## Snapshot damage stats at fire time so upgrades don't change mid-flight
	var dmg:     float = get_stat("damage")
	var crit_ch: float = get_stat("crit_chance")
	var crit_m:  float = get_stat("crit_multiplier")

	_spawn_mortar_marker(target_pos, aoe_radius, fuse_time, dmg, crit_ch, crit_m, tint)

func _spawn_mortar_marker(
		pos: Vector2, radius: float, fuse: float,
		dmg: float, crit_ch: float, crit_m: float, tint: Color) -> void:

	var marker := Node2D.new()
	marker.global_position = pos
	get_tree().current_scene.add_child(marker)

	## AoE preview circle
	var preview := ColorRect.new()
	preview.color    = Color(tint.r, tint.g, tint.b, 0.18)
	preview.size     = Vector2(radius * 2.0, radius * 2.0)
	preview.position = Vector2(-radius, -radius)
	marker.add_child(preview)

	## Warning border (4 sides)
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

	## Impact dot at the exact landing point
	var dot := ColorRect.new()
	dot.color    = Color(tint.r + 0.3, tint.g + 0.1, tint.b + 0.3, 1.0)
	dot.size     = Vector2(7.0, 7.0)
	dot.position = Vector2(-3.5, -3.5)
	marker.add_child(dot)

	## Pulsing warning animation
	var warn := create_tween().set_loops(int(fuse * 6.0))
	warn.tween_property(preview, "modulate:a", 0.15, fuse / 12.0)
	warn.tween_property(preview, "modulate:a", 1.0,  fuse / 12.0)

	## Detonate after fuse
	get_tree().create_timer(fuse).timeout.connect(
		func():
			if is_instance_valid(marker):
				_detonate_mortar(pos, radius, dmg, crit_ch, crit_m, tint)
				marker.queue_free()
	)

func _detonate_mortar(
		pos: Vector2, radius: float,
		dmg: float, crit_ch: float, crit_m: float, tint: Color) -> void:

	## Damage everything in the blast radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if pos.distance_to(enemy.global_position) <= radius:
			CombatManager.resolve_hit(self, enemy, dmg, crit_ch, crit_m)

	## Expanding ring flash
	var ring := ColorRect.new()
	ring.color    = Color(tint.r, tint.g, tint.b, 0.55)
	ring.size     = Vector2(radius * 2.0, radius * 2.0)
	ring.position = pos - Vector2(radius, radius)
	get_tree().current_scene.add_child(ring)

	var rt := create_tween()
	rt.tween_property(ring, "scale",       Vector2(1.5, 1.5), 0.22).set_trans(Tween.TRANS_EXPO)
	rt.parallel().tween_property(ring, "modulate:a", 0.0,          0.22)
	rt.tween_callback(ring.queue_free)

	## Particle burst
	var particles := CPUParticles2D.new()
	particles.global_position        = pos
	particles.amount                 = 20
	particles.lifetime               = 0.6
	particles.one_shot               = true
	particles.explosiveness          = 0.95
	particles.direction              = Vector2.ZERO
	particles.spread                 = 180.0
	particles.initial_velocity_min   = 80.0
	particles.initial_velocity_max   = 200.0
	particles.gravity                = Vector2.ZERO
	particles.scale_amount_min       = 3.0
	particles.scale_amount_max       = 8.0
	particles.color                  = tint
	get_tree().current_scene.add_child(particles)
	particles.emitting = true
	get_tree().create_timer(1.2).timeout.connect(
		func(): if is_instance_valid(particles): particles.queue_free()
	)

# ─── Shared helpers ────────────────────────────────────────────────────────────

func _get_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest

func _spawn_projectile(direction: Vector2) -> void:
	var proj: Area2D = projectile_scene.instantiate()
	proj.global_position = global_position
	proj.direction       = direction
	proj.damage          = get_stat("damage")
	proj.crit_chance     = get_stat("crit_chance")
	proj.crit_multiplier = get_stat("crit_multiplier")
	proj.pierce_count    = int(get_stat("pierce"))
	proj.scale_factor    = get_stat("projectile_size")
	proj.source          = self

	## Apply weapon-specific projectile properties
	if _weapon_data.has("projectile_speed"):
		proj.speed = _weapon_data["projectile_speed"]
	if _weapon_data.has("lifetime"):
		proj.lifetime = _weapon_data["lifetime"]

	## Tint projectile to match weapon colour
	proj.modulate = _weapon_data.get("tint", Color.WHITE)

	get_tree().current_scene.add_child(proj)

# ─── Pickup collection ─────────────────────────────────────────────────────────

func _update_pickup_radius() -> void:
	if pickup_shape and pickup_shape.shape:
		pickup_shape.shape.radius = get_stat("pickup_radius")

func _on_pickup_area_entered(area: Area2D) -> void:
	if area.has_method("start_magnet"):
		area.start_magnet(self)

# ─── Death ────────────────────────────────────────────────────────────────────

func _die() -> void:
	_is_dead = true
	_cleanup_weapon_state()
	died.emit()
	GameManager.on_player_died()

func _cleanup_weapon_state() -> void:
	## Free any orbit orbs so they don't outlive the run
	for orb in _orbit_orbs:
		if is_instance_valid(orb):
			orb.queue_free()
	_orbit_orbs.clear()

func reset_stats() -> void:
	stats.hp = stats.max_hp
	xp = 0.0
	level = 1
	flat_mods.clear()
	percent_mods.clear()
	_is_dead = false
	_update_pickup_radius()
