extends RefCounted

## SimPilot — the bot's hands. Presses the real InputMap actions each physics frame; the player
## script reads them back through Input exactly as it reads a keyboard.
##
## It does NOT aim. Settings.auto_aim is on for the whole worker, so every swing, bolt and skill
## points wherever the shipped auto-aim lock says — the same target selection a controller player
## gets. That keeps the bot from being a better aimer than a person, and keeps aiming out of the
## thing being measured.
##
## ── Rotations ──────────────────────────────────────────────────────────────────────────────────
##   L        mash light (LMB) — the light graph, restarted from neutral whenever it ends
##   H        mash heavy (RMB tap, released well inside TAUNT_HOLD_THRESHOLD)
##   L1H..L4H light until the chain reaches depth k (EventBus.on_combo_step), then heavy — the
##            "light-light-heavy" family; heavy keeps being pressed for as long as a heavy graph runs
##   C        hold RMB from neutral for `hold` seconds (the channel), release, repeat
##   W        hold LMB for `hold` seconds, release, repeat — the light graphs' held branches
##            (the Fighter's Whirlwind is `_branch_held("light_attack", ...)` off Attack/Swirl)
##
## Tapping is press-on-frame-N / release-on-N+1, every TAP_EVERY frames — i.e. as fast as Input can
## register separate just_pressed edges. It was 6 frames (10/s) until 2026-09-26, which looked like
## plenty against the kit's 0.22s MIN_TAP_CADENCE but was not: the chain advances on a BUFFERED
## press, and whether a fresh one was waiting when a window opened depended on how the 6-frame
## phase happened to line up with the chain. Measured on the Drifter light loop: advances landed
## 0.167s OR 0.183s apart depending on that phase, a ±3% DPS wobble that moved every time a pick
## changed attack timing (it made Flow read as -6% single-target). At every other frame there is
## always a fresh press in the buffer, which is what a player tapping early into each window gets.
##
## ── Skills ─────────────────────────────────────────────────────────────────────────────────────
##   none | q | e | qe      cast that slot whenever SkillComponent reports it ready
##   e_once | e_once_q      press E exactly once at the start (stance kits: Quiver Swap), + Q on CD
##   qed                    Q and E on cooldown, plus dash whenever a charge is up — several class
##                          dashes deal damage (Hell Breach, Planeshift), so the dash is a real part
##                          of those kits' output and the calibration should be allowed to find it
## _tick_combo only reads Q/E from NEUTRAL, so while a wanted skill is ready the pilot stops
## feeding the combo and lets it lapse — the same thing a person does to get a cast out.

const ALL_ACTIONS: Array[String] = ["light_attack", "heavy_attack", "skill_q", "skill_e", "dash",
		"move_left", "move_right", "move_up", "move_down", "fire"]
const ROTATIONS: Array[String] = ["L", "H", "L1H", "L2H", "L3H", "L4H", "C", "W"]
const TAP_EVERY: int = 2
## Skills are only cast with an enemy this close — a person does not burn a nuke on empty floor.
const SKILL_ENGAGE: float = 240.0
const MOVE_DEADBAND: float = 6.0
## Pressure kiting: enemies inside this radius push the pilot away, scaled by closeness.
const KITE_RADIUS: float = 70.0
const KITE_WEIGHT: float = 1.6
const WALL_MARGIN: float = 90.0
const ARENA_HALF: Vector2 = Vector2(800.0, 600.0)

var _player: Node2D = null
var _rotation: String = "L"
var _skills: String = "none"
var _range: float = 40.0
var _hold_frames: int = 90
var _k: int = 0                        ## depth threshold for LkH
var _depth: int = 0                    ## current light-chain depth (on_combo_step)
var _held: Dictionary = {}             ## action -> true while this pilot holds it
var _release_at: Dictionary = {}       ## action -> frame to release a tap on
var _channel_until: int = -1
var _channel_cool_until: int = 0
var _e_once_done: bool = false
## Escape-kiting in the pressure arena. OFF by default: with it on, slow melee mobs could not catch
## the bot unless it cornered itself, so survival came out bimodal (0 or 5 downs for the same build
## on different seeds) and measured the kiting, not the build. Kept for experiments.
var _kite: bool = false

