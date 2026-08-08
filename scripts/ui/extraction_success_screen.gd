extends CanvasLayer

## Extraction Success Screen — the run's after-action report.
##
## Rebuilt 2026-08-02. It used to show four lines (kills, time, level, phase) plus the loot
## manifest, which badly undersold a run you had just fought your way out of. Ben: "post run
## stats are dopamine" — so it now reports how deep you got, what you did, what hit you, what
## kept you alive, and which of your abilities actually carried the run.
##
## Numbers come from RunReportManager.get_summary(). That node used to be debug-only telemetry
## and is now always on precisely so this screen can read it; every field below was already
## being collected or was one signal away (HitData has always carried `ability`; EventBus.on_heal
## had been emitted for months with no listener).
##
## Layout budget: the VBox in the scene is 460x320 inside a 640x360 viewport. Header + button +
## separations eat ~120, so the scroll gets ~200px and everything else must live inside it.
## Per CLAUDE.md the scroll is SHOW_AS_NEEDED (Godot's default AUTO) — never SHOW_NEVER, which
## would clip the breakdown on a long run.

@onready var kills_label: Label = $VBox/KillsLabel
@onready var time_label: Label = $VBox/TimeLabel
@onready var level_label: Label = $VBox/LevelLabel
@onready var play_again_button: Button = $VBox/PlayAgainButton

## Reached through preload, NOT the bare class_name. A newly added class_name is not in the
## editor's global class list until it rescans, and until then every script referencing it
## fails to LOAD — which is silent: _ready() never runs, so this screen simply never
## connected to run_failed and never appeared. Same trap GatewayExtraction hit on 2026-08-02.
const ReportView := preload("res://scripts/ui/run_report_view.gd")

var _loot_scroll: ScrollContainer = null  ## replaced each run; queue_freed on reuse

const LOOT_SCROLL_SPEED: float = 220.0  ## px/s for stick/D-pad manifest scrolling


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	play_again_button.pressed.connect(_on_return_to_hub)
	GameManager.extraction_successful.connect(_on_extraction_successful)

func _process(delta: float) -> void:
	## The manifest is all Labels (nothing focusable), so let D-pad / stick /
	## arrow keys scroll it directly while focus stays on the return button.
	if not visible or _loot_scroll == null or not is_instance_valid(_loot_scroll):
		return
	var dir: float = Input.get_axis("ui_up", "ui_down")
	if dir != 0.0:
		_loot_scroll.scroll_vertical += int(dir * LOOT_SCROLL_SPEED * delta)


func _on_extraction_successful() -> void:
	if GameManager.last_run_was_win:
		return  ## WinScreen takes over instead of the normal results screen
	if _loot_scroll != null and is_instance_valid(_loot_scroll):
		_loot_scroll.queue_free()
	_loot_scroll = null

	var resources_earned: int = int(GameManager.last_run_loot)
	var total_seconds: int = int(GameManager.run_time)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	var summary: Dictionary = ReportView.summary_for(self)

	## ── Header: three existing scene labels, repurposed as a compact stat block ──
	## "How far" leads, because in a descent that is the run's headline. Outside descent there is
	## no depth, so the row is HIDDEN rather than filled with a fallback — the obvious fallback
	## (phase) is already on the third line, and printing it twice just looks like a bug.
	kills_label.visible = summary.has("depth_percent")
	if kills_label.visible:
		kills_label.text = "Depth %d%%   ·   %d blocks cleared" % [
			int(round(float(summary["depth_percent"]) * 100.0)), int(summary.get("blocks_cleared", 0))]
	time_label.text  = "Time %d:%02d   ·   %s kills" % [minutes, seconds, ReportView.fmt(GameManager.kills)]
	level_label.text = "Level %d   ·   Phase %d" % [_get_player_level(), GameManager.phase_number]

	## Insert a scrollable container before the button so overflow never hides it.
	var vbox: VBoxContainer = $VBox
	_loot_scroll = ReportView.make_scroll()
	var lv: VBoxContainer = _loot_scroll.get_node("Body")
	vbox.add_child(_loot_scroll)
	vbox.move_child(_loot_scroll, play_again_button.get_index())

	ReportView.combat_section(lv, summary)
	ReportView.dealt_breakdown(lv, summary)
	_build_loot_section(lv, resources_earned)

	play_again_button.text = "Return to Hub"
	visible = true
	play_again_button.grab_focus.call_deferred()
	## Deferred because the ScrollContainer has no final content height until the next layout
	## pass — setting it now would clamp against a stale max and leave the view part-scrolled.
	_reset_scroll.call_deferred()

	ProgressionManager.record_extraction(resources_earned, GameManager.kills, GameManager.phase_number, GameManager.last_run_loot, _get_player_level() - 1)
	AchievementManager.check_run_end("extraction")


