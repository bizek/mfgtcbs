extends Area2D

## Projectile — Moves in a direction, damages enemies on hit, auto-frees offscreen.
## Supports mod effects: pierce, chain, explosive, elemental status, lifesteal.

@export var speed: float = 400.0
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var crit_chance: float = 0.05
var crit_multiplier: float = 1.5
var pierce_count: int = 0
var scale_factor: float = 1.0
var source: Node = null

## ── Mod effect properties ─────────────────────────────────────────────────────

## Chain: on hit, bounce to 1 nearby enemy for reduced damage
var mod_chain: bool = false
var mod_chain_range: float = 120.0
var mod_chain_damage_mult: float = 0.6
var is_chain_projectile: bool = false  ## Chain projectiles don't chain again

## Explosive: on hit, AOE burst at impact point
var mod_explosive: bool = false
var mod_explosive_radius: float = 40.0
var mod_explosive_damage_mult: float = 0.3

## Elemental status: "fire", "cryo", "shock" — applied to enemies on hit
var mod_status: String = ""
var mod_status_params: Dictionary = {}

## Lifesteal: percentage of damage dealt returned as HP to source
var mod_lifesteal: float = 0.0

## Gravity: steer toward nearest enemy each frame
var mod_gravity: bool = false
var mod_gravity_pull: float = 300.0
var mod_gravity_range: float = 150.0

## Ricochet: reflect off arena walls instead of despawning
var mod_ricochet: bool = false
var _bounces_remaining: int = 0
## Inner playable limits: ARENA_HALF_(W/H) - WALL_THICKNESS (800-48, 600-48)
const _BOUNCE_LIMIT_X: float = 752.0
const _BOUNCE_LIMIT_Y: float = 552.0

## Split: on death (last hit or expiry), spawn N smaller projectiles in a fan
var mod_split: bool = false
var mod_split_count: int = 3
var mod_split_damage_mult: float = 0.4
var _is_split: bool = false   ## Split projectiles never split again

## ── Internal state ────────────────────────────────────────────────────────────
var _hits: int = 0
var _life_timer: float = 0.0
var _hit_enemies: Array = []   ## For pierce: skip enemies already hit by THIS projectile
var _has_split: bool = false   ## Prevent double-split if both hit and expiry fire close together

func _ready() -> void:
	## Apply scale
	if scale_factor != 1.0:
		scale = Vector2(scale_factor, scale_factor)

	## Set rotation to face direction
	rotation = direction.angle()

	## Connect body entered for hitting enemies
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	## Gravity steering — bend direction toward nearest enemy in range
	if mod_gravity:
		var target: Node2D = _find_nearest_in_range(global_position, mod_gravity_range)
		if target != null:
			var to_target: Vector2 = (target.global_position - global_position).normalized()
			direction = (direction + to_target * mod_gravity_pull * delta).normalized()
			rotation = direction.angle()

	## Move in direction
	global_position += direction * speed * delta

	## Ricochet: bounds check after move, reflect off walls
	if mod_ricochet and _bounces_remaining > 0:
		var bounced: bool = false
		if abs(global_position.x) >= _BOUNCE_LIMIT_X:
			direction.x = -direction.x
			global_position.x = sign(global_position.x) * _BOUNCE_LIMIT_X
			bounced = true
		if abs(global_position.y) >= _BOUNCE_LIMIT_Y:
			direction.y = -direction.y
			global_position.y = sign(global_position.y) * _BOUNCE_LIMIT_Y
			bounced = true
		if bounced:
			_bounces_remaining -= 1
			rotation = direction.angle()
			_spawn_ricochet_flash()

	## Lifetime check
	_life_timer += delta
	if _life_timer >= lifetime:
		_try_split()
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	## Walls are StaticBody2D — bounce if ricochet active, otherwise stop
	if body is StaticBody2D:
		if mod_ricochet and _bounces_remaining > 0:
			return  ## _physics_process handles the reflection via bounds check
		_try_split()
		queue_free()
		return
	if not body.is_in_group("enemies"):
		return
	if not body.has_method("take_damage"):
		return
	## Don't hit the same enemy twice from the same projectile instance (pierce)
	if body in _hit_enemies:
		return
	_hit_enemies.append(body)

	## Use CombatManager for damage resolution
	CombatManager.resolve_hit(source if source else self, body, damage, crit_chance, crit_multiplier)

	## Lifesteal: heal source for a % of the raw damage (pre-armor approximation)
	if mod_lifesteal > 0.0 and is_instance_valid(source) and source.has_method("heal"):
		source.heal(damage * mod_lifesteal)

	## Apply elemental status
	if not mod_status.is_empty() and body.has_method("apply_status"):
		body.apply_status(mod_status, mod_status_params)

	## Chain bounce — skip if this IS already a chain projectile
	if mod_chain and not is_chain_projectile and is_instance_valid(body):
		_fire_chain_bounce(body)

	## Explosive AOE at impact point
	if mod_explosive and is_instance_valid(body):
		_fire_explosion(body.global_position)

	_hits += 1
	if _hits > pierce_count:
		_try_split()
		queue_free()

