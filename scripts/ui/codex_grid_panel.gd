@tool
class_name CodexGridPanel
extends Control

## Codex Grid Panel — Armory overlay showing the mod combo discovery matrix.
## Pure view layer: reads from CodexManager, emits signals, never writes game logic.

const PIXEL_FONT := preload("res://assets/fonts/m5x7.ttf")

signal close_requested
## Emitted when cursor enters a combo row — armory uses this for reactive preview.
signal entry_hovered(combo_id: StringName)

# ── Color palette ─────────────────────────────────────────────────────────────
const COL_BG         := Color(0.04, 0.05, 0.08, 0.97)
const COL_BORDER     := Color(0.45, 0.25, 0.80, 1.0)
const COL_TITLE      := Color(0.72, 0.52, 0.98, 1.0)
const COL_DIM        := Color(0.40, 0.40, 0.45)
const COL_BODY       := Color(0.78, 0.78, 0.84)
const COL_UNKNOWN    := Color(0.28, 0.28, 0.32)
const COL_DISCOVERED := Color(0.60, 0.60, 0.68)
const COL_REVEALED   := Color(0.88, 0.88, 0.95)
const COL_MASTERED   := Color(0.95, 0.78, 0.22)

const TYPE_COLORS := {
	ModCombo.ComboType.BEHAVIOR_BEHAVIOR:   Color(0.35, 0.75, 1.0),
	ModCombo.ComboType.BEHAVIOR_ELEMENTAL:  Color(0.45, 0.90, 0.50),
	ModCombo.ComboType.ELEMENTAL_ELEMENTAL: Color(1.0, 0.58, 0.22),
	ModCombo.ComboType.STAT_INTERACTION:    Color(0.78, 0.55, 1.0),
	ModCombo.ComboType.TRIPLE_LEGENDARY:    Color(0.95, 0.78, 0.22),
}

const TYPE_NAMES := {
	ModCombo.ComboType.BEHAVIOR_BEHAVIOR:   "BEH \u00d7 BEH",
	ModCombo.ComboType.BEHAVIOR_ELEMENTAL:  "BEH \u00d7 ELE",
	ModCombo.ComboType.ELEMENTAL_ELEMENTAL: "ELE \u00d7 ELE",
	ModCombo.ComboType.STAT_INTERACTION:    "STAT",
	ModCombo.ComboType.TRIPLE_LEGENDARY:    "TRIPLE \u2605",
}

const TYPE_NAMES_LONG := {
	ModCombo.ComboType.BEHAVIOR_BEHAVIOR:   "BEHAVIOR \u00d7 BEHAVIOR",
	ModCombo.ComboType.BEHAVIOR_ELEMENTAL:  "BEHAVIOR \u00d7 ELEMENTAL",
	ModCombo.ComboType.ELEMENTAL_ELEMENTAL: "ELEMENTAL \u00d7 ELEMENTAL",
	ModCombo.ComboType.STAT_INTERACTION:    "STAT INTERACTION",
	ModCombo.ComboType.TRIPLE_LEGENDARY:    "LEGENDARY TRIPLE",
}

# ── State ─────────────────────────────────────────────────────────────────────
var _filter:       String    = "all"   # all / discovered / undiscovered / mastered
var _sort:         String    = "type"  # type / alpha / mastery
var _selected_id:  StringName = ""
var _highlight_id: StringName = ""     # set by armory for reactive mod hover preview

# Built UI node refs
var _counter_label:        Label
var _list_vbox:            VBoxContainer
var _detail_type_badge:    Label
var _detail_name:          Label
var _detail_state:         Label
var _detail_mods:          Label
var _detail_sep:           ColorRect
var _detail_desc:          Label
var _detail_prog_bg:       ColorRect
var _detail_prog_fill:     ColorRect
var _detail_prog_label:    Label
var _detail_mastery_bonus: Label
var _filter_btns:          Dictionary = {}
var _sort_btns:            Dictionary = {}
var _entry_rows:           Dictionary = {}  # combo_id → Control


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_build_ui()
	_refresh()
	CodexManager.combo_discovered.connect(_on_codex_event)
	CodexManager.combo_revealed.connect(_on_codex_event)
	CodexManager.combo_mastered.connect(_on_codex_event)


## Called by armory to highlight a cell during mod-hover preview.
func set_hover_highlight(combo_id: StringName) -> void:
	_highlight_id = combo_id
	_refresh_list()


