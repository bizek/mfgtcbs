@tool
extends Control

## Launch Pad panel — shows current loadout and hosts the BEGIN DESCENT button.

signal close_requested

@onready var _base: HubPanelBase = $PanelBase

@onready var _character_lbl:    Label  = $PanelBase/ContentContainer/CharacterLabel
@onready var _weapon_lbl:       Label  = $PanelBase/ContentContainer/WeaponLabel
@onready var _slot1_lbl:        Label  = $PanelBase/ContentContainer/Slot1Label
@onready var _slot2_lbl:        Label  = $PanelBase/ContentContainer/Slot2Label
@onready var _slot3_lbl:        Label  = $PanelBase/ContentContainer/Slot3Label
@onready var _passive_lbl:      Label  = $PanelBase/ContentContainer/PassiveLabel
@onready var _begin_btn:        Button = $PanelBase/ContentContainer/BeginDescentBtn

func _ready() -> void:
	_base.close_requested.connect(func(): close_requested.emit())
	_base.style_btn(_begin_btn,
			Color(0.08, 0.28, 0.14, 0.80), Color(0.12, 0.40, 0.20, 0.90), 4)
	_begin_btn.add_theme_color_override("font_color",       Color(0.22, 0.96, 0.44))
	_begin_btn.add_theme_color_override("font_hover_color", Color(0.80, 1.00, 0.86))
	_begin_btn.pressed.connect(_start_run)
	if Engine.is_editor_hint():
		return
	populate(ProgressionManager)

func populate(pm: Node) -> void:
	var char_id: String       = pm.selected_character
	var char_data: Dictionary = CharacterData.ALL.get(char_id, CharacterData.ALL["The Drifter"])
	var char_col: Color       = char_data.get("color", Color(0.92, 0.86, 0.60))

	_character_lbl.text = "Character:   %s" % char_data.get("display_name", char_id)
	_character_lbl.add_theme_color_override("font_color", char_col)

	var slot_count: int = pm.starting_weapon_slots() if char_id == "The Drifter" else 1

	if slot_count >= 2:
		_weapon_lbl.visible  = false
		_slot1_lbl.visible   = true
		_slot2_lbl.visible   = true
		_slot3_lbl.visible   = slot_count >= 3
		_passive_lbl.visible = false
		_slot1_lbl.text = "Slot 1:      %s" % pm.selected_weapon
		var w2: String = pm.selected_weapon_2 if not (pm.selected_weapon_2 as String).is_empty() else "\u2014 none \u2014"
		_slot2_lbl.text = "Slot 2:      %s" % w2
		if slot_count >= 3:
			var w3: String = pm.selected_weapon_3 if not (pm.selected_weapon_3 as String).is_empty() else "\u2014 none \u2014"
			_slot3_lbl.text = "Slot 3:      %s" % w3
	else:
		var starting_weapon: String = char_data.get("starting_weapon", pm.selected_weapon)
		if char_id == "The Drifter":
			starting_weapon = pm.selected_weapon
		_weapon_lbl.visible  = true
		_slot1_lbl.visible   = false
		_slot2_lbl.visible   = false
		_slot3_lbl.visible   = false
		_weapon_lbl.text = "Weapon:      %s" % starting_weapon

		if char_id != "The Drifter":
			_passive_lbl.visible = true
			_passive_lbl.text    = "Passive:     %s" % char_data.get("passive_desc", "")
		else:
			_passive_lbl.visible = false

func _start_run() -> void:
	get_tree().change_scene_to_file("res://scenes/main_arena.tscn")
