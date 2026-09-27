extends RefCounted

## SimArena — what stands in the training room for one scenario, and how it is kept there.
##
##   single    one immortal, rooted dummy            → sustained single-target DPS
##   cluster   six immortal, rooted dummies, tight   → sustained AoE DPS (sum over the pack)
##   horde     killable chasing fodder, player immune → clear speed (kills/min); fires on-kill procs
##   pressure  the real enemy mix at real stats, hitting back, escalating → survival time
##
## "Immortal" is the Training Panel's own recipe (1e9 HP, pinned every frame). No player effect
## scales off enemy MAX HP (DamageCalculator's percent_max_hp is a heal-only path), so an absurd
## pool cannot inflate a hit — verified 2026-09-26. What immortal dummies DO hide is anything that
## reads the target's current HP fraction or needs a kill; that is what `horde` exists for.

const DUMMY_SCENE: String = "res://scenes/enemies/fodder.tscn"
const DUMMY_HP: float = 1.0e9
const TARGET_OFFSET: Vector2 = Vector2(0.0, -100.0)
const CLUSTER_RADIUS: float = 24.0
const CLUSTER_RING: int = 5
## Chasers spawn on a ring this far from the player — close enough that the fight starts at once,
## far enough that nothing spawns inside a swing.
const SPAWN_RING: float = 170.0
## Keep spawns inside the flat arena (±800 x ±600), with a margin for the wall band.
const BOUND: Rect2 = Rect2(-740.0, -540.0, 1480.0, 1080.0)

## Pressure mix: enemy ids as registered in EnemySpawnManager, with draw weights.
const PRESSURE_MIX: Array = [["fodder", 5], ["swarmer", 3], ["brute", 1], ["caster", 1]]
const PRESSURE_SPAWN_EVERY: int = 24          ## frames between spawns while under the target count
const PRESSURE_START: int = 4
const PRESSURE_GROWTH_S: float = 5.0          ## +1 to the target alive count every N seconds
const PRESSURE_CAP: int = 30
## +1.0 difficulty every N seconds: at 150s that is 11x, i.e. enemies at 6x HP, 4x contact damage,
## 2x speed (enemy.apply_difficulty_scaling). Steep on purpose: a level-1 kit goes down several
## times inside the window, so "lives spent" has a range to discriminate in.
const PRESSURE_RAMP_S: float = 15.0
## Horde: a new pack lands when this many (or fewer) of the last one are still standing.
const HORDE_REFILL_AT: int = 2
const HORDE_PACK_DIST: float = 130.0
const HORDE_PACK_SPREAD: float = 26.0

var _scene: Node = null
var _player: Node2D = null
var _kind: String = "single"
var _dummies: Array[Node2D] = []
var _chasers: Array[Node2D] = []
var _horde_count: int = 10
var _horde_hp: float = 60.0
var _spawned: int = 0
var _spawn_misses: Dictionary = {}
var _peak_alive: int = 0
var _dummy_scene: PackedScene = null
var _start_pos: Vector2 = Vector2.ZERO
## Scenario "dummy_touch": true keeps the dummies' touch handler connected — only for verifying
## the game's own zero-contact-damage gate (enemy._on_hurtbox_body_entered).
var _dummy_touch: bool = false
var _immortal_topup: bool = false


func place_player() -> void:
	_player.global_position = _start_pos
	_player.velocity = Vector2.ZERO
	_player.knockback_velocity = Vector2.ZERO


