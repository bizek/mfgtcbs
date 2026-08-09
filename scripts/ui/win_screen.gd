extends CanvasLayer

## WinScreen — Shown instead of ExtractionSuccessScreen when the run clears the
## final biome's boss gate and extracts. Records run stats, then hands off to credits.

@onready var kills_label: Label = $VBox/KillsLabel
@onready var time_label: Label = $VBox/TimeLabel
@onready var character_label: Label = $VBox/CharacterLabel
@onready var continue_button: Button = $VBox/ContinueButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	continue_button.pressed.connect(_on_continue)
	GameManager.extraction_successful.connect(_on_extraction_successful)


func _on_extraction_successful() -> void:
	if not GameManager.last_run_was_win:
		return  ## Normal extraction — ExtractionSuccessScreen handles it instead

	var resources_earned: int = int(GameManager.last_run_loot)
	var total_seconds: int = int(GameManager.run_time)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60

	kills_label.text = "Kills: %d" % GameManager.kills
	time_label.text = "Time: %d:%02d" % [minutes, seconds]
	character_label.text = "Cleared with: %s" % ProgressionManager.selected_character

	ProgressionManager.record_extraction(resources_earned, GameManager.kills, GameManager.phase_number, GameManager.last_run_loot, _get_player_level() - 1)
	AchievementManager.check_run_end("extraction")

	visible = true
	continue_button.grab_focus.call_deferred()

func _get_player_level() -> int:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		return player.level
	return 1

func _on_continue() -> void:
	visible = false
	## A slower fade than the default here: this is the hand-off from the win
	## screen to the credits roll, and it is the one transition worth lingering on.
	SceneTransition.change_scene("res://scenes/ui/credits.tscn", 0.6, 0.5)
