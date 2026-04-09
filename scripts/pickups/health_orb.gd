extends Area2D

## Health Orb — Dropped rarely, floats toward player when in pickup radius, heals player

@export var heal_amount: float = 15.0
@export var magnet_speed: float = 300.0
@export var magnet_acceleration: float = 800.0

var _current_speed: float = 0.0
var _target: Node2D = null
var _collected: bool = false
var _player_cache: Node2D = null

func _ready() -> void:
	## Pickups on collision layer 5
	collision_layer = 16  ## Layer 5 = bit 4 = 16
	collision_mask = 0

func _physics_process(delta: float) -> void:
	if _collected:
		return

	if _target == null or not is_instance_valid(_target):
		_current_speed = 0.0
		if _player_cache == null or not is_instance_valid(_player_cache):
			_player_cache = get_tree().get_first_node_in_group("player")
		if _player_cache != null:
			var pickup_radius: float = _player_cache.get_stat("pickup_radius") if _player_cache.has_method("get_stat") else 50.0
			if global_position.distance_to(_player_cache.global_position) <= pickup_radius:
				start_magnet(_player_cache)
		return

	## Accelerate toward player
	_current_speed = minf(_current_speed + magnet_acceleration * delta, magnet_speed)
	var direction: Vector2 = (_target.global_position - global_position).normalized()
	global_position += direction * _current_speed * delta

	## Close enough to collect
	if global_position.distance_to(_target.global_position) < 8.0:
		_collect(_target)

func start_magnet(player: Node2D) -> void:
	_target = player

func _collect(player: Node2D) -> void:
	_collected = true
	if player.has_method("heal"):
		player.heal(heal_amount)
	queue_free()
