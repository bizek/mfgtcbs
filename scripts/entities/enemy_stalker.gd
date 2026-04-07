extends "res://scripts/entities/enemy.gd"

## EnemyStalker — nearly invisible while hunting. Snaps visible with a flash when it
## closes to reveal distance. Low HP, terrifying burst damage. Atmosphere builder.

const REVEAL_DISTANCE: float = 60.0
const HIDDEN_ALPHA: float = 0.07
const REVEALED_COLOR: Color = Color(0.65, 0.82, 1.0, 1.0)

var _revealed: bool = false

func _ready() -> void:
	super._ready()
	## Start nearly invisible
	_base_modulate = Color(0.85, 0.9, 1.0, HIDDEN_ALPHA)
	if sprite:
		sprite.modulate = _base_modulate

func _physics_process(delta: float) -> void:
	if _is_dead or player_ref == null or not is_instance_valid(player_ref):
		return

	## Tick status effects and contact damage cooldown
	_contact_damage_timer = maxf(_contact_damage_timer - delta, 0.0)
	_tick_statuses(delta)

	## Shade passive: treat invisible player same as base
	if player_ref.has_method("is_invisible") and player_ref.is_invisible():
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		return

	var dist: float = global_position.distance_to(player_ref.global_position)

	## Trigger reveal
	if not _revealed and dist <= REVEAL_DISTANCE:
		_reveal()

	## Chase player — full speed whether hidden or revealed
	var direction: Vector2 = (player_ref.global_position - global_position).normalized()
	velocity = direction * move_speed * _speed_mult + knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)

	if sprite:
		sprite.play("walk")

func _reveal() -> void:
	_revealed = true
	_base_modulate = REVEALED_COLOR
	## Violent white flash, then settle to revealed color
	if sprite:
		sprite.modulate = Color(8.0, 8.0, 8.0, 1.0)
		var t := create_tween()
		t.tween_property(sprite, "modulate", REVEALED_COLOR, 0.20)
