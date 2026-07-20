class_name RunReportManager
extends Node

## RunReportManager — end-of-run balance telemetry.
##
## Debug-only: MainArena instantiates this only when GameManager.debug_mode is
## true, so it costs nothing in a shipped build. Purely signal-driven (no
## _process), so it costs nothing per-frame even while active.
##
## Listens to existing GameManager/EventBus/player signals — no new gameplay
## signals were added. Writes user://run_report_<timestamp>.json on run end
## (death or extraction) and prints the same payload to console.

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


func setup(player: Node2D, depth_tracker: DepthTracker) -> void:
	_player = player
	_depth_tracker = depth_tracker
	_character_id = ProgressionManager.selected_character
	_last_loot_value = GameManager.loot_carried

	GameManager.player_died.connect(_on_player_died)
	GameManager.extraction_successful.connect(_on_extraction_successful)
	GameManager.loot_changed.connect(_on_loot_changed)
	EventBus.on_kill.connect(_on_kill)
	EventBus.on_hit_dealt.connect(_on_hit_dealt)
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
	if _current_block_index < 0:
		return
	var amount: float = hit_data.amount if hit_data is HitData else float(hit_data.get("amount", 0.0))
	if source == _player:
		_current_block_dmg_dealt += amount
	if target == _player:
		_current_block_dmg_taken += amount
		if source != null and "enemy_id" in source:
			_death_cause = str(source.enemy_id)


func _on_leveled_up(new_level: int) -> void:
	_xp_curve.append({"time_seconds": GameManager.run_time, "level": new_level})


func _on_loot_changed(new_value: float) -> void:
	var delta: float = new_value - _last_loot_value
	if delta > 0.0:
		_gold_earned += delta
	elif delta < 0.0:
		_gold_spent += -delta
	_last_loot_value = new_value


func _on_player_died() -> void:
	_finalize("death")


func _on_extraction_successful() -> void:
	_finalize("extraction")


func _finalize(outcome: String) -> void:
	if _finalized:
		return
	_finalized = true
	_close_current_block()

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
		"gold_carried_at_end": GameManager.loot_carried if outcome == "death" else GameManager.last_run_loot,
		"peak_instability": GameManager.peak_instability,
		"weapons_collected": GameManager.collected_weapons.duplicate(),
		"mods_collected": GameManager.collected_mods.duplicate(),
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
