extends CanvasLayer

## Game Over Screen — Shows run stats, records death penalty, returns to hub.

@onready var kills_label: Label = $VBox/KillsLabel
@onready var time_label: Label = $VBox/TimeLabel
@onready var level_label: Label = $VBox/LevelLabel
@onready var restart_button: Button = $VBox/RestartButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	restart_button.pressed.connect(_on_return_to_hub)
	GameManager.player_died.connect(_on_player_died)

func _on_player_died() -> void:
	var loot_value: int = int(GameManager.loot_carried)
	var salvaged: int = int(loot_value * 0.25)
	var total_seconds: int = int(GameManager.run_time)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60

	kills_label.text = "Kills: %d" % GameManager.kills
	time_label.text = "Time: %d:%02d" % [minutes, seconds]
	level_label.text = "Level: %d   Salvaged: +%d" % [_get_player_level(), salvaged]

	## Show insured item if one was active
	var insured: String = GameManager.insured_item
	if not insured.is_empty() and ProgressionManager.has_upgrade("insurance_license"):
		var display: String = WeaponData.ALL.get(insured, {}).get("display_name", insured)
		var ins_lbl := Label.new()
		ins_lbl.text = "[★] Insured: %s kept" % display
		ins_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.22))
		$VBox.add_child(ins_lbl)
		$VBox.move_child(ins_lbl, restart_button.get_index())

	restart_button.text = "Return to Hub"
	visible = true

	ProgressionManager.record_death(loot_value, GameManager.kills, GameManager.phase_number)

func _get_player_level() -> int:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		return player.level
	return 1

func _on_return_to_hub() -> void:
	visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
