extends Control

## Research Terminal panel — purchase weapon blueprints to unlock them in future runs.
## Script-only panel; instantiates HubPanelBase at runtime so no separate .tscn is needed.

signal close_requested

const _PANEL_BASE_SCENE := preload("res://scenes/ui/hub_panel_base.tscn")
const ACCENT: Color = Color(0.20, 0.85, 0.55)

var _base: HubPanelBase = null
var _pm: Node = null

## Built once; holds [label_node, buy_btn_node] per blueprint weapon row.
var _rows: Array = []
var _built: bool = false

func _ready() -> void:
	_base = _PANEL_BASE_SCENE.instantiate()
	_base.title_text  = "RESEARCH"
	_base.accent_color = ACCENT
	add_child(_base)
	_base.close_requested.connect(func(): close_requested.emit())

	if Engine.is_editor_hint():
		return
	_build_ui()
	populate(ProgressionManager)


func populate(pm: Node) -> void:
	_pm = pm
	if _built:
		_refresh()


# ── UI construction (called once) ────────────────────────────────────────────

func _build_ui() -> void:
	var content := _base.get_content()
	var font    := HubPanelBase.PIXEL_FONT

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 0)
	scroll.size = Vector2(HubPanelBase.PANEL_W, HubPanelBase.CONTENT_H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left",   8)
	margin.add_theme_constant_override("margin_right",  8)
	margin.add_theme_constant_override("margin_top",    4)
	margin.add_theme_constant_override("margin_bottom", 4)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	## One row per blueprint weapon (unlock_id != "")
	for weapon_id in WeaponData.ALL:
		var weapon_data: Dictionary = WeaponData.ALL[weapon_id]
		if weapon_data.get("unlock_id", "").is_empty():
			continue  ## Starter/character-exclusive — not purchasable here

		var cost: int       = weapon_data.get("blueprint_cost", 0)
		var display: String = weapon_data.get("display_name", weapon_id)
		var desc: String    = weapon_data.get("description", "")

		## Weapon name + description label
		var name_lbl := Label.new()
		name_lbl.add_theme_font_override("font",      font)
		name_lbl.add_theme_font_size_override("font_size", HubPanelBase.FONT_BODY)
		name_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.87))
		name_lbl.text = "%s  [%d res]\n  %s" % [display, cost, desc]
		name_lbl.custom_minimum_size = Vector2(HubPanelBase.LABEL_W, 28)
		vbox.add_child(name_lbl)

		## Buy button
		var btn := Button.new()
		btn.add_theme_font_override("font",      font)
		btn.add_theme_font_size_override("font_size", HubPanelBase.FONT_BODY)
		btn.custom_minimum_size = Vector2(HubPanelBase.LABEL_W, 20)
		vbox.add_child(btn)

		_rows.append({"weapon_id": weapon_id, "label": name_lbl, "btn": btn})

	_built = true
	_refresh()


# ── Refresh row states ────────────────────────────────────────────────────────

func _refresh() -> void:
	if not _built or _pm == null:
		return
	for row in _rows:
		var weapon_id: String   = row["weapon_id"]
		var weapon_data: Dictionary = WeaponData.ALL.get(weapon_id, {})
		var cost: int           = weapon_data.get("blueprint_cost", 0)
		var display: String     = weapon_data.get("display_name", weapon_id)
		var desc: String        = weapon_data.get("description", "")
		var owned: bool         = weapon_id in _pm.unlocked_weapons
		var can_afford: bool    = _pm.resources >= cost

		var lbl: Label   = row["label"]
		var btn: Button  = row["btn"]

		if owned:
			lbl.add_theme_color_override("font_color", Color(0.45, 0.72, 0.50))
			lbl.text = "%s  [OWNED]\n  %s" % [display, desc]
			btn.text     = "OWNED"
			btn.disabled = true
			_base.style_btn(btn, Color(0.08, 0.18, 0.10, 0.60), Color(0.08, 0.18, 0.10, 0.60), 4)
			btn.add_theme_color_override("font_color", Color(0.40, 0.60, 0.44))
		elif not can_afford:
			lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
			lbl.text = "%s  [%d res]\n  %s" % [display, cost, desc]
			btn.text     = "BUY"
			btn.disabled = true
			_base.style_btn(btn, Color(0.10, 0.10, 0.12, 0.50), Color(0.10, 0.10, 0.12, 0.50), 4)
			btn.add_theme_color_override("font_color", Color(0.38, 0.38, 0.42))
		else:
			lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.87))
			lbl.text = "%s  [%d res]\n  %s" % [display, cost, desc]
			btn.text     = "BUY"
			btn.disabled = false
			_base.style_btn(btn, Color(0.04, 0.22, 0.14, 0.70), Color(0.06, 0.32, 0.20, 0.85), 4)
			btn.add_theme_color_override("font_color",       Color(0.40, 0.95, 0.62))
			btn.add_theme_color_override("font_hover_color", Color(0.70, 1.00, 0.82))

		## Reconnect buy signal (disconnect first to prevent duplicate fires)
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn.callable)
		if not owned:
			var cap_id := weapon_id
			btn.pressed.connect(func():
				if _pm.purchase_weapon_blueprint(cap_id):
					_refresh()
			)