## Diagnostics.
var _taps: Dictionary = {}
var _skill_casts: Dictionary = {"skill_q": 0, "skill_e": 0}
var _skill_starved: Dictionary = {"skill_q": 0, "skill_e": 0}
var _frames_moving: int = 0
var _frames_total: int = 0
var _dist_sum: float = 0.0
var _dist_n: int = 0
var _max_depth: int = 0
var _channels: int = 0
var _prev_ready: Dictionary = {"skill_q": false, "skill_e": false}
## Optional per-half-second trace (scenario "trace": true) — for debugging the pilot, not reports.
var _trace_on: bool = false
var _trace: Array = []
var _trace_every: int = 30


func setup(player: Node2D, sc: Dictionary) -> void:
	_player = player
	_rotation = str(sc.get("rotation", "L"))
	_skills = str(sc.get("skills", "none"))
	_range = float(sc.get("range", 40.0))
	_hold_frames = int(round(float(sc.get("hold", 1.5)) * 60.0))
	if _rotation.begins_with("L") and _rotation.ends_with("H") and _rotation.length() == 3:
		_k = int(_rotation.substr(1, 1))
	_trace_on = bool(sc.get("trace", false))
	_trace_every = maxi(1, int(sc.get("trace_every", 30)))
	_kite = bool(sc.get("kite", false))
	EventBus.on_combo_step.connect(_on_combo_step)


func _on_combo_step(entity, depth: int, _is_finisher: bool) -> void:
	if entity == _player:
		_depth = depth
		_max_depth = maxi(_max_depth, depth)


func tick(frame: int, arena) -> void:
	_frames_total += 1
	_release_due(frame)
	var target: Node2D = arena.nearest_enemy(_player.global_position)
	_steer(target, arena)

	var runner = _player.get("choreography_runner")
	var running: bool = runner != null and runner.is_running()
	if not running:
		_depth = 0
	if _trace_on and (frame % _trace_every == 0 or (frame < 40 and _player.knockback_velocity.length_squared() > 1.0)):
		_trace.append({
			"t": frame / 60.0,
			"pos": [snappedf(_player.global_position.x, 0.1), snappedf(_player.global_position.y, 0.1)],
			"vel": snappedf(_player.velocity.length(), 0.1),
			"dist": snappedf(_player.global_position.distance_to(target.global_position), 0.1) if target else -1.0,
			"running": running,
			"ability": str(runner.get_ability().ability_id) if running and runner.get_ability() else "",
			"auto": str(_player.get_auto_aim_target().name) if _player.get_auto_aim_target() else "",
			"near": str(target.name) if target else "",
			"kb": [snappedf(_player.knockback_velocity.x, 0.1), snappedf(_player.knockback_velocity.y, 0.1)],
			"v": [snappedf(_player.velocity.x, 0.1), snappedf(_player.velocity.y, 0.1)],
			"dash": snappedf(float(_player.get("_dash_timer")), 0.01),
			"anim": str(_player.sprite.animation) if _player.get("sprite") else "",
		})

	if _skills == "qed" and target != null and int(_player.get("_dash_charges")) > 0:
		_tap("dash", frame)

	## Skills first: while one we want is ready, starve the combo so the cast comes out.
	var want_skill: String = _wanted_ready_skill(frame, target)
	if want_skill != "":
		if not running:
			_tap(want_skill, frame)
		return

	match _rotation:
		"C":
			_tick_hold("heavy_attack", frame, running)
		"W":
			_tick_hold("light_attack", frame, running)
		"H":
			_tap("heavy_attack", frame)
		"L":
			_tap("light_attack", frame)
		_:
			if _k > 0:
				_tick_light_heavy(frame, runner, running)
			else:
				_tap("light_attack", frame)


func _tick_light_heavy(frame: int, runner, running: bool) -> void:
	if not running:
		_tap("light_attack", frame)
		return
	var light_graph = _player.get("_combo_ability")
	if runner.get_ability() == light_graph:
		_tap("heavy_attack" if _depth >= _k else "light_attack", frame)
	else:
		## A heavy graph is running: keep feeding it heavy so it reaches its finisher.
		_tap("heavy_attack", frame)


func _tick_hold(action: String, frame: int, running: bool) -> void:
	if _channel_until > 0:
		if frame >= _channel_until:
			_release(action)
			_channel_until = -1
			_channel_cool_until = frame + 18
		return
	if frame < _channel_cool_until or running:
		return
	_press(action)
	_channel_until = frame + _hold_frames
	_channels += 1


