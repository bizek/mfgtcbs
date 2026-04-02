@tool
extends Control

## Roster panel — character list (left) and detail view (right).

signal close_requested

@onready var _base: HubPanelBase = $PanelBase

## Left-column character rows — indexed to match CharacterData.ORDER.
@onready var _char_highlights: Array[ColorRect] = [
	$PanelBase/ContentContainer/CharHighlight0,
	$PanelBase/ContentContainer/CharHighlight1,
	$PanelBase/ContentContainer/CharHighlight2,
	$PanelBase/ContentContainer/CharHighlight3,
	$PanelBase/ContentContainer/CharHighlight4,
	$PanelBase/ContentContainer/CharHighlight5,
	$PanelBase/ContentContainer/CharHighlight6,
]
@onready var _char_dots: Array[ColorRect] = [
	$PanelBase/ContentContainer/CharDot0,
	$PanelBase/ContentContainer/CharDot1,
	$PanelBase/ContentContainer/CharDot2,
	$PanelBase/ContentContainer/CharDot3,
	$PanelBase/ContentContainer/CharDot4,
	$PanelBase/ContentContainer/CharDot5,
	$PanelBase/ContentContainer/CharDot6,
]
@onready var _char_btns: Array[Button] = [
	$PanelBase/ContentContainer/CharBtn0,
	$PanelBase/ContentContainer/CharBtn1,
	$PanelBase/ContentContainer/CharBtn2,
	$PanelBase/ContentContainer/CharBtn3,
	$PanelBase/ContentContainer/CharBtn4,
	$PanelBase/ContentContainer/CharBtn5,
	$PanelBase/ContentContainer/CharBtn6,
]

## Right-column detail nodes.
@onready var _detail_name:    Label  = $PanelBase/ContentContainer/DetailNameLabel
@onready var _detail_hp:      Label  = $PanelBase/ContentContainer/DetailHPLabel
@onready var _detail_arm:     Label  = $PanelBase/ContentContainer/DetailArmLabel
@onready var _detail_spd:     Label  = $PanelBase/ContentContainer/DetailSpdLabel
@onready var _detail_weapon:  Label  = $PanelBase/ContentContainer/DetailWeaponLabel
@onready var _detail_passive: Label  = $PanelBase/ContentContainer/DetailPassiveLabel
@onready var _detail_action:  Button = $PanelBase/ContentContainer/DetailActionBtn
@onready var _resources_lbl:  Label  = $PanelBase/ContentContainer/ResourcesLabel

## Which character is shown in the detail pane.
var _detail_char: String = ""
var _pm: Node = null

func _ready() -> void:
	_base.close_requested.connect(func(): close_requested.emit())
	if Engine.is_editor_hint():
		return
	populate(ProgressionManager)

func populate(pm: Node) -> void:
	_pm = pm
	if _detail_char.is_empty():
		_detail_char = pm.selected_character
	_build()

