extends Node

## SimDriver — runs a queue of balance scenarios inside the REAL game, one Training Room load per
## scenario, and writes one JSON line of measurements per scenario.
##
## Nothing here re-implements combat. A scenario configures the same state a player would
## (character, class mods, level-up picks), loads the same main_arena scene in training mode, and
## presses the same InputMap actions a player would, so every number that comes out went through
## ChoreographyRunner, EffectDispatcher, DamageCalculator and the status system exactly as in play.
##
## Safety (CLAUDE.md "In-Game Testing — Training Room ONLY"):
##   * GameManager.training_mode is asserted on EVERY arrival, together with a live TrainingPanel.
##     If either is missing the worker aborts the whole job (exit 3) — it never measures a real run.
##   * Every scene change goes through the panel's own keep_training_mode(), the documented guard
##     against TrainingPanel._exit_tree clearing the flag on the way out.
##   * Persistence is off for the whole process (SimMode, --sim). Profile edits below are in memory.
##
## Job file (JSON): {"scenarios": [ {scenario}, ... ]}
## Scenario keys (all but id/character optional):
##   id          String   unique key echoed into the result
##   character   String   CharacterData id, e.g. "The Drifter"
##   mods        Array    class-mod ids to equip (≤ 3)
##   upgrades    Array    level-up pick ids applied in order (generic, ability or evolution ids)
##   arena       String   "single" | "cluster" | "horde" | "pressure"   (see SimArena)
##   rotation    String   see SimPilot.ROTATIONS
##   skills      String   "none" | "q" | "e" | "qe" | "e_once" | "e_once_q"
##   range       float    preferred standoff distance to the target, px
##   duration    float    measured seconds (wall-clock frames / 60; hitstop counts as elapsed)
##   seed        int      RNG seed — the same seed across a comparison is common random numbers
##   enemy_hp    float    horde: fodder HP
##   hold        float    rotation "C": channel hold seconds
##   weapon      String   class weapon in slot 1 (default: the character's signature green). The
##                        stages measure green only; this exists to compare blue/purple tiers.

const ARENA_SCENE: String = "res://scenes/main_arena.tscn"
const TRAINING_PANEL_SCRIPT: String = "res://scripts/ui/training_panel.gd"
const FPS: float = 60.0
## Frames to let the panel's deferred dummy spawn land before the arena is cleared.
const SETTLE_FRAMES: int = 3
## Hard ceiling on a scene load, in frames. A load that never reports ready is a harness fault,
## not a slow machine — main_arena readies in one frame headless.
const LOAD_TIMEOUT_FRAMES: int = 600

const SimPilot := preload("res://tools/sim/sim_pilot.gd")
const SimArena := preload("res://tools/sim/sim_arena.gd")
const SimMeter := preload("res://tools/sim/sim_meter.gd")

enum Phase { IDLE, LOADING, SETTLE, ARENA, RUN, DONE }
## Frames the arena's own population gets to finish initialising (with the arena's per-tick pins
## active) before the player is placed next to it. See _begin_run.
const ARENA_SETTLE_FRAMES: int = 4

var _scenarios: Array = []
var _index: int = -1
var _phase: Phase = Phase.IDLE
var _phase_frames: int = 0
var _out_path: String = ""
var _out: FileAccess = null
var _started_ms: int = 0

var _sc: Dictionary = {}
var _player: Node2D = null
var _pilot = null
var _arena = null
var _meter = null
var _warnings: Array[String] = []


func _ready() -> void:
	## Run before the arena and the player every physics frame, so an action pressed here reads
	## as just_pressed in the player's own _physics_process on the SAME frame.
	process_physics_priority = -1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	_started_ms = Time.get_ticks_msec()

	var job_path: String = _arg("--job=")
	_out_path = _arg("--out=")
	if job_path == "" or _out_path == "":
		_fail("usage: -- --sim --job=<json> --out=<jsonl>")
		return
	var text: String = FileAccess.get_file_as_string(job_path)
	var job = JSON.parse_string(text)
	if not (job is Dictionary) or not (job.get("scenarios") is Array):
		_fail("job file unreadable or has no scenarios: " + job_path)
		return
	_scenarios = job["scenarios"]
	_out = FileAccess.open(_out_path, FileAccess.WRITE)
	if _out == null:
		_fail("cannot open output " + _out_path)
		return

	## Process-wide sim configuration. Every one of these is an in-memory assignment — none of
	## them goes through a setter that persists (and SimMode blocks the ones that would).
	GameManager.debug_mode = false      ## no F-key panels / Unit Editor window in a worker
	Settings.auto_aim = true            ## the bot aims through the shipped auto-aim seam
	Settings.screen_shake = false
	Settings.damage_numbers_enabled = false
	_meter = SimMeter.new()
	_meter.connect_bus()
	_next_scenario()


