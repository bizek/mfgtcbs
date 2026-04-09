extends "res://scripts/entities/enemy.gd"

## EnemyGuardian — Miniboss-tier enemy that guards an extraction point.
## Extends enemy.gd to inherit status effects, elite modifiers, health drops.
## Stats (Phase 1 base): 300 HP, 20 damage, 10 armor, slow (42 speed).
## All stat multipliers applied via phase_multiplier set BEFORE add_child().
## Emits guardian_killed on death. Drops a Keystone (guaranteed first kill per phase).

signal guardian_killed

## Set these BEFORE adding to the scene tree so _ready() picks them up.
var phase_multiplier: float = 1.0
## Spawn count — 0 = first guardian, 1+ = respawned (harder each time)
var spawn_count: int = 0

## Local ref used during _build_sprite(); wired to parent's `sprite` in _ready()
var _guardian_sprite: AnimatedSprite2D = null
## Local ref used during _build_hurtbox(); wired to parent's `hurtbox` in _ready()
var _guardian_hurtbox: Area2D = null

## ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	## Apply phase scaling and respawn hardening BEFORE super._ready() sets hp = max_hp
	var effective_mult: float = phase_multiplier * (1.0 + spawn_count * 0.35)
	max_hp = 300.0 * effective_mult
	contact_damage = 20.0 * effective_mult
	armor = 10.0
	xp_value = 50.0
	move_speed = 42.0
	health_drop_chance = 0.25  ## Guardians are generous with health orbs

	## Build programmatic children (guardian has no .tscn)
	_build_collision_shape()
	_build_sprite()
	_build_hurtbox()

	## Wire parent's @onready vars — they resolved to null because there's no .tscn scene
	sprite = _guardian_sprite
	hurtbox = _guardian_hurtbox

	## Parent _ready(): sets hp=max_hp, adds to "enemies" group, finds player_ref,
	## loads pickup scenes, connects hurtbox.body_entered signal
	super._ready()

	add_to_group("guardians")

	## Guardian base tint (crimson)
	_base_modulate = Color(0.72, 0.14, 0.11, 1.0)
	if sprite:
		sprite.modulate = _base_modulate

	## Physics — layer 2 (enemies), mask 1+2 (collides with player and other enemies)
	collision_layer = 2
	collision_mask = 3

## ── Build ─────────────────────────────────────────────────────────────────────

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
	_guardian_sprite.modulate = Color(0.72, 0.14, 0.11, 1.0)

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

	_guardian_sprite.sprite_frames = frames
	## Scale 0.65 → ~42×83 display px (clearly bigger than brute at ~58 wide)
	_guardian_sprite.scale = Vector2(0.65, 0.65)
	## Offset up so the center of the 128-tall sprite aligns to the collision body
	_guardian_sprite.offset = Vector2(0, -26)
	_guardian_sprite.play("idle")
	add_child(_guardian_sprite)

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
	## Signal connection handled by super._ready() via inherited hurtbox var

## ── Physics (override for guardian-specific behavior) ─────────────────────────

func _physics_process(delta: float) -> void:
	if _is_dead or player_ref == null or not is_instance_valid(player_ref):
		return
	if GameManager.current_state != GameManager.GameState.RUN_ACTIVE:
		return

	_contact_damage_timer = maxf(_contact_damage_timer - delta, 0.0)

	## Frozen: cannot move (inherited from enemy.gd status system)
	if _frozen:
		_freeze_timer -= delta
		if _freeze_timer <= 0.0:
			_frozen = false
			_speed_mult = 1.0 if not _statuses.has("cryo") else (1.0 - _statuses["cryo"].get("slow_pct", 0.3))
			if sprite:
				sprite.modulate = _base_modulate
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		return

	## Shade passive: don't chase an invisible player
	if player_ref.has_method("is_invisible") and player_ref.is_invisible():
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		return

	## Tick status effects (burning DOT, cryo duration) — inherited
	_tick_statuses(delta)

	var dir: Vector2 = (player_ref.global_position - global_position).normalized()
	velocity = dir * move_speed * _speed_mult + knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 600.0 * delta)

	## Sustained contact damage polling
	if _contact_damage_timer <= 0.0 and hurtbox != null:
		for body in hurtbox.get_overlapping_bodies():
			if body.is_in_group("player") and body.has_method("take_damage"):
				CombatManager.resolve_hit(self, body, contact_damage, 0.0, 1.0)
				_contact_damage_timer = CONTACT_DAMAGE_INTERVAL
				break

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")

## ── Overrides ────────────────────────────────────────────────────────────────

## Guardians resist knockback — they're massive, not skittish
func apply_knockback(force: Vector2) -> void:
	knockback_velocity += force * 0.25

func take_damage(amount: float) -> void:
	super.take_damage(amount)
	## Broadcast HP so HUD health bar stays current
	GameManager.guardian_state_changed.emit(maxf(hp, 0.0), max_hp, true)

func _die() -> void:
	_is_dead = true
	guardian_killed.emit()
	died.emit(self)

	## Void-Touched: explode before the death burst
	if _void_touched:
		_void_explosion()

	_try_drop_keystone()
	_drop_xp()
	_drop_health()
	_spawn_death_burst()
	queue_free()

## ── Guardian-specific ────────────────────────────────────────────────────────

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
