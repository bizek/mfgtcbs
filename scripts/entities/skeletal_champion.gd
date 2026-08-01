extends Node2D

## SkeletalChampion — the Necromancer's (The Shade) raised minion (Rise_Corpse → Skeletal_Champion
## package). A ground-walking skeleton with its OWN legs: it holds near the Shade, walks over to
## strike anything that strays close, and only trudges after the Shade once left behind — never glued
## to the player's movement.
##
## Two spawn modes (both use these same sheets):
##   • Q "Rise Corpse"  — a squad of persistent champions; resummon replaces (old ones are banished).
##     They hold ground near the Shade and cleave what comes close. His standing bodyguard.
##   • E "Bone Legion"  — VOLATILE skeletons (`volatile = true`): they ignore the Shade, sprint at
##     the nearest enemy and detonate on arrival, or blow up where they stand when the fuse runs out.
##     Thrown ordnance, not a bodyguard.
##
## The two modes exist because E used to be a strictly worse Q — same entity, same art, fewer of
## them (2 vs 4), weaker (0.35 vs 0.6), shorter-lived (8s vs 25s), for 4 seconds off the cooldown.
## There was no reason to press it (Ben 2026-08-01: "what makes the E skeletons better than the Q
## skeletons other than theres more on Q than on E"). Volatility gives E its own job: Q is sustained
## presence you keep alive, E is a burst you spend into a pack and never see again.
##
## Mirrors the SpiritGuardian / FireFamiliar / BloodElemental pet standard (CLAUDE.md): no pooling,
## damage reads the player's live damage stat through DamageCalculator at strike time.
##
## It rises in place: the Rise_Skeletal_Champion emerge plays as the champion's OWN "spawn" state (it
## IS the skeleton clawing up), held inert until it finishes, THEN it goes active. This keeps the
## animation welded to the entity — no walking off and leaving the rise behind as a remnant (Ben
## 2026-07-23) — and because it's the champion's own body sheet's matching emerge, the risen bones
## become the actual skeleton. Mirrors SpiritGuardian's spawn→walk state pattern.

class_name SkeletalChampion

const ASSET_DIR: String = "res://assets/minifantasy/Minifantasy_True_Villains_I_v1.0/_Minifantasy_True_Villains_Assets/Supreme_Necromancer/Special_Animations/Rise_Corpse/Skeletal_Champion/"
## The emerge sheet lives one level up in Rise_Corpse/ (32px, 2 rows — row 0 = one skeleton clawing up).
const RISE_SHEET: String = "res://assets/minifantasy/Minifantasy_True_Villains_I_v1.0/_Minifantasy_True_Villains_Assets/Supreme_Necromancer/Special_Animations/Rise_Corpse/Rise_Skeletal_Champion.png"
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

## ── Volatile mode (Bone Legion) ──────────────────────────────────────────────
## A volatile skeleton never cleaves and never goes home: it runs down the nearest enemy and blows
## up. Its fuse is `lifetime`, so it always detonates eventually — a legion raised into empty air
## still goes off, it just goes off where it stands.
const VOLATILE_SPEED_MULT: float = 1.7   ## they sprint; a fuse that ambles is a wasted fuse
const VOLATILE_ENGAGE_SQ: float = 300.0 * 300.0   ## hunts far wider than a champion's 120px patch
const VOLATILE_TINT: Color = Color(0.72, 1.0, 0.68)   ## sickly corpse-light — reads as "unstable"

## Set by the host before adding to the tree (defaults suit the persistent Q champion).
var player_ref: Node2D = null
var damage_type: String = "Void"
var lifetime: float = 25.0               ## persistent; Bone Legion overrides to a few seconds
var damage_mult: float = 0.6             ## × the player's live damage stat
var volatile: bool = false               ## Bone Legion mode: charge + detonate instead of cleave
var detonate_radius: float = 34.0        ## blast radius when volatile
var detonate_mult: float = 0.8           ## blast damage × the player's live damage stat

var _sprite: AnimatedSprite2D = null
var _facing: String = "down_left"
var _state: String = "spawn"             ## "spawn" (rising, inert) → "walk" → "die"
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
	if volatile:
		_sprite.modulate = VOLATILE_TINT
	add_child(_sprite)
	_sprite.animation_finished.connect(_on_anim_finished)
	if is_instance_valid(player_ref):
		_home_side = -1.0 if global_position.x < player_ref.global_position.x else 1.0
	## Play the emerge as our own sprite and stay inert (see _process) until it finishes — the bones
	## assemble in place and become this skeleton, then _on_anim_finished flips us to active.
	_sprite.play(&"spawn")


