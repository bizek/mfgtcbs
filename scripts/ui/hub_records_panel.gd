@tool
extends Control

## Records panel — lifetime stat display + achievements sub-tab, dark industrial redesign.

signal close_requested

@onready var _base:    HubPanelBase = $PanelBase
@onready var _content: Control      = $PanelBase/ContentContainer

const C_BORDER := Color(0.165, 0.145, 0.125)
const C_AMBER  := Color(0.831, 0.447, 0.102)
const C_T0     := Color(0.800, 0.690, 0.565)
const C_T2     := Color(0.314, 0.235, 0.157)
const C_LOCKED := Color(0.42, 0.40, 0.44)
const C_DESC   := Color(0.55, 0.53, 0.58)

const FS_MD := 16
const FS_SM := 16
const FS_XS := 16

var _stats_btn:  Button
var _achv_btn:   Button
var _stats_page: VBoxContainer
var _achv_page:  ScrollContainer
var _active_tab: String = "stats"

const ACHV_SCROLL_SPEED: float = 220.0  ## px/s — rows are Labels (nothing
## focusable), so D-pad/stick scrolls the list directly instead of via focus.

func _ready() -> void:
	_base.close_requested.connect(func(): close_requested.emit())
	if Engine.is_editor_hint():
		return
	## No populate() here — hub._open_panel() calls it the moment it adds us to the tree,
	## so a self-populate built the whole panel TWICE on every open. (Ben 2026-07-30.)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree():
		return
	if _achv_page == null or not is_instance_valid(_achv_page) or not _achv_page.visible:
		return
	var dir: float = Input.get_axis("ui_up", "ui_down")
	if dir != 0.0:
		_achv_page.scroll_vertical += int(dir * ACHV_SCROLL_SPEED * delta)


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

	## ── Tab strip
	var tab_row := HBoxContainer.new()
	tab_row.custom_minimum_size = Vector2(0, 20)
	tab_row.add_theme_constant_override("separation", 6)
	vbox.add_child(tab_row)

	_stats_btn = _tab_button(tab_row, "STATS", "stats")
	_achv_btn  = _tab_button(tab_row, "ACHIEVEMENTS", "achievements")

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 5)
	vbox.add_child(gap2)

	## ── Pages
	var pages := Control.new()
	pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.add_child(pages)

	_stats_page = _build_stats_page(pm)
	_stats_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	pages.add_child(_stats_page)

	_achv_page = _build_achievements_page()
	_achv_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	pages.add_child(_achv_page)

	_set_tab("stats")


func _tab_button(parent: Control, text: String, tab_id: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", FS_XS)
	btn.custom_minimum_size = Vector2(0, 20)
	btn.focus_mode = Control.FOCUS_ALL
	_base.style_btn(btn, Color(0.10, 0.09, 0.08), Color(C_AMBER.r, C_AMBER.g, C_AMBER.b, 0.22), 8)
	btn.pressed.connect(func(): _set_tab(tab_id))
	parent.add_child(btn)
	return btn


func _set_tab(tab_id: String) -> void:
	_active_tab = tab_id
	_stats_page.visible = tab_id == "stats"
	_achv_page.visible  = tab_id == "achievements"
	_stats_btn.add_theme_color_override("font_color", C_T0 if tab_id == "stats" else C_T2)
	_achv_btn.add_theme_color_override("font_color",  C_T0 if tab_id == "achievements" else C_T2)


func _build_stats_page(pm: Node) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_theme_constant_override("separation", 0)

	var total_runs: int  = 0 if pm == null else pm.total_runs
	var extractions: int = 0 if pm == null else pm.successful_extractions
	var rate_str: String
	if pm == null or total_runs == 0:
		rate_str = "-"
	else:
		rate_str = "%d%%" % int(float(extractions) / float(total_runs) * 100.0)

	var rows: Array[Array] = [
		["Total Runs",             str(total_runs)],
		["Successful Extractions", str(extractions)],
		["Deaths",                 str(0 if pm == null else pm.deaths)],
		["Total Kills",            str(0 if pm == null else pm.total_kills)],
		["Deepest Phase",          str(0 if pm == null else pm.deepest_phase)],
		["Biggest Haul",           str(0 if pm == null else int(pm.most_loot_extracted))],
		["Extraction Rate",        rate_str],
	]

	for i in rows.size():
		var row := HBoxContainer.new()
		row.mouse_filter          = Control.MOUSE_FILTER_IGNORE
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size   = Vector2(0, 22)
		row.add_theme_constant_override("separation", 4)
		page.add_child(row)

		var stat_lbl := _lbl(row, rows[i][0], FS_XS, C_T2)
		stat_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		_lbl(row, rows[i][1], FS_MD, C_T0)

		if i < rows.size() - 1:
			var rule := ColorRect.new()
			rule.custom_minimum_size   = Vector2(0, 1)
			rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rule.color                 = C_BORDER
			page.add_child(rule)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(spacer)

	return page


func _build_achievements_page() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)

	for i in AchievementData.ORDER.size():
		var id: String = AchievementData.ORDER[i]
		_add_achievement_row(list, id)
		if i < AchievementData.ORDER.size() - 1:
			var rule := ColorRect.new()
			rule.custom_minimum_size = Vector2(0, 1)
			rule.color = C_BORDER
			list.add_child(rule)

	return scroll


func _add_achievement_row(parent: Control, id: String) -> void:
	var def: Dictionary = AchievementData.ALL.get(id, {})
	var unlocked: bool = AchievementManager.is_unlocked(id)
	var secret: bool = def.get("secret", false) and not unlocked

	var row := HBoxContainer.new()
	row.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0, 36)
	row.add_theme_constant_override("separation", 8)
	if not unlocked:
		row.modulate = Color(1.0, 1.0, 1.0, 0.55)
	parent.add_child(row)

	var icon_col: Color = def.get("color", C_T0) if unlocked else C_LOCKED
	var icon_lbl := _lbl(row, str(def.get("icon", "?")), 18, icon_col)
	icon_lbl.custom_minimum_size = Vector2(22, 0)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 1)
	row.add_child(text_col)

	var title_text: String = str(def.get("title", id)) if not secret else "???"
	_lbl(text_col, title_text, FS_XS, C_T0 if unlocked else C_T2)

	var desc_text: String = "???" if secret else str(def.get("description", ""))
	var desc_lbl := _lbl(text_col, desc_text, 12, C_DESC)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if unlocked:
		var check := _lbl(row, "✓", FS_XS, Color(0.4, 0.85, 0.55))
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	elif def.get("kind", "") == "threshold":
		var progress: Vector2 = AchievementManager.get_progress(id)
		var prog_lbl := _lbl(row, "%d/%d" % [int(progress.x), int(progress.y)], 12, C_LOCKED)
		prog_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _lbl(parent: Control, text: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(l)
	return l
