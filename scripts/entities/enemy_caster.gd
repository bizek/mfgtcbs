extends "res://scripts/entities/enemy.gd"

## EnemyCaster — moves toward player until in preferred range, then stops and fires
## slow projectiles every 2 seconds. Priority kill target: it forces movement.

const PREFERRED_RANGE: float = 175.0
const FIRE_INTERVAL: float = 2.0

var _fire_timer: float = 1.2  ## Slight delay before first shot
var _projectile_scene: PackedScene = null

func _ready() -> void:
	super._ready()
	_base_modulate = Color(0.45, 0.5, 1.0, 1.0)
	if sprite:
		sprite.modulate = _base_modulate
	if ResourceLoader.exists("res://scenes/projectiles/enemy_projectile.tscn"):
		_projectile_scene = load("res://scenes/projectiles/enemy_projectile.tscn")

func _physics_process(delta: float) -> void:
	if _is_dead or player_ref == null or not is_instance_valid(player_ref):
		return

	## Shade passive: don't react to an invisible player
	if player_ref.has_method("is_invisible") and player_ref.is_invisible():
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		return

	var dist: float = global_position.distance_to(player_ref.global_position)

	if dist > PREFERRED_RANGE:
		## Close the gap
		var dir: Vector2 = (player_ref.global_position - global_position).normalized()
		velocity = dir * move_speed + knockback_velocity
	else:
		## Hold position — only knockback moves us
		velocity = knockback_velocity

	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)

	if sprite:
		sprite.play("walk" if velocity.length() > 5.0 else "idle")

	## Fire cooldown — only shoot when roughly in range
	_fire_timer -= delta
	if _fire_timer <= 0.0 and dist <= PREFERRED_RANGE * 1.3:
		_fire_timer = FIRE_INTERVAL
		_fire_projectile()

func _fire_projectile() -> void:
	if _projectile_scene == null or player_ref == null or not is_instance_valid(player_ref):
		return
	var proj: Area2D = _projectile_scene.instantiate()
	proj.global_position = global_position
	proj.direction = (player_ref.global_position - global_position).normalized()
	proj.damage = contact_damage
	proj.source = self
	get_tree().current_scene.add_child(proj)
