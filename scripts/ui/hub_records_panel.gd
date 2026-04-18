@tool
extends Control

## Records panel — lifetime stat display, dark industrial redesign.

signal close_requested

@onready var _base:    HubPanelBase = $PanelBase
@onready var _content: Control      = $PanelBase/ContentContainer

const C_BORDER := Color(0.165, 0.145, 0.125)
const C_AMBER  := Color(0.831, 0.447, 0.102)
const C_T0     := Color(0.800, 0.690, 0.565)
const C_T2     := Color(0.314, 0.235, 0.157)

const FONT  := HubPanelBase.PIXEL_FONT
const FS_MD := 19
const FS_SM := 16
const FS_XS := 13

func _ready() -> void:
	_base.close_requested.connect(func(): close_requested.emit())
	if Engine.is_editor_hint():
		return
	populate(ProgressionManager)


func populate(pm: Node) -> void:
	for child in _content.get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_top",    33)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_bottom",  8)
	_content.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 0)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	## ── Section header
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 5)
	hdr.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(hdr)

	_lbl(hdr, "MISSION RECORDS", FS_SM, C_T2)

	var hdr_rule := ColorRect.new()
	hdr_rule.custom_minimum_size   = Vector2(0, 1)
	hdr_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_rule.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	hdr_rule.color                 = C_BORDER
	hdr.add_child(hdr_rule)

	## Amber accent rule
	var accent := ColorRect.new()
	accent.custom_minimum_size   = Vector2(0, 1)
	accent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accent.color                 = Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.40)
	vbox.add_child(accent)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 5)
	vbox.add_child(gap)

	## ── Stat rows
	var total_runs: int  = 0 if pm == null else pm.total_runs
	var extractions: int = 0 if pm == null else pm.successful_extractions
	var rate_str: String
	if pm == null or total_runs == 0:
		rate_str = "\u2014"
	else:
		rate_str = "%d%%" % int(float(extractions) / float(total_runs) * 100.0)

	var rows: Array[Array] = [
		["Total Runs",             str(total_runs)],
		["Successful Extractions", str(extractions)],
		["Deaths",                 str(0 if pm == null else pm.deaths)],
		["Total Kills",            str(0 if pm == null else pm.total_kills)],
		["Deepest Phase",          str(0 if pm == null else pm.deepest_phase)],
		["Most Loot",              str(0 if pm == null else int(pm.most_loot_extracted))],
		["Extraction Rate",        rate_str],
	]

	for i in rows.size():
		var row := HBoxContainer.new()
		row.mouse_filter          = Control.MOUSE_FILTER_IGNORE
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size   = Vector2(0, 22)
		row.add_theme_constant_override("separation", 4)
		vbox.add_child(row)

		var stat_lbl := _lbl(row, rows[i][0], FS_XS, C_T2)
		stat_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		_lbl(row, rows[i][1], FS_MD, C_T0)

		if i < rows.size() - 1:
			var rule := ColorRect.new()
			rule.custom_minimum_size   = Vector2(0, 1)
			rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rule.color                 = C_BORDER
			vbox.add_child(rule)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)


func _lbl(parent: Control, text: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(l)
	return l
