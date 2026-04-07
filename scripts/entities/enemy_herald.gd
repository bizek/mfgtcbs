extends "res://scripts/entities/enemy.gd"

## EnemyHerald — fragile support enemy. Emits a visible aura that buffs all nearby enemies
## with +30% damage and +20% speed. Doesn't attack. Kill it first or suffer the consequences.

const AURA_RADIUS: float = 100.0
const BUFF_SCAN_INTERVAL: float = 0.4  ## Seconds between aura scans (not every frame)
const DAMAGE_BUFF: float = 0.30        ## +30% damage to buffed enemies
const SPEED_BUFF: float  = 0.20        ## +20% speed to buffed enemies

var _scan_timer: float = 0.0
var _buffed_enemies: Array = []
var _aura_pulse: float = 0.0
var _aura_alpha: float = 0.18

func _ready() -> void:
	super._ready()
	_base_modulate = Color(0.85, 0.25, 1.0, 1.0)
	if sprite:
		sprite.modulate = _base_modulate

func _physics_process(delta: float) -> void:
	if _is_dead or player_ref == null or not is_instance_valid(player_ref):
		return

	## Tick status effects and contact damage cooldown
	_contact_damage_timer = maxf(_contact_damage_timer - delta, 0.0)
	_tick_statuses(delta)

	## Move toward player (stays near pack naturally)
	if not (player_ref.has_method("is_invisible") and player_ref.is_invisible()):
		var direction: Vector2 = (player_ref.global_position - global_position).normalized()
		velocity = direction * move_speed * _speed_mult + knockback_velocity
	else:
		velocity = knockback_velocity

	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)

	if sprite:
		sprite.play("walk")

	## Pulse aura visual
	_aura_pulse += delta * 2.8
	_aura_alpha = 0.12 + sin(_aura_pulse) * 0.07
	queue_redraw()

	## Periodic buff scan — cheaper than scanning every frame
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = BUFF_SCAN_INTERVAL
		_update_aura_buffs()

func _draw() -> void:
	if _is_dead:
		return
	## Outer soft ring
	draw_circle(Vector2.ZERO, AURA_RADIUS, Color(0.85, 0.2, 1.0, _aura_alpha * 0.5))
	## Inner brighter ring
	draw_circle(Vector2.ZERO, AURA_RADIUS * 0.6, Color(0.9, 0.3, 1.0, _aura_alpha))

func _update_aura_buffs() -> void:
	var all_enemies: Array = get_tree().get_nodes_in_group("enemies")
	var now_nearby: Array = []

	for enemy in all_enemies:
		if enemy == self or not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) <= AURA_RADIUS:
			now_nearby.append(enemy)

	## Unbuff enemies that have left the aura
	var still_buffed: Array = []
	for enemy in _buffed_enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy in now_nearby:
			still_buffed.append(enemy)
		else:
			_unbuff_enemy(enemy)
	_buffed_enemies = still_buffed

	## Buff newly entered enemies
	for enemy in now_nearby:
		if enemy not in _buffed_enemies:
			_buff_enemy(enemy)
			_buffed_enemies.append(enemy)

func _buff_enemy(enemy: Node) -> void:
	if enemy.has_meta("herald_orig_damage"):
		return  ## Already buffed (shouldn't happen but guard anyway)
	enemy.set_meta("herald_orig_damage", enemy.contact_damage)
	enemy.set_meta("herald_orig_speed",  enemy.move_speed)
	enemy.contact_damage *= (1.0 + DAMAGE_BUFF)
	enemy.move_speed     *= (1.0 + SPEED_BUFF)

func _unbuff_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_meta("herald_orig_damage"):
		enemy.contact_damage = enemy.get_meta("herald_orig_damage")
		enemy.move_speed     = enemy.get_meta("herald_orig_speed")
		enemy.remove_meta("herald_orig_damage")
		enemy.remove_meta("herald_orig_speed")

func _die() -> void:
	## Clean up all active buffs before dying
	for enemy in _buffed_enemies:
		_unbuff_enemy(enemy)
	_buffed_enemies.clear()
	super._die()
