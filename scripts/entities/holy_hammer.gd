extends Area2D

## HolyHammer — blessed-hammer projectile that spirals outward around the Warden (hammerdin).
## Spawned by player.gd when the Paladin kit's Holy Hammer combo node fires; several are
## launched at staggered angles and corkscrew out from the player, damaging each enemy they
## pass through once per hammer.
##
## Modeled on OrbitOrb (Area2D contact hits, live player damage stat). Visuals are the
## Holy_Hammer package used in full: the Orthogonal projectile sheet's rows for cardinal
## travel, the Diagonal sheet's rows for diagonal travel (anim follows the hammer's current
## tangential direction), and the Impact sheet as a one-shot burst on every enemy hit.

class_name HolyHammer

const SHEET_ORTHO: String = "res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Holy_Hammer/HolyHammerProjectileOrthogonal.png"
const SHEET_DIAG: String = "res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Holy_Hammer/HolyHammerProjectileDiagonal.png"
const SHEET_IMPACT: String = "res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Holy_Hammer/HolyHammerImpact.png"

## Sheet row → travel direction. The 4-frame tumble makes small mismatches invisible in
## motion — if a scrub shows a wrong-facing hammer, swap rows here (one dict per sheet).
const ORTHO_ROWS: Dictionary = {"n": 0, "e": 1, "s": 2, "w": 3}
const DIAG_ROWS: Dictionary = {"ne": 0, "se": 1, "sw": 2, "nw": 3}
## Octant index (atan2-based, 0 = east, clockwise) → direction anim name.
const OCTANT_ANIMS: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

## Set by player.gd before add_child
var player_ref: Node2D = null      ## live damage stat source (and anchor when follow_player)
var damage_type: String = "Physical"
var damage_mult: float = 0.9       ## × the player's live damage stat, per enemy hit
var start_angle: float = 0.0       ## radians; spawner staggers multiple hammers evenly
var spin_speed: float = 0.7        ## revolutions per second (1.1 read too fast — Ben 2026-07-20)
var radius_start: float = 10.0
var radius_growth: float = 62.0    ## px/sec spiral-out rate
var max_radius: float = 120.0      ## despawn past this (spawner scales it with melee_range)
## Spiral anchor: the CAST point, captured at spawn — each hammer corkscrews out from where it
## was thrown (Ben 2026-07-20). A future class mod flips follow_player so spirals track the
## moving Warden instead.
var follow_player: bool = false
var _anchor: Vector2 = Vector2.ZERO

var _angle: float = 0.0
var _radius: float = 0.0
var _hit_ids: Dictionary = {}      ## enemy instance_id → true (one hit per enemy per hammer)
var _sprite: AnimatedSprite2D = null

static var _frames_cache: SpriteFrames = null


func _ready() -> void:
	collision_layer = 4   ## player_projectiles (bit 2)
	collision_mask  = 2   ## enemies (bit 1)
	monitoring      = true
	monitorable     = false
	top_level       = true   ## world space — position driven from the player each frame

	_angle = start_angle
	_radius = radius_start

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _get_frames()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.play(&"e")
	add_child(_sprite)

	body_entered.connect(_on_body_entered)
	if is_instance_valid(player_ref):
		_anchor = player_ref.global_position
		global_position = _anchor + Vector2(cos(_angle), sin(_angle)) * _radius


func _process(delta: float) -> void:
	if not is_instance_valid(player_ref):
		queue_free()
		return
	if follow_player:
		_anchor = player_ref.global_position
	_angle += spin_speed * TAU * delta
	_radius += radius_growth * delta
	if _radius > max_radius:
		queue_free()
		return
	var prev: Vector2 = global_position
	global_position = _anchor + Vector2(cos(_angle), sin(_angle)) * _radius
	_update_direction_anim(global_position - prev)


func _update_direction_anim(v: Vector2) -> void:
	if _sprite == null or v.length_squared() < 0.01:
		return
	var oct: int = wrapi(roundi(atan2(v.y, v.x) / (PI / 4.0)), 0, 8)
	var anim := StringName(OCTANT_ANIMS[oct])
	if _sprite.animation != anim:
		_sprite.play(anim)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies") or not body.has_method("take_damage"):
		return
	var enemy_id: int = body.get_instance_id()
	if _hit_ids.has(enemy_id):
		return   ## blessed-hammer rule: each hammer hits each enemy once
	_hit_ids[enemy_id] = true

	var dmg: float = 30.0
	var attacker: Node2D = self
	if is_instance_valid(player_ref):
		dmg = player_ref.get_stat("damage") * damage_mult
		attacker = player_ref
	var hit := DamageCalculator.calculate_raw_hit(attacker, body, dmg, damage_type)
	if not hit.is_dodged:
		body.take_damage(hit)
		## No knockback — hammers should keep enemies in the spiral's path, not scatter them.
	_spawn_impact(body.global_position)


## One-shot golden burst (the package's Impact sheet) at the hit position.
func _spawn_impact(at: Vector2) -> void:
	var burst := AnimatedSprite2D.new()
	burst.sprite_frames = _get_frames()
	burst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	burst.z_index = 1
	get_tree().current_scene.add_child(burst)
	burst.global_position = at
	burst.play(&"impact")
	burst.animation_finished.connect(burst.queue_free)


## Shared SpriteFrames: 8 looping 4-frame tumble anims (n/ne/e/…/nw) + the one-shot "impact".
static func _get_frames() -> SpriteFrames:
	if _frames_cache:
		return _frames_cache
	var frames := SpriteFrames.new()
	frames.clear_all()
	_slice_directions(frames, SHEET_ORTHO, ORTHO_ROWS)
	_slice_directions(frames, SHEET_DIAG, DIAG_ROWS)
	var impact: Texture2D = load(SHEET_IMPACT)
	if impact:
		frames.add_animation(&"impact")
		frames.set_animation_loop(&"impact", false)
		frames.set_animation_speed(&"impact", 18.0)
		for i in range(int(impact.get_width() / 32.0)):
			var cell := AtlasTexture.new()
			cell.atlas = impact
			cell.region = Rect2(i * 32, 0, 32, 32)
			cell.filter_clip = true
			frames.add_frame(&"impact", cell)
	_frames_cache = frames
	return frames


static func _slice_directions(frames: SpriteFrames, path: String, rows: Dictionary) -> void:
	var tex: Texture2D = load(path)
	if tex == null:
		return
	for dir_name in rows:
		var anim := StringName(dir_name)
		frames.add_animation(anim)
		frames.set_animation_loop(anim, true)
		frames.set_animation_speed(anim, 12.0)   ## tumble cycle
		for i in range(4):
			var cell := AtlasTexture.new()
			cell.atlas = tex
			cell.region = Rect2(i * 32, int(rows[dir_name]) * 32, 32, 32)
			cell.filter_clip = true
			frames.add_frame(anim, cell)
