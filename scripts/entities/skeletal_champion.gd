extends Node2D

## SkeletalChampion — the Necromancer's (The Shade) raised minion (Rise_Corpse → Skeletal_Champion
## package). A ground-walking skeleton with its OWN legs: it holds near the Shade, walks over to
## strike anything that strays close, and only trudges after the Shade once left behind — never glued
## to the player's movement.
##
## Two spawn modes (both use these same sheets):
##   • Q "Rise Corpse"  — one persistent champion; resummon replaces (old one is banished).
##   • E "Bone Legion"  — a short-lived pack of weaker skeletons (caller sets a shorter `lifetime`
##     and lower `damage_mult`); they self-free when their timer runs out.
##
## Mirrors the SpiritGuardian / FireFamiliar / BloodElemental pet standard (CLAUDE.md): no pooling,
## damage reads the player's live damage stat through DamageCalculator at strike time. The pack has no
## champion-owned summon/unsummon intro (the Rise_Corpse cast VFX is the summon), so it starts in idle.

class_name SkeletalChampion

const ASSET_DIR: String = "res://assets/minifantasy/Minifantasy_True_Villains_I_v1.0/_Minifantasy_True_Villains_Assets/Supreme_Necromancer/Special_Animations/Rise_Corpse/Skeletal_Champion/"
## Facing → sheet row (same diagonal-facing convention as CharacterSpriteFactory.DIR_ROWS).
const DIR_ROWS: Dictionary = {"down_right": 0, "down_left": 1, "up_right": 2, "up_left": 3}

const WALK_SPEED: float = 44.0           ## own legs — constant-speed walking, never lerp-glued
const CATCHUP_MULT: float = 1.6          ## heavy jog when left far behind
const ENGAGE_RANGE: float = 120.0        ## walks over to enemies this close to ITSELF
const ENGAGE_RANGE_SQ: float = ENGAGE_RANGE * ENGAGE_RANGE
const LEASH_RANGE_SQ: float = 120.0 * 120.0   ## won't chase prey further than this from the player
const STRIKE_RANGE: float = 30.0         ## cleave reach
const STRIKE_RANGE_SQ: float = STRIKE_RANGE * STRIKE_RANGE
const HOME_FAR_SQ: float = 44.0 * 44.0   ## starts trudging after the player beyond this
const HOME_NEAR_SQ: float = 24.0 * 24.0  ## settles once back within this (hysteresis — no jitter)
const ATTACK_COOLDOWN: float = 1.5
const STRIKE_DELAY: float = 4.0 / 14.0   ## attack anim frame 4 @ 14fps = the cleave

## Set by the host before adding to the tree (defaults suit the persistent Q champion).
var player_ref: Node2D = null
var damage_type: String = "Void"
var lifetime: float = 25.0               ## persistent; Bone Legion overrides to a few seconds
var damage_mult: float = 0.6             ## × the player's live damage stat

var _sprite: AnimatedSprite2D = null
var _facing: String = "down_left"
var _state: String = "walk"              ## "walk" → "die"
var _life: float = 0.0
var _cooldown: float = 0.0
var _strike_timer: float = -1.0
var _strike_target: Node2D = null
var _hunt_target: Node2D = null
var _rescan: float = 0.0
var _trudging: bool = false              ## currently walking home (hysteresis state)
var _home_side: float = 1.0              ## fixed at spawn — no side-flipping teleport anchors

static var _frames_cache: SpriteFrames = null


func _ready() -> void:
	z_index = 1
	_life = lifetime
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _get_frames()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_sprite.animation_finished.connect(_on_anim_finished)
	if is_instance_valid(player_ref):
		_home_side = -1.0 if global_position.x < player_ref.global_position.x else 1.0
	_play_dir(&"idle")


