extends Area2D

## EnemyProjectile — fired by Caster enemies. Slow, visible, dodgeable.
## Drawn procedurally (no texture needed). Hits player on contact.

@export var speed: float = 90.0
@export var lifetime: float = 3.5

var direction: Vector2 = Vector2.RIGHT
var damage: float = 8.0
var source: Node = null

var _life_timer: float = 0.0

func _ready() -> void:
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_life_timer += delta
	if _life_timer >= lifetime:
		queue_free()

func _draw() -> void:
	## Outer glow halo
	draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.35, 0.0, 0.22))
	## Mid ring
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.5, 0.1, 0.7))
	## Bright core
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.55, 0.12, 1.0))
	## Hot centre point
	draw_circle(Vector2.ZERO, 1.4, Color(1.0, 0.95, 0.75, 1.0))

func _on_body_entered(body: Node2D) -> void:
	## Walls are StaticBody2D — stop on contact
	if body is StaticBody2D:
		queue_free()
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("take_damage"):
		return
	CombatManager.resolve_hit(source if source != null else self, body, damage, 0.0, 1.0)
	queue_free()
