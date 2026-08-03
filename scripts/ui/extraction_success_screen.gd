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

const FONT_PATH: String = "res://assets/fonts/m5x7.ttf"

var _loot_scroll: ScrollContainer = null  ## replaced each run; queue_freed on reuse

const LOOT_SCROLL_SPEED: float = 220.0  ## px/s for stick/D-pad manifest scrolling

const SCROLL_SIZE: Vector2 = Vector2(440, 196)

## Damage-breakdown row geometry, summing to SCROLL_SIZE.x minus the scrollbar.
const ROW_NAME_W: float = 150.0
const ROW_BAR_W: float = 150.0
const ROW_VALUE_W: float = 118.0
const BAR_H: float = 9.0

## Rank colours for the damage breakdown — brightest at the top, cooling as it goes down, so the
## carry move is obvious at a glance rather than needing the numbers read.
const RANK_COLORS: Array[Color] = [
	Color(1.00, 0.86, 0.30),   ## gold
	Color(1.00, 0.62, 0.25),   ## amber
	Color(0.85, 0.48, 0.85),   ## violet
	Color(0.45, 0.75, 1.00),   ## blue
	Color(0.55, 0.80, 0.55),   ## green
]
const RANK_COLOR_TAIL: Color = Color(0.55, 0.58, 0.62)

const COL_HEADING: Color = Color(0.55, 0.62, 0.68)
const COL_GOOD: Color    = Color(0.55, 0.90, 0.55)
const COL_BAD: Color     = Color(0.95, 0.45, 0.45)
const COL_NEUTRAL: Color = Color(0.85, 0.88, 0.92)
const COL_GOLD: Color    = Color(1.0, 0.82, 0.2)

## Abilities below this share of total damage are folded into one "others" row, so a long tail of
## 0.4% chip damage can't push the loot manifest off the bottom of the scroll.
const MIN_ABILITY_SHARE: float = 0.02


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
	var summary: Dictionary = _get_summary()

	## ── Header: three existing scene labels, repurposed as a compact stat block ──
	## "How far" leads, because in a descent that is the run's headline. Outside descent there is
	## no depth, so the row is HIDDEN rather than filled with a fallback — the obvious fallback
	## (phase) is already on the third line, and printing it twice just looks like a bug.
	kills_label.visible = summary.has("depth_percent")
	if kills_label.visible:
		kills_label.text = "Depth %d%%   ·   %d blocks cleared" % [
			int(round(float(summary["depth_percent"]) * 100.0)), int(summary.get("blocks_cleared", 0))]
	time_label.text  = "Time %d:%02d   ·   %s kills" % [minutes, seconds, _fmt(GameManager.kills)]
	level_label.text = "Level %d   ·   Phase %d" % [_get_player_level(), GameManager.phase_number]

	## Insert a scrollable container before the button so overflow never hides it.
	var vbox: VBoxContainer = $VBox
	_loot_scroll = ScrollContainer.new()
	_loot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_loot_scroll.custom_minimum_size = SCROLL_SIZE
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 3)
	_loot_scroll.add_child(lv)
	vbox.add_child(_loot_scroll)
	vbox.move_child(_loot_scroll, play_again_button.get_index())

	_build_combat_section(lv, summary)
	_build_damage_breakdown(lv, summary)
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

func _build_combat_section(lv: VBoxContainer, summary: Dictionary) -> void:
	if summary.is_empty():
		return
	_heading(lv, "COMBAT")
	var dealt: float = float(summary.get("damage_dealt", 0.0))
	var taken: float = float(summary.get("damage_taken", 0.0))
	var healed: float = float(summary.get("healed", 0.0))

	_stat(lv, "Damage dealt", _fmt(dealt), COL_GOOD)
	_stat(lv, "Damage taken", _fmt(taken), COL_BAD)
	if healed > 0.0:
		_stat(lv, "Healed", _fmt(healed), COL_GOOD)
	_stat(lv, "Biggest hit", _fmt(float(summary.get("biggest_hit", 0.0))), COL_NEUTRAL)
	## Net survival margin — the "how close was that" number.
	if taken > 0.0:
		_stat(lv, "Damage ratio", "%.1fx" % (dealt / taken),
			COL_GOOD if dealt >= taken else COL_BAD)


func _build_damage_breakdown(lv: VBoxContainer, summary: Dictionary) -> void:
	var abilities: Array = summary.get("abilities", [])
	if abilities.is_empty():
		return
	_heading(lv, "DAMAGE BY ABILITY")

	var rank: int = 0
	var tail_damage: float = 0.0
	var tail_hits: int = 0
	for entry in abilities:
		var share: float = float(entry["share"])
		## Fold the long tail so the manifest below stays reachable.
		if share < MIN_ABILITY_SHARE and rank >= RANK_COLORS.size():
			tail_damage += float(entry["damage"])
			tail_hits += int(entry["hits"])
			continue
		_bar_row(lv, str(entry["name"]), float(entry["damage"]), share, int(entry["hits"]),
			RANK_COLORS[rank] if rank < RANK_COLORS.size() else RANK_COLOR_TAIL)
		rank += 1

	if tail_damage > 0.0:
		var total: float = float(summary.get("damage_dealt", 0.0))
		_bar_row(lv, "everything else", tail_damage,
			(tail_damage / total) if total > 0.0 else 0.0, tail_hits, RANK_COLOR_TAIL)


