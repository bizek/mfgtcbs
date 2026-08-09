extends CanvasLayer

## Game Over Screen — the after-action report for a run that ended badly.
##
## Serves both ways a run can end badly: dying, and walking out from the pause menu (Abandon Run,
## Ben 2026-08-01). They settle identically — same 25% salvage, same rollback — so they share this
## screen; only the title, the framing and the recorded stat differ.
##
## Rebuilt 2026-08-03. It used to be four lines (kills, time, level, salvaged) while the
## extraction screen had a full breakdown — even though RunReportManager collects every one of
## those numbers on a death too and simply had no reader here. Ben: the death screen should have
## just as much information, including what killed the player.
##
## The two screens now share RunReportView so they cannot drift. What differs is emphasis:
##
##   - The extraction screen leads with what you EARNED. This one leads with what KILLED you,
##     because that is the only question a player has at this moment.
##   - It adds WHAT HIT YOU (damage taken bucketed by enemy), which answers that question at the
##     level that changes the next run. The killing blow alone is often misleading: the thing that
##     landed the last 12 damage is frequently not the thing that did the other 400.
##   - The haul section reports what was LOST versus salvaged, rather than what was banked.

@onready var title_label: Label = $VBox/Title
@onready var kills_label: Label = $VBox/KillsLabel
@onready var time_label: Label = $VBox/TimeLabel
@onready var level_label: Label = $VBox/LevelLabel
@onready var restart_button: Button = $VBox/RestartButton

## Reached through preload, NOT the bare class_name. A newly added class_name is not in the
## editor's global class list until it rescans, and until then every script referencing it
## fails to LOAD — which is silent: _ready() never runs, so this screen simply never
## connected to run_failed and never appeared. Same trap GatewayExtraction hit on 2026-08-02.
const ReportView := preload("res://scripts/ui/run_report_view.gd")


## m5x7 is 16px-native: one design pixel equals one screen pixel only at 16 and its integer
## multiples. Title at 32, everything else at 16, nothing in between.
const TITLE_SIZE: int = 32
const BODY_SIZE: int  = 16

const SCROLL_SPEED: float = 220.0  ## px/s for stick/D-pad scrolling

## Must match ProgressionManager._record_lost_run, which applies the real number. This was
## hardcoded separately in both files and would have silently started lying to the player the
## moment either one moved.
const SALVAGE_RATE: float = 0.25

var _scroll: ScrollContainer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	restart_button.pressed.connect(_on_return_to_hub)
	GameManager.run_failed.connect(_show_lost_run)


func _process(delta: float) -> void:
	## The report is all Labels (nothing focusable), so let D-pad / stick / arrows scroll it
	## while focus stays on the return button.
	if not visible or _scroll == null or not is_instance_valid(_scroll):
		return
	var dir: float = Input.get_axis("ui_up", "ui_down")
	if dir != 0.0:
		_scroll.scroll_vertical += int(dir * SCROLL_SPEED * delta)


func _show_lost_run(abandoned: bool) -> void:
	if _scroll != null and is_instance_valid(_scroll):
		_scroll.queue_free()
	_scroll = null

	var loot_value: int = int(GameManager.loot_carried)
	var total_seconds: int = int(GameManager.run_time)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	var summary: Dictionary = ReportView.summary_for(self)

	title_label.text = "RUN ABANDONED" if abandoned else "YOU DIED"

	## ── Header: the same compact stat block the extraction screen uses ──
	## Depth leads where there is depth, and is HIDDEN rather than faked outside descent — the
	## obvious fallback (phase) already sits on the third line.
	kills_label.visible = summary.has("depth_percent")
	if kills_label.visible:
		kills_label.text = "Depth %d%%   ·   %d blocks cleared" % [
			int(round(float(summary["depth_percent"]) * 100.0)),
			int(summary.get("blocks_cleared", 0))]
	time_label.text  = "Time %d:%02d   ·   %s kills" % [
		minutes, seconds, ReportView.fmt(GameManager.kills)]
	level_label.text = "Level %d   ·   Phase %d" % [_get_player_level(), GameManager.phase_number]

	_scroll = ReportView.make_scroll()
	var lv: VBoxContainer = _scroll.get_node("Body")
	$VBox.add_child(_scroll)
	$VBox.move_child(_scroll, restart_button.get_index())

	if not abandoned:
		_build_killed_by(lv, summary)
	ReportView.taken_breakdown(lv, summary)
	ReportView.combat_section(lv, summary)
	ReportView.dealt_breakdown(lv, summary)
	_build_haul_section(lv, loot_value)

	restart_button.text = "Return to Hub"
	visible = true
	restart_button.grab_focus.call_deferred()
	## Deferred because the ScrollContainer has no final content height until the next layout
	## pass — setting it now clamps against a stale max and leaves the view part-scrolled.
	_reset_scroll.call_deferred()

	var levels_gained: int = _get_player_level() - 1
	if abandoned:
		ProgressionManager.record_abandon(loot_value, GameManager.kills, GameManager.phase_number, levels_gained)
		AchievementManager.check_run_end("abandon")
	else:
		ProgressionManager.record_death(loot_value, GameManager.kills, GameManager.phase_number, levels_gained)
		AchievementManager.check_run_end("death")


