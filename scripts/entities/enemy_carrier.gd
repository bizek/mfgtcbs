extends "res://scripts/entities/enemy.gd"

## EnemyCarrier — spawns at arena edge and flees FROM the player toward the opposite side.
## Drops valuable loot on death. Despawns silently if it escapes the arena bounds.
## Purpose: chasing it pulls you out of position — risk/reward extraction tension.

var _loot_drop_scene: PackedScene = null
var _loot_value: float = 45.0  ## High instability weight — worth extracting with

func _ready() -> void:
	super._ready()
	add_to_group("carriers")
	_base_modulate = Color(1.0, 0.85, 0.1, 1.0)
	if sprite:
		sprite.modulate = _base_modulate
	if ResourceLoader.exists("res://scenes/pickups/loot_drop.tscn"):
		_loot_drop_scene = load("res://scenes/pickups/loot_drop.tscn")
	_spawn_trail_particles()

func _physics_process(delta: float) -> void:
	if _is_dead or player_ref == null or not is_instance_valid(player_ref):
		return

	## Tick status effects (fire DOT, cryo, etc.) and contact damage cooldown
	_contact_damage_timer = maxf(_contact_damage_timer - delta, 0.0)
	_tick_statuses(delta)

	## Run away from player
	var dir: Vector2 = (global_position - player_ref.global_position).normalized()
	velocity = dir * move_speed * _speed_mult + knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)

	if sprite:
		sprite.play("walk")

	## Despawn silently when it escapes the arena — player missed it
	var bounds: Rect2 = EnemySpawnManager.arena_bounds
	if not bounds.has_point(global_position):
		_despawn_escaped()

func _despawn_escaped() -> void:
	_is_dead = true
	EnemySpawnManager.on_enemy_despawned()
	queue_free()

func _die() -> void:
	## Scatter valuable loot before normal death handling
	_drop_carrier_loot()
	super._die()

func _drop_carrier_loot() -> void:
	if _loot_drop_scene == null:
		return
	var count: int = randi_range(2, 3)
	for i in range(count):
		var drop: Area2D = _loot_drop_scene.instantiate()
		var offset := Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))
		drop.global_position = global_position + offset
		drop.value = _loot_value / float(count)
		get_tree().current_scene.add_child(drop)

func _spawn_trail_particles() -> void:
	## Continuous golden sparkle trail so the carrier is readable at a glance
	var p := CPUParticles2D.new()
	p.amount = 8
	p.lifetime = 0.7
	p.one_shot = false
	p.explosiveness = 0.0
	p.direction = Vector2(0.0, -1.0)
	p.spread = 180.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 20.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(1.0, 0.85, 0.2, 0.9)
	add_child(p)
	p.emitting = true