# ── UI Construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Outer dark panel
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COL_BG
	panel_style.set_border_width_all(1)
	panel_style.border_color = COL_BORDER
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	# Title bar strip
	var title_bar := ColorRect.new()
	title_bar.color = Color(COL_BORDER.r * 0.28, COL_BORDER.g * 0.14, COL_BORDER.b * 0.38)
	title_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_bar.size.y = 22.0
	add_child(title_bar)

	# "CODEX" heading
	var title_lbl := _make_label("CODEX", 10, 4, COL_TITLE, 16)
	add_child(title_lbl)

	# Completion counter (centered in title bar)
	_counter_label = _make_label("", 0, 6, COL_DIM, 11)
	_counter_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter_label.size.y = 14.0
	add_child(_counter_label)

	# Close button
	var close_btn := _make_button("\u00d7", -22, 3, 18, 16)
	close_btn.set_anchor(SIDE_LEFT, 1.0)
	close_btn.set_anchor(SIDE_RIGHT, 1.0)
	close_btn.offset_left = -22.0
	close_btn.offset_right = -2.0
	close_btn.offset_top = 3.0
	close_btn.offset_bottom = 19.0
	close_btn.add_theme_color_override("font_color", COL_DIM)
	_style_btn_flat(close_btn, Color.TRANSPARENT, Color(0.55, 0.08, 0.08, 0.55))
	close_btn.pressed.connect(func(): close_requested.emit())
	add_child(close_btn)

	# ── Filter row ────────────────────────────────────────────────────────────
	var filter_y: float = 25.0
	var filter_defs: Array = [
		["all",           "ALL"],
		["discovered",    "FOUND"],
		["undiscovered",  "UNKNOWN"],
		["mastered",      "MASTERED"],
	]
	var fx: float = 4.0
	for def in filter_defs:
		var key: String = def[0]
		var btn := _make_button(def[1], fx, filter_y, 108, 14)
		btn.add_theme_font_size_override("font_size", 13)
		_style_btn_flat(btn, Color.TRANSPARENT, Color(0.28, 0.18, 0.48, 0.55))
		btn.pressed.connect(func():
			_filter = key
			_refresh_filter_styles()
			_refresh_list()
		)
		_filter_btns[key] = btn
		add_child(btn)
		fx += 110.0

	# ── Sort row ──────────────────────────────────────────────────────────────
	var sort_y: float = 40.0
	var sort_defs: Array = [
		["type",   "BY TYPE"],
		["alpha",  "A \u2013 Z"],
		["mastery","MASTERY %"],
	]
	var sx: float = 4.0
	for def in sort_defs:
		var key: String = def[0]
		var btn := _make_button(def[1], sx, sort_y, 88, 12)
		btn.add_theme_font_size_override("font_size", 12)
		_style_btn_flat(btn, Color.TRANSPARENT, Color(0.20, 0.14, 0.32, 0.40))
		btn.pressed.connect(func():
			_sort = key
			_refresh_sort_styles()
			_refresh_list()
		)
		_sort_btns[key] = btn
		add_child(btn)
		sx += 90.0

	# Top-content divider
	var hdiv := ColorRect.new()
	hdiv.color = Color(COL_BORDER.r, COL_BORDER.g, COL_BORDER.b, 0.30)
	hdiv.set_anchor(SIDE_LEFT,  0.0); hdiv.set_anchor(SIDE_RIGHT, 1.0)
	hdiv.offset_top = 54.0; hdiv.offset_bottom = 55.0
	add_child(hdiv)

	# ── Left: scrollable combo list ───────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(2, 56)
	scroll.set_anchor(SIDE_BOTTOM, 1.0)
	scroll.offset_bottom = -2.0
	scroll.size.x = 182.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 1)
	scroll.add_child(_list_vbox)

	# Vertical separator between list and detail
	var vsep := ColorRect.new()
	vsep.color = Color(COL_BORDER.r, COL_BORDER.g, COL_BORDER.b, 0.30)
	vsep.position = Vector2(185.0, 56.0)
	vsep.set_anchor(SIDE_BOTTOM, 1.0)
	vsep.size.x = 1.0
	vsep.offset_bottom = -2.0
	add_child(vsep)

	# ── Right: detail panel ───────────────────────────────────────────────────
	var dx: float = 190.0
	var dy: float = 60.0
	var dw: float = 280.0

	_detail_type_badge = _make_label("", dx, dy, COL_DIM, 9)
	_detail_type_badge.size.x = dw
	add_child(_detail_type_badge)
	dy += 13.0

	_detail_name = _make_label("\u2014 select a combo \u2014", dx, dy, COL_DIM, 14)
	_detail_name.size.x = dw
	add_child(_detail_name)
	dy += 20.0

	_detail_state = _make_label("", dx, dy, COL_DIM, 10)
	_detail_state.size.x = dw
	add_child(_detail_state)
	dy += 14.0

	_detail_mods = _make_label("", dx, dy, COL_DIM, 10)
	_detail_mods.size.x = dw
	add_child(_detail_mods)
	dy += 18.0

	_detail_sep = ColorRect.new()
	_detail_sep.color = Color(0.28, 0.28, 0.35, 0.40)
	_detail_sep.position = Vector2(dx, dy)
	_detail_sep.size = Vector2(dw, 1.0)
	add_child(_detail_sep)
	dy += 6.0

	_detail_desc = _make_label("", dx, dy, COL_BODY, 11)
	_detail_desc.size = Vector2(dw, 90.0)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_detail_desc)
	dy += 96.0

	# Mastery progress bar
	_detail_prog_bg = ColorRect.new()
	_detail_prog_bg.color = Color(0.14, 0.14, 0.18)
	_detail_prog_bg.position = Vector2(dx, dy)
	_detail_prog_bg.size = Vector2(dw, 7.0)
	_detail_prog_bg.visible = false
	add_child(_detail_prog_bg)

	_detail_prog_fill = ColorRect.new()
	_detail_prog_fill.color = COL_MASTERED
	_detail_prog_fill.position = Vector2(dx, dy)
	_detail_prog_fill.size = Vector2(0.0, 7.0)
	_detail_prog_fill.visible = false
	add_child(_detail_prog_fill)
	dy += 9.0

	_detail_prog_label = _make_label("", dx, dy, COL_DIM, 9)
	_detail_prog_label.size.x = dw
	_detail_prog_label.visible = false
	add_child(_detail_prog_label)
	dy += 14.0

	_detail_mastery_bonus = _make_label("", dx, dy, COL_MASTERED, 10)
	_detail_mastery_bonus.size = Vector2(dw, 28.0)
	_detail_mastery_bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_mastery_bonus.visible = false
	add_child(_detail_mastery_bonus)

	_refresh_filter_styles()
	_refresh_sort_styles()


