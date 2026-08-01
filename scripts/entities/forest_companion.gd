extends Node2D

## ForestCompanion — the Verdant's called beasts (Q: one Forest Bear · E: a pair of Forest Hounds).
##
## Replaces the shapeshift system entirely (Ben 2026-08-01: "i dont like the transformations at all.
## what if Q summoned a bear and E summoned 2 hounds"). The Druid keeps the ranged caster chain he
## liked and the pack's Forest Beast / Forest Hound sheets — idle, walk, attack, damage, all four
## facing rows each — now drive autonomous companions instead of the player's own body.
##
## ONE script, two species, because the two are mechanically identical animals with different
## numbers and different sheets. Same reasoning as SkeletalChampion serving both the Q champion and
## the E legion: a second script would be the same 200 lines with two constants changed.
##
## Pet standard (CLAUDE.md, set by FireFamiliar/BloodElemental): its OWN constant-speed locomotion
## with catch-up, hunts prey within a player-centric leash, settles/roams with hysteresis when idle,
## never lerp-glued to the player. Damage reads the player's live damage stat at strike time.

class_name ForestCompanion

const SHAPE_DIR: String = "res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Druid/Special_Animations/Shape_Shifting/"
## Facing → sheet row (the pack's standard diagonal-facing order, same as CharacterSpriteFactory).
const DIR_ROWS: Dictionary = {"down_right": 0, "down_left": 1, "up_right": 2, "up_left": 3}

## Per-species sheets, frame counts and feel. The Bear is the anchor you summon and fight behind;
## the Hounds are a fast, fragile pair that go and worry whatever is nearest. Neither pack folder
## ships a Die sheet, which is why despawning fades rather than playing an outro.
const SPECIES: Dictionary = {
	"bear": {
		"folder": "Forest_Beast/Minifantasy_TrueHeroesForestBeast",
		"idle": [11, 9.0], "walk": [6, 10.0], "attack": [5, 18.0], "dmg": [4, 15.0],
		"lifetime": 20.0,
		"walk_speed": 42.0,       ## lumbering — it holds ground rather than chasing
		"engage": 130.0,
		"leash": 130.0,
		"strike_range": 32.0,
		"cooldown": 1.8,
		"strike_frame": 2,        ## the paw lands
		"damage_mult": 0.75,      ## × the player's live damage stat — the heavy hitter
		"aoe_radius": 26.0,       ## the swipe catches a small cluster, not one body
		"scale": 1.0,
	},
	"hound": {
		"folder": "Forest_Hound/Minifantasy_TrueHeroesForestHound",
		"idle": [12, 9.0], "walk": [4, 12.0], "attack": [4, 14.0], "dmg": [4, 15.0],
		"lifetime": 14.0,
		"walk_speed": 68.0,       ## they run the fight down
		"engage": 190.0,
		"leash": 190.0,
		"strike_range": 24.0,
		"cooldown": 0.9,          ## bites twice for every one of the bear's swipes
		"strike_frame": 2,
		"damage_mult": 0.28,      ## individually slight; there are two of them
		"aoe_radius": 0.0,        ## single-target bites
		"scale": 0.85,            ## visibly smaller than the bear
	},
}

const CATCHUP_MULT: float = 1.6           ## jog when left far behind
const HOME_FAR_SQ: float = 46.0 * 46.0    ## starts following the player beyond this
const HOME_NEAR_SQ: float = 26.0 * 26.0   ## settles once back within this (hysteresis — no jitter)
const MATERIALIZE_TIME: float = 0.3       ## rise-in, paired with the host's root-eruption decal
const FADE_TIME: float = 0.4              ## despawn dissolve (no Die sheet in either folder)

## Set by player.gd before add_child.
var species: String = "bear"
var player_ref: Node2D = null
var damage_type: String = "Physical"
## Where this animal idles relative to the player, in local pixels. The SPAWNER assigns it, because
## only the spawner knows how many it is raising: left to themselves both hounds computed the same
## home from their spawn side and settled 2px apart, reading as one animal instead of a pair.
## Zero means "pick a side from where I spawned", which is what a lone bear does.
var home_offset: Vector2 = Vector2.ZERO

var _cfg: Dictionary = {}
var _sprite: AnimatedSprite2D = null
var _facing: String = "down_left"
var _state: String = "rise"                ## "rise" → "walk" → "fade"
var _life: float = 0.0
var _t: float = 0.0                        ## rise/fade progress
var _cooldown: float = 0.0
var _strike_timer: float = -1.0
var _strike_target: Node2D = null
var _hunt_target: Node2D = null
var _rescan: float = 0.0
var _following: bool = false               ## currently walking home (hysteresis state)
var _home_side: float = 1.0                ## fixed at spawn — no side-flipping anchors

static var _frames_cache: Dictionary = {}  ## species → SpriteFrames


