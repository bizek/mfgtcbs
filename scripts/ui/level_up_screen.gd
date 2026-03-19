extends CanvasLayer

## Level-Up Screen — Pauses game, shows 3 upgrade choices, resumes on pick

signal upgrade_selected(upgrade: Dictionary)

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var choices_container: VBoxContainer = $Panel/VBox/ChoicesContainer

var player_ref: Node2D = null
var _choices: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func setup(player: Node2D) -> void:
	player_ref = player
	player_ref.leveled_up.connect(_on_player_leveled_up)

func _on_player_leveled_up(new_level: int) -> void:
	title_label.text = "LEVEL %d!" % new_level
	_choices = UpgradeManager.generate_choices(3)
	_show_choices()
	visible = true
	GameManager.enter_level_up()

func _show_choices() -> void:
	## Clear old buttons
	for child in choices_container.get_children():
		child.queue_free()

	## Load pixel font for buttons (same font used by the HUD)
	var pixel_font: FontFile = load("res://assets/fonts/m5x7.ttf")

	## Create a button for each choice
	for i in range(_choices.size()):
		var upgrade: Dictionary = _choices[i]
		var btn := Button.new()
		btn.text = "%s\n%s" % [upgrade.name, upgrade.description]
		btn.custom_minimum_size = Vector2(210, 38)
		if pixel_font:
			btn.add_theme_font_override("font", pixel_font)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_choice_pressed.bind(i))
		choices_container.add_child(btn)

func _on_choice_pressed(index: int) -> void:
	var upgrade: Dictionary = _choices[index]
	UpgradeManager.apply_upgrade(upgrade, player_ref)
	upgrade_selected.emit(upgrade)
	visible = false
	GameManager.exit_level_up()