func _build() -> void:
	var pm := _pm
	_resources_lbl.text = "Resources: %d" % pm.resources

	## ── Left column ──────────────────────────────────────────────────────────
	var order: Array = CharacterData.ORDER
	for i in range(order.size()):
		var char_id: String       = order[i]
		var cdata: Dictionary     = CharacterData.ALL[char_id]
		var is_unlocked: bool     = pm.has_character(char_id)
		var is_selected: bool     = pm.selected_character == char_id
		var is_detail: bool       = _detail_char == char_id
		var char_col: Color       = cdata.get("color", Color.WHITE)

		## Highlight row background for the currently viewed detail character.
		_char_highlights[i].visible = is_detail
		if is_detail:
			_char_highlights[i].color = Color(
				char_col.r * 0.12, char_col.g * 0.12, char_col.b * 0.18, 0.90)

		## Dot colour: full colour if unlocked, dim if locked.
		_char_dots[i].color = char_col if is_unlocked \
				else Color(char_col.r * 0.35, char_col.g * 0.35, char_col.b * 0.35)

		## Name button text and colour.
		var display_name: String = cdata.get("display_name", char_id)
		_char_btns[i].text = ("▶ " if is_selected else "  ") + display_name

		var name_col: Color
		if is_selected:
			name_col = char_col
		elif is_unlocked:
			name_col = Color(0.78, 0.78, 0.84)
		else:
			name_col = Color(0.36, 0.36, 0.40)
		_char_btns[i].add_theme_color_override("font_color", name_col)

		## Reconnect pressed signal (disconnect old first to avoid duplicates).
		if _char_btns[i].pressed.get_connections().size() > 0:
			for conn in _char_btns[i].pressed.get_connections():
				_char_btns[i].pressed.disconnect(conn.callable)
		var cid := char_id
		_char_btns[i].pressed.connect(func():
			_detail_char = cid
			populate(_pm)
		)

	## ── Right column (detail) ────────────────────────────────────────────────
	var ddata: Dictionary = CharacterData.ALL.get(_detail_char, CharacterData.ALL["The Drifter"])
	var d_col: Color      = ddata.get("color", Color.WHITE)
	var d_unlocked: bool  = pm.has_character(_detail_char)
	var d_selected: bool  = pm.selected_character == _detail_char
	var d_cost: int       = ddata.get("unlock_cost", 0)

	var name_col: Color = d_col if d_unlocked else Color(d_col.r * 0.45, d_col.g * 0.45, d_col.b * 0.45)
	_detail_name.text = ddata.get("display_name", _detail_char)
	_detail_name.add_theme_color_override("font_color", name_col)

	var stat_col: Color = Color(0.58, 0.58, 0.64) if d_unlocked else Color(0.32, 0.32, 0.36)
	_detail_hp.text  = "HP   %d" % int(ddata.get("base_hp",         100.0))
	_detail_arm.text = "Arm  %d" % int(ddata.get("base_armor",        0.0))
	_detail_spd.text = "Spd  %d" % int(ddata.get("base_move_speed", 200.0))
	for lbl in [_detail_hp, _detail_arm, _detail_spd]:
		lbl.add_theme_color_override("font_color", stat_col)

	_detail_weapon.text = ddata.get("starting_weapon", "?")
	_detail_weapon.add_theme_color_override("font_color", stat_col)

	_detail_passive.text = ddata.get("passive_desc", "None.")
	_detail_passive.add_theme_color_override("font_color",
			d_col if d_unlocked else Color(0.32, 0.32, 0.36))

	## Action button — disconnect old signal first.
	if _detail_action.pressed.get_connections().size() > 0:
		for conn in _detail_action.pressed.get_connections():
			_detail_action.pressed.disconnect(conn.callable)

	if d_selected:
		_detail_action.text     = "[ ACTIVE ]"
		_detail_action.disabled = true
		_detail_action.add_theme_color_override("font_color", d_col)
		_base.style_btn(_detail_action,
				Color(d_col.r * 0.12, d_col.g * 0.12, d_col.b * 0.18, 0.70),
				Color(d_col.r * 0.12, d_col.g * 0.12, d_col.b * 0.18, 0.70), 4)
	elif d_unlocked:
		_detail_action.text     = "SELECT"
		_detail_action.disabled = false
		_detail_action.add_theme_color_override("font_color",       Color(0.78, 0.96, 0.78))
		_detail_action.add_theme_color_override("font_hover_color", Color(1.00, 1.00, 1.00))
		_base.style_btn(_detail_action, Color(0.10, 0.24, 0.12, 0.70), Color(0.16, 0.38, 0.18, 0.85), 4)
		var sel_id := _detail_char
		_detail_action.pressed.connect(func():
			_pm.select_character(sel_id)
			populate(_pm)
		)
	elif pm.resources >= d_cost:
		_detail_action.text     = "BUY  %d res" % d_cost
		_detail_action.disabled = false
		_detail_action.add_theme_color_override("font_color",       Color(0.98, 0.84, 0.28))
		_detail_action.add_theme_color_override("font_hover_color", Color(1.00, 0.96, 0.70))
		_base.style_btn(_detail_action, Color(0.28, 0.22, 0.04, 0.70), Color(0.40, 0.32, 0.06, 0.85), 4)
		var buy_id := _detail_char
		_detail_action.pressed.connect(func():
			if _pm.purchase_character(buy_id):
				populate(_pm)
		)
	else:
		_detail_action.text     = "%d res" % d_cost
		_detail_action.disabled = true
		_detail_action.add_theme_color_override("font_color", Color(0.38, 0.38, 0.42))
		_base.style_btn(_detail_action,
				Color(0.10, 0.10, 0.12, 0.40), Color(0.10, 0.10, 0.12, 0.40), 4)
