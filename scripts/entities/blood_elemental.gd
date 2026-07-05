extends Node2D

## BloodElemental — the Blood Mage's summoned companion (Blood_Elemental package used in full:
## Summon intro, Idle, Move, Attack + frame-matched Attack_Effect overlay, Banish-Die outro).
## A ground walker that lumbers beside the player and pounds the nearest enemy. One at a
## time — the player replaces it on resummon (old one banishes).
##
## FireFamiliar pattern: no pooling (max one alive), damage reads the player's live damage
## stat through DamageCalculator at strike time.

class_name BloodElemental

const ASSET_DIR: String = "res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Summon_Blood_Elemental/Blood_Elemental/"
## Facing → sheet row (same diagonal-facing convention as CharacterSpriteFactory.DIR_ROWS).
const DIR_ROWS: Dictionary = {"down_right": 0, "down_left": 1, "up_right": 2, "up_left": 3}

const LIFETIME: float = 15.0
const ATTACK_RANGE: float = 90.0
const ATTACK_RANGE_SQ: float = ATTACK_RANGE * ATTACK_RANGE
const ATTACK_COOLDOWN: float = 1.8
const STRIKE_DELAY: float = 12.0 / 18.0  ## attack anim frame 12 @ 18fps = the pound
const DAMAGE_MULT: float = 0.6           ## × the player's live damage stat
const FOLLOW_OFFSET := Vector2(22.0, 4.0)
const FOLLOW_SPEED: float = 4.0          ## lazy-follow lerp weight (heavier than the familiar)

var player_ref: Node2D = null
var damage_type: String = "Physical"

var _sprite: AnimatedSprite2D = null
var _fx: AnimatedSprite2D = null         ## frame-matched Attack_Effect overlay
var _facing: String = "down_left"
var _state: String = "spawn"             ## "spawn" → "walk" → "die"
var _life: float = LIFETIME
var _cooldown: float = 0.0
var _strike_timer: float = -1.0
var _strike_target: Node2D = null

static var _frames_cache: SpriteFrames = null


func _ready() -> void:
	z_index = 1
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _get_frames()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_fx = AnimatedSprite2D.new()
	_fx.sprite_frames = _get_frames()
	_fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fx.z_index = 1
	_fx.visible = false
	add_child(_fx)
	_fx.animation_finished.connect(func() -> void: _fx.visible = false)
	_sprite.animation_finished.connect(_on_anim_finished)
	_sprite.play(&"spawn")


func _process(delta: float) -> void:
	if not is_instance_valid(player_ref):
		queue_free()
		return
	if _state == "die" or _state == "spawn":
		return

	## Lumber along beside the player, on the side the player faces.
	var side: float = -1.0 if String(player_ref.get("_facing")).ends_with("left") else 1.0
	var anchor: Vector2 = player_ref.global_position \
			+ Vector2(FOLLOW_OFFSET.x * side, FOLLOW_OFFSET.y)
	var to_anchor: Vector2 = anchor - global_position
	global_position = global_position.lerp(anchor, minf(FOLLOW_SPEED * delta, 1.0))

	_life -= delta
	if _life <= 0.0:
		banish()
		return

	## Resolve a pending strike (damage lands on the attack anim's pound frame).
	if _strike_timer > 0.0:
		_strike_timer -= delta
		if _strike_timer <= 0.0:
			_resolve_strike()
		return   ## hold facing while striking

	_cooldown -= delta
	if _cooldown <= 0.0:
		var target: Node2D = _nearest_enemy()
		if target:
			_start_strike(target)
			return
		_cooldown = 0.25   ## nothing in range — re-scan shortly, don't scan every frame
	## Move anim while trailing the player, Idle when settled at the anchor.
	if to_anchor.length_squared() > 16.0:
		_face_toward(to_anchor)
		_play_dir(&"move")
	else:
		_play_dir(&"idle")


func _start_strike(target: Node2D) -> void:
	_strike_target = target
	_strike_timer = STRIKE_DELAY
	_cooldown = ATTACK_COOLDOWN
	_face_toward(target.global_position - global_position)
	_play_dir(&"attack")
	_fx.visible = true
	_fx.play(StringName("attack_fx_" + _facing))


