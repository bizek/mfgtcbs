class_name RunReportManager
extends Node

## RunReportManager — run telemetry, and the data source behind the results screen.
##
## ALWAYS ON as of 2026-08-02 (it used to be debug-only). It is purely signal-driven with no
## _process, so an always-on instance costs nothing per frame — and the results screen needs
## every number it collects. The JSON dump and the console spam stay debug-gated; only the
## collecting is unconditional. See get_summary().
##
## Listens to existing GameManager/EventBus/player signals — no new gameplay signals were added.
## Writes user://run_report_<timestamp>.json on run end (death or extraction) in debug builds.

var _player: Node2D = null
var _depth_tracker: DepthTracker = null
var _character_id: String = ""

var _block_log: Array[Dictionary] = []
var _current_block_index: int = -1
var _current_block_start_time: float = 0.0
var _current_block_kills: int = 0
var _current_block_dmg_dealt: float = 0.0
var _current_block_dmg_taken: float = 0.0

var _xp_curve: Array[Dictionary] = []
var _gold_earned: float = 0.0
var _gold_spent: float = 0.0
var _last_loot_value: float = 0.0

var _death_cause: String = "unknown"
var _finalized: bool = false

## ── Results-screen totals (2026-08-02) ───────────────────────────────────────────────────────
## Run-wide, not per-block. The block log above is balance telemetry; these are what the player
## is shown, and the two are deliberately kept apart so tuning the report can't reshape the UI.
var _total_dealt: float = 0.0
var _total_taken: float = 0.0
var _total_healed: float = 0.0
var _hits_dealt: int = 0
var _biggest_hit: float = 0.0
var _deepest_percent: float = 0.0

## ability_id -> {"name": String, "damage": float, "hits": int}
## Keyed off HitData.ability, which every hit has carried all along — it was simply never read.
## Damage with no ability attached (companion strikes, ground zones, thorns) is pooled under
## OTHER_SOURCE_KEY rather than dropped, so the breakdown always sums to _total_dealt.
var _by_ability: Dictionary = {}

const OTHER_SOURCE_KEY: String = "__other__"
const OTHER_SOURCE_NAME: String = "Companions & effects"


func setup(player: Node2D, depth_tracker: DepthTracker) -> void:
	_player = player
	_depth_tracker = depth_tracker
	_character_id = ProgressionManager.selected_character
	_last_loot_value = GameManager.loot_carried

	GameManager.run_failed.connect(_on_run_failed)
	GameManager.extraction_successful.connect(_on_extraction_successful)
	GameManager.loot_changed.connect(_on_loot_changed)
	EventBus.on_kill.connect(_on_kill)
	EventBus.on_hit_dealt.connect(_on_hit_dealt)
	## on_heal has been emitted from five places (player self-heals, EffectDispatcher) since
	## healing existed and had NO listener until now — the results screen is its first consumer.
	EventBus.on_heal.connect(_on_heal)
	if _player.has_signal("leveled_up"):
		_player.leveled_up.connect(_on_leveled_up)

	if _depth_tracker != null:
		_depth_tracker.block_entered.connect(_on_block_entered)
	_start_block(0)


func _start_block(index: int) -> void:
	_current_block_index = index
	_current_block_start_time = GameManager.run_time
	_current_block_kills = 0
	_current_block_dmg_dealt = 0.0
	_current_block_dmg_taken = 0.0


func _close_current_block() -> void:
	if _current_block_index < 0:
		return
	_block_log.append({
		"block_index": _current_block_index,
		"time_seconds": GameManager.run_time - _current_block_start_time,
		"kills": _current_block_kills,
		"damage_dealt": _current_block_dmg_dealt,
		"damage_taken": _current_block_dmg_taken,
	})


func _on_block_entered(block_index: int) -> void:
	## DepthTracker fires block_entered(0) on its very first _process tick even though
	## block 0 is already current (last_block_index starts at -1) — ignore the no-op.
	if block_index == _current_block_index:
		return
	_close_current_block()
	_start_block(block_index)


func _on_kill(_killer: Node, victim: Node) -> void:
	if _current_block_index < 0:
		return
	if victim != null and victim.is_in_group("enemies"):
		_current_block_kills += 1


func _on_hit_dealt(source: Node, target: Node, hit_data) -> void:
	var amount: float = hit_data.amount if hit_data is HitData else float(hit_data.get("amount", 0.0))

	if source == _player:
		_total_dealt += amount
		_hits_dealt += 1
		_biggest_hit = maxf(_biggest_hit, amount)
		_credit_ability(hit_data, amount)
		if _current_block_index >= 0:
			_current_block_dmg_dealt += amount

	if target == _player:
		## Blocked/dodged hits still arrive here; HitData.amount is already the post-mitigation
		## number, so a fully-dodged hit contributes 0 and does not inflate "damage taken".
		_total_taken += amount
		if _current_block_index >= 0:
			_current_block_dmg_taken += amount
		if source != null and "enemy_id" in source:
			_death_cause = str(source.enemy_id)


