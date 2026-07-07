extends CanvasLayer

## WinScreen — Shown instead of ExtractionSuccessScreen when the run clears the
## final biome's boss gate and extracts. Records run stats, then hands off to credits.

@onready var kills_label: Label = $VBox/KillsLabel
@onready var time_label: Label = $VBox/TimeLabel
@onready var character_label: Label = $VBox/CharacterLabel
@onready var continue_button: Button = $VBox/ContinueButton

const FONT_PATH: String = "res://assets/fonts/m5x7.ttf"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	continue_button.pressed.connect(_on_continue)
	GameManager.extraction_successful.connect(_on_extraction_successful)
	_apply_font()

func _apply_font() -> void:
	if not ResourceLoader.exists(FONT_PATH):
		return
	var font := load(FONT_PATH)
	for child in $VBox.get_children():
		if child is Label:
			child.add_theme_font_override("font", font)
		elif child is Button:
			child.add_theme_font_override("font", font)

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

	ProgressionManager.record_extraction(resources_earned, GameManager.kills, GameManager.phase_number, GameManager.last_run_loot)
	AchievementManager.check_run_end("extraction")

	visible = true
	continue_button.grab_focus.call_deferred()

func _on_continue() -> void:
	visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/credits.tscn")
