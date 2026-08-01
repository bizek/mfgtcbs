extends Node2D

## MirrorArcher — the Scavenger's (Ranger) Q companion: a spectral duplicate of HERSELF that
## splits off, plants its feet and looses arrows at whatever wanders into range, then fades.
##
## Replaced Skirmisher's Step (Ben 2026-07-29): trading the Q shove for sustained ranged pressure
## gives the roster's only pure archer a reason to hold a firing line instead of kiting forever.
## Conceal (E) covered the survivability that cost at the time; Conceal is gone as of 2026-07-31
## (the slot is Quiver Swap), so the Scavenger's disengage is now her dash plus the melee knives
## she gives up when she arms a head — range and positioning, not a panic button.
##
## It is a MIRROR, so it is drawn from the Ranger's own sheets (Idle / Walk / SingleShot) tinted
## a cold translucent blue, and — this is the point — it fires the player's ACTUAL arrow through
## the normal projectile pipeline rather than a look-alike: same sprite, same seek/turn steering,
## same damage pipeline. It shoots what she shoots. See CLAUDE.md's full-asset-utilization rule.
##
## Mirrors the AngryDemon / SkeletalChampion / SpiritGuardian / FireFamiliar / BloodElemental pet
## standard (CLAUDE.md): no pooling, its own locomotion, leashed hunting, settle/roam hysteresis.
## The one deliberate divergence is that an ARCHER holds its ground — it never walks toward prey,
## only back toward the player once genuinely left behind. Chasing is the melee pets' job.

class_name MirrorArcher

const ASSET_DIR: String = "res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Ranger/"
## Facing → sheet row, the pack's diagonal 4-row convention (CharacterSpriteFactory.DIR_ROWS).
const DIR_ROWS: Dictionary = {"down_right": 0, "down_left": 1, "up_right": 2, "up_left": 3}

## Playback rates are THE SCAVENGER'S, not the pack's.
##
## The pack's AnimationInfo.txt authors these sheets at 200ms (5fps) for Idle/Walk and 100ms (10fps)
## for Single Shot, and this used to play them at exactly that — the only thing in the game that took
## a Minifantasy rate literally. That was right about the sheet and wrong on screen: the Mirror Archer
## stands next to the Scavenger running THE SAME THREE SHEETS at 9 / 10 / 24, so the reflection
## animated at roughly half her speed, side by side (idle 3.20s vs 1.78s, shot 1.00s vs 0.42s).
## It was also the only companion outside the pet house rates (idle 8-10 / move 10-12 / attack 14+)
## that AngryDemon, SkeletalChampion, SpiritGuardian, FireFamiliar and BloodElemental all share.
## Matched to her own rates so it reads as a reflection. (Audit 2026-07-31.)
const IDLE_FPS: float = 9.0
const WALK_FPS: float = 10.0
const IDLE_FRAMES: int = 16
const WALK_FRAMES: int = 4
const SHOT_FRAMES: int = 10
const SHOT_FPS: float = 24.0
const SHOT_HIT_FRAME: int = 6
## Derived, so retiming the draw automatically retimes the loose — never hand-set this.
const DRAW_DELAY: float = float(SHOT_HIT_FRAME) / SHOT_FPS   ## 0.25s into the draw

const WALK_SPEED: float = 46.0            ## own legs — constant speed, never lerp-glued
const CATCHUP_MULT: float = 1.7
const SHOOT_RANGE: float = 170.0          ## it shoots this far from ITSELF
const SHOOT_RANGE_SQ: float = SHOOT_RANGE * SHOOT_RANGE
const SHOT_COOLDOWN: float = 1.0
const RESCAN: float = 0.25
const HOME_FAR_SQ: float = 150.0 * 150.0  ## only trudges after her once left this far behind
const HOME_NEAR_SQ: float = 60.0 * 60.0   ## settles back within this (hysteresis — no jitter)
const FADE_TIME: float = 0.45             ## the reflection thins out and is gone

const TINT: Color = Color(0.55, 0.8, 1.0, 0.62)   ## cold, translucent — a reflection, not a twin

## Set by the host before adding to the tree.
var player_ref: Node2D = null
var ability_ref: AbilityDefinition = null   ## routed onto the arrows so on-hit triggers keep context
var lifetime: float = 10.0
var damage_mult: float = 0.5                ## × the player's live damage stat, per arrow

var _sprite: AnimatedSprite2D = null
var _facing: String = "down_right"
var _state: String = "live"                 ## "live" → "fade"
var _life: float = 0.0
var _cooldown: float = 0.4                  ## a short beat before the first arrow
var _draw_timer: float = -1.0
var _shot_target: Node2D = null
var _prey: Node2D = null
var _rescan: float = 0.0
var _trudging: bool = false
var _home_side: float = 1.0
var _arrow: SpawnProjectilesEffect = null
var _arrow_quiver: String = ""     ## head the template currently carries; "" = unarmed (its build state)

static var _frames_cache: SpriteFrames = null


func _ready() -> void:
	z_index = 1
	_life = lifetime
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _get_frames()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.modulate = TINT
	add_child(_sprite)
	if is_instance_valid(player_ref):
		_home_side = -1.0 if global_position.x < player_ref.global_position.x else 1.0
		_facing = player_ref.get("_facing") if player_ref.get("_facing") != null else "down_right"
		if not DIR_ROWS.has(_facing):
			_facing = "down_right"
	## One arrow template, reused: only its damage and spawn offset change per shot.
	_arrow = ChainFactory._arrow_volley("Physical", 1.0, 1, 0.0)
	_play_dir(&"idle")
	## Materialise: the reflection resolves out of nothing rather than popping in.
	_sprite.modulate = Color(TINT.r, TINT.g, TINT.b, 0.0)
	var t := create_tween()
	t.tween_property(_sprite, "modulate:a", TINT.a, 0.25)