## The skill slot to cast right now, or "". Also counts casts by watching ready→not-ready edges.
func _wanted_ready_skill(frame: int, target: Node2D) -> String:
	var sc = _player.get("skill_component")
	if sc == null:
		return ""
	for slot: String in ["skill_q", "skill_e"]:
		var ready: bool = sc.has_skill(slot) and sc.is_ready(slot)
		if _prev_ready[slot] and not ready:
			_skill_casts[slot] = int(_skill_casts[slot]) + 1
		_prev_ready[slot] = ready
	var engaged: bool = target != null and \
			_player.global_position.distance_to(target.global_position) <= SKILL_ENGAGE
	if not engaged:
		return ""
	if _skills.begins_with("e_once") and not _e_once_done:
		if sc.has_skill("skill_e") and sc.is_ready("skill_e"):
			_e_once_done = true
			return "skill_e"
	for slot: String in _skill_slots():
		if sc.has_skill(slot) and sc.is_ready(slot):
			_skill_starved[slot] = int(_skill_starved[slot]) + 1
			return slot
	return ""


func _skill_slots() -> Array[String]:
	match _skills:
		"q", "e_once_q":
			return ["skill_q"]
		"e":
			return ["skill_e"]
		"qe", "qed":
			return ["skill_q", "skill_e"]
	return []


func _steer(target: Node2D, arena) -> void:
	var v: Vector2 = Vector2.ZERO
	var pos: Vector2 = _player.global_position
	if target != null:
		var to_t: Vector2 = target.global_position - pos
		var d: float = to_t.length()
		_dist_sum += d
		_dist_n += 1
		if d > _range + MOVE_DEADBAND:
			v = to_t / maxf(d, 0.001)
		elif d < _range - MOVE_DEADBAND:
			v = -to_t / maxf(d, 0.001)
	if _kite and arena.kind() == "pressure":
		v += _kite_push(pos, arena)
	if v.length_squared() > 1.0:
		v = v.normalized()
	_set_move(v)


func _kite_push(pos: Vector2, arena) -> Vector2:
	var push: Vector2 = Vector2.ZERO
	for e in arena.live_enemies():
		var away: Vector2 = pos - e.global_position
		var d: float = away.length()
		if d < KITE_RADIUS and d > 0.001:
			push += away / d * (1.0 - d / KITE_RADIUS) * KITE_WEIGHT
	## Walls: the arena is a box, and a kiting bot that backs into a corner dies there.
	if pos.x > ARENA_HALF.x - WALL_MARGIN:
		push.x -= 1.0
	elif pos.x < -ARENA_HALF.x + WALL_MARGIN:
		push.x += 1.0
	if pos.y > ARENA_HALF.y - WALL_MARGIN:
		push.y -= 1.0
	elif pos.y < -ARENA_HALF.y + WALL_MARGIN:
		push.y += 1.0
	return push


func _set_move(v: Vector2) -> void:
	_set_axis("move_right", maxf(v.x, 0.0))
	_set_axis("move_left", maxf(-v.x, 0.0))
	_set_axis("move_down", maxf(v.y, 0.0))
	_set_axis("move_up", maxf(-v.y, 0.0))
	if v.length_squared() > 0.0:
		_frames_moving += 1


func _set_axis(action: String, strength: float) -> void:
	if strength > 0.001:
		Input.action_press(action, clampf(strength, 0.0, 1.0))
	else:
		Input.action_release(action)


func _tap(action: String, frame: int) -> void:
	if frame % TAP_EVERY != 0 or _held.get(action, false):
		return
	_press(action)
	_release_at[action] = frame + 1
	_taps[action] = int(_taps.get(action, 0)) + 1


func _press(action: String) -> void:
	Input.action_press(action)
	_held[action] = true


func _release(action: String) -> void:
	Input.action_release(action)
	_held[action] = false


func _release_due(frame: int) -> void:
	for a in _release_at.keys():
		if frame >= int(_release_at[a]):
			_release(a)
			_release_at.erase(a)


func diagnostics() -> Dictionary:
	return {
		"taps": _taps,
		"skill_casts": _skill_casts,
		"channels": _channels,
		"max_depth": _max_depth,
		"moving_frac": float(_frames_moving) / maxf(_frames_total, 1),
		"avg_dist": _dist_sum / maxf(_dist_n, 1),
		"trace": _trace,
	}


func warnings() -> Array:
	var w: Array = []
	for slot: String in _skill_slots():
		if int(_skill_casts[slot]) == 0:
			w.append("%s requested but never cast" % slot)
	if (_rotation == "C" or _rotation == "W") and _channels == 0:
		w.append("channel rotation never started a hold")
	return w