func _build_loot_section(lv: VBoxContainer, resources_earned: int) -> void:
	_heading(lv, "LOOT")

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
	_loot(lv, "Resources:  +%s  %s" % [_fmt(total_resource_value), res_detail], COL_GOLD, 17)

	for w in weapons_found:
		_loot(lv, "  Weapon:  %s  [%s]" % [w.name, w.rarity.to_upper()],
				LootTables.RARITY_COLORS.get(w.rarity, Color.WHITE), 17)

	## Mods are the "special find" line — the one that makes someone go deeper next run.
	for m in mods_found:
		_loot(lv, "  Mod:     %s  [%s]" % [m.name, m.rarity.to_upper()],
				LootTables.RARITY_COLORS.get(m.rarity, Color.WHITE), 17)

	if manifest.is_empty():
		_loot(lv, "  (no loot extracted)", Color(0.5, 0.5, 0.5), 16)

	var peak: float = GameManager.peak_instability
	var peak_tier: Dictionary = LootTables.get_instability_tier(peak)
	_loot(lv, "Peak Instability: %s  (%d)" % [peak_tier.name, int(peak)], peak_tier.color, 16)

	if GameManager.active_extraction_type == "locked":
		var phase_bonuses: Array = [0, 0, 0, 25, 50, 100]
		var bonus_pct: int = phase_bonuses[clampi(GameManager.phase_number, 0, 5)]
		if bonus_pct > 0:
			_loot(lv, "Locked Bonus: +%d%%" % bonus_pct, Color(0.9, 0.75, 0.2), 16)

	_loot(lv, "── TOTAL RESOURCES:  +%s" % _fmt(resources_earned), Color(1.0, 0.92, 0.4), 21)


# ── Row builders ──────────────────────────────────────────────────────────────────────────────

## One ability's damage: name, proportional bar, value + share + hit count.
func _bar_row(parent: VBoxContainer, ability_name: String, damage: float, share: float,
		hits: int, col: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := _make_label(ability_name, col, 16)
	name_lbl.custom_minimum_size = Vector2(ROW_NAME_W, 0)
	name_lbl.clip_text = true
	row.add_child(name_lbl)

	## Track + fill. The fill is sized directly rather than by stretch ratio so a 3% ability
	## still renders a visible sliver instead of collapsing to nothing.
	var track := Control.new()
	track.custom_minimum_size = Vector2(ROW_BAR_W, BAR_H)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track_bg := ColorRect.new()
	track_bg.color = Color(1, 1, 1, 0.07)
	track_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.add_child(track_bg)
	var fill := ColorRect.new()
	fill.color = col
	fill.position = Vector2.ZERO
	fill.size = Vector2(maxf(ROW_BAR_W * share, 2.0), BAR_H)
	track.add_child(fill)
	row.add_child(track)

	var value_lbl := _make_label("%s  %d%%  (%dx)" % [_fmt(damage), int(round(share * 100.0)), hits],
		col, 16)
	value_lbl.custom_minimum_size = Vector2(ROW_VALUE_W, 0)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_lbl)

	parent.add_child(row)


## Label-on-the-left, value-on-the-right stat line.
func _stat(parent: VBoxContainer, label: String, value: String, col: Color) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := _make_label(label, Color(0.72, 0.76, 0.80), 17)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var v := _make_label(value, col, 17)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	parent.add_child(row)


func _heading(parent: VBoxContainer, text: String) -> void:
	_loot(parent, "── %s ──────────────────" % text, COL_HEADING, 16)


func _loot(parent: VBoxContainer, text: String, col: Color, font_size: int) -> void:
	parent.add_child(_make_label(text, col, font_size))


func _make_label(text: String, col: Color, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	var settings := LabelSettings.new()
	if ResourceLoader.exists(FONT_PATH):
		settings.font = load(FONT_PATH)
	settings.font_size     = font_size
	settings.font_color    = col
	settings.outline_size  = 1
	settings.outline_color = Color(0.0, 0.0, 0.0, 0.85)
	lbl.label_settings = settings
	return lbl


# ── Helpers ───────────────────────────────────────────────────────────────────────────────────

## RunReportManager is a sibling under MainArena. Returns {} in any mode that has no tracker
## (training room, flat arena) so every section degrades to "just don't draw it".
func _get_summary() -> Dictionary:
	var parent: Node = get_parent()
	if parent == null:
		return {}
	var rr: Node = parent.get_node_or_null("RunReportManager")
	if rr == null or not rr.has_method("get_summary"):
		return {}
	return rr.get_summary()


## Thousands separators. A five-figure damage total reads as an achievement; "48213" reads as
## noise, and this screen is supposed to feel like a reward.
func _fmt(value: Variant) -> String:
	var n: int = int(round(float(value)))
	var neg: bool = n < 0
	var s: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if neg else out


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
