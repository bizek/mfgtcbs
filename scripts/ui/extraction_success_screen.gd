extends CanvasLayer

## Extraction Success Screen — Shows run stats, records progression, returns to hub.

@onready var kills_label: Label = $VBox/KillsLabel
@onready var time_label: Label = $VBox/TimeLabel
@onready var level_label: Label = $VBox/LevelLabel
@onready var play_again_button: Button = $VBox/PlayAgainButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	play_again_button.pressed.connect(_on_return_to_hub)
	GameManager.extraction_successful.connect(_on_extraction_successful)

func _on_extraction_successful() -> void:
	var resources_earned: int = int(GameManager.last_run_loot)
	var total_seconds: int = int(GameManager.run_time)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60

	kills_label.text = "Kills: %d" % GameManager.kills
	time_label.text  = "Time: %d:%02d" % [minutes, seconds]
	level_label.text = "Level: %d   Resources: +%d" % [_get_player_level(), resources_earned]

	## Show any weapons extracted this run (weapons were already unlocked by GameManager)
	var weapons := GameManager.collected_weapons
	if not weapons.is_empty():
		var vbox: Control = $VBox
		var weapon_lbl := Label.new()
		weapon_lbl.text = "Weapons unlocked: " + ", ".join(weapons)
		## Insert before the button so layout stays clean
		vbox.add_child(weapon_lbl)
		vbox.move_child(weapon_lbl, play_again_button.get_index())

	play_again_button.text = "Return to Hub"
	visible = true

	ProgressionManager.record_extraction(resources_earned, GameManager.kills, GameManager.phase_number, GameManager.last_run_loot)

func _get_player_level() -> int:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		return player.level
	return 1

func _on_return_to_hub() -> void:
	visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