# ── Refresh ───────────────────────────────────────────────────────────────────

func _refresh() -> void:
	_refresh_counter()
	_refresh_list()
	_refresh_detail()


func _refresh_counter() -> void:
	var total   := CodexManager.entries.size()
	var found   := 0
	for entry in CodexManager.entries.values():
		if entry.discovered:
			found += 1
	_counter_label.text = "%d / %d Combos Discovered" % [found, total]


func _refresh_list() -> void:
	for child in _list_vbox.get_children():
		child.queue_free()
	_entry_rows.clear()

	for entry: CodexEntry in _get_filtered_sorted():
		var row := _build_list_row(entry)
		_list_vbox.add_child(row)
		_entry_rows[entry.combo.combo_id] = row


func _get_filtered_sorted() -> Array:
	var result: Array = []
	for entry in CodexManager.entries.values():
		match _filter:
			"discovered":   if not entry.discovered:    continue
			"undiscovered": if entry.discovered:         continue
			"mastered":     if not entry.is_mastered():  continue
		result.append(entry)

	match _sort:
		"type":
			result.sort_custom(func(a: CodexEntry, b: CodexEntry) -> bool:
				if a.combo.combo_type != b.combo.combo_type:
					return a.combo.combo_type < b.combo.combo_type
				return a.combo.combo_name < b.combo.combo_name
			)
		"alpha":
			result.sort_custom(func(a: CodexEntry, b: CodexEntry) -> bool:
				return a.combo.combo_name < b.combo.combo_name
			)
		"mastery":
			result.sort_custom(func(a: CodexEntry, b: CodexEntry) -> bool:
				return a.mastery_progress() > b.mastery_progress()
			)

	return result


