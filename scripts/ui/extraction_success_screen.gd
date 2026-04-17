extends CanvasLayer

## Extraction Success Screen — Shows itemized run stats and records progression.

@onready var kills_label: Label = $VBox/KillsLabel
@onready var time_label: Label = $VBox/TimeLabel
@onready var level_label: Label = $VBox/LevelLabel
@onready var play_again_button: Button = $VBox/PlayAgainButton

const FONT_PATH: String = "res://assets/fonts/m5x7.ttf"

var _dynamic_labels: Array = []  ## Labels added this session — cleared on reuse

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	play_again_button.pressed.connect(_on_return_to_hub)
	GameManager.extraction_successful.connect(_on_extraction_successful)

func _on_extraction_successful() -> void:
	## Clear any labels from a previous screen showing
	for lbl in _dynamic_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_dynamic_labels.clear()

	var resources_earned: int = int(GameManager.last_run_loot)
	var total_seconds: int = int(GameManager.run_time)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60

	kills_label.text = "Kills: %d" % GameManager.kills
	time_label.text  = "Time: %d:%02d" % [minutes, seconds]
	level_label.text = "Level: %d   Phase: %d" % [_get_player_level(), GameManager.phase_number]

	var vbox: VBoxContainer = $VBox
	var btn_idx: int = play_again_button.get_index()

	## ── Divider ──────────────────────────────────────────────────────────────
	_insert_label(vbox, btn_idx, "── LOOT ─────────────────", Color(0.55, 0.55, 0.55), 9)

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
				var sz: String = entry.rarity  ## size stored in rarity field for resources
				if resource_counts.has(sz):
					resource_counts[sz] += 1
			"weapon":
				weapons_found.append(entry)
			"mod":
				mods_found.append(entry)

	## Resources row
	var res_parts: Array = []
	if resource_counts["small"] > 0:
		res_parts.append("%d small" % resource_counts["small"])
	if resource_counts["medium"] > 0:
		res_parts.append("%d medium" % resource_counts["medium"])
	if resource_counts["large"] > 0:
		res_parts.append("%d large" % resource_counts["large"])
	var res_detail: String = "(" + ", ".join(res_parts) + ")" if not res_parts.is_empty() else ""
	_insert_label(vbox, btn_idx, "Resources:  +%d  %s" % [int(total_resource_value), res_detail], Color(1.0, 0.82, 0.2), 10)

	## Weapons row (one per line, color-coded by rarity)
	for w in weapons_found:
		var col: Color = LootTables.RARITY_COLORS.get(w.rarity, Color.WHITE)
		_insert_label(vbox, btn_idx, "  Weapon:  %s  [%s]" % [w.name, w.rarity.to_upper()], col, 10)

	## Mods row (one per line, color-coded by rarity)
	for m in mods_found:
		var col: Color = LootTables.RARITY_COLORS.get(m.rarity, Color.WHITE)
		_insert_label(vbox, btn_idx, "  Mod:     %s  [%s]" % [m.name, m.rarity.to_upper()], col, 10)

	## Empty loot message
	if manifest.is_empty():
		_insert_label(vbox, btn_idx, "  (no loot extracted)", Color(0.5, 0.5, 0.5), 9)

	## ── Instability peak ─────────────────────────────────────────────────────
	var peak: float = GameManager.peak_instability
	var peak_tier: Dictionary = LootTables.get_instability_tier(peak)
	_insert_label(vbox, btn_idx,
		"Peak Instability: %s  (%d)" % [peak_tier.name, int(peak)],
		peak_tier.color, 9)

	## ── Phase bonus (locked extraction) ──────────────────────────────────────
	if GameManager.active_extraction_type == "locked":
		var phase_bonuses: Array = [0, 0, 0, 25, 50, 100]
		var bonus_pct: int = phase_bonuses[clampi(GameManager.phase_number, 0, 5)]
		if bonus_pct > 0:
			_insert_label(vbox, btn_idx, "Locked Bonus: +%d%%" % bonus_pct, Color(0.9, 0.75, 0.2), 9)

	## ── Total resources ───────────────────────────────────────────────────────
	_insert_label(vbox, btn_idx, "── TOTAL RESOURCES:  +%d" % resources_earned, Color(1.0, 0.92, 0.4), 11)

	play_again_button.text = "Return to Hub"
	visible = true

	ProgressionManager.record_extraction(resources_earned, GameManager.kills, GameManager.phase_number, GameManager.last_run_loot)

func _insert_label(parent: Node, before_idx: int, text: String, col: Color, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	var settings := LabelSettings.new()
	if ResourceLoader.exists(FONT_PATH):
		settings.font = load(FONT_PATH)
	settings.font_size    = font_size
	settings.font_color   = col
	settings.outline_size = 1
	settings.outline_color = Color(0.0, 0.0, 0.0, 0.85)
	lbl.label_settings = settings
	parent.add_child(lbl)
	parent.move_child(lbl, before_idx)
	_dynamic_labels.append(lbl)
	return lbl

func _get_player_level() -> int:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		return player.level
	return 1

func _on_return_to_hub() -> void:
	visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
