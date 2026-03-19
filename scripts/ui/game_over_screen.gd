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
