extends CanvasLayer

## Level-Up Screen — Pauses game, shows 3 upgrade choices, resumes on pick

signal upgrade_selected(upgrade: Dictionary)

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var choices_container: VBoxContainer = $Panel/VBox/ChoicesContainer

const WEAPON_SWAP_COST: float = 30.0

var player_ref: Node2D = null
var _choices: Array[Dictionary] = []
var _rerolls_remaining: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func setup(player: Node2D) -> void:
	player_ref = player
	player_ref.leveled_up.connect(_on_player_leveled_up)

func _on_player_leveled_up(new_level: int) -> void:
	title_label.text = "LEVEL %d!" % new_level
	_rerolls_remaining = ProgressionManager.get_max_rerolls()
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
		if upgrade.get("is_evolution", false):
			btn.text = "★ %s\n%s" % [upgrade.name, upgrade.description]
			btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
		else:
			btn.text = "%s\n%s" % [upgrade.name, upgrade.description]
		btn.custom_minimum_size = Vector2(210, 38)
		if pixel_font:
			btn.add_theme_font_override("font", pixel_font)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_choice_pressed.bind(i))
		choices_container.add_child(btn)

	## Reroll button
	var reroll_btn := Button.new()
	reroll_btn.custom_minimum_size = Vector2(210, 30)
	if pixel_font:
		reroll_btn.add_theme_font_override("font", pixel_font)
	reroll_btn.add_theme_font_size_override("font_size", 14)
	reroll_btn.disabled = _rerolls_remaining <= 0
	reroll_btn.text = "Reroll  [%d left]" % _rerolls_remaining
	reroll_btn.pressed.connect(_on_reroll_pressed)
	choices_container.add_child(reroll_btn)

	_build_weapon_cache(pixel_font)

func _build_weapon_cache(pixel_font: FontFile) -> void:
	var current_weapon: String = player_ref.get_active_weapon_id()
	var available: Array[String] = []
	for weapon_id in ProgressionManager.unlocked_weapons:
		if weapon_id == current_weapon:
			continue
		var wdata: Dictionary = WeaponData.ALL.get(weapon_id, {})
		if wdata.get("unlock_id", "").is_empty():
			continue  ## Skip starters — they're always available, not a mid-run prize
		available.append(weapon_id)

	if available.is_empty():
		return

	## Pick one random weapon to offer — you don't get to browse the full cache
	var offered: String = available[randi() % available.size()]
	var wdata: Dictionary = WeaponData.ALL[offered]

	var sep := HSeparator.new()
	choices_container.add_child(sep)

	var header := Label.new()
	header.text = "— WEAPON CACHE  [%.0f / %.0f loot] —" % [GameManager.loot_carried, WEAPON_SWAP_COST]
	if pixel_font:
		header.add_theme_font_override("font", pixel_font)
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choices_container.add_child(header)

	var display: String = wdata.get("display_name", offered)
	var desc: String    = wdata.get("description", "")
	var btn := Button.new()
	btn.text = "%s\n%s\n[Cost: 30 loot — drops current weapon]" % [display, desc]
	btn.custom_minimum_size = Vector2(210, 52)
	btn.disabled = GameManager.loot_carried < WEAPON_SWAP_COST
	if pixel_font:
		btn.add_theme_font_override("font", pixel_font)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	btn.pressed.connect(_on_weapon_swap_pressed.bind(offered))
	choices_container.add_child(btn)

func _on_weapon_swap_pressed(weapon_id: String) -> void:
	if not GameManager.spend_loot(WEAPON_SWAP_COST):
		return
	player_ref.drop_current_weapon()
	player_ref.switch_weapon(weapon_id)
	visible = false
	GameManager.exit_level_up()

func _on_reroll_pressed() -> void:
	if _rerolls_remaining <= 0:
		return
	_rerolls_remaining -= 1
	_choices = UpgradeManager.generate_choices(3)
	_show_choices()

func _on_choice_pressed(index: int) -> void:
	var upgrade: Dictionary = _choices[index]
	UpgradeManager.apply_upgrade(upgrade, player_ref)
	upgrade_selected.emit(upgrade)
	visible = false
	GameManager.exit_level_up()
