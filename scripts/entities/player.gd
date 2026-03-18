extends CharacterBody2D

## Player — Movement, auto-fire weapon, stats, health, leveling

signal health_changed(current: float, maximum: float)
signal xp_changed(current: float, needed: float)
signal leveled_up(new_level: int)
signal died

## Base stats (The Drifter)
var stats: Dictionary = {
	"max_hp": 100.0,
	"hp": 100.0,
	"armor": 0.0,
	"move_speed": 260.0,
	"damage": 100.0,
	"attack_speed": 1.0,
	"crit_chance": 0.05,
	"crit_multiplier": 1.5,
	"pickup_radius": 50.0,
	"projectile_count": 1,
	"pierce": 0,
	"projectile_size": 1.0,
	"extraction_speed": 1.0,
}

## Stat modifiers from upgrades
var flat_mods: Dictionary = {}
var percent_mods: Dictionary = {}

## XP and leveling
var xp: float = 0.0
var level: int = 1
var xp_base: float = 10.0
var xp_growth: float = 0.3

## Weapon
var fire_timer: float = 0.0
var projectile_scene: PackedScene

## State
var _is_dead: bool = false

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var pickup_area: Area2D = $PickupCollector
@onready var pickup_shape: CollisionShape2D = $PickupCollector/CollisionShape

func _ready() -> void:
	add_to_group("player")
	projectile_scene = preload("res://scenes/projectile.tscn")
	_update_pickup_radius()
	health_changed.emit(stats.hp, get_stat("max_hp"))
	pickup_area.area_entered.connect(_on_pickup_area_entered)

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	## Movement
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()
	
	## Acceleration-based movement: 0 → max speed in ~0.1 seconds
	var target_velocity: Vector2 = input_dir * get_stat("move_speed")
	velocity = velocity.move_toward(target_velocity, 2600.0 * delta)
	move_and_slide()
	if sprite:
		if input_dir.x != 0:
			sprite.flip_h = input_dir.x < 0
		if input_dir.length_squared() > 0:
			sprite.play("walk")
		else:
			sprite.play("idle")
	
	## Auto-fire weapon
	fire_timer -= delta
	if fire_timer <= 0.0:
		_fire_weapon()
		fire_timer = 1.0 / get_stat("attack_speed")

func get_stat(stat_name: String) -> float:
	var base: float = stats.get(stat_name, 0.0)
	var flat: float = flat_mods.get(stat_name, 0.0)
	var pct: float = percent_mods.get(stat_name, 0.0)
	return (base + flat) * (1.0 + pct)

func get_armor() -> float:
	return get_stat("armor")

func is_dead() -> bool:
	return _is_dead

func take_damage(amount: float) -> void:
	if _is_dead:
		return
	stats.hp -= amount
	health_changed.emit(stats.hp, get_stat("max_hp"))
	
	## Flash red on hit
	sprite.modulate = Color.RED
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	
	if stats.hp <= 0.0:
		stats.hp = 0.0
		_die()

func heal(amount: float) -> void:
	if _is_dead:
		return
	stats.hp = minf(stats.hp + amount, get_stat("max_hp"))
	health_changed.emit(stats.hp, get_stat("max_hp"))

func add_xp(amount: float) -> void:
	if _is_dead:
		return
	xp += amount
	var xp_needed := _xp_to_next_level()
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		leveled_up.emit(level)
		xp_needed = _xp_to_next_level()
	xp_changed.emit(xp, _xp_to_next_level())

func apply_stat_upgrade(upgrade: Dictionary) -> void:
	var stat_name: String = upgrade.stat
	var value: float = upgrade.value
	if upgrade.type == "flat":
		flat_mods[stat_name] = flat_mods.get(stat_name, 0.0) + value
		## If max_hp increased, also heal that amount
		if stat_name == "max_hp":
			heal(value)
	elif upgrade.type == "percent":
		percent_mods[stat_name] = percent_mods.get(stat_name, 0.0) + value
	
	## Update pickup radius if changed
	if stat_name == "pickup_radius":
		_update_pickup_radius()

func _xp_to_next_level() -> float:
	return xp_base * (1.0 + (level - 1) * xp_growth)

func _fire_weapon() -> void:
	if projectile_scene == null:
		return
	
	## Find nearest enemy
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	
	if nearest == null:
		return
	
	var direction: Vector2 = (nearest.global_position - global_position).normalized()
	var proj_count: int = int(get_stat("projectile_count"))
	
	## Spread multiple projectiles in a small arc
	for i in range(proj_count):
		var angle_offset: float = 0.0
		if proj_count > 1:
			angle_offset = deg_to_rad(-10.0 + 20.0 * (float(i) / float(proj_count - 1)))
		var dir: Vector2 = direction.rotated(angle_offset)
		_spawn_projectile(dir)

func _spawn_projectile(direction: Vector2) -> void:
	var proj: Area2D = projectile_scene.instantiate()
	proj.global_position = global_position
	proj.direction = direction
	proj.damage = get_stat("damage")
	proj.crit_chance = get_stat("crit_chance")
	proj.crit_multiplier = get_stat("crit_multiplier")
	proj.pierce_count = int(get_stat("pierce"))
	proj.scale_factor = get_stat("projectile_size")
	proj.source = self
	get_tree().current_scene.add_child(proj)

func _update_pickup_radius() -> void:
	if pickup_shape and pickup_shape.shape:
		pickup_shape.shape.radius = get_stat("pickup_radius")

func _on_pickup_area_entered(area: Area2D) -> void:
	if area.has_method("start_magnet"):
		area.start_magnet(self)

func _die() -> void:
	_is_dead = true
	died.emit()
	GameManager.on_player_died()

func reset_stats() -> void:
	stats.hp = stats.max_hp
	xp = 0.0
	level = 1
	flat_mods.clear()
	percent_mods.clear()
	_is_dead = false
	_update_pickup_radius()