## Bucket a player hit under the ability that produced it. Companion strikes and ground-zone
## ticks resolve through DamageCalculator with ability = null (they have no AbilityDefinition to
## hand in), so they pool under one honest label instead of vanishing from the breakdown.
func _credit_ability(hit_data, amount: float) -> void:
	var key: String = OTHER_SOURCE_KEY
	var display: String = OTHER_SOURCE_NAME
	if hit_data is HitData and hit_data.ability != null:
		var ab = hit_data.ability
		var id: String = str(ab.ability_id) if "ability_id" in ab else ""
		if id != "":
			key = id
			## ability_name is what the kit calls the move ("Bramble Barrage"); fall back to the
			## id so a nameless ability still shows up rather than being silently pooled.
			display = str(ab.ability_name) if "ability_name" in ab and str(ab.ability_name) != "" else id
	if not _by_ability.has(key):
		_by_ability[key] = {"name": display, "damage": 0.0, "hits": 0}
	var row: Dictionary = _by_ability[key]
	row["damage"] = float(row["damage"]) + amount
	row["hits"] = int(row["hits"]) + 1


func _on_heal(_source: Node, target: Node, amount: float) -> void:
	## Only the player's own healing is a results-screen stat — enemy/pet healing is not.
	if target == _player:
		_total_healed += amount


func _on_leveled_up(new_level: int) -> void:
	_xp_curve.append({"time_seconds": GameManager.run_time, "level": new_level})


func _on_loot_changed(new_value: float) -> void:
	var delta: float = new_value - _last_loot_value
	if delta > 0.0:
		_gold_earned += delta
	elif delta < 0.0:
		_gold_spent += -delta
	_last_loot_value = new_value


## Everything the results screen needs, in one call. Safe to call before or after _finalize().
##
## `abilities` is sorted hardest-hitting first and carries a share of the run's total so the
## screen can draw bars without recomputing anything. Deliberately returns plain data — the UI
## decides what to show and how; this decides nothing about presentation.
func get_summary() -> Dictionary:
	_capture_depth()
	var abilities: Array[Dictionary] = []
	for key: String in _by_ability:
		var row: Dictionary = _by_ability[key]
		var dmg: float = float(row["damage"])
		abilities.append({
			"id": key,
			"name": str(row["name"]),
			"damage": dmg,
			"hits": int(row["hits"]),
			"share": (dmg / _total_dealt) if _total_dealt > 0.0 else 0.0,
		})
	abilities.sort_custom(func(a, b): return float(a["damage"]) > float(b["damage"]))

	var out: Dictionary = {
		"damage_dealt": _total_dealt,
		"damage_taken": _total_taken,
		"healed": _total_healed,
		"hits_dealt": _hits_dealt,
		"biggest_hit": _biggest_hit,
		"abilities": abilities,
		"gold_earned": _gold_earned,
		"gold_spent": _gold_spent,
	}
	## Depth keys are OMITTED, not zeroed, when there is no DepthTracker (flat arena, training
	## room). A zero would render as an honest-looking "Depth 0%" on a mode that has no depth.
	if _depth_tracker != null and is_instance_valid(_depth_tracker):
		out["depth_percent"] = _deepest_percent
		out["blocks_cleared"] = _block_log.size()
	return out


## Depth is polled rather than tracked by signal: DepthTracker.depth_progress is already a
## monotonic high-water mark, so reading it at the end is both simpler and exactly right.
func _capture_depth() -> void:
	if _depth_tracker != null and is_instance_valid(_depth_tracker):
		_deepest_percent = maxf(_deepest_percent, _depth_tracker.depth_progress)


func _on_run_failed(abandoned: bool) -> void:
	_finalize("abandon" if abandoned else "death")


func _on_extraction_successful() -> void:
	_finalize("extraction")


func _finalize(outcome: String) -> void:
	if _finalized:
		return
	_finalized = true
	_close_current_block()
	_capture_depth()

	## The results screen is always fed; only the telemetry dump below is debug-gated.
	if not GameManager.debug_mode:
		return

	var report: Dictionary = {
		"character_id": _character_id,
		"outcome": outcome,
		"death_cause": _death_cause if outcome == "death" else "",
		"run_time_seconds": GameManager.run_time,
		"blocks": _block_log,
		"xp_curve": _xp_curve,
		"final_level": _player.level if is_instance_valid(_player) else 0,
		"gold_earned": _gold_earned,
		"gold_spent": _gold_spent,
		## Only extraction banks the run's loot into last_run_loot; every losing outcome (death,
		## abandon) still has it sitting on the player, so read it from there.
		"gold_carried_at_end": GameManager.last_run_loot if outcome == "extraction" else GameManager.loot_carried,
		"peak_instability": GameManager.peak_instability,
		"weapons_collected": GameManager.collected_weapons.duplicate(),
		"mods_collected": GameManager.collected_mods.duplicate(),
		## Per-ability damage share. This is the balance data for the mod/level-up rework — it is
		## what will show which of the 12 kits have moves nobody's damage actually comes from.
		"damage_by_ability": get_summary()["abilities"],
		"damage_taken_total": _total_taken,
		"healed_total": _total_healed,
		"deepest_percent": _deepest_percent,
	}

	var stamp: String = Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var path: String = "user://run_report_%s.json" % stamp
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()

	print("[RunReport] INCOME  earned=%.0f  spent=%.0f  net=%.0f  phase=%d  outcome=%s" % [
		_gold_earned, _gold_spent, _gold_earned - _gold_spent, GameManager.phase_number, outcome])
	## Passive-point telemetry: all points currently come from level-ups (1 pt per level gained).
	## Boss-kill bonuses and other sources are not yet wired; their slots are 0 for now.
	## Gathering data before any rate tuning — do NOT change award rates based on this alone.
	var pts_levelups: int = maxi((report["final_level"] as int) - 1, 0)
	print("[PassivePoints] earned=%d  level_ups=%d  boss_kills=0  other=0" % [
		pts_levelups, pts_levelups])
	print("[RunReport] saved %s" % path)
	print(JSON.stringify(report, "\t"))