func _process(delta: float) -> void:
	if not is_instance_valid(player_ref):
		queue_free()
		return
	if _state == "fade":
		return

	_life -= delta
	if _life <= 0.0:
		disperse()
		return

	## Resolve a pending shot — the arrow leaves on the draw's loose frame, not on the keypress.
	if _draw_timer > 0.0:
		_draw_timer -= delta
		if _draw_timer <= 0.0:
			_loose()
		return   ## holds its stance through the draw

	_cooldown -= delta

	_rescan -= delta
	if _rescan <= 0.0:
		_rescan = RESCAN
		_prey = _nearest_prey()
	var target: Node2D = _prey
	if target != null and (not is_instance_valid(target) or not target.get("is_alive") \
			or global_position.distance_squared_to(target.global_position) > SHOOT_RANGE_SQ):
		target = null
		_prey = null

	if target:
		## An archer plants its feet: it turns and draws, it does not walk the target down.
		_face_toward(target.global_position - global_position)
		if _cooldown <= 0.0:
			_start_draw(target)
		else:
			_play_dir(&"idle")
		return

	## Nothing in range — hold the line, and only follow her once genuinely left behind.
	var home: Vector2 = player_ref.global_position + Vector2(34.0 * _home_side, 10.0)
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


func _walk_toward(dest: Vector2, delta: float) -> void:
	var to_dest: Vector2 = dest - global_position
	var speed: float = WALK_SPEED
	if global_position.distance_squared_to(player_ref.global_position) > 220.0 * 220.0:
		speed *= CATCHUP_MULT
	var step: Vector2 = to_dest.limit_length(speed * delta)
	if step.length_squared() > 0.04:
		global_position += step
		_face_toward(to_dest)
	_play_dir(&"move")


func _start_draw(target: Node2D) -> void:
	_shot_target = target
	_draw_timer = DRAW_DELAY
	_cooldown = SHOT_COOLDOWN
	_play_dir(&"shoot", true)


## Loose the player's own arrow FROM the mirror's position. Routing it through the player as the
## effect source (with the mirror's offset baked into spawn_offset) is deliberate: the arrow then
## inherits her faction, her damage pipeline and the same seek/turn steering as a real shot, which
## is exactly what a mirror image should produce. `_spawn_aimed_single` reads both
## `source.attack_target` and `spawn_offset`, so the shot originates and aims from here.
func _loose() -> void:
	_draw_timer = -1.0
	var target: Node2D = _shot_target
	_shot_target = null
	if not is_instance_valid(target) or not target.get("is_alive"):
		return
	if not is_instance_valid(player_ref) or player_ref.combat_manager == null:
		return
	_sync_quiver()
	_arrow.projectile.on_hit_effects[0].base_damage = player_ref.get_stat("damage") * damage_mult
	_arrow.spawn_offset = global_position - player_ref.global_position
	var prev: Node2D = player_ref.attack_target
	player_ref.attack_target = target
	EffectDispatcher.execute_effects([_arrow], player_ref, [player_ref],
			ability_ref, player_ref.combat_manager)
	player_ref.attack_target = prev


## The reflection shoots what the Scavenger has loaded (quiver stance, player E). The arrow is one
## reused template, so the head can't just be appended per shot — it would compound. Instead the
## template is REBUILT from the factory whenever the stance changes and stamped once, which also
## makes unloading the quiver revert it cleanly.
func _sync_quiver() -> void:
	if not player_ref.has_method("get_quiver"):
		return
	var quiver: String = player_ref.get_quiver()
	if quiver == _arrow_quiver:
		return
	_arrow_quiver = quiver
	var offset: Vector2 = _arrow.spawn_offset
	_arrow = ChainFactory._arrow_volley("Physical", 1.0, 1, 0.0)
	_arrow.spawn_offset = offset
	if quiver != "":
		player_ref.apply_quiver(_arrow)


## Early dismissal (resummon or lifetime end): thin out and go.
func disperse() -> void:
	if _state == "fade":
		return
	_state = "fade"
	var t := create_tween()
	t.tween_property(_sprite, "modulate:a", 0.0, FADE_TIME)
	t.tween_callback(queue_free)


## Kept name-compatible with the other companions so player.gd can dismiss any kind generically.
func banish() -> void:
	disperse()


func _nearest_prey() -> Node2D:
	var best: Node2D = null
	var best_d: float = SHOOT_RANGE_SQ
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


func _play_dir(base: StringName, restart: bool = false) -> void:
	var dir_anim := StringName(String(base) + "_" + _facing)
	if not _sprite.sprite_frames.has_animation(dir_anim):
		return
	if restart or _sprite.animation != dir_anim:
		_sprite.play(dir_anim)


## Shared SpriteFrames sliced from the Ranger's own general sheets — idle, walk and the single-shot
## draw, all 4-row diagonal at 32px.
static func _get_frames() -> SpriteFrames:
	if _frames_cache:
		return _frames_cache
	var frames := SpriteFrames.new()
	frames.clear_all()
	_slice_rows(frames, "idle",  ASSET_DIR + "General_Animations/Ranger_Idle.png", IDLE_FRAMES, IDLE_FPS, true)
	_slice_rows(frames, "move",  ASSET_DIR + "General_Animations/Ranger_walk.png", WALK_FRAMES, WALK_FPS, true)
	_slice_rows(frames, "shoot", ASSET_DIR + "General_Animations/Ranger_SingleShot_Diagonal.png",
			SHOT_FRAMES, SHOT_FPS, false)
	_frames_cache = frames
	return frames


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
