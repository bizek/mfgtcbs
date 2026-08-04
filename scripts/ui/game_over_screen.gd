extends CanvasLayer

## Game Over Screen — Shows run stats, records the run's penalty, returns to hub.
##
## Serves both ways a run can end badly: dying, and walking out from the pause menu (Abandon Run,
## Ben 2026-08-01). They settle identically — same 25% salvage, same rollback — so they share this
## screen; only the title and the recorded stat differ.

@onready var title_label: Label = $VBox/Title
@onready var kills_label: Label = $VBox/KillsLabel
@onready var time_label: Label = $VBox/TimeLabel
@onready var level_label: Label = $VBox/LevelLabel
@onready var restart_button: Button = $VBox/RestartButton

const FONT_PATH: String = "res://assets/fonts/m5x7.ttf"

## m5x7 is a 16px-native pixel font: one design pixel equals one screen pixel only at 16 and
## its integer multiples. Anything else lands glyph stems on fractional pixels, and with
## antialiasing off they snap unevenly before the 3x viewport upscale magnifies the mess.
## So: body at 16, the title at 32, nothing in between.
const TITLE_SIZE: int = 32
const BODY_SIZE: int  = 16

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	restart_button.pressed.connect(_on_return_to_hub)
	GameManager.run_failed.connect(_show_lost_run)
	_apply_font()

## This screen had shipped with no font override at all, so the one screen you are guaranteed to
## read on a bad run was the only one still rendering in Godot's default vector font — antialiased
## at 640x360, then nearest-upscaled 3x into mush. Every sibling screen already did this.
func _apply_font() -> void:
	if not ResourceLoader.exists(FONT_PATH):
		return
	var font := load(FONT_PATH)
	for child in $VBox.get_children():
		if child is Label or child is Button:
			child.add_theme_font_override("font", font)
			child.add_theme_font_size_override(
				"font_size", TITLE_SIZE if child == title_label else BODY_SIZE)

func _show_lost_run(abandoned: bool) -> void:
	var loot_value: int = int(GameManager.loot_carried)
	var salvaged: int = int(loot_value * 0.25)
	var total_seconds: int = int(GameManager.run_time)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60

	title_label.text = "RUN ABANDONED" if abandoned else "YOU DIED"
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
		## Built after _apply_font() has already walked the VBox, so it fonts itself.
		if ResourceLoader.exists(FONT_PATH):
			ins_lbl.add_theme_font_override("font", load(FONT_PATH))
		ins_lbl.add_theme_font_size_override("font_size", BODY_SIZE)
		$VBox.add_child(ins_lbl)
		$VBox.move_child(ins_lbl, restart_button.get_index())

	restart_button.text = "Return to Hub"
	visible = true
	restart_button.grab_focus.call_deferred()

	var levels_gained: int = _get_player_level() - 1
	if abandoned:
		ProgressionManager.record_abandon(loot_value, GameManager.kills, GameManager.phase_number, levels_gained)
		AchievementManager.check_run_end("abandon")
	else:
		ProgressionManager.record_death(loot_value, GameManager.kills, GameManager.phase_number, levels_gained)
		AchievementManager.check_run_end("death")

func _get_player_level() -> int:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		return player.level
	return 1

func _on_return_to_hub() -> void:
	visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
