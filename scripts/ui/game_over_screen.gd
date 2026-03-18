extends CanvasLayer

## Game Over Screen — Shows stats, restart button

@onready var kills_label: Label = $VBox/KillsLabel
@onready var time_label: Label = $VBox/TimeLabel
@onready var level_label: Label = $VBox/LevelLabel
@onready var restart_button: Button = $VBox/RestartButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	GameManager.player_died.connect(_on_player_died)

func _on_player_died() -> void:
	var total_seconds: int = int(GameManager.run_time)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	kills_label.text = "Kills: %d" % GameManager.kills
	time_label.text = "Time: %d:%02d" % [minutes, seconds]
	level_label.text = "Level: %d" % _get_player_level()
	visible = true

func _get_player_level() -> int:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		return player.level
	return 1

func _on_restart_pressed() -> void:
	visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()
