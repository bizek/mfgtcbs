extends CharacterBody2D

## Enemy — Base enemy script. Chases player, has health, deals contact damage, drops XP on death.

signal died(enemy: Node2D)

## Stats (overridden per enemy type via @export)
@export var max_hp: float = 30.0
@export var move_speed: float = 42.0
@export var contact_damage: float = 10.0
@export var armor: float = 0.0
@export var xp_value: float = 1.0

var hp: float
var _is_dead: bool = false
var is_elite: bool = false   ## Set true by apply_elite_modifier(); checked for mod drops
var player_ref: Node2D = null

## Knockback
var knockback_velocity: Vector2 = Vector2.ZERO

## Hit flash tween (stored so rapid hits kill the previous tween)
var _hit_tween: Tween = null

## Base sprite color — hit flash tweens back to this instead of plain white.
## Override in subclass _ready() or via apply_elite_modifier() to change resting color.
var _base_modulate: Color = Color.WHITE

## Preload pickup scenes
var xp_pickup_scene: PackedScene
var health_orb_scene: PackedScene
@export var health_drop_chance: float = 0.05 ## 5% chance to drop health orb

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hurtbox: Area2D = $Hurtbox

# ─── Status effects ───────────────────────────────────────────────────────────

## Active status effects: { "fire": {timer, ...}, "cryo": {...}, "shock": {...} }
var _statuses: Dictionary = {}

## Speed multiplier from Chilled. Separate from base move_speed.
var _speed_mult: float = 1.0

## Contact damage cooldown — prevents body_entered from dealing damage more than once per interval,
## and drives the get_overlapping_bodies() poll for sustained contact.
var _contact_damage_timer: float = 0.0
const CONTACT_DAMAGE_INTERVAL: float = 0.8

## Cryo stacks toward Frozen
var _cryo_stacks: int = 0
var _frozen: bool = false
var _freeze_timer: float = 0.0

## Burning particle emitter (child node, managed by status system)
var _burn_particles: CPUParticles2D = null

## Shock visual tween (looping, killed when shock removed)
var _shock_tween: Tween = null

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	xp_pickup_scene = load("res://scenes/pickups/xp_gem.tscn") if ResourceLoader.exists("res://scenes/pickups/xp_gem.tscn") else null
	health_orb_scene = load("res://scenes/pickups/health_orb.tscn") if ResourceLoader.exists("res://scenes/pickups/health_orb.tscn") else null

	## Find the player
	player_ref = get_tree().get_first_node_in_group("player")

	## Connect hurtbox for contact damage
	if hurtbox:
		hurtbox.body_entered.connect(_on_hurtbox_body_entered)

func _physics_process(delta: float) -> void:
	if _is_dead or player_ref == null or not is_instance_valid(player_ref):
		return

	## Tick contact damage cooldown regardless of movement state
	_contact_damage_timer = maxf(_contact_damage_timer - delta, 0.0)

	## Frozen: cannot move
	if _frozen:
		_freeze_timer -= delta
		if _freeze_timer <= 0.0:
			_frozen = false
			_speed_mult = 1.0 if not _statuses.has("cryo") else (1.0 - _statuses["cryo"].get("slow_pct", 0.3))
			if sprite:
				sprite.modulate = _base_modulate
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		return

	## Shade passive: don't chase an invisible player
	if player_ref.has_method("is_invisible") and player_ref.is_invisible():
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		return

	## Tick status effects (burning DOT, cryo duration)
	_tick_statuses(delta)

	## Chase player (chilled = reduced speed)
	var direction: Vector2 = (player_ref.global_position - global_position).normalized()
	velocity = direction * move_speed * _speed_mult + knockback_velocity
	move_and_slide()

	## Decay knockback
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)

	## Sustained contact damage: poll the hurtbox every CONTACT_DAMAGE_INTERVAL seconds.
	## Handles cases where the player stays inside the hurtbox without re-triggering body_entered.
	if _contact_damage_timer <= 0.0 and hurtbox != null:
		for body in hurtbox.get_overlapping_bodies():
			if body.is_in_group("player") and body.has_method("take_damage"):
				CombatManager.resolve_hit(self, body, contact_damage, 0.0, 1.0)
				_contact_damage_timer = CONTACT_DAMAGE_INTERVAL
				break

	if sprite:
		sprite.play("walk")

func get_armor() -> float:
	return armor

func is_dead() -> bool:
	return _is_dead

