@tool
extends Control

## Workshop panel — hub upgrades (permanent purchases).

signal close_requested

@onready var _base: HubPanelBase = $PanelBase

var _insurance_name: Label  = null
var _insurance_btn:  Button = null
var _armory_name:    Label  = null
var _armory_btn:     Button = null
var _channel_name:   Label  = null
var _channel_btn:    Button = null
var _reroll_cap_name: Label  = null
var _reroll_cap_btn:  Button = null
var _intel_name:      Label  = null
var _intel_btn:       Button = null
var _hub_tier:       Label  = null
var _spent:          Label  = null

var _pm: Node = null

func _ready() -> void:
	_base.close_requested.connect(func(): close_requested.emit())
	if Engine.is_editor_hint():
		return
	_build_ui()
	populate(ProgressionManager)

func _build_ui() -> void:
	var content: Control = _base.get_content()
	var font := HubPanelBase.PIXEL_FONT

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 0)
	scroll.size = Vector2(HubPanelBase.PANEL_W, HubPanelBase.CONTENT_H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	## Inset content within the scroll area
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	scroll.add_child(margin)
	margin.add_child(vbox)

	## Upgrade rows: [label_var, btn_var]
	_insurance_name   = _add_row_label(vbox, font, HubPanelBase.FONT_BODY)
	_insurance_btn    = _add_row_btn(vbox, font, HubPanelBase.FONT_BODY)
	_armory_name      = _add_row_label(vbox, font, HubPanelBase.FONT_BODY)
	_armory_btn       = _add_row_btn(vbox, font, HubPanelBase.FONT_BODY)
	_channel_name     = _add_row_label(vbox, font, HubPanelBase.FONT_BODY)
	_channel_btn      = _add_row_btn(vbox, font, HubPanelBase.FONT_BODY)
	_reroll_cap_name  = _add_row_label(vbox, font, HubPanelBase.FONT_BODY)
	_reroll_cap_btn   = _add_row_btn(vbox, font, HubPanelBase.FONT_BODY)
	_intel_name       = _add_row_label(vbox, font, HubPanelBase.FONT_BODY)
	_intel_btn        = _add_row_btn(vbox, font, HubPanelBase.FONT_BODY)

	## Footer
	_hub_tier = _add_row_label(vbox, font, HubPanelBase.FONT_DIM, Color(0.55, 0.55, 0.62))
	_spent    = _add_row_label(vbox, font, HubPanelBase.FONT_DIM, Color(0.55, 0.55, 0.62))

func _add_row_label(parent: Control, font: Font, font_size: int,
		color: Color = Color(0.82, 0.82, 0.87)) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.custom_minimum_size = Vector2(272, 18)
	parent.add_child(lbl)
	return lbl

func _add_row_btn(parent: Control, font: Font, font_size: int) -> Button:
	var btn := Button.new()
	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.custom_minimum_size = Vector2(272, 20)
	parent.add_child(btn)
	return btn

func populate(pm: Node) -> void:
	_pm = pm
	_build()

func _build() -> void:
	var pm := _pm

	## Insurance License row
	var ins_cost: int  = ProgressionManager.UPGRADE_COSTS.get("insurance_license", 0)
	var ins_owned: bool = pm.has_upgrade("insurance_license")
	_insurance_name.text = "Insurance License  [%d res]" % ins_cost
	_setup_upgrade_btn(_insurance_btn, "insurance_license", ins_cost, ins_owned)

	## Armory Expansion row (tiered)
	var arm_tier: int  = pm.get_upgrade_tier("armory_expansion")
	var arm_max: bool  = arm_tier >= 2
	var arm_next_id: String = "armory_expansion_%d" % (arm_tier + 1)
	var arm_cost: int  = ProgressionManager.UPGRADE_COSTS.get(arm_next_id, 0)
	var arm_slots: int = pm.starting_weapon_slots()
	if arm_max:
		_armory_name.text = "Armory Expansion  MAX  [%d slots]" % arm_slots
		_setup_upgrade_btn(_armory_btn, "", 0, true)
	else:
		_armory_name.text = "Armory Expansion %d/2  [%d res]  (%d slots)" % [arm_tier, arm_cost, arm_slots]
		_setup_upgrade_btn(_armory_btn, arm_next_id, arm_cost, false)

	## Channel Accelerator row (tiered)
	var ch_tier: int = pm.get_upgrade_tier("channel_accelerator")
	var ch_max: bool = ch_tier >= 3
	var ch_next_id: String = "channel_accelerator_%d" % (ch_tier + 1)
	var ch_cost: int = ProgressionManager.UPGRADE_COSTS.get(ch_next_id, 0)
	var ch_duration: float = pm.get_channel_duration()
	if ch_max:
		_channel_name.text = "Channel Accelerator  MAX  [%.1fs]" % ch_duration
		_setup_upgrade_btn(_channel_btn, "", 0, true)
	else:
		_channel_name.text = "Channel Accelerator %d/3  [%d res]  (%.1fs)" % [ch_tier, ch_cost, ch_duration]
		_setup_upgrade_btn(_channel_btn, ch_next_id, ch_cost, false)

	## Reroll Capacity row (tiered, 2 tiers)
	var rc_tier: int = pm.get_upgrade_tier("reroll_capacity")
	var rc_max: bool = rc_tier >= 2
	var rc_next_id: String = "reroll_capacity_%d" % (rc_tier + 1)
	var rc_cost: int = ProgressionManager.UPGRADE_COSTS.get(rc_next_id, 0)
	if rc_max:
		_reroll_cap_name.text = "Reroll Capacity  MAX  [%d rerolls]" % pm.get_max_rerolls()
		_setup_upgrade_btn(_reroll_cap_btn, "", 0, true)
	else:
		_reroll_cap_name.text = "Reroll Capacity %d/2  [%d res]" % [rc_tier, rc_cost]
		_setup_upgrade_btn(_reroll_cap_btn, rc_next_id, rc_cost, false)

	## Extraction Intel row (single purchase)
	var intel_cost: int  = ProgressionManager.UPGRADE_COSTS.get("extraction_intel_1", 0)
	var intel_owned: bool = pm.has_upgrade("extraction_intel_1")
	_intel_name.text = "Extraction Intel I  [%d res]" % intel_cost
	_setup_upgrade_btn(_intel_btn, "extraction_intel_1", intel_cost, intel_owned)

	## Footer
	var tier_labels := ["Bare (spend 300 to upgrade)", "Torches lit", "Restored"]
	var tier: int = pm.get_hub_tier()
	_hub_tier.text = "Hub:   %s" % tier_labels[tier]
	_spent.text    = "Spent: %d res" % pm.total_resources_spent

func _setup_upgrade_btn(btn: Button, upgrade_id: String, cost: int, owned: bool) -> void:
	## Disconnect any previous signal connections to avoid double-firing on repopulate.
	if btn.pressed.get_connections().size() > 0:
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn.callable)

	if owned:
		btn.text     = "OWNED" if upgrade_id != "" else "MAX"
		btn.disabled = true
		_base.style_btn(btn, Color(0.08, 0.18, 0.10, 0.60), Color(0.08, 0.18, 0.10, 0.60), 4)
		btn.add_theme_color_override("font_color", Color(0.40, 0.60, 0.44))
	elif _pm.resources < cost:
		btn.text     = "BUY"
		btn.disabled = true
		_base.style_btn(btn, Color(0.10, 0.10, 0.12, 0.50), Color(0.10, 0.10, 0.12, 0.50), 4)
		btn.add_theme_color_override("font_color", Color(0.38, 0.38, 0.42))
	else:
		btn.text     = "BUY"
		btn.disabled = false
		_base.style_btn(btn, Color(0.28, 0.22, 0.04, 0.70), Color(0.40, 0.32, 0.06, 0.85), 4)
		btn.add_theme_color_override("font_color",       Color(0.98, 0.84, 0.28))
		btn.add_theme_color_override("font_hover_color", Color(1.00, 0.96, 0.70))
		var cap_id := upgrade_id
		btn.pressed.connect(func():
			if _pm.purchase_upgrade(cap_id):
				populate(_pm)
		)