# ── Sections ──────────────────────────────────────────────────────────────────────────────────

## The headline. Only shown on a death — an abandoned run has no killer, and inventing one for
## someone who walked out voluntarily would read as a bug.
func _build_killed_by(lv: VBoxContainer, summary: Dictionary) -> void:
	var blow: Dictionary = summary.get("killing_blow", {})
	if blow.is_empty():
		return
	ReportView.heading(lv, "KILLED BY")
	var who: String = str(blow.get("name", "something in the dark"))
	var move: String = str(blow.get("ability", ""))
	if move != "":
		who += "  —  %s" % move
	ReportView.line(lv, who, ReportView.COL_BAD)
	var amount: String = ReportView.fmt(float(blow.get("amount", 0.0)))
	if bool(blow.get("crit", false)):
		amount += "  CRIT"
	ReportView.stat(lv, "Final blow", amount, ReportView.COL_BAD)


## What the run cost. The mirror of the extraction screen's HAUL section: the same numbers, told
## as a loss instead of a payout.
func _build_haul_section(lv: VBoxContainer, loot_value: int) -> void:
	ReportView.heading(lv, "HAUL LOST")

	var salvaged: int = int(loot_value * SALVAGE_RATE)
	var lost: int = loot_value - salvaged
	ReportView.line(lv, "Carried:  %s" % ReportView.fmt(loot_value), ReportView.COL_LABEL)
	ReportView.stat(lv, "Lost to the dark", "-%s" % ReportView.fmt(lost), ReportView.COL_BAD)

	var peak: float = GameManager.peak_instability
	var peak_tier: Dictionary = LootTables.get_instability_tier(peak)
	ReportView.line(lv, "Peak Instability: %s  (%d)" % [peak_tier.name, int(peak)], peak_tier.color)

	## Insurance is the one thing that survives, so it sits with the loss it offsets.
	var insured: String = GameManager.insured_item
	if not insured.is_empty() and ProgressionManager.has_upgrade("insurance_license"):
		var display: String = WeaponData.ALL.get(insured, {}).get("display_name", insured)
		ReportView.line(lv, "[*] Insured: %s kept" % display, Color(1.0, 0.88, 0.22))

	## A real divider, not a "──" prefix — U+2500 is not in m5x7. See ReportView.rule.
	ReportView.rule(lv)
	ReportView.line(lv, "SALVAGED TO VAULT:  +%s" % ReportView.fmt(salvaged),
		Color(1.0, 0.92, 0.4))


# ── Helpers ───────────────────────────────────────────────────────────────────────────────────

func _reset_scroll() -> void:
	if _scroll != null and is_instance_valid(_scroll):
		_scroll.scroll_vertical = 0


func _get_player_level() -> int:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		return player.level
	return 1


func _on_return_to_hub() -> void:
	visible = false
	## SceneTransition unpauses as part of the swap — this screen runs behind
	## get_tree().paused = true, and the fade is process_mode ALWAYS for that reason.
	SceneTransition.change_scene("res://scenes/hub.tscn")
