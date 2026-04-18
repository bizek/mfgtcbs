@tool
extends Control

## Workshop panel — hub upgrades (permanent purchases).
## Dark industrial aesthetic matching hub_armory_panel.

signal close_requested

@onready var _base: HubPanelBase = $PanelBase

## ── Color palette ────────────────────────────────────────────────────────────
const C_CARD     := Color(0.082, 0.075, 0.063)
const C_BORDER   := Color(0.165, 0.145, 0.125)
const C_AMBER    := Color(0.831, 0.447, 0.102)
const C_AMBER_HI := Color(0.941, 0.565, 0.188)
const C_AMBER_LO := Color(0.353, 0.173, 0.031)
const C_GREEN_HI := Color(0.314, 0.690, 0.188)
const C_T0       := Color(0.800, 0.690, 0.565)
const C_T1       := Color(0.541, 0.408, 0.282)
const C_T2       := Color(0.314, 0.235, 0.157)

const FONT  := HubPanelBase.PIXEL_FONT
const FS_MD := 19
const FS_SM := 16
const FS_XS := 13

## ── State ────────────────────────────────────────────────────────────────────
var _pm: Node = null


func _ready() -> void:
	_base.close_requested.connect(func(): close_requested.emit())
	if Engine.is_editor_hint():
		return
	populate(ProgressionManager)


func populate(pm: Node) -> void:
	_pm = pm
	var content: Control = _base.get_content()
	for child in content.get_children():
		child.queue_free()
	_build(content)


func _build(root: Control) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_top",     4)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_bottom",  8)
	root.add_child(margin)

	var outer := VBoxContainer.new()
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_theme_constant_override("separation", 5)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	margin.add_child(outer)

	## Section header
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 5)
	hdr.custom_minimum_size = Vector2(0, 16)
	outer.add_child(hdr)

	_lbl(hdr, "HUB UPGRADES", FS_SM, C_T2)

	var rule := ColorRect.new()
	rule.custom_minimum_size   = Vector2(0, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	rule.color                 = C_AMBER
	hdr.add_child(rule)

	## Scrollable card list
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var cards := VBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 4)
	scroll.add_child(cards)

	for udata: Dictionary in _get_all_upgrades():
		_build_upgrade_card(cards, udata)

	## Footer
	_build_footer(outer)


## ── Upgrade data ─────────────────────────────────────────────────────────────

func _get_all_upgrades() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if Engine.is_editor_hint() or _pm == null:
		for entry: Array in [
			["INSURANCE LICENSE",   "SINGLE PURCHASE", "—"],
			["ARMORY EXPANSION",    "TIER 0 / 2",      "—"],
			["CHANNEL ACCELERATOR", "TIER 0 / 3",      "—"],
			["REROLL CAPACITY",     "TIER 0 / 2",      "—"],
			["EXTRACTION INTEL I",  "SINGLE PURCHASE", "—"],
		]:
			result.append({"name": entry[0], "tier_text": entry[1],
				"cost_text": entry[2], "upgrade_id": "", "is_maxed": false, "is_affordable": false})
		return result

	## Insurance License — single purchase
	var ins_cost: int   = ProgressionManager.UPGRADE_COSTS.get("insurance_license", 0)
	var ins_owned: bool = _pm.has_upgrade("insurance_license")
	result.append({
		"name":         "INSURANCE LICENSE",
		"tier_text":    "OWNED" if ins_owned else "SINGLE PURCHASE",
		"cost_text":    "---" if ins_owned else "%d RES" % ins_cost,
		"upgrade_id":   "insurance_license",
		"is_maxed":     ins_owned,
		"is_affordable": not ins_owned and _pm.resources >= ins_cost,
	})

	## Armory Expansion — 2 tiers
	var arm_tier: int  = _pm.get_upgrade_tier("armory_expansion")
	var arm_max:  bool = arm_tier >= 2
	var arm_next: String = "armory_expansion_%d" % (arm_tier + 1)
	var arm_cost: int  = ProgressionManager.UPGRADE_COSTS.get(arm_next, 0)
	result.append({
		"name":         "ARMORY EXPANSION",
		"tier_text":    "TIER %d / 2" % arm_tier,
		"cost_text":    "---" if arm_max else "%d RES" % arm_cost,
		"upgrade_id":   arm_next,
		"is_maxed":     arm_max,
		"is_affordable": not arm_max and _pm.resources >= arm_cost,
	})

	## Channel Accelerator — 3 tiers
	var ch_tier: int  = _pm.get_upgrade_tier("channel_accelerator")
	var ch_max:  bool = ch_tier >= 3
	var ch_next: String = "channel_accelerator_%d" % (ch_tier + 1)
	var ch_cost: int  = ProgressionManager.UPGRADE_COSTS.get(ch_next, 0)
	result.append({
		"name":         "CHANNEL ACCELERATOR",
		"tier_text":    "TIER %d / 3" % ch_tier,
		"cost_text":    "---" if ch_max else "%d RES" % ch_cost,
		"upgrade_id":   ch_next,
		"is_maxed":     ch_max,
		"is_affordable": not ch_max and _pm.resources >= ch_cost,
	})

	## Reroll Capacity — 2 tiers
	var rc_tier: int  = _pm.get_upgrade_tier("reroll_capacity")
	var rc_max:  bool = rc_tier >= 2
	var rc_next: String = "reroll_capacity_%d" % (rc_tier + 1)
	var rc_cost: int  = ProgressionManager.UPGRADE_COSTS.get(rc_next, 0)
	result.append({
		"name":         "REROLL CAPACITY",
		"tier_text":    "TIER %d / 2" % rc_tier,
		"cost_text":    "---" if rc_max else "%d RES" % rc_cost,
		"upgrade_id":   rc_next,
		"is_maxed":     rc_max,
		"is_affordable": not rc_max and _pm.resources >= rc_cost,
	})

	## Extraction Intel I — single purchase
	var intel_cost:  int  = ProgressionManager.UPGRADE_COSTS.get("extraction_intel_1", 0)
	var intel_owned: bool = _pm.has_upgrade("extraction_intel_1")
	result.append({
		"name":         "EXTRACTION INTEL I",
		"tier_text":    "OWNED" if intel_owned else "SINGLE PURCHASE",
		"cost_text":    "---" if intel_owned else "%d RES" % intel_cost,
		"upgrade_id":   "extraction_intel_1",
		"is_maxed":     intel_owned,
		"is_affordable": not intel_owned and _pm.resources >= intel_cost,
	})

	return result