func _build_list_row(entry: CodexEntry) -> Control:
	var combo_id   := entry.combo.combo_id
	var is_sel     := combo_id == _selected_id
	var is_hi      := combo_id == _highlight_id
	var type_col: Color = TYPE_COLORS.get(entry.combo.combo_type, COL_DIM)

	var row := Control.new()
	row.custom_minimum_size = Vector2(180.0, 16.0)

	# Row background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	if is_sel:
		bg.color = Color(0.22, 0.14, 0.38, 0.90)
	elif is_hi:
		bg.color = Color(0.38, 0.32, 0.12, 0.55)
	else:
		bg.color = Color.TRANSPARENT
	row.add_child(bg)

	# Type color pip
	var pip := ColorRect.new()
	pip.position = Vector2(2.0, 4.0)
	pip.size     = Vector2(3.0, 8.0)
	pip.color    = type_col if entry.discovered else COL_UNKNOWN
	row.add_child(pip)

	# Combo name label
	var name_lbl := Label.new()
	name_lbl.add_theme_font_override("font", PIXEL_FONT)
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.position = Vector2(8.0, 2.0)
	name_lbl.size     = Vector2(146.0, 13.0)
	name_lbl.clip_text = true

	if not entry.discovered:
		if is_hi:
			# Pulse hint: "there's something here"
			name_lbl.text = "?  \u25ba discover"
			name_lbl.add_theme_color_override("font_color",
				Color(COL_MASTERED.r, COL_MASTERED.g * 0.7, 0.15, 0.85))
		else:
			name_lbl.text = "???"
			name_lbl.add_theme_color_override("font_color", COL_UNKNOWN)
	elif entry.is_mastered():
		name_lbl.text = entry.combo.combo_name
		name_lbl.add_theme_color_override("font_color", COL_MASTERED)
	elif entry.revealed:
		name_lbl.text = entry.combo.combo_name
		name_lbl.add_theme_color_override("font_color", COL_REVEALED)
	else:
		name_lbl.text = entry.combo.combo_name
		name_lbl.add_theme_color_override("font_color", COL_DISCOVERED)

	row.add_child(name_lbl)

	# Mastery star badge
	if entry.is_mastered():
		var star := Label.new()
		star.add_theme_font_override("font", PIXEL_FONT)
		star.add_theme_font_size_override("font_size", 15)
		star.text = "\u2605"
		star.add_theme_color_override("font_color", COL_MASTERED)
		star.position = Vector2(156.0, 2.0)
		star.size     = Vector2(14.0, 13.0)
		row.add_child(star)

	# Discovered-not-revealed hint
	if entry.discovered and not entry.revealed and not entry.is_mastered():
		var hint := Label.new()
		hint.add_theme_font_override("font", PIXEL_FONT)
		hint.add_theme_font_size_override("font_size", 12)
		hint.text = "???"
		hint.add_theme_color_override("font_color", COL_DIM)
		hint.position = Vector2(156.0, 3.0)
		hint.size     = Vector2(22.0, 12.0)
		row.add_child(hint)

	# Invisible button overlay for click + hover
	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.focus_mode = Control.FOCUS_NONE
	_style_btn_flat(btn, Color.TRANSPARENT, Color(0.28, 0.20, 0.44, 0.45))
	btn.pressed.connect(func():
		_selected_id = combo_id
		_refresh_list()
		_refresh_detail()
	)
	btn.mouse_entered.connect(func(): entry_hovered.emit(combo_id))
	row.add_child(btn)

	return row