func _ready() -> void:
	z_index = 1
	_cfg = SPECIES.get(species, SPECIES["bear"])
	_life = float(_cfg["lifetime"])
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _get_frames(species)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	if is_instance_valid(player_ref):
		_home_side = -1.0 if global_position.x < player_ref.global_position.x else 1.0
		if home_offset == Vector2.ZERO:
			home_offset = Vector2(26.0 * _home_side, 6.0)
	_play_dir(&"idle")
	## Rises out of the ground: the host drops the pack's root-eruption decal at these feet, and the
	## animal grows into place over it rather than popping in at full size.
	_sprite.scale = Vector2.ZERO
	_sprite.modulate.a = 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(player_ref):
		queue_free()
		return

	if _state == "rise":
		_t += delta
		var k: float = clampf(_t / MATERIALIZE_TIME, 0.0, 1.0)
		var s: float = float(_cfg["scale"]) * k
		_sprite.scale = Vector2(s, s)
		_sprite.modulate.a = k
		if k >= 1.0:
			_state = "walk"
		return

	if _state == "fade":
		_t += delta
		_sprite.modulate.a = clampf(1.0 - _t / FADE_TIME, 0.0, 1.0)
		if _t >= FADE_TIME:
			queue_free()
		return

	_life -= delta
	if _life <= 0.0:
		banish()
		return

	## Resolve a pending strike (damage lands on the attack anim's contact frame).
	if _strike_timer > 0.0:
		_strike_timer -= delta
		if _strike_timer <= 0.0:
			_resolve_strike()
		return   ## hold position + facing while striking

	_cooldown -= delta

	## Hunt: go after prey near ITSELF, leashed to the player's vicinity so it never wanders off.
	_rescan -= delta
	if _rescan <= 0.0:
		_rescan = 0.3
		_hunt_target = _nearest_prey()
	var target: Node2D = _hunt_target
	var leash_sq: float = float(_cfg["leash"]) * float(_cfg["leash"])
	if target != null and (not is_instance_valid(target) or not target.get("is_alive") \
			or player_ref.global_position.distance_squared_to(target.global_position) > leash_sq):
		target = null
		_hunt_target = null

	if target:
		var to_t: Vector2 = target.global_position - global_position
		var reach: float = float(_cfg["strike_range"])
		if to_t.length_squared() <= reach * reach:
			if _cooldown <= 0.0:
				_start_strike(target)
			else:
				_face_toward(to_t)
				_play_dir(&"idle")   ## circling its prey between strikes
		else:
			_walk_toward(target.global_position, delta)
		return

	## No prey — hold ground near the player; only follow once left behind.
	var home: Vector2 = player_ref.global_position + home_offset
	var d2: float = global_position.distance_squared_to(home)
	if _following:
		if d2 <= HOME_NEAR_SQ:
			_following = false
	elif d2 >= HOME_FAR_SQ:
		_following = true
	if _following:
		_walk_toward(home, delta)
	else:
		_play_dir(&"idle")


## Constant-speed locomotion (faster when left far behind) — its own legs, never a lerp.
func _walk_toward(dest: Vector2, delta: float) -> void:
	var to_dest: Vector2 = dest - global_position
	var speed: float = float(_cfg["walk_speed"])
	if player_ref and global_position.distance_squared_to(player_ref.global_position) > 130.0 * 130.0:
		speed *= CATCHUP_MULT
	var step: Vector2 = to_dest.limit_length(speed * delta)
	if step.length_squared() > 0.04:
		global_position += step
		_face_toward(to_dest)
	_play_dir(&"walk")


func _start_strike(target: Node2D) -> void:
	_strike_target = target
	_strike_timer = float(_cfg["strike_frame"]) / float(_cfg["attack"][1])
	_cooldown = float(_cfg["cooldown"])
	_face_toward(target.global_position - global_position)
	_play_dir(&"attack")


func _resolve_strike() -> void:
	_strike_timer = -1.0
	var target: Node2D = _strike_target
	_strike_target = null
	if not is_instance_valid(target) or not target.get("is_alive"):
		return
	var reach: float = float(_cfg["strike_range"]) + 20.0
	if global_position.distance_squared_to(target.global_position) > reach * reach:
		return   ## it slipped out of reach mid-swing
	var attacker: Node2D = player_ref if is_instance_valid(player_ref) else self
	var dmg: float = 20.0
	if is_instance_valid(player_ref):
		dmg = player_ref.get_stat("damage") * float(_cfg["damage_mult"])

	## The bear's swipe catches everything in front of it; a hound's bite is one throat.
	var radius: float = float(_cfg["aoe_radius"])
	if radius <= 0.0:
		_bite(attacker, target, dmg)
		return
	var r_sq: float = radius * radius
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.get("is_alive"):
			continue
		if target.global_position.distance_squared_to(e.global_position) <= r_sq:
			_bite(attacker, e, dmg)


func _bite(attacker: Node2D, victim: Node2D, dmg: float) -> void:
	var hit := DamageCalculator.calculate_raw_hit(attacker, victim, dmg, damage_type)
	if not hit.is_dodged:
		victim.take_damage(hit)


## Early dismissal (resummon or lifetime end). Neither species ships a Die sheet, so it dissolves.
func banish() -> void:
	if _state == "fade":
		return
	_state = "fade"
	_t = 0.0


## Kept name-compatible with the other pets so player.gd can dismiss any kind generically.
func disperse() -> void:
	banish()


func _nearest_prey() -> Node2D:
	var best: Node2D = null
	var engage: float = float(_cfg["engage"])
	var best_d: float = engage * engage
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


## Shared per-species SpriteFrames: idle/walk/attack/dmg, all 4 facing rows.
static func _get_frames(sp: String) -> SpriteFrames:
	if _frames_cache.has(sp):
		return _frames_cache[sp]
	var cfg: Dictionary = SPECIES.get(sp, SPECIES["bear"])
	var stem: String = SHAPE_DIR + str(cfg["folder"])
	var frames := SpriteFrames.new()
	frames.clear_all()
	for anim in ["idle", "walk", "attack", "dmg"]:
		var spec: Array = cfg[anim]
		var loops: bool = anim == "idle" or anim == "walk"
		_slice_rows(frames, anim, "%s%s.png" % [stem, anim.capitalize()], int(spec[0]), float(spec[1]), loops)
	_frames_cache[sp] = frames
	return frames


static func _slice_rows(frames: SpriteFrames, base: String, path: String,
		count: int, fps: float, loops: bool) -> void:
	var tex: Texture2D = load(path)
	if tex == null:
		push_warning("ForestCompanion: missing sheet " + path)
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
