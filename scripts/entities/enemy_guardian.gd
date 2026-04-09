extends "res://scripts/entities/enemy.gd"

## EnemyGuardian — Miniboss-tier enemy that guards an extraction point.
## Uses GuardianData for base stats via setup_from_enemy_def().
## Game-specific overrides: custom sprite, keystone drops, guardian_killed signal.

signal guardian_killed

## Set these BEFORE adding to the scene tree so _ready() picks them up.
var phase_multiplier: float = 1.0
var spawn_count: int = 0

var _guardian_sprite: AnimatedSprite2D = null
var _guardian_hurtbox: Area2D = null


func _ready() -> void:
	# Apply difficulty scaling based on phase/spawn count
	var effective_mult: float = phase_multiplier * (1.0 + spawn_count * 0.35)
	max_hp *= effective_mult
	contact_damage *= effective_mult
	health.setup(max_hp)

	_build_collision_shape()
	_build_sprite()
	_build_hurtbox()

	sprite = _guardian_sprite
	hurtbox = _guardian_hurtbox

	super._ready()

	add_to_group("guardians")
	if sprite:
		sprite.modulate = _base_modulate
	collision_layer = 2
	collision_mask = 3


func _build_collision_shape() -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 28)
	cs.shape = rect
	add_child(cs)


func _build_sprite() -> void:
	_guardian_sprite = AnimatedSprite2D.new()
	_guardian_sprite.name = "Sprite"
	_guardian_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_guardian_sprite.modulate = _base_modulate

	var frames := SpriteFrames.new()
	frames.clear_all()

	const CYCLOP_BASE: String = "res://assets/minifantasy/Minifantasy_Creatures_v3.3_Commercial_Version/Minifantasy_Creatures_Assets/Monsters/Cyclop/"
	var idle_path: String = CYCLOP_BASE + "CyclopIdle.png"
	var walk_path: String = CYCLOP_BASE + "CyclopWalk.png"

	if ResourceLoader.exists(idle_path):
		var sheet: Texture2D = load(idle_path)
		frames.add_animation("idle")
		frames.set_animation_loop("idle", true)
		frames.set_animation_speed("idle", 6.0)
		for i in range(8):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * 64, 0, 64, 128)
			atlas.filter_clip = true
			frames.add_frame("idle", atlas)

	if ResourceLoader.exists(walk_path):
		var sheet: Texture2D = load(walk_path)
		frames.add_animation("walk")
		frames.set_animation_loop("walk", true)
		frames.set_animation_speed("walk", 8.0)
		for i in range(3):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * 64, 0, 64, 128)
			atlas.filter_clip = true
			frames.add_frame("walk", atlas)

	_guardian_sprite.sprite_frames = frames
	_guardian_sprite.scale = Vector2(0.65, 0.65)
	_guardian_sprite.offset = Vector2(0, -26)
	_guardian_sprite.play("idle")
	add_child(_guardian_sprite)

	var p := CPUParticles2D.new()
	p.amount = 12
	p.lifetime = 0.9
	p.one_shot = false
	p.explosiveness = 0.0
	p.direction = Vector2(0.0, -1.0)
	p.spread = 65.0
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 35.0
	p.gravity = Vector2(0.0, -12.0)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color = Color(0.90, 0.20, 0.06, 0.75)
	p.emitting = true
	add_child(p)

	var breathe := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	breathe.tween_property(self, "scale", Vector2(1.06, 1.06), 1.1)
	breathe.tween_property(self, "scale", Vector2(1.0, 1.0), 1.1)


func _build_hurtbox() -> void:
	_guardian_hurtbox = Area2D.new()
	_guardian_hurtbox.name = "Hurtbox"
	_guardian_hurtbox.collision_layer = 2
	_guardian_hurtbox.collision_mask = 1
	var hcs := CollisionShape2D.new()
	var hrect := RectangleShape2D.new()
	hrect.size = Vector2(32, 32)
	hcs.shape = hrect
	_guardian_hurtbox.add_child(hcs)
	add_child(_guardian_hurtbox)


func take_damage(hit_data) -> void:
	super.take_damage(hit_data)
	GameManager.guardian_state_changed.emit(maxf(health.current_hp, 0.0), health.max_hp, true)


func _on_health_died(_entity: Node2D) -> void:
	if not is_alive:
		return
	is_alive = false
	if trigger_component:
		trigger_component.cleanup()

	guardian_killed.emit()
	EventBus.on_death.emit(self)
	var killer: Node2D = last_hit_by if is_instance_valid(last_hit_by) else null
	if killer:
		EventBus.on_kill.emit(killer, self)

	died.emit(self)
	_try_drop_keystone()
	_drop_xp()
	_drop_health()
	_spawn_death_burst()
	queue_free()


func _try_drop_keystone() -> void:
	if GameManager.player_has_keystone:
		return
	var guaranteed: bool = not GameManager.guardian_killed_this_phase
	GameManager.guardian_killed_this_phase = true
	if guaranteed or randf() < 0.05:
		var KeystoneScript = load("res://scripts/pickups/keystone_pickup.gd")
		if KeystoneScript:
			var pickup: Area2D = KeystoneScript.new()
			pickup.global_position = global_position
			get_tree().current_scene.add_child(pickup)


func _spawn_death_burst() -> void:
	VFXHelpers.spawn_burst(
		get_tree().current_scene, global_position,
		Color(0.9, 0.18, 0.06, 1.0), 22, 1.0, 90.0, 260.0, 3.0, 9.0,
		Vector2(0.0, 90.0))
