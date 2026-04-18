extends CanvasLayer

## Extraction Success Screen — Shows itemized run stats and records progression.

@onready var kills_label: Label = $VBox/KillsLabel
@onready var time_label: Label = $VBox/TimeLabel
@onready var level_label: Label = $VBox/LevelLabel
@onready var play_again_button: Button = $VBox/PlayAgainButton

const FONT_PATH: String = "res://assets/fonts/m5x7.ttf"

var _loot_scroll: ScrollContainer = null  ## replaced each run; queue_freed on reuse

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	play_again_button.pressed.connect(_on_return_to_hub)
	GameManager.extraction_successful.connect(_on_extraction_successful)

func _on_extraction_successful() -> void:
	if _loot_scroll != null and is_instance_valid(_loot_scroll):
		_loot_scroll.queue_free()
	_loot_scroll = null

	var resources_earned: int = int(GameManager.last_run_loot)
	var total_seconds: int = int(GameManager.run_time)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60

	kills_label.text = "Kills: %d" % GameManager.kills
	time_label.text  = "Time: %d:%02d" % [minutes, seconds]
	level_label.text = "Level: %d   Phase: %d" % [_get_player_level(), GameManager.phase_number]

	## Insert a scrollable container before the button so overflow never hides it.
	var vbox: VBoxContainer = $VBox
	_loot_scroll = ScrollContainer.new()
	_loot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_loot_scroll.custom_minimum_size = Vector2(420, 130)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 3)
	_loot_scroll.add_child(lv)
	vbox.add_child(_loot_scroll)
	vbox.move_child(_loot_scroll, play_again_button.get_index())

	## ── Divider ──────────────────────────────────────────────────────────────
	_loot(lv, "── LOOT ─────────────────", Color(0.55, 0.55, 0.55), 16)

	## ── Itemize manifest ─────────────────────────────────────────────────────
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

	## Resources row
	var res_parts: Array = []
	if resource_counts["small"]  > 0: res_parts.append("%d small"  % resource_counts["small"])
	if resource_counts["medium"] > 0: res_parts.append("%d medium" % resource_counts["medium"])
	if resource_counts["large"]  > 0: res_parts.append("%d large"  % resource_counts["large"])
	var res_detail: String = "(" + ", ".join(res_parts) + ")" if not res_parts.is_empty() else ""
	_loot(lv, "Resources:  +%d  %s" % [int(total_resource_value), res_detail], Color(1.0, 0.82, 0.2), 17)

	## Weapons (one per line, rarity-colored)
	for w in weapons_found:
		_loot(lv, "  Weapon:  %s  [%s]" % [w.name, w.rarity.to_upper()],
				LootTables.RARITY_COLORS.get(w.rarity, Color.WHITE), 17)

	## Mods (one per line, rarity-colored)
	for m in mods_found:
		_loot(lv, "  Mod:     %s  [%s]" % [m.name, m.rarity.to_upper()],
				LootTables.RARITY_COLORS.get(m.rarity, Color.WHITE), 17)

	if manifest.is_empty():
		_loot(lv, "  (no loot extracted)", Color(0.5, 0.5, 0.5), 16)

	## ── Instability peak ─────────────────────────────────────────────────────
	var peak: float = GameManager.peak_instability
	var peak_tier: Dictionary = LootTables.get_instability_tier(peak)
	_loot(lv, "Peak Instability: %s  (%d)" % [peak_tier.name, int(peak)], peak_tier.color, 16)

	## ── Phase bonus (locked extraction) ──────────────────────────────────────
	if GameManager.active_extraction_type == "locked":
		var phase_bonuses: Array = [0, 0, 0, 25, 50, 100]
		var bonus_pct: int = phase_bonuses[clampi(GameManager.phase_number, 0, 5)]
		if bonus_pct > 0:
			_loot(lv, "Locked Bonus: +%d%%" % bonus_pct, Color(0.9, 0.75, 0.2), 16)

	## ── Total resources ──────────────────────────────────────────────────────
	_loot(lv, "── TOTAL RESOURCES:  +%d" % resources_earned, Color(1.0, 0.92, 0.4), 21)

	play_again_button.text = "Return to Hub"
	visible = true

	ProgressionManager.record_extraction(resources_earned, GameManager.kills, GameManager.phase_number, GameManager.last_run_loot)

func _loot(parent: VBoxContainer, text: String, col: Color, font_size: int) -> void:
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
	parent.add_child(lbl)

func _get_player_level() -> int:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		return player.level
	return 1

func _on_return_to_hub() -> void:
	visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