# ─── Chain bounce ──────────────────────────────────────────────────────────────

func _fire_chain_bounce(origin_enemy: Node2D) -> void:
	var nearest: Node2D = null
	var nearest_dist: float = mod_chain_range

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy == origin_enemy:
			continue
		var dist: float = origin_enemy.global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	if nearest == null:
		return

	## Spawn a reduced-damage chain projectile
	var chain_proj: Area2D = duplicate()
	chain_proj.is_chain_projectile = true
	chain_proj.mod_chain = false     ## Chains don't chain
	chain_proj.mod_explosive = mod_explosive
	chain_proj.mod_status = mod_status
	chain_proj.mod_status_params = mod_status_params
	chain_proj.mod_lifesteal = mod_lifesteal
	chain_proj.damage = damage * mod_chain_damage_mult
	chain_proj.pierce_count = 0
	chain_proj._hits = 0
	chain_proj._hit_enemies = [origin_enemy]
	chain_proj._life_timer = 0.0
	chain_proj.global_position = origin_enemy.global_position
	chain_proj.direction = (nearest.global_position - origin_enemy.global_position).normalized()

	get_tree().current_scene.add_child(chain_proj)

	## Draw a brief arc line from origin to chain target
	var line := Line2D.new()
	line.top_level = true
	line.add_point(origin_enemy.global_position)
	line.add_point(nearest.global_position)
	line.width = 1.5
	line.default_color = Color(0.35, 0.75, 1.0, 0.75)
	get_tree().current_scene.add_child(line)
	var t := line.create_tween()
	t.tween_property(line, "modulate:a", 0.0, 0.14)
	t.tween_callback(line.queue_free)

# ─── Split ─────────────────────────────────────────────────────────────────────

func _try_split() -> void:
	if not mod_split or _is_split or _has_split:
		return
	_has_split = true
	_fire_split()

func _fire_split() -> void:
	var arc_rad: float = deg_to_rad(90.0)
	var base_angle: float = direction.angle()

	for i in range(mod_split_count):
		var angle: float
		if mod_split_count > 1:
			angle = base_angle - arc_rad * 0.5 + arc_rad * float(i) / float(mod_split_count - 1)
		else:
			angle = base_angle

		var split_proj: Area2D = duplicate()
		split_proj._is_split         = true
		split_proj.mod_split         = false
		split_proj._has_split        = false
		split_proj._hits             = 0
		split_proj._hit_enemies      = []
		split_proj._life_timer       = 0.0
		split_proj.damage            = damage * mod_split_damage_mult
		split_proj.lifetime          = maxf((lifetime - _life_timer) * 0.5, 0.5)
		split_proj.direction         = Vector2.from_angle(angle)
		split_proj.global_position   = global_position
		get_tree().current_scene.add_child(split_proj)

	## Brief fan-burst visual
	var tint: Color = modulate
	for i in range(mod_split_count):
		var angle: float
		if mod_split_count > 1:
			angle = base_angle - arc_rad * 0.5 + arc_rad * float(i) / float(mod_split_count - 1)
		else:
			angle = base_angle
		var ray_end: Vector2 = global_position + Vector2.from_angle(angle) * 18.0
		var line := Line2D.new()
		line.top_level = true
		line.add_point(global_position)
		line.add_point(ray_end)
		line.width = 2.0
		line.default_color = Color(tint.r, tint.g, tint.b, 0.85)
		get_tree().current_scene.add_child(line)
		var t := line.create_tween()
		t.tween_property(line, "modulate:a", 0.0, 0.12)
		t.tween_callback(line.queue_free)