func take_damage(amount: float) -> void:
	if _is_dead:
		return

	## Shocked: chain damage to nearest OTHER enemy on this hit, then remove shocked
	if _statuses.has("shock"):
		var shock_data: Dictionary = _statuses["shock"]
		_statuses.erase("shock")
		_remove_shock_visual()
		_trigger_shock_chain(amount, shock_data)

	hp -= amount

	## Flash bright white on hit — kill any running tween first
	if sprite:
		if _hit_tween and _hit_tween.is_valid():
			_hit_tween.kill()
		sprite.modulate = Color(5.0, 5.0, 5.0, 1.0)
		_hit_tween = create_tween()
		_hit_tween.tween_property(sprite, "modulate", _base_modulate, 0.08)

	if hp <= 0.0:
		hp = 0.0
		_die()

func apply_knockback(force: Vector2) -> void:
	knockback_velocity += force

func apply_difficulty_scaling(difficulty: float) -> void:
	max_hp *= (1.0 + (difficulty - 1.0) * 0.5)
	hp = max_hp
	contact_damage *= (1.0 + (difficulty - 1.0) * 0.3)
	move_speed *= (1.0 + (difficulty - 1.0) * 0.1)

## Upgrades this enemy into an Elite: doubled HP, 1.5× damage, +3 armor, gold glow tint.
## Call after apply_difficulty_scaling so the elite bonus stacks on top of difficulty.
func apply_elite_modifier() -> void:
	max_hp *= 2.0
	hp = max_hp
	contact_damage *= 1.5
	armor += 3.0
	xp_value *= 2.5
	is_elite = true
	## Gold pulsing glow
	_base_modulate = Color(1.0, 0.75, 0.1, 1.0)
	if sprite:
		sprite.modulate = _base_modulate
		var glow_tween := create_tween().set_loops()
		glow_tween.tween_property(sprite, "modulate", Color(1.6, 1.1, 0.15, 1.0), 0.45)
		glow_tween.tween_property(sprite, "modulate", Color(0.9, 0.55, 0.05, 1.0), 0.45)

# ─── Status effect system ─────────────────────────────────────────────────────

func apply_status(effect: String, params: Dictionary) -> void:
	if _is_dead:
		return
	match effect:
		"fire":
			_statuses["fire"] = {
				"timer":      params.get("dot_duration", 3.0),
				"dot_damage": params.get("dot_damage",   3.0),
				"tick_timer": 1.0,
			}
			_spawn_burn_particles()

		"cryo":
			var freeze_stacks: int = params.get("freeze_stacks", 3)
			_cryo_stacks += 1
			if _cryo_stacks >= freeze_stacks and not _frozen:
				_apply_freeze(params.get("freeze_duration", 1.5))
			else:
				_statuses["cryo"] = {
					"timer":    params.get("duration", 3.0),
					"slow_pct": params.get("slow_pct", 0.3),
				}
				_speed_mult = 1.0 - params.get("slow_pct", 0.3)
				_apply_chilled_tint()

		"shock":
			_statuses["shock"] = {
				"chain_damage_pct": params.get("chain_damage_pct", 0.5),
				"chain_range":      params.get("chain_range",      100.0),
			}
			_spawn_shock_particles()

func _tick_statuses(delta: float) -> void:
	var to_remove: Array = []

	for effect in _statuses:
		var s: Dictionary = _statuses[effect]
		s["timer"] -= delta
		if s["timer"] <= 0.0:
			to_remove.append(effect)
			continue
		match effect:
			"fire":
				## Tick burning damage once per second
				s["tick_timer"] -= delta
				if s["tick_timer"] <= 0.0:
					s["tick_timer"] = 1.0
					if not _is_dead:
						hp -= s["dot_damage"]
						if hp <= 0.0:
							hp = 0.0
							_die()
							return

	for key in to_remove:
		_remove_status(key)

func _remove_status(effect: String) -> void:
	_statuses.erase(effect)
	match effect:
		"fire":
			if _burn_particles and is_instance_valid(_burn_particles):
				_burn_particles.emitting = false
				get_tree().create_timer(1.0).timeout.connect(
					func(): if is_instance_valid(_burn_particles): _burn_particles.queue_free()
				)
				_burn_particles = null
		"cryo":
			_cryo_stacks = 0
			_speed_mult = 1.0
			_restore_base_modulate()
		"shock":
			_remove_shock_visual()

func _apply_freeze(duration: float) -> void:
	_frozen = true
	_freeze_timer = duration
	_cryo_stacks = 0
	_statuses.erase("cryo")
	_speed_mult = 0.0
	## Bright ice-blue flash to signal freeze
	if sprite:
		if _hit_tween and _hit_tween.is_valid():
			_hit_tween.kill()
		sprite.modulate = Color(0.7, 0.9, 1.0, 1.0)

func _apply_chilled_tint() -> void:
	_base_modulate = Color(0.55, 0.78, 1.0)
	if sprite and not (_hit_tween and _hit_tween.is_valid()):
		sprite.modulate = _base_modulate