func _arg(prefix: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return ""


func _fail(msg: String, code: int = 2) -> void:
	printerr("[sim] FATAL: " + msg)
	if _out != null:
		_out.store_line(JSON.stringify({"fatal": msg}))
		_out.flush()
	get_tree().quit(code)


# ─── Scenario lifecycle ───────────────────────────────────────────────────────

func _next_scenario() -> void:
	_release_all()
	_index += 1
	if _index >= _scenarios.size():
		_phase = Phase.DONE
		print("[sim] done: %d scenarios in %.1fs" % [_scenarios.size(),
				(Time.get_ticks_msec() - _started_ms) / 1000.0])
		_out.flush()
		get_tree().quit(0)
		return
	_sc = _scenarios[_index]
	_warnings.clear()
	_player = null
	if not _configure_profile():
		return

	## The scene change. If a panel is live we are "already in the room": its _exit_tree would
	## clear training_mode AFTER we set it, so ask the panel itself to keep it.
	var panel: Node = _find_training_panel()
	if panel != null:
		panel.keep_training_mode()
	GameManager.training_mode = true
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(ARENA_SCENE)
	_set_phase(Phase.LOADING)


## Clean, reproducible profile: no passive tree, signature weapon, no trinkets, no workshop, only
## the scenario's class mods. Measuring against Ben's live save would make every number depend on
## what he happens to have allocated this week.
func _configure_profile() -> bool:
	var char_id: String = str(_sc.get("character", "The Drifter"))
	if not CharacterData.ALL.has(char_id):
		_fail("unknown character '%s' in scenario %s" % [char_id, _sc.get("id", "?")])
		return false
	seed(int(_sc.get("seed", 1)))
	ProgressionManager.selected_character = char_id
	ProgressionManager.passive_allocations = {}
	ProgressionManager.character_loadouts = {}
	if _sc.has("weapon"):
		var wid: String = str(_sc["weapon"])
		if not WeaponData.equippable_for(wid, char_id):
			_fail("weapon '%s' is not equippable by %s (scenario %s)" % [wid, char_id, _sc.get("id", "?")])
			return false
		ProgressionManager.character_loadouts = {char_id: [wid, "", ""]}
	ProgressionManager.character_trinkets = {}
	ProgressionManager.hub_upgrades = []
	var mods: Array = []
	for m in _sc.get("mods", []):
		mods.append(str(m))
	ProgressionManager.character_mods = {char_id: mods}
	UpgradeManager.reset()
	EnemySpawnManager.active_enemies = 0
	return true


func _find_training_panel() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	for c in scene.get_children():
		var s = c.get_script()
		if s != null and s.resource_path == TRAINING_PANEL_SCRIPT:
			return c
	return null


func _set_phase(p: Phase) -> void:
	_phase = p
	_phase_frames = 0


func _physics_process(_delta: float) -> void:
	_phase_frames += 1
	match _phase:
		Phase.LOADING:
			_tick_loading()
		Phase.SETTLE:
			if _phase_frames >= SETTLE_FRAMES:
				_begin_run()
		Phase.ARENA:
			_arena.tick(0)
			if _phase_frames >= ARENA_SETTLE_FRAMES:
				_start_measure()
		Phase.RUN:
			_tick_run()


func _tick_loading() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or not scene.get("is_scene_ready"):
		if _phase_frames > LOAD_TIMEOUT_FRAMES:
			_fail("arena never became ready for scenario " + str(_sc.get("id", "?")))
		return
	## THE assertion. Anything else means main_arena built a real run: stop the worker.
	if not GameManager.training_mode or _find_training_panel() == null:
		_fail("arrived OUTSIDE the training room (training_mode=%s) — aborting, never measure a real run"
				% GameManager.training_mode, 3)
		return
	_player = scene.get_node_or_null("Player")
	if _player == null:
		_fail("no Player node in arena")
		return
	_set_phase(Phase.SETTLE)


func _begin_run() -> void:
	var scene: Node = get_tree().current_scene
	var panel: Node = _find_training_panel()
	## The panel spawns its own dummy row on setup; the scenario owns what stands in the arena.
	if panel != null:
		panel._clear_enemies()
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO

	var applied: Array = _apply_upgrades(_sc.get("upgrades", []))
	## Investigation hook: raw stat dicts ({"stat", "type", "value"}) straight into
	## apply_stat_upgrade, to isolate one stat of a multi-stat pick. Not used by any stage.
	for raw in _sc.get("raw_stats", []):
		if raw is Dictionary:
			_player.apply_stat_upgrade(raw)
			applied.append("raw:%s" % raw.get("stat", "?"))

	_arena = SimArena.new()
	_arena.setup(scene, _player, _sc)
	_sc["_applied_upgrades"] = applied
	if _arena.kind() != "single" and _arena.kind() != "cluster":
		_start_measure()   ## live arenas spawn on their own schedule from frame 0, as before
		return
	## Dummies are spawned now but the player is placed next to them only after ARENA_SETTLE_FRAMES.
	## A freshly spawned fodder finishes initialising during its first physics step and comes up
	## WITH contact damage for that step, and god_mode stops the damage but not the contact
	## knockback — so a player placed overlapping the pack on the spawn frame took one shove off
	## it. Armor scales that shove, which made +3 armor read as "+16% pack DPS" (2026-09-27).
	_set_phase(Phase.ARENA)


func _start_measure() -> void:
	_arena.place_player()
	_pilot = SimPilot.new()
	_pilot.setup(_player, _sc)
	_meter.begin(_player)
	_meter.log_hits = bool(_sc.get("hit_log", false))
	_set_phase(Phase.RUN)


## Resolve each id to the dict the level-up screen would have handed UpgradeManager, and apply it
## through the same apply_upgrade() the screen calls. Unknown ids are reported, never guessed.
func _apply_upgrades(ids: Array) -> Array:
	var applied: Array = []
	var kit_id: String = ModApplicability.kit_of(ProgressionManager.selected_character)
	for raw in ids:
		var uid: String = str(raw)
		var entry: Dictionary = _lookup_upgrade(uid, kit_id)
		if entry.is_empty():
			_warnings.append("unknown upgrade id '%s'" % uid)
			continue
		UpgradeManager.apply_upgrade(entry, _player)
		applied.append(uid)
	return applied


func _lookup_upgrade(uid: String, kit_id: String) -> Dictionary:
	for e: Dictionary in UpgradeManager.upgrade_pool:
		if e.get("id", "") == uid:
			return e
	for e: Dictionary in AbilityUpgradeData.get_upgrades_for_kit(kit_id):
		if e.get("id", "") == uid:
			return e
	for e: Dictionary in UpgradeManager.EVOLUTION_RECIPES:
		if e.get("id", "") == uid:
			return e
	return {}


func _tick_run() -> void:
	var duration_frames: int = int(round(float(_sc.get("duration", 30.0)) * FPS))
	_arena.tick(_phase_frames)
	var alive: bool = is_instance_valid(_player) and _player.is_alive
	if alive:
		_pilot.tick(_phase_frames, _arena)
	_meter.frames = _phase_frames
	if not alive or _arena.finished() or _phase_frames >= duration_frames:
		_finish(alive and not _arena.finished())


func _finish(alive: bool) -> void:
	_release_all()
	var r: Dictionary = _meter.result()
	r["id"] = _sc.get("id", "")
	r["character"] = _sc.get("character", "")
	r["kit"] = ModApplicability.kit_of(str(_sc.get("character", "")))
	r["arena"] = _sc.get("arena", "single")
	r["rotation"] = _sc.get("rotation", "L")
	r["skills"] = _sc.get("skills", "none")
	r["range"] = float(_sc.get("range", 40.0))
	r["seed"] = int(_sc.get("seed", 1))
	r["mods"] = _sc.get("mods", [])
	r["active_mods"] = ProgressionManager.get_active_class_mods(str(_sc.get("character", "")))
	r["upgrades"] = _sc.get("upgrades", [])
	r["applied_upgrades"] = _sc.get("_applied_upgrades", [])
	r["survived"] = alive
	r["level_stats"] = _snapshot_stats()
	r["pilot"] = _pilot.diagnostics()
	r["arena_info"] = _arena.diagnostics()
	if _arena.kind() == "pressure":
		r["downs"] = _arena.downs
		r["censored"] = _arena.downs == 0   ## lasted the whole window; `seconds` is a floor
	var warn: Array = _warnings.duplicate()
	warn.append_array(_pilot.warnings())
	r["warnings"] = warn
	## Mods that were asked for but did not survive get_active_class_mods are a harness error in
	## the job, not a balance finding — surface them loudly.
	for m in r["mods"]:
		if not r["active_mods"].has(m):
			warn.append("mod '%s' is not active for %s" % [m, r["character"]])
	_out.store_line(JSON.stringify(r))
	_out.flush()
	_arena.teardown()
	_next_scenario()


func _snapshot_stats() -> Dictionary:
	if not is_instance_valid(_player):
		return {}
	var out: Dictionary = {}
	for s: String in ["max_hp", "damage", "attack_speed", "crit_chance", "crit_multiplier",
			"move_speed", "melee_range", "projectile_count"]:
		out[s] = _player.get_stat(s)
	out["hp_now"] = _player.health.current_hp if _player.health else 0.0
	out["armor_eff"] = _player.get_armor()
	return out


func _release_all() -> void:
	for a: String in SimPilot.ALL_ACTIONS:
		if InputMap.has_action(a):
			Input.action_release(a)
