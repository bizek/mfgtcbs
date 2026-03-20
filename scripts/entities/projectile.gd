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

## ── Internal state ────────────────────────────────────────────────────────────
var _hits: int = 0
var _life_timer: float = 0.0
var _hit_enemies: Array = []   ## For pierce: skip enemies already hit by THIS projectile

func _ready() -> void:
	## Apply scale
	if scale_factor != 1.0:
		scale = Vector2(scale_factor, scale_factor)

	## Set rotation to face direction
	rotation = direction.angle()

	## Connect body entered for hitting enemies
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	## Move in direction
	global_position += direction * speed * delta

	## Lifetime check
	_life_timer += delta
	if _life_timer >= lifetime:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	## Walls are StaticBody2D — stop on contact
	if body is StaticBody2D:
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

# ─── Explosive AOE ─────────────────────────────────────────────────────────────

func _fire_explosion(pos: Vector2) -> void:
	var aoe_dmg: float = damage * mod_explosive_damage_mult

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if pos.distance_to(enemy.global_position) <= mod_explosive_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(aoe_dmg)

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