func _resolve_strike() -> void:
	_strike_timer = -1.0
	var target: Node2D = _strike_target
	_strike_target = null
	if not is_instance_valid(target) or not target.get("is_alive"):
		return
	if global_position.distance_squared_to(target.global_position) > ATTACK_RANGE_SQ * 1.7:
		return   ## it slipped well out of reach mid-swing
	var dmg: float = 30.0
	var attacker: Node2D = self
	if is_instance_valid(player_ref):
		dmg = player_ref.get_stat("damage") * DAMAGE_MULT
		attacker = player_ref
	var hit := DamageCalculator.calculate_raw_hit(attacker, target, dmg, damage_type)
	if not hit.is_dodged:
		target.take_damage(hit)


## Early dismissal (resummon or lifetime end): Banish-Die outro, then free.
func banish() -> void:
	if _state == "die":
		return
	_state = "die"
	_fx.visible = false
	_play_dir(&"die")


## Kept name-compatible with FireFamiliar so player.gd can dismiss either kind generically.
func disperse() -> void:
	banish()


func _on_anim_finished() -> void:
	if _state == "spawn":
		_state = "walk"
		_play_dir(&"idle")
	elif _state == "die":
		queue_free()


func _nearest_enemy() -> Node2D:
	## Cheap scan gated by ATTACK_COOLDOWN / the 0.25s rescan — never per-frame.
	var best: Node2D = null
	var best_d: float = ATTACK_RANGE_SQ
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.get("is_alive"):
			continue
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _face_toward(v: Vector2) -> void:
	if v.length_squared() < 1.0:
		return
	_facing = ("down" if v.y >= 0.0 else "up") + ("_right" if v.x >= 0.0 else "_left")


func _play_dir(base: StringName) -> void:
	var dir_anim := StringName(String(base) + "_" + _facing)
	if _sprite.sprite_frames.has_animation(dir_anim):
		if _sprite.animation != dir_anim:
			_sprite.play(dir_anim)
	elif _sprite.animation != base:
		_sprite.play(base)


## Shared SpriteFrames: spawn/die (1-row intro/outro), idle/move/attack/attack_fx (4-row).
static func _get_frames() -> SpriteFrames:
	if _frames_cache:
		return _frames_cache
	var frames := SpriteFrames.new()
	frames.clear_all()
	_slice_single(frames, "spawn", ASSET_DIR + "Summon.png", 16, 14.0, false)
	_slice_single(frames, "die", ASSET_DIR + "Banish-Die.png", 17, 16.0, false)
	_slice_rows(frames, "idle", ASSET_DIR + "Idle.png", 4, 8.0, true)
	_slice_rows(frames, "move", ASSET_DIR + "Move.png", 6, 10.0, true)
	_slice_rows(frames, "attack", ASSET_DIR + "Attack.png", 22, 18.0, false)
	_slice_rows(frames, "attack_fx", ASSET_DIR + "Attack_Effect.png", 22, 18.0, false)
	_frames_cache = frames
	return frames


static func _slice_single(frames: SpriteFrames, anim_name: String, path: String,
		count: int, fps: float, loops: bool) -> void:
	var tex: Texture2D = load(path)
	if tex == null:
		return
	var anim := StringName(anim_name)
	frames.add_animation(anim)
	frames.set_animation_loop(anim, loops)
	frames.set_animation_speed(anim, fps)
	for i in range(count):
		var cell := AtlasTexture.new()
		cell.atlas = tex
		cell.region = Rect2(i * 32, 0, 32, 32)
		cell.filter_clip = true
		frames.add_frame(anim, cell)


static func _slice_rows(frames: SpriteFrames, base: String, path: String,
		count: int, fps: float, loops: bool) -> void:
	var tex: Texture2D = load(path)
	if tex == null:
		return
	for facing in DIR_ROWS:
		var anim := StringName("%s_%s" % [base, facing])
		frames.add_animation(anim)
		frames.set_animation_loop(anim, loops)
		frames.set_animation_speed(anim, fps)
		for i in range(count):
			var cell := AtlasTexture.new()
			cell.atlas = tex
			cell.region = Rect2(i * 32, int(DIR_ROWS[facing]) * 32, 32, 32)
			cell.filter_clip = true
			frames.add_frame(anim, cell)


## The elemental's die anim has no directional rows — _play_dir falls back to the base name.
