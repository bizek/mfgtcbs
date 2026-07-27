extends Area2D

## OrbitOrb — Persistent orb that circles the player and shocks enemies on contact.
## Created by the player when Lightning Orb is equipped. Lives until the player is gone.
##
## Damage uses the player's live get_stat("damage") so upgrades apply correctly.

class_name OrbitOrb

## Set by player before add_child
var player_ref: Node2D = null
var orbit_radius: float = 64.0
var orbit_speed: float = 1.8       ## full rotations per second
var orbit_offset: float = 0.0     ## starting angle in radians (spread orbs evenly)
var tint: Color = Color(0.78, 0.95, 1.0)
var hit_radius: float = 7.0       ## base collision radius before size scaling
var size_mult: float = 1.0        ## from size mod; scales hitbox and visuals
var on_hit_effects: Array = []    ## built by WeaponFactory; applied after each hit
var combat_manager_ref: Node2D = null

## Per-enemy hit cooldown — prevents frame-spam damage on the same enemy
const HIT_COOLDOWN: float = 0.45
var _hit_cooldowns: Dictionary = {}  ## enemy instance_id → seconds remaining

var _angle: float = 0.0

func _ready() -> void:
	collision_layer = 4   ## player_projectiles (bit 2)
	collision_mask  = 2   ## enemies (bit 1)
	monitoring      = true
	monitorable     = false

	_angle = orbit_offset

	## Collision shape — scaled by size mod
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = hit_radius * size_mult
	shape.shape = circle
	add_child(shape)

	_build_visual()

	body_entered.connect(_on_body_entered)

## Pack II's Arcane Orb, continuous row. 32px cells, 16 frames per row, rows are
## cast / continuous / end — we loop row 1 forever, since the orb lives until the player does.
const ORB_SHEET: String = "res://assets/minifantasy/Minifantasy_Spell_Effects_II_v1.0/Spell_Effects_II/Arcane_Magic_School/Arcane_Orb/_Standalone_Effects/Orb_Only_Orb.png"
const ORB_CELL: int = 32
const ORB_FRAMES: int = 16
const ORB_ROW: int = 1
const ORB_FPS: float = 12.0
## The art fills its 32px cell; the orb should read at roughly the old 20px glow, hence <1 scale.
const ORB_ART_SCALE: float = 0.62
static var _orb_frames: SpriteFrames = null


func _build_visual() -> void:
	## Prefer the pack sprite; the ColorRect stack below is the fallback when the sheet is absent.
	if _build_sprite_visual():
		return
	_build_primitive_visual()


## Returns false when the sheet is missing, so the caller can fall back rather than render nothing.
func _build_sprite_visual() -> bool:
	var frames: SpriteFrames = _get_orb_frames()
	if frames == null:
		return false
	var orb := AnimatedSprite2D.new()
	orb.sprite_frames = frames
	orb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	orb.centered = true
	orb.scale = Vector2.ONE * ORB_ART_SCALE * size_mult
	orb.modulate = tint
	add_child(orb)
	orb.play(&"spin")
	## Same gentle breathing the primitive version had, so the orb still feels alive at rest.
	var tween := create_tween().set_loops()
	tween.tween_property(orb, "modulate:a", 0.72, 0.55)
	tween.tween_property(orb, "modulate:a", 1.0,  0.55)
	return true


static func _get_orb_frames() -> SpriteFrames:
	if _orb_frames != null:
		return _orb_frames
	if not ResourceLoader.exists(ORB_SHEET):
		return null
	var sheet: Texture2D = load(ORB_SHEET)
	if sheet == null:
		return null
	var frames := SpriteFrames.new()
	frames.clear_all()
	frames.add_animation(&"spin")
	frames.set_animation_loop(&"spin", true)
	frames.set_animation_speed(&"spin", ORB_FPS)
	for i in ORB_FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * ORB_CELL, ORB_ROW * ORB_CELL, ORB_CELL, ORB_CELL)
		atlas.filter_clip = true
		frames.add_frame(&"spin", atlas)
	_orb_frames = frames
	return frames


func _build_primitive_visual() -> void:
	var s: float = size_mult
	## Soft outer glow
	var glow := ColorRect.new()
	glow.color = Color(tint.r, tint.g, tint.b, 0.28)
	glow.size = Vector2(20.0, 20.0) * s
	glow.position = Vector2(-10.0, -10.0) * s
	add_child(glow)

	## Core orb
	var core := ColorRect.new()
	core.color = tint
	core.size = Vector2(9.0, 9.0) * s
	core.position = Vector2(-4.5, -4.5) * s
	add_child(core)

	## Bright white center spark
	var spark := ColorRect.new()
	spark.color = Color(1.0, 1.0, 1.0, 0.90)
	spark.size = Vector2(3.0, 3.0) * s
	spark.position = Vector2(-1.5, -1.5) * s
	add_child(spark)

	## Pulse animation — orb breathes in and out gently
	var tween := create_tween().set_loops()
	tween.tween_property(glow, "modulate:a", 0.35, 0.55)
	tween.tween_property(glow, "modulate:a", 1.0,  0.55)

func _process(delta: float) -> void:
	## Self-destruct if player is gone (scene change or death cleanup)
	if not is_instance_valid(player_ref):
		queue_free()
		return

	## Tick down per-enemy hit cooldowns
	for key in _hit_cooldowns.keys():
		_hit_cooldowns[key] -= delta
		if _hit_cooldowns[key] <= 0.0:
			_hit_cooldowns.erase(key)

	## Orbit the player
	_angle += orbit_speed * TAU * delta
	global_position = player_ref.global_position + Vector2(cos(_angle), sin(_angle)) * orbit_radius

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	if not body.has_method("take_damage"):
		return

	var enemy_id: int = body.get_instance_id()
	if _hit_cooldowns.has(enemy_id):
		return
	_hit_cooldowns[enemy_id] = HIT_COOLDOWN

	## Read player's live damage stat so upgrades apply
	var dmg: float = 28.0
	if is_instance_valid(player_ref):
		dmg = player_ref.get_stat("damage")

	var attacker: Node2D = player_ref if is_instance_valid(player_ref) else self
	var hit := DamageCalculator.calculate_raw_hit(attacker, body, dmg, "Lightning")
	if not hit.is_dodged:
		body.take_damage(hit)
		# Knockback from orb contact
		var kb_dir: Vector2 = (body.global_position - global_position).normalized()
		if kb_dir == Vector2.ZERO:
			kb_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		if body.has_method("apply_knockback"):
			body.apply_knockback(kb_dir * 120.0)
		# Mod on-hit effects (elemental, dot, chain, explosive)
		if not on_hit_effects.is_empty() and is_instance_valid(combat_manager_ref):
			EffectDispatcher.execute_effects(on_hit_effects, attacker, [body], null, combat_manager_ref)

	## Small electric flash on the orb
	modulate = Color(2.2, 2.2, 2.8, 1.0)
	var flash := create_tween()
	flash.tween_property(self, "modulate", Color.WHITE, 0.08)