func _process(delta: float) -> void:
	if not is_instance_valid(player_ref):
		queue_free()
		return
	## Inert while rising (spawn) or dissolving (die) — no hunting, no locomotion, holds its spot.
	if _state == "die" or _state == "spawn":
		return

	_life -= delta
	if _life <= 0.0:
		## A volatile skeleton's lifetime IS its fuse — it always goes off, even with nothing near.
		if volatile:
			_detonate()
		else:
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
	## The player-centric leash keeps a champion fighting over the Shade's patch of ground. A
	## volatile skeleton has no patch to hold — it is already spent — so it chases wherever it must.
	if target != null and (not is_instance_valid(target) or not target.get("is_alive") \
			or (not volatile and player_ref.global_position.distance_squared_to(target.global_position) > LEASH_RANGE_SQ)):
		target = null
		_hunt_target = null

	if target:
		var to_t: Vector2 = target.global_position - global_position
		if to_t.length_squared() <= STRIKE_RANGE_SQ:
			if volatile:
				_detonate()
			elif _cooldown <= 0.0:
				_start_strike(target)
			else:
				_face_toward(to_t)
				_play_dir(&"idle")   ## looming over its prey between cleaves
		else:
			_walk_toward(target.global_position, delta)
		return

	## No prey in reach. A volatile skeleton keeps running forward rather than reporting back —
	## it burns its fuse looking for something to hit.
	if volatile:
		_play_dir(&"move")
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
	if volatile:
		speed *= VOLATILE_SPEED_MULT
	elif player_ref and global_position.distance_squared_to(player_ref.global_position) > 120.0 * 120.0:
		speed *= CATCHUP_MULT   ## catch-up is a bodyguard behaviour; a fuse never goes home
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


## Bone Legion payload: the skeleton comes apart, throwing its own bones through everything around
## it. Damage reads the player's LIVE damage stat at detonation time, like every other pet strike in
## the game, so it scales with the run instead of with whatever the Shade had when he raised it.
## One-shot and terminal — it frees itself immediately, no Die outro (there is nothing left to fall
## over), and the Bone_Impact burst is the whole visual.
func _detonate() -> void:
	if _state == "die":
		return
	_state = "die"
	var dmg: float = 24.0
	var attacker: Node2D = self
	if is_instance_valid(player_ref):
		dmg = player_ref.get_stat("damage") * detonate_mult
		attacker = player_ref
	var r_sq: float = detonate_radius * detonate_radius
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.get("is_alive"):
			continue
		if global_position.distance_squared_to(e.global_position) > r_sq:
			continue
		var hit := DamageCalculator.calculate_raw_hit(attacker, e, dmg, damage_type)
		if not hit.is_dodged:
			e.take_damage(hit)
	_spawn_blast_vfx()
	queue_free()


## The pack's own Bone_Impact one-shot, scaled to the blast radius. Parented to the scene rather than
## to self, because self is about to be freed.
func _spawn_blast_vfx() -> void:
	var frames: SpriteFrames = ChainFactory._get_bone_impact_frames()
	if frames == null or not frames.has_animation(&"impact"):
		return
	var burst := AnimatedSprite2D.new()
	burst.sprite_frames = frames
	burst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	burst.z_index = 2
	burst.modulate = VOLATILE_TINT
	## The sheet's burst is drawn for a 32px cell; scale it to cover the radius it actually deals in.
	var s: float = detonate_radius / 16.0
	burst.scale = Vector2(s, s)
	get_tree().current_scene.add_child(burst)
	burst.global_position = global_position
	burst.play(&"impact")
	burst.animation_finished.connect(burst.queue_free)


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
	if _state == "spawn":
		## Fully risen — hand off from the emerge to a facing idle and go active.
		_state = "walk"
		_play_dir(&"idle")
	elif _state == "die":
		queue_free()


func _nearest_prey() -> Node2D:
	## Nearest live enemy within engage range of the CHAMPION. Gated by the 0.3s rescan.
	var best: Node2D = null
	var best_d: float = VOLATILE_ENGAGE_SQ if volatile else ENGAGE_RANGE_SQ
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
	## "spawn" = the matching Rise_Skeletal_Champion emerge (32px, row 0 = one skeleton clawing up),
	## non-directional, plays once. The body sheets are the risen skeleton it becomes.
	_slice_single(frames, "spawn", RISE_SHEET, 18, 18.0, false)
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
