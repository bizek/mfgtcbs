extends Area2D

## XP Gem — Dropped by enemies, floats toward player when in pickup radius, grants XP

@export var xp_value: float = 1.0
@export var magnet_speed: float = 350.0
@export var magnet_acceleration: float = 900.0

var _current_speed: float = 0.0
var _target: Node2D = null
var _collected: bool = false

## Cached player for poll-based detection
var _player_cache: Node2D = null

func _ready() -> void:
	## Pickups on collision layer 5
	collision_layer = 16  ## Layer 5 = bit 4 = 16
	collision_mask = 0

func _physics_process(delta: float) -> void:
	if _collected:
		return

	## Poll-based magnet: find player and check pickup radius each frame if not yet magnetized
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
	if player.has_method("add_xp"):
		player.add_xp(xp_value)
	queue_free()