func setup(scene: Node, player: Node2D, sc: Dictionary) -> void:
	_scene = scene
	_player = player
	_kind = str(sc.get("arena", "single"))
	_horde_count = int(sc.get("horde_count", 8))
	_horde_hp = float(sc.get("enemy_hp", 60.0))
	_dummy_touch = bool(sc.get("dummy_touch", false))
	_dummy_scene = load(DUMMY_SCENE)
	var rng_range: float = float(sc.get("range", 40.0))
	match _kind:
		"single":
			_player.god_mode = true
			_spawn_dummy(TARGET_OFFSET)
			## Start AT the preferred range (placed by place_player once the dummies have settled):
			## sustained DPS should not include a walk-in, which would penalise exactly the
			## short-range kits by a fixed, meaningless 1-2 seconds.
			_start_pos = TARGET_OFFSET + Vector2(0.0, rng_range)
		"cluster":
			_player.god_mode = true
			_spawn_dummy(TARGET_OFFSET)
			for i in range(CLUSTER_RING):
				var a: float = TAU * float(i) / float(CLUSTER_RING) - PI * 0.5
				_spawn_dummy(TARGET_OFFSET + Vector2(cos(a), sin(a)) * CLUSTER_RADIUS)
			## Ring slot 0 sits straight up, so the nearest dummy to a player below the pack is
			## the centre one at exactly `range`.
			_start_pos = TARGET_OFFSET + Vector2(0.0, rng_range)
		"horde":
			## Immune, but NOT via god_mode. god_mode returns from take_damage before i-frames are
			## set, so every contact shove that real play blocks with i-frames landed here — and
			## with the player's (since fixed) compounding knockback, a Tempest Vortex pull threw
			## the Sellsword into the wall and read as a game bug (2026-09-27). Death prevention +
			## a top-up keeps the whole real hit path (i-frames, flash, flinch, blocked knockback).
			_player.god_mode = false
			_player.health._death_prevention_count += 1
			_immortal_topup = true
		"pressure":
			_player.god_mode = false
			GameManager.difficulty_multiplier = 1.0
			## Survival = seconds until the FIRST would-be death, in a brawl: enemies ring the
			## player and the bot fights at its policy's range without escape-kiting (see
			## SimPilot._kite for why). The engine's own death-prevention hook (the counter that
			## prevents_death statuses use) catches the killing blow, so the death screen / run-end
			## flow never runs; the driver ends the scenario on that first down. Measured
			## 2026-09-26: first-down time has a seed-to-seed CV of ~0.05-0.13 here, against ~0.8
			## for time-to-death with kiting and ~1-2 for "lives spent over a window".
			_player.health._death_prevention_count += 1
			_player.health.death_prevented.connect(_on_death_prevented)
		_:
			push_error("[sim] unknown arena '%s'" % _kind)


var downs: int = 0
var first_down_frame: int = -1
var _frame: int = 0


func _on_death_prevented(_entity) -> void:
	## Only OUR prevention caught it — a kit's own prevents_death status (if one is active) is a
	## real mechanic and must behave exactly as in play, so it is not counted or refilled.
	if _player.health._death_prevention_count > 1:
		return
	downs += 1
	if first_down_frame < 0:
		first_down_frame = _frame
	_player.health.current_hp = _player.health.max_hp
	_player.health.health_changed.emit(_player.health.current_hp, _player.health.max_hp)


## Lives spent: whole downs plus the fraction of the current bar that is gone.
func finished() -> bool:
	return _kind == "pressure" and downs > 0


func lives_used() -> float:
	if not is_instance_valid(_player) or _player.health == null or _player.health.max_hp <= 0.0:
		return float(downs)
	return downs + (1.0 - _player.health.current_hp / _player.health.max_hp)


func _spawn_dummy(pos: Vector2) -> void:
	var d: Node2D = _dummy_scene.instantiate()
	_scene.add_child(d)
	d.global_position = pos
	d.max_hp = DUMMY_HP
	d.base_move_speed = 0.0
	d.contact_damage = 0.0
	d.xp_value = 0.0
	d.health_drop_chance = 0.0
	if d.health:
		d.health.setup(DUMMY_HP)
	## Dummies must not touch the player at all. enemy._on_hurtbox_body_entered applies contact
	## KNOCKBACK on first touch without checking contact_damage > 0 (the sustained-contact path
	## does check), so even a zero-damage dummy shoves the player off the pack, and god_mode stops
	## damage, not knockback. Armor scales the shove: after the 2026-09-27 armor fix, +3 armor left
	## the player 5 px closer and a third dummy inside every swing, so Vitality read as "+16% pack
	## DPS". Disconnecting the touch handler keeps the dummy arenas a pure damage measurement.
	if not _dummy_touch and d.get("hurtbox") != null 			and d.hurtbox.body_entered.is_connected(d._on_hurtbox_body_entered):
		d.hurtbox.body_entered.disconnect(d._on_hurtbox_body_entered)
	_dummies.append(d)