func _restore_base_modulate() -> void:
	_base_modulate = Color(1.0, 0.75, 0.1, 1.0) if is_elite else Color.WHITE
	if sprite and not (_hit_tween and _hit_tween.is_valid()):
		sprite.modulate = _base_modulate

## Spawn persistent orange particle emitter child for burning visual
func _spawn_burn_particles() -> void:
	if _burn_particles and is_instance_valid(_burn_particles):
		return  ## Already burning
	var p := CPUParticles2D.new()
	p.amount = 6
	p.lifetime = 0.5
	p.one_shot = false
	p.explosiveness = 0.0
	p.direction = Vector2(0.0, -1.0)
	p.spread = 40.0
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 28.0
	p.gravity = Vector2(0.0, -10.0)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color = Color(1.0, 0.42, 0.06, 0.9)
	add_child(p)
	p.emitting = true
	_burn_particles = p

## Brief yellow spark burst — applied on shock application
func _spawn_shock_particles() -> void:
	var p := CPUParticles2D.new()
	p.amount = 8
	p.lifetime = 0.3
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 55.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(1.0, 0.92, 0.15, 1.0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(0.5).timeout.connect(func(): if is_instance_valid(p): p.queue_free())
	## Sustained yellow shimmer while shocked
	if sprite:
		if _shock_tween and _shock_tween.is_valid():
			_shock_tween.kill()
		_shock_tween = create_tween().set_loops()
		_shock_tween.tween_property(sprite, "modulate:g", 1.3, 0.12)
		_shock_tween.tween_property(sprite, "modulate:g", 0.85, 0.12)

func _remove_shock_visual() -> void:
	if _shock_tween and _shock_tween.is_valid():
		_shock_tween.kill()
		_shock_tween = null
	if sprite and not (_hit_tween and _hit_tween.is_valid()):
		sprite.modulate = _base_modulate

## Triggered by take_damage when shocked. Chains damage to nearest other enemy.
func _trigger_shock_chain(source_damage: float, shock_data: Dictionary) -> void:
	var chain_range: float  = shock_data.get("chain_range",      100.0)
	var chain_pct:   float  = shock_data.get("chain_damage_pct",   0.5)
	var chain_dmg:   float  = source_damage * chain_pct
	var nearest: Node2D = null
	var nearest_dist: float = chain_range

	for other in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(other) or other == self:
			continue
		var dist: float = global_position.distance_to(other.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = other

	if nearest != null and nearest.has_method("take_damage"):
		nearest.take_damage(chain_dmg)
		_spawn_shock_chain_visual(nearest.global_position)

func _spawn_shock_chain_visual(target_pos: Vector2) -> void:
	var line := Line2D.new()
	line.top_level = true
	line.add_point(global_position)
	line.add_point(target_pos)
	line.width = 2.5
	line.default_color = Color(1.0, 0.95, 0.2, 0.9)
	get_tree().current_scene.add_child(line)
	var t := line.create_tween()
	t.tween_property(line, "modulate:a", 0.0, 0.18)
	t.tween_callback(line.queue_free)

func _die() -> void:
	_is_dead = true
	died.emit(self)

	## Notify managers
	GameManager.register_kill()
	EnemySpawnManager.on_enemy_died()

	## Spawn burst effect before freeing
	_spawn_death_effect()

	## Drop pickups
	_drop_xp()
	_drop_health()

	## Remove from scene
	queue_free()

func _spawn_death_effect() -> void:
	var particles := CPUParticles2D.new()
	particles.global_position = global_position
	particles.amount = 8
	particles.lifetime = 0.45
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 180.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 130.0
	particles.gravity = Vector2(0.0, 120.0)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1.0, 0.5, 0.1, 1.0)
	get_tree().current_scene.add_child(particles)
	particles.emitting = true
	## Auto-free after particles finish
	get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

func _drop_xp() -> void:
	if xp_pickup_scene == null:
		return
	var pickup: Node2D = xp_pickup_scene.instantiate()
	pickup.global_position = global_position
	pickup.xp_value = xp_value
	get_tree().current_scene.add_child(pickup)

func _drop_health() -> void:
	if health_orb_scene == null:
		return
	if randf() > health_drop_chance:
		return
	var orb: Node2D = health_orb_scene.instantiate()
	orb.global_position = global_position
	get_tree().current_scene.add_child(orb)

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if _is_dead:
		return
	if body.is_in_group("player") and body.has_method("take_damage") and _contact_damage_timer <= 0.0:
		CombatManager.resolve_hit(self, body, contact_damage, 0.0, 1.0)
		_contact_damage_timer = CONTACT_DAMAGE_INTERVAL
