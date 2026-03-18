extends CharacterBody2D

## Enemy — Base enemy script. Chases player, has health, deals contact damage, drops XP on death.

signal died(enemy: Node2D)

## Stats (overridden per enemy type via @export)
@export var max_hp: float = 30.0
@export var move_speed: float = 60.0
@export var contact_damage: float = 10.0
@export var armor: float = 0.0
@export var xp_value: float = 1.0

var hp: float
var _is_dead: bool = false
var player_ref: Node2D = null

## Knockback
var knockback_velocity: Vector2 = Vector2.ZERO

## Hit flash tween (stored so rapid hits kill the previous tween)
var _hit_tween: Tween = null

## Preload pickup scenes
var xp_pickup_scene: PackedScene
var health_orb_scene: PackedScene
@export var health_drop_chance: float = 0.05 ## 5% chance to drop health orb

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hurtbox: Area2D = $Hurtbox

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

	## Chase player
	var direction: Vector2 = (player_ref.global_position - global_position).normalized()
	velocity = direction * move_speed + knockback_velocity
	move_and_slide()

	## Decay knockback
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)

	if sprite:
		sprite.play("walk")

func get_armor() -> float:
	return armor

func is_dead() -> bool:
	return _is_dead

func take_damage(amount: float) -> void:
	if _is_dead:
		return
	hp -= amount

	## Flash bright white on hit — kill any running tween first
	if sprite:
		if _hit_tween and _hit_tween.is_valid():
			_hit_tween.kill()
		sprite.modulate = Color(5.0, 5.0, 5.0, 1.0)
		_hit_tween = create_tween()
		_hit_tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)

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
	if body.is_in_group("player") and body.has_method("take_damage"):
		## Use CombatManager for damage resolution
		CombatManager.resolve_hit(self, body, contact_damage, 0.0, 1.0)