# ── Sections ──────────────────────────────────────────────────────────────────────────────────
##
## COMBAT and DAMAGE BY ABILITY now come from RunReportView, shared with the death screen. Only
## the haul manifest stays local: it is the one section that is genuinely specific to getting out
## alive, and the death screen tells the same numbers as a loss instead.


func _build_loot_section(lv: VBoxContainer, resources_earned: int) -> void:
	## HAUL is what you carried and stood to lose; VAULT is where it lands once you are out.
	## This screen is the only place a player watches one become the other, so it is the place
	## the two names have to be unmistakable. See the note on GameManager.loot_carried.
	ReportView.heading(lv, "HAUL")

	var manifest: Array = GameManager.run_loot_manifest
	var total_resource_value: float = 0.0
	var resource_counts: Dictionary = { "small": 0, "medium": 0, "large": 0 }
	var weapons_found: Array = []
	var mods_found: Array = []

	for entry in manifest:
		match entry.type:
			"resource":
				total_resource_value += entry.value
				var sz: String = entry.rarity
				if resource_counts.has(sz):
					resource_counts[sz] += 1
			"weapon":
				weapons_found.append(entry)
			"mod":
				mods_found.append(entry)

	var res_parts: Array = []
	if resource_counts["small"]  > 0: res_parts.append("%d small"  % resource_counts["small"])
	if resource_counts["medium"] > 0: res_parts.append("%d medium" % resource_counts["medium"])
	if resource_counts["large"]  > 0: res_parts.append("%d large"  % resource_counts["large"])
	var res_detail: String = "(" + ", ".join(res_parts) + ")" if not res_parts.is_empty() else ""
	ReportView.line(lv, "Salvage:  +%s  %s" % [ReportView.fmt(total_resource_value), res_detail], ReportView.COL_GOLD)

	for w in weapons_found:
		ReportView.tagged_line(lv, "  Weapon:  %s" % w.name,
				LootTables.RARITY_COLORS.get(w.rarity, Color.WHITE), w.rarity)

	## Mods are the "special find" line — the one that makes someone go deeper next run.
	for m in mods_found:
		ReportView.tagged_line(lv, "  Mod:     %s" % m.name,
				LootTables.RARITY_COLORS.get(m.rarity, Color.WHITE), m.rarity)

	if manifest.is_empty():
		ReportView.line(lv, "  (nothing hauled out)", Color(0.5, 0.5, 0.5))

	var peak: float = GameManager.peak_instability
	var peak_tier: Dictionary = LootTables.get_instability_tier(peak)
	ReportView.line(lv, "Peak Instability: %s  (%d)" % [peak_tier.name, int(peak)], peak_tier.color)

	if GameManager.active_extraction_type == "locked":
		var phase_bonuses: Array = [0, 0, 0, 25, 50, 100]
		var bonus_pct: int = phase_bonuses[clampi(GameManager.phase_number, 0, 5)]
		if bonus_pct > 0:
			ReportView.line(lv, "Locked Bonus: +%d%%" % bonus_pct, Color(0.9, 0.75, 0.2))

	## How far you got, priced. Only shown when it actually moved the number — a 1.0x line on
	## every escape would read as a penalty rather than a baseline.
	var mult: float = GameManager.last_run_payout_mult
	if not is_equal_approx(mult, 1.0):
		ReportView.line(lv, "Depth Bonus:  x%.2f  (%s)" % [mult, _payout_label()],
			Color(0.55, 0.95, 0.65))

	ReportView.line(lv, "── BANKED TO VAULT:  +%s" % ReportView.fmt(resources_earned), Color(1.0, 0.92, 0.4))


# ── Helpers ───────────────────────────────────────────────────────────────────────────────────

## Plain-English name for the rung the run settled on.
func _payout_label() -> String:
	match GameManager.active_extraction_type:
		"miniboss": return "miniboss slain"
		"descent_portal": return "full descent"
		"locked": return "locked extraction"
		_: return "escaped"


func _reset_scroll() -> void:
	if _loot_scroll != null and is_instance_valid(_loot_scroll):
		_loot_scroll.scroll_vertical = 0


func _get_player_level() -> int:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		return player.level
	return 1


func _on_return_to_hub() -> void:
	visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