func tick(frame: int) -> void:
	_frame = frame
	if _immortal_topup and is_instance_valid(_player) and _player.health:
		_player.health.current_hp = _player.health.max_hp
	match _kind:
		"single", "cluster":
			for d in _dummies:
				if is_instance_valid(d) and d.health:
					d.health.current_hp = d.health.max_hp
					d.health.is_dead = false
					d.is_alive = true
					d.contact_damage = 0.0   ## harmless every tick, as the TrainingPanel pins its row
		"horde":
			_prune()
			## Waves, not a sprinkle: a clumped pack arrives from one bearing whenever the last
			## one is nearly cleared — the shape the real spawner's ring converges into, and the
			## one AoE is for. A thin even ring measured walking speed more than clear speed.
			if _chasers.size() <= HORDE_REFILL_AT:
				_spawn_pack(_horde_count, _horde_hp)
		"pressure":
			_prune()
			var t: float = frame / 60.0
			## Difficulty ramps on the same seam the real run clock uses (difficulty_multiplier →
			## _get_effective_difficulty → enemy.apply_difficulty_scaling), so late spawns carry
			## more HP, contact damage and speed exactly as they would deeper in a run.
			GameManager.difficulty_multiplier = 1.0 + t / PRESSURE_RAMP_S
			var want: int = mini(PRESSURE_START + int(t / PRESSURE_GROWTH_S), PRESSURE_CAP)
			if _chasers.size() < want and frame % PRESSURE_SPAWN_EVERY == 0:
				_spawn_chaser(_pick_pressure_id(), -1.0)
	_peak_alive = maxi(_peak_alive, _chasers.size())
	## EnemySpawnManager only DEcrements active_enemies through the on_kill hookup that
	## start_spawning() makes — and the training room never calls start_spawning. Every spawn_add
	## here counted up and nothing counted down, so spawning silently stopped at max_enemies (90)
	## and the pressure test turned into "survive an empty room". The sim owns this room's
	## population, so it states the count outright.
	if _kind == "horde" or _kind == "pressure":
		EnemySpawnManager.active_enemies = _chasers.size()


func _prune() -> void:
	var keep: Array[Node2D] = []
	for c in _chasers:
		if is_instance_valid(c) and c.is_alive:
			keep.append(c)
	_chasers = keep


func _pick_pressure_id() -> String:
	var total: int = 0
	for pair in PRESSURE_MIX:
		total += int(pair[1])
	var roll: int = randi() % total
	for pair in PRESSURE_MIX:
		roll -= int(pair[1])
		if roll < 0:
			return str(pair[0])
	return "fodder"


## Spawn through EnemySpawnManager.spawn_add — the real definition, the real scene, the real
## difficulty scaling — then override only what the scenario controls. XP is zeroed so a kill can
## never open the level-up screen (it pauses the tree) and silently change the build mid-measure.
func _spawn_chaser(enemy_id: String, hp: float) -> bool:
	var pos: Vector2 = _ring_point()
	var e: Node2D = EnemySpawnManager.spawn_add(enemy_id, pos)
	if e == null:
		_spawn_misses[enemy_id] = int(_spawn_misses.get(enemy_id, 0)) + 1
		return false
	e.xp_value = 0.0
	e.health_drop_chance = 0.0
	if hp > 0.0:
		e.max_hp = hp
		if e.health:
			e.health.setup(hp)
	_chasers.append(e)
	_spawned += 1
	return true


func _spawn_pack(count: int, hp: float) -> void:
	var origin: Vector2 = _player.global_position
	var bearing: Vector2 = Vector2.from_angle(randf() * TAU)
	var centre: Vector2 = origin + bearing * HORDE_PACK_DIST
	if not BOUND.has_point(centre):
		centre = origin + (Vector2.ZERO - origin).normalized() * HORDE_PACK_DIST
	for _i in range(count):
		var off: Vector2 = Vector2.from_angle(randf() * TAU) * randf() * HORDE_PACK_SPREAD
		var e: Node2D = EnemySpawnManager.spawn_add("fodder", centre + off)
		if e == null:
			_spawn_misses["fodder"] = int(_spawn_misses.get("fodder", 0)) + 1
			continue
		e.xp_value = 0.0
		e.health_drop_chance = 0.0
		e.max_hp = hp
		if e.health:
			e.health.setup(hp)
		_chasers.append(e)
		_spawned += 1


func _ring_point() -> Vector2:
	var origin: Vector2 = _player.global_position if is_instance_valid(_player) else Vector2.ZERO
	for _i in range(8):
		var a: float = randf() * TAU
		var p: Vector2 = origin + Vector2(cos(a), sin(a)) * SPAWN_RING
		if BOUND.has_point(p):
			return p
	## Pinned in a corner: fall back toward the arena centre.
	return origin + (Vector2.ZERO - origin).normalized() * SPAWN_RING


## Nearest live enemy to `from`, or null. The pilot's movement target (aiming itself is the
## shipped auto-aim, which scores by distance too).
func nearest_enemy(from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for e in _scene.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.is_alive:
			continue
		var d: float = from.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func live_enemies() -> Array:
	var out: Array = []
	for e in _scene.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.is_alive:
			out.append(e)
	return out


func kind() -> String:
	return _kind


func diagnostics() -> Dictionary:
	return {"spawned": _spawned, "peak_alive": _peak_alive, "spawn_misses": _spawn_misses,
			"dummies": _dummies.size(), "downs": downs,
			"first_down_s": (first_down_frame / 60.0) if first_down_frame >= 0 else -1.0}


func teardown() -> void:
	_dummies.clear()
	_chasers.clear()