func _refresh_detail() -> void:
	if _selected_id.is_empty() or _selected_id not in CodexManager.entries:
		_detail_type_badge.text    = ""
		_detail_name.text          = "\u2014 select a combo \u2014"
		_detail_name.add_theme_color_override("font_color", COL_DIM)
		_detail_state.text         = ""
		_detail_mods.text          = ""
		_detail_desc.text          = ""
		_detail_prog_bg.visible    = false
		_detail_prog_fill.visible  = false
		_detail_prog_label.visible = false
		_detail_mastery_bonus.visible = false
		return

	var entry: CodexEntry = CodexManager.entries[_selected_id]
	var combo := entry.combo
	var type_col: Color = TYPE_COLORS.get(combo.combo_type, COL_DIM)

	# Type badge
	_detail_type_badge.text = TYPE_NAMES_LONG.get(combo.combo_type, "COMBO")
	_detail_type_badge.add_theme_color_override("font_color", type_col)

	# Name
	if not entry.discovered:
		_detail_name.text = "UNDISCOVERED"
		_detail_name.add_theme_color_override("font_color", COL_UNKNOWN)
	elif entry.is_mastered():
		_detail_name.text = combo.combo_name
		_detail_name.add_theme_color_override("font_color", COL_MASTERED)
	elif entry.revealed:
		_detail_name.text = combo.combo_name
		_detail_name.add_theme_color_override("font_color", COL_REVEALED)
	else:
		_detail_name.text = combo.combo_name
		_detail_name.add_theme_color_override("font_color", COL_DISCOVERED)

	# State label
	if not entry.discovered:
		_detail_state.text = "[ UNKNOWN \u2014 slot this mod pair in the armory ]"
		_detail_state.add_theme_color_override("font_color", COL_UNKNOWN)
	elif not entry.revealed:
		_detail_state.text = "[ DISCOVERED \u2014 trigger in a run to reveal ]"
		_detail_state.add_theme_color_override("font_color", COL_DISCOVERED)
	elif entry.is_mastered():
		_detail_state.text = "[ MASTERED ]"
		_detail_state.add_theme_color_override("font_color", COL_MASTERED)
	else:
		_detail_state.text = "[ REVEALED ]"
		_detail_state.add_theme_color_override("font_color", COL_REVEALED)

	# Required mods
	var mod_names: Array[String] = []
	for mod_id: StringName in combo.required_mods:
		var mod_data: Dictionary = ModData.ALL.get(str(mod_id), {})
		mod_names.append(mod_data.get("name", str(mod_id)))
	_detail_mods.text = "Requires: " + " + ".join(mod_names)
	_detail_mods.add_theme_color_override("font_color", COL_DIM)

	# Description
	if entry.revealed:
		_detail_desc.text = combo.description
		_detail_desc.add_theme_color_override("font_color", COL_BODY)
	else:
		_detail_desc.text = "???"
		_detail_desc.add_theme_color_override("font_color", COL_UNKNOWN)

	# Progress bar
	var show_progress := entry.discovered
	_detail_prog_bg.visible    = show_progress
	_detail_prog_fill.visible  = show_progress
	_detail_prog_label.visible = show_progress

	if show_progress:
		var prog := entry.mastery_progress()
		var bar_w: float = _detail_prog_bg.size.x
		_detail_prog_fill.size.x = prog * bar_w
		_detail_prog_fill.color  = (
			COL_MASTERED if entry.is_mastered()
			else type_col.lerp(COL_MASTERED, prog * 0.6)
		)
		_detail_prog_label.text = "%d / %d triggers  (%d%%)" % [
			entry.times_triggered, entry.mastery_threshold,
			int(prog * 100.0)
		]

	# Mastery bonus
	_detail_mastery_bonus.visible = entry.is_mastered()
	if entry.is_mastered():
		_detail_mastery_bonus.text = "\u2605 MASTERY BONUS: " + entry.mastery_bonus_description


func _refresh_filter_styles() -> void:
	for key in _filter_btns:
		var btn: Button = _filter_btns[key]
		var active: bool = key == _filter
		btn.add_theme_color_override("font_color", COL_TITLE if active else COL_DIM)
		_style_btn_flat(
			btn,
			Color(0.22, 0.12, 0.42, 0.75) if active else Color.TRANSPARENT,
			Color(0.28, 0.18, 0.48, 0.55)
		)


func _refresh_sort_styles() -> void:
	for key in _sort_btns:
		var btn: Button = _sort_btns[key]
		var active: bool = key == _sort
		btn.add_theme_color_override("font_color", COL_TITLE if active else COL_DIM)


# ── Event handlers ────────────────────────────────────────────────────────────

func _on_codex_event(combo_id: StringName) -> void:
	_refresh_counter()
	_refresh_list()
	# Flash the updated row if it exists
	if combo_id in _entry_rows:
		_flash_row(_entry_rows[combo_id])
	# Refresh detail if it's the selected combo
	if combo_id == _selected_id:
		_refresh_detail()


func _flash_row(row: Control) -> void:
	var tween := create_tween()
	tween.tween_property(row, "modulate", Color(2.2, 1.8, 0.4, 1.0), 0.0)
	tween.tween_property(row, "modulate", Color.WHITE, 0.50).set_ease(Tween.EASE_OUT)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_label(text: String, x: float, y: float,
		col: Color, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text     = text
	lbl.position = Vector2(x, y)
	lbl.add_theme_font_override("font", PIXEL_FONT)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", col)
	return lbl


func _make_button(text: String, x: float, y: float,
		w: float, h: float) -> Button:
	var btn := Button.new()
	btn.text     = text
	btn.position = Vector2(x, y)
	btn.size     = Vector2(w, h)
	btn.add_theme_font_override("font", PIXEL_FONT)
	btn.add_theme_font_size_override("font_size", 15)
	btn.focus_mode = Control.FOCUS_NONE
	return btn


func _style_btn_flat(btn: Button, normal_col: Color, hover_col: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = hover_col if state in ["hover", "pressed"] else normal_col
		sb.set_border_width_all(0)
		sb.set_content_margin_all(2)
		btn.add_theme_stylebox_override(state, sb)
