extends CharacterBody2D

## EnemyGuardian — Miniboss-tier enemy that guards an extraction point.
## Stats (Phase 1 base): 300 HP, 20 damage, 10 armor, slow (42 speed).
## All stat multipliers applied via phase_multiplier set BEFORE add_child().
## Emits guardian_killed on death. Drops a Keystone (guaranteed first kill per phase).

signal guardian_killed

## Set this BEFORE adding to the scene tree so _ready() picks it up.
var phase_multiplier: float = 1.0
## Spawn count — 0 = first guardian, 1+ = respawned (harder each time)
var spawn_count: int = 0

var max_hp: float = 300.0
var hp: float = 300.0
var move_speed: float = 42.0
var contact_damage: float = 20.0
var armor: float = 10.0
var xp_value: float = 50.0

var _is_dead: bool = false
var player_ref: Node2D = null
var knockback_velocity: Vector2 = Vector2.ZERO
var _hit_tween: Tween = null
var _sprite: AnimatedSprite2D = null
var _base_modulate: Color = Color(0.72, 0.14, 0.11, 1.0)
var _hurtbox: Area2D = null
var _contact_damage_timer: float = 0.0
const CONTACT_DAMAGE_INTERVAL: float = 0.8

## ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	## Apply phase scaling and respawn hardening
	var effective_mult: float = phase_multiplier * (1.0 + spawn_count * 0.35)
	max_hp = 300.0 * effective_mult
	hp = max_hp
	contact_damage = 20.0 * effective_mult
	## Armor stays at 10 per spec (doesn't scale)

	add_to_group("enemies")
	add_to_group("guardians")
	player_ref = get_tree().get_first_node_in_group("player")

	## Physics — same layers as regular enemies
	collision_layer = 2
	collision_mask = 3

	_build_collision_shape()
	_build_sprite()
	_build_hurtbox()

## ── Build ─────────────────────────────────────────────────────────────────────

func _build_collision_shape() -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 28)
	cs.shape = rect
	add_child(cs)

func _build_sprite() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.modulate = _base_modulate

	var frames := SpriteFrames.new()
	frames.clear_all()

	const CYCLOP_BASE: String = "res://assets/minifantasy/Minifantasy_Creatures_v3.3_Commercial_Version/Minifantasy_Creatures_Assets/Monsters/Cyclop/"
	var idle_path: String = CYCLOP_BASE + "CyclopIdle.png"
	var walk_path: String = CYCLOP_BASE + "CyclopWalk.png"

	## Idle: 8 frames × 64 wide × 128 tall (512×128 sheet)
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

	## Walk: 3 frames × 64 wide × 128 tall (192×128 sheet)
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

	_sprite.sprite_frames = frames
	## Scale 0.65 → ~42×83 display px (clearly bigger than brute at ~58 wide)
	_sprite.scale = Vector2(0.65, 0.65)
	## Offset up so the center of the 128-tall sprite aligns to the collision body
	_sprite.offset = Vector2(0, -26)
	_sprite.play("idle")
	add_child(_sprite)

	## Glowing ember particles — emanate from the guardian at all times
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

	## Scale-breathe pulse (alive, menacing)
	var breathe := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	breathe.tween_property(self, "scale", Vector2(1.06, 1.06), 1.1)
	breathe.tween_property(self, "scale", Vector2(1.0, 1.0), 1.1)

func _build_hurtbox() -> void:
	## Area2D that detects player body for contact damage
	var hurtbox := Area2D.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 2
	hurtbox.collision_mask = 1
	var hcs := CollisionShape2D.new()
	var hrect := RectangleShape2D.new()
	hrect.size = Vector2(32, 32)
	hcs.shape = hrect
	hurtbox.add_child(hcs)
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	add_child(hurtbox)
	_hurtbox = hurtbox

## ── Physics ───────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _is_dead or player_ref == null or not is_instance_valid(player_ref):
		return
	if GameManager.current_state != GameManager.GameState.RUN_ACTIVE:
		return

	_contact_damage_timer = maxf(_contact_damage_timer - delta, 0.0)

	var dir: Vector2 = (player_ref.global_position - global_position).normalized()
	velocity = dir * move_speed + knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 600.0 * delta)

	## Sustained contact damage polling
	if _contact_damage_timer <= 0.0 and _hurtbox != null:
		for body in _hurtbox.get_overlapping_bodies():
			if body.is_in_group("player") and body.has_method("take_damage"):
				CombatManager.resolve_hit(self, body, contact_damage, 0.0, 1.0)
				_contact_damage_timer = CONTACT_DAMAGE_INTERVAL
				break

	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("walk"):
		_sprite.play("walk")

## ── Public interface (matches enemy.gd contract for CombatManager) ────────────

func get_armor() -> float:
	return armor

func is_dead() -> bool:
	return _is_dead

func take_damage(amount: float) -> void:
	if _is_dead:
		return
	hp -= amount

	## White hit flash
	if _sprite:
		if _hit_tween and _hit_tween.is_valid():
			_hit_tween.kill()
		_sprite.modulate = Color(5.0, 5.0, 5.0, 1.0)
		_hit_tween = create_tween()
		_hit_tween.tween_property(_sprite, "modulate", _base_modulate, 0.10)

	## Broadcast HP so HUD health bar stays current
	GameManager.guardian_state_changed.emit(maxf(hp, 0.0), max_hp, true)

	if hp <= 0.0:
		hp = 0.0
		_die()

## Guardians resist knockback — they're massive, not skittish
func apply_knockback(force: Vector2) -> void:
	knockback_velocity += force * 0.25

## ── Death ─────────────────────────────────────────────────────────────────────

func _die() -> void:
	_is_dead = true
	guardian_killed.emit()

	GameManager.register_kill()
	EnemySpawnManager.on_enemy_died()

	_try_drop_keystone()
	_drop_xp()
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

func _drop_xp() -> void:
	var xp_path: String = "res://scenes/pickups/xp_gem.tscn"
	if not ResourceLoader.exists(xp_path):
		return
	var gem: Node2D = (load(xp_path) as PackedScene).instantiate()
	gem.global_position = global_position
	gem.xp_value = xp_value
	get_tree().current_scene.add_child(gem)

func _spawn_death_burst() -> void:
	var p := CPUParticles2D.new()
	p.global_position = global_position
	p.amount = 22
	p.lifetime = 1.0
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 260.0
	p.gravity = Vector2(0.0, 90.0)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 9.0
	p.color = Color(0.9, 0.18, 0.06, 1.0)
	get_tree().current_scene.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(func(): if is_instance_valid(p): p.queue_free())

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if _is_dead:
		return
	if body.is_in_group("player") and body.has_method("take_damage") and _contact_damage_timer <= 0.0:
		CombatManager.resolve_hit(self, body, contact_damage, 0.0, 1.0)
		_contact_damage_timer = CONTACT_DAMAGE_INTERVAL
