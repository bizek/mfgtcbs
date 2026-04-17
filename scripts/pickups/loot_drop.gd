extends Area2D

## LootDrop — A shiny loot pickup that drops from enemies.
## Spawns with a beam of light effect, magnetizes to the player, and adds
## to carried loot (raising Instability) on pickup.

@export var value: float = 15.0
var size: String = "medium"  ## "small", "medium", "large" — affects visuals + instability

var _magnetized: bool = false
var _target: Node2D = null
var _beam_alpha: float = 1.0
var _age: float = 0.0
var _collected: bool = false

const BEAM_DURATION: float = 1.8
const MAGNET_SPEED: float = 220.0

func _ready() -> void:
	collision_layer = 16  ## Layer 5 = pickups
	collision_mask = 1    ## Detects layer 1 = player body
	monitoring = true

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_age += delta

	## Fade the beam of light after BEAM_DURATION seconds
	if _age < BEAM_DURATION:
		_beam_alpha = 1.0 - (_age / BEAM_DURATION)
	else:
		_beam_alpha = 0.0

	queue_redraw()

	## Move toward player when magnetized
	if _magnetized and is_instance_valid(_target):
		var dir := (_target.global_position - global_position).normalized()
		global_position += dir * MAGNET_SPEED * delta
		if global_position.distance_to(_target.global_position) < 6.0:
			_collect()

func _draw() -> void:
	## Beam of light — tall thin column above the orb, fades out
	if _beam_alpha > 0.01:
		draw_rect(Rect2(-2.0, -54.0, 4.0, 52.0), Color(1.0, 0.88, 0.2, _beam_alpha * 0.55))
		## Slightly wider glow behind the beam
		draw_rect(Rect2(-4.0, -54.0, 8.0, 52.0), Color(1.0, 0.85, 0.1, _beam_alpha * 0.18))

	## Gold orb — size varies by resource size
	var r: float = 3.0 if size == "small" else (5.0 if size == "medium" else 7.0)
	var hr: float = r * 0.5
	draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), Color(1.0, 0.82, 0.08, 1.0))
	draw_rect(Rect2(-hr, -hr, hr * 2.0, hr * 2.0), Color(1.0, 0.97, 0.65, 1.0))

## Called by the player's PickupCollector Area2D when this enters pickup radius
func start_magnet(target: Node2D) -> void:
	_magnetized = true
	_target = target

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_collect()

func _collect() -> void:
	if _collected:
		return
	_collected = true
	GameManager.add_loot(value)
	var inst_amount: float = float(LootTables.RESOURCE_INSTABILITY.get(size, 3))
	GameManager.add_instability(inst_amount)
	var size_name: String = size.capitalize()
	GameManager.run_loot_manifest.append({ "type": "resource", "name": size_name + " Resource", "value": value, "rarity": size })
	queue_free()