# ─── Ricochet flash ────────────────────────────────────────────────────────────

func _spawn_ricochet_flash() -> void:
	var tint: Color = modulate
	var spark := CPUParticles2D.new()
	spark.global_position      = global_position
	spark.amount               = 4
	spark.lifetime             = 0.18
	spark.one_shot             = true
	spark.explosiveness        = 1.0
	spark.direction            = Vector2.ZERO
	spark.spread               = 180.0
	spark.initial_velocity_min = 30.0
	spark.initial_velocity_max = 80.0
	spark.gravity              = Vector2.ZERO
	spark.scale_amount_min     = 2.0
	spark.scale_amount_max     = 4.0
	spark.color                = Color(tint.r, tint.g, tint.b, 1.0)
	get_tree().current_scene.add_child(spark)
	spark.emitting = true
	get_tree().create_timer(0.4).timeout.connect(func(): if is_instance_valid(spark): spark.queue_free())

# ─── Gravity helpers ───────────────────────────────────────────────────────────

func _find_nearest_in_range(pos: Vector2, range_px: float) -> Node2D:
	## Prefer SpatialGrid via source (player) for O(1) lookup
	if is_instance_valid(source) and source.get("enemy_grid") != null:
		var candidates: Array = source.enemy_grid.get_nearby_in_range(pos, range_px)
		var nearest: Node2D = null
		var nearest_dist: float = range_px + 1.0
		for c in candidates:
			if not is_instance_valid(c):
				continue
			var d: float = pos.distance_to(c.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = c
		return nearest
	## Fallback: linear scan
	var nearest: Node2D = null
	var nearest_dist: float = range_px
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var d: float = pos.distance_to(enemy.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = enemy
	return nearest

# ─── Explosive AOE ─────────────────────────────────────────────────────────────

func _fire_explosion(pos: Vector2) -> void:
	var aoe_dmg: float = damage * mod_explosive_damage_mult

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if pos.distance_to(enemy.global_position) <= mod_explosive_radius:
			if enemy.has_method("take_damage"):
				CombatManager.resolve_secondary_hit(source if source else self, enemy, aoe_dmg)

	## Orange burst visual
	var ring := ColorRect.new()
	ring.color = Color(1.0, 0.48, 0.08, 0.55)
	ring.size = Vector2(mod_explosive_radius * 2.0, mod_explosive_radius * 2.0)
	ring.position = pos - Vector2(mod_explosive_radius, mod_explosive_radius)
	ring.top_level = true
	get_tree().current_scene.add_child(ring)

	var rt := ring.create_tween()
	rt.tween_property(ring, "scale",       Vector2(1.6, 1.6), 0.18).set_trans(Tween.TRANS_EXPO)
	rt.parallel().tween_property(ring, "modulate:a", 0.0, 0.18)
	rt.tween_callback(ring.queue_free)

	## Spark particles
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.amount = 10
	p.lifetime = 0.4
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 120.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = Color(1.0, 0.55, 0.10, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(0.8).timeout.connect(func(): if is_instance_valid(p): p.queue_free())
