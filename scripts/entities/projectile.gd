extends Area2D

## Projectile — Moves in a direction, damages enemies on hit, auto-frees offscreen.

@export var speed: float = 400.0
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var crit_chance: float = 0.05
var crit_multiplier: float = 1.5
var pierce_count: int = 0
var scale_factor: float = 1.0
var source: Node = null

var _hits: int = 0
var _life_timer: float = 0.0

@onready var sprite: ColorRect = $Sprite

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
	if not body.is_in_group("enemies"):
		return
	if not body.has_method("take_damage"):
		return
	
	## Use CombatManager for damage resolution
	CombatManager.resolve_hit(source if source else self, body, damage, crit_chance, crit_multiplier)
	
	_hits += 1
	if _hits > pierce_count:
		queue_free()