## ── Card builder ─────────────────────────────────────────────────────────────

func _build_upgrade_card(parent: Control, udata: Dictionary) -> void:
	var is_purchasable: bool = udata.get("is_affordable", false)
	var is_maxed:       bool = udata.get("is_maxed",      false)

	## Card panel
	var card := Panel.new()
	card.custom_minimum_size   = Vector2(0, 44)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cs := StyleBoxFlat.new()
	cs.bg_color            = C_CARD
	cs.border_color        = C_BORDER
	cs.border_width_left   = 1
	cs.border_width_top    = 1
	cs.border_width_right  = 1
	cs.border_width_bottom = 1
	cs.set_content_margin_all(0)
	card.add_theme_stylebox_override("panel", cs)
	parent.add_child(card)

	## Layout: [3px strip | content]
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	card.add_child(row)

	## Left amber/border strip
	var strip := ColorRect.new()
	strip.custom_minimum_size = Vector2(3, 0)
	strip.color = C_AMBER if is_purchasable else C_BORDER
	row.add_child(strip)

	## Inner margin
	var cm := MarginContainer.new()
	cm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cm.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	cm.add_theme_constant_override("margin_left",   6)
	cm.add_theme_constant_override("margin_top",    5)
	cm.add_theme_constant_override("margin_right",  6)
	cm.add_theme_constant_override("margin_bottom", 5)
	row.add_child(cm)

	## Content HBox: [left info | right action]
	var content := HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	cm.add_child(content)

	## Left VBox: upgrade name + tier badge
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	lv.add_theme_constant_override("separation", 2)
	content.add_child(lv)

	_lbl(lv, udata.get("name", ""),      FS_MD, C_T0)
	_lbl(lv, udata.get("tier_text", ""), FS_XS, C_T2)

	## Right VBox: cost label + button
	var rv := VBoxContainer.new()
	rv.size_flags_horizontal = Control.SIZE_SHRINK_END
	rv.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	rv.add_theme_constant_override("separation", 2)
	content.add_child(rv)

	_lbl(rv, udata.get("cost_text", ""), FS_XS, C_T2)

	var btn := Button.new()
	btn.focus_mode          = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(52, 0)
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", FS_XS)

	if is_maxed:
		btn.text     = "MAXED"
		btn.disabled = true
		btn.add_theme_color_override("font_color", C_GREEN_HI)
		_style_btn_flat(btn, Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	elif is_purchasable:
		btn.text     = "BUY"
		btn.disabled = false
		btn.add_theme_color_override("font_color",       C_AMBER)
		btn.add_theme_color_override("font_hover_color", C_AMBER_HI)
		_style_btn_flat(btn, Color(0, 0, 0, 0), C_AMBER_LO)
		var cap_id: String = udata.get("upgrade_id", "")
		btn.pressed.connect(func():
			if _pm.purchase_upgrade(cap_id):
				populate(_pm)
		)
	else:
		btn.text     = "LOCKED"
		btn.disabled = true
		btn.add_theme_color_override("font_color", C_T2)
		_style_btn_flat(btn, Color(0, 0, 0, 0), Color(0, 0, 0, 0))

	rv.add_child(btn)


## ── Footer ───────────────────────────────────────────────────────────────────

func _build_footer(parent: Control) -> void:
	var sep := ColorRect.new()
	sep.custom_minimum_size   = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sep.color                 = C_BORDER
	parent.add_child(sep)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.custom_minimum_size = Vector2(0, 18)
	parent.add_child(hbox)

	var res_text  := "—"
	var tier_text := "—"
	if not Engine.is_editor_hint() and _pm != null:
		res_text = "%d RES REMAINING" % _pm.resources
		var tier_labels: Array[String] = ["BARE", "TORCHES LIT", "RESTORED"]
		tier_text = "HUB: %s" % tier_labels[_pm.get_hub_tier()]

	_lbl(hbox, res_text, FS_SM, C_T1)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_lbl(hbox, tier_text, FS_XS, C_T2)


## ── Style helpers ────────────────────────────────────────────────────────────

func _lbl(parent: Control, text: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(l)
	return l


func _style_btn_flat(btn: Button, normal_bg: Color, hover_bg: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = hover_bg if state in ["hover", "pressed"] else normal_bg
		sb.set_border_width_all(0)
		sb.set_content_margin_all(2)
		btn.add_theme_stylebox_override(state, sb)