func _process(delta: float) -> void:
	if not is_instance_valid(player_ref):
		queue_free()
		return
	if _state == "die":
		return

	_life -= delta
	if _life <= 0.0:
		banish()
		return

	## Resolve a pending strike (damage lands on the attack anim's cleave frame).
	if _strike_timer > 0.0:
		_strike_timer -= delta
		if _strike_timer <= 0.0:
			_resolve_strike()
		return   ## hold position + facing while striking

	_cooldown -= delta

	## Hunt: walk over to prey that strays close (leashed to the player's vicinity).
	_rescan -= delta
	if _rescan <= 0.0:
		_rescan = 0.3
		_hunt_target = _nearest_prey()
	var target: Node2D = _hunt_target
	if target != null and (not is_instance_valid(target) or not target.get("is_alive") \
			or player_ref.global_position.distance_squared_to(target.global_position) > LEASH_RANGE_SQ):
		target = null
		_hunt_target = null

	if target:
		var to_t: Vector2 = target.global_position - global_position
		if to_t.length_squared() <= STRIKE_RANGE_SQ:
			if _cooldown <= 0.0:
				_start_strike(target)
			else:
				_face_toward(to_t)
				_play_dir(&"idle")   ## looming over its prey between cleaves
		else:
			_walk_toward(target.global_position, delta)
		return

	## No prey — hold ground near the player; only trudge after them once left behind.
	var home: Vector2 = player_ref.global_position + Vector2(24.0 * _home_side, 6.0)
	var d2: float = global_position.distance_squared_to(home)
	if _trudging:
		if d2 <= HOME_NEAR_SQ:
			_trudging = false
	elif d2 >= HOME_FAR_SQ:
		_trudging = true
	if _trudging:
		_walk_toward(home, delta)
	else:
		_play_dir(&"idle")


## Constant-speed walking (heavy jog when left far behind) — its own locomotion, no lerp.
func _walk_toward(dest: Vector2, delta: float) -> void:
	var to_dest: Vector2 = dest - global_position
	var speed: float = WALK_SPEED
	if player_ref and global_position.distance_squared_to(player_ref.global_position) > 120.0 * 120.0:
		speed *= CATCHUP_MULT
	var step: Vector2 = to_dest.limit_length(speed * delta)
	if step.length_squared() > 0.04:
		global_position += step
		_face_toward(to_dest)
	_play_dir(&"move")


func _start_strike(target: Node2D) -> void:
	_strike_target = target
	_strike_timer = STRIKE_DELAY
	_cooldown = ATTACK_COOLDOWN
	_face_toward(target.global_position - global_position)
	_play_dir(&"attack")


func _resolve_strike() -> void:
	_strike_timer = -1.0
	var target: Node2D = _strike_target
	_strike_target = null
	if not is_instance_valid(target) or not target.get("is_alive"):
		return
	if global_position.distance_squared_to(target.global_position) > 52.0 * 52.0:
		return   ## it slipped well out of cleave reach mid-swing
	var dmg: float = 20.0
	var attacker: Node2D = self
	if is_instance_valid(player_ref):
		dmg = player_ref.get_stat("damage") * damage_mult
		attacker = player_ref
	var hit := DamageCalculator.calculate_raw_hit(attacker, target, dmg, damage_type)
	if not hit.is_dodged:
		target.take_damage(hit)


## Early dismissal (resummon or lifetime end): Die outro, then free.
func banish() -> void:
	if _state == "die":
		return
	_state = "die"
	_play_dir(&"die")


## Kept name-compatible with SpiritGuardian/FireFamiliar/BloodElemental so player.gd can dismiss
## any kind generically.
func disperse() -> void:
	banish()


func _on_anim_finished() -> void:
	if _state == "die":
		queue_free()


func _nearest_prey() -> Node2D:
	## Nearest live enemy within engage range of the CHAMPION. Gated by the 0.3s rescan.
	var best: Node2D = null
	var best_d: float = ENGAGE_RANGE_SQ
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


## Shared SpriteFrames: idle/move/attack (4-row directional), die (single-row outro).
static func _get_frames() -> SpriteFrames:
	if _frames_cache:
		return _frames_cache
	var frames := SpriteFrames.new()
	frames.clear_all()
	_slice_rows(frames, "idle",   ASSET_DIR + "Idle.png",   18, 10.0, true)
	_slice_rows(frames, "move",   ASSET_DIR + "Walk.png",    8, 12.0, true)
	_slice_rows(frames, "attack", ASSET_DIR + "Attack.png",  8, 14.0, false)
	_slice_single(frames, "die",  ASSET_DIR + "Die.png",    16, 16.0, false)
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
