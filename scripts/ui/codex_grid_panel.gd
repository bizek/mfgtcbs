@tool
class_name CodexGridPanel
extends Control

## Codex Grid Panel — Armory overlay showing the mod combo discovery matrix.
## Pure view layer: reads from CodexManager, emits signals, never writes game logic.


signal close_requested
## Emitted when cursor enters a combo row — armory uses this for reactive preview.
signal entry_hovered(combo_id: StringName)

## Preloaded under a local alias rather than the bare class_name — see hub_roster_panel.gd.
const Icons := preload("res://scripts/ui/ui_icons.gd")

# ── Layout ────────────────────────────────────────────────────────────────────
## The panel now wears the theme's R1 plate, whose frame art is 9px thick, so nothing may sit
## flush against an edge any more.
const PAD:      float = 10.0
const ROW_H:    float = 16.0
const LIST_W:   float = 178.0

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

## Grid-frame line colours — the sheet's WHITE tint put through a modulate. Selection and the
## armory's hover preview light the SAME frame up rather than swapping in a different look, which
## is what makes a 69-row list read as one grid instead of three.
const CELL_IDLE      := Color(0.60, 0.58, 0.66, 0.24)
const CELL_SELECTED  := Color(0.72, 0.52, 0.98, 0.95)
const CELL_HIGHLIGHT := Color(0.95, 0.78, 0.22, 0.85)
const RULE_COL       := Color(0.55, 0.42, 0.78, 0.60)
const FRAME_COL      := Color(0.52, 0.46, 0.64, 0.45)

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
var _detail_new:           Control       # NEW ribbon beside the selected combo's name
var _detail_state:         HBoxContainer # state tag + its one-line instruction
var _detail_state_hint:    Label
var _detail_mods:          Label
var _detail_sep:           Control
var _detail_desc:          Label
var _detail_prog_row:      Control
var _detail_prog_bg:       ColorRect
var _detail_prog_fill:     ColorRect
var _detail_prog_label:    Label
var _detail_mastery_bonus: Label
var _filter_btns:          Dictionary = {}
var _sort_btns:            Dictionary = {}
var _entry_rows:           Dictionary = {}  # combo_id → Control
## Guards the mark-seen-on-close hook against the hide that happens while the armory builds this.
var _shown:                bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_build_ui()
	_refresh()
	CodexManager.combo_discovered.connect(_on_codex_event)
	CodexManager.combo_revealed.connect(_on_codex_event)
	CodexManager.combo_mastered.connect(_on_codex_event)
	## NEW badges last the whole browsing session, not one click: they clear when the codex closes,
	## so a player who opens it to look at one row does not lose the marks on the other four.
	visibility_changed.connect(func():
		if visible:
			_shown = true
			_refresh()
			UINav.focus_first(self)
		elif _shown:
			CodexManager.mark_all_seen()
	)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()


## Called by armory to highlight a cell during mod-hover preview.
func set_hover_highlight(combo_id: StringName) -> void:
	_highlight_id = combo_id
	_refresh_list()


# ── UI Construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	## Opaque backing first \u2014 this is an overlay and has to occlude the armory behind it. The pack
	## plate goes on top of it, so the frame art is what the player sees at the edges.
	var backing := ColorRect.new()
	backing.color = COL_BG
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)

	## The pack's R1 corner-bracket plate, straight off the project theme's default `Panel`. The
	## hand-rolled purple StyleBoxFlat that used to be here was the last of this panel's own boxes.
	##
	## R1 not R0, even though R0 is the tier the pack labels "dense lists and inventory grids": the
	## density here comes from the row cells, and the *shell* is a modal sitting on top of the
	## armory's own R1 plate \u2014 dropping it to the plainest tier would make the thing in front read
	## as less important than the thing behind it.
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	## Everything from here down is laid out by CONTAINERS rather than hand-accumulated pixel
	## offsets. The old fixed rows (filter at y=25, sort at y=40, 15px apart) only ever fitted
	## because their labels were 9-14px; at m5x7's native 16 a button is ~23 tall and those two
	## rows overlap each other.
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for name in ["left", "top", "right", "bottom"]:
		root.add_theme_constant_override("margin_" + name, int(PAD))
	add_child(root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	root.add_child(col)

	# Header: title | completion counter | close
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	col.add_child(header)

	var title_lbl := _detail_label("CODEX", COL_TITLE)
	title_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header.add_child(title_lbl)

	_counter_label = _detail_label("", COL_DIM)
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_counter_label)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.focus_mode = Control.FOCUS_ALL
	close_btn.custom_minimum_size = Vector2(20.0, 0.0)
	close_btn.add_theme_color_override("font_color", COL_DIM)
	_style_btn_flat(close_btn, Color.TRANSPARENT, Color(0.55, 0.08, 0.08, 0.55))
	close_btn.pressed.connect(func(): close_requested.emit())
	header.add_child(close_btn)

	# Filter row
	var filter_defs: Array = [
		["all",           "ALL"],
		["discovered",    "FOUND"],
		["undiscovered",  "UNKNOWN"],
		["mastered",      "MASTERED"],
	]
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 2)
	col.add_child(filter_row)
	for def in filter_defs:
		var key: String = def[0]
		var btn := _row_button(def[1])
		_style_btn_flat(btn, Color.TRANSPARENT, Color(0.28, 0.18, 0.48, 0.55))
		btn.pressed.connect(func():
			_filter = key
			_refresh_filter_styles()
			_refresh_list()
		)
		_filter_btns[key] = btn
		filter_row.add_child(btn)

	# Sort row
	var sort_defs: Array = [
		["type",   "BY TYPE"],
		["alpha",  "A – Z"],
		["mastery","MASTERY %"],
	]
	var sort_row := HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 2)
	col.add_child(sort_row)
	for def in sort_defs:
		var key: String = def[0]
		var btn := _row_button(def[1])
		_style_btn_flat(btn, Color.TRANSPARENT, Color(0.20, 0.14, 0.32, 0.40))
		btn.pressed.connect(func():
			_sort = key
			_refresh_sort_styles()
			_refresh_list()
		)
		_sort_btns[key] = btn
		sort_row.add_child(btn)

	## Top-content divider — the grid sheet's own rule, tiled, in place of a flat ColorRect.
	var hdiv := _rule(true, RULE_COL)
	hdiv.custom_minimum_size = Vector2(0.0, 1.0)
	hdiv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(hdiv)

	# Body: combo list | rule | detail card
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(LIST_W, 0.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## -1, so each row's cell frame SHARES its border with the row above instead of drawing a
	## second line 1px away. That is how the sheet's own 5x5 grid is built: 12px cells on an
	## 11px pitch, borders in common.
	_list_vbox.add_theme_constant_override("separation", -1)
	scroll.add_child(_list_vbox)

	## No vertical rule between the halves: the row cells and the detail card each carry their own
	## frame, and a third line 4px from both just reads as a smudge. The pack's vertical rule is
	## still reachable via `_rule(false, …)` for anywhere that has no frames to lean on.

	## The detail column gets the grid sheet's larger frame, so the two halves read as list-grid
	## and detail-card rather than as text floating loose on a plate.
	##
	## It is a real container stack now instead of a hand-accumulated `dy`, and that is not
	## tidying. Every label in this column was sized 9-14, which is below m5x7's 16px native grid
	## \u2014 at those sizes the glyphs FUSE rather than merely soften (CLAUDE.md's font section). At 16
	## the old fixed offsets overlap each other, and a long description had nowhere to go, so the
	## column is a ScrollContainer on SHOW_AS_NEEDED.
	var detail_frame := PanelContainer.new()
	detail_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_grid_frame(detail_frame, FRAME_COL, false)
	body.add_child(detail_frame)

	var dscroll := ScrollContainer.new()
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_frame.add_child(dscroll)

	var dbox := VBoxContainer.new()
	dbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dbox.add_theme_constant_override("separation", 2)
	dscroll.add_child(dbox)

	_detail_type_badge = _detail_label("", COL_DIM)
	dbox.add_child(_detail_type_badge)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	name_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dbox.add_child(name_row)

	_detail_name = _detail_label("\u2014 select a combo \u2014", COL_DIM)
	_detail_name.clip_text = true
	name_row.add_child(_detail_name)

	## The pack's other tag design, at its authored 48x14. Built once and toggled rather than
	## rebuilt on every selection.
	_detail_new = Icons.ribbon(Icons.Tag.RED, "NEW")
	if _detail_new != null:
		_detail_new.visible = false
		name_row.add_child(_detail_new)

	## State is now a tag plus the one line of instruction that goes with it. Splitting them is
	## the point: "[ DISCOVERED \u2014 trigger in a run to reveal ]" put the state and its how-to
	## inside one pair of brackets, and the state is the half a player scans for.
	_detail_state = HBoxContainer.new()
	_detail_state.add_theme_constant_override("separation", 5)
	_detail_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dbox.add_child(_detail_state)

	_detail_state_hint = _detail_label("", COL_DIM)
	_detail_state_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_state_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_detail_mods = _detail_label("", COL_DIM)
	_detail_mods.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dbox.add_child(_detail_mods)

	_detail_sep = _rule(true, Color(0.62, 0.60, 0.70, 0.45))
	_detail_sep.custom_minimum_size = Vector2(0.0, 1.0)
	_detail_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dbox.add_child(_detail_sep)

	_detail_desc = _detail_label("", COL_BODY)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dbox.add_child(_detail_desc)

	# Mastery progress bar
	_detail_prog_row = Control.new()
	_detail_prog_row.custom_minimum_size = Vector2(0.0, 7.0)
	_detail_prog_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_prog_row.visible = false
	dbox.add_child(_detail_prog_row)

	_detail_prog_bg = ColorRect.new()
	_detail_prog_bg.color = Color(0.14, 0.14, 0.18)
	_detail_prog_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_prog_row.add_child(_detail_prog_bg)

	## Filled by anchor rather than by pixel width, so it tracks the column instead of a `dw` that
	## was captured at build time.
	_detail_prog_fill = ColorRect.new()
	_detail_prog_fill.color = COL_MASTERED
	_detail_prog_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_prog_fill.anchor_right = 0.0
	_detail_prog_row.add_child(_detail_prog_fill)

	_detail_prog_label = _detail_label("", COL_DIM)
	_detail_prog_label.visible = false
	dbox.add_child(_detail_prog_label)

	_detail_mastery_bonus = _detail_label("", COL_MASTERED)
	_detail_mastery_bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_mastery_bonus.visible = false
	dbox.add_child(_detail_mastery_bonus)

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
	row.custom_minimum_size = Vector2(0.0, ROW_H)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## m5x7's line box at 16 is 23px, taller than the row, so a label left to fill would spill out
	## of the bottom border and into the next cell. Clipping is the backstop; the label is also
	## SHRINK_CENTER below so the spill is symmetric and the text sits on the row's centre line.
	row.clip_contents = true

	# Row fill — state colour, behind the frame
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_sel:
		bg.color = Color(0.22, 0.14, 0.38, 0.90)
	elif is_hi:
		bg.color = Color(0.38, 0.32, 0.12, 0.55)
	else:
		bg.color = Color.TRANSPARENT
	row.add_child(bg)

	## Row frame — the grid sheet's 12x12 cell, tiled out to the row's width. This IS the "grid"
	## in CodexGridPanel: 69 cells sharing borders down a column, which is what the sheet's own
	## 5x5 block does and what a codex/journal grid is for.
	var cell := Panel.new()
	cell.set_anchors_preset(Control.PRESET_FULL_RECT)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cell_col: Color = CELL_IDLE
	if is_sel:
		cell_col = CELL_SELECTED
	elif is_hi:
		cell_col = CELL_HIGHLIGHT
	_apply_grid_frame(cell, cell_col, true)
	row.add_child(cell)

	## Pip, name and tags share one HBox, so the name simply takes whatever the tags leave rather
	## than a fixed column being reserved for markers most rows do not have.
	var line := HBoxContainer.new()
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_left  = 3.0
	line.offset_right = -3.0
	line.add_theme_constant_override("separation", 3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)

	# Type color pip
	var pip := ColorRect.new()
	pip.custom_minimum_size = Vector2(3.0, 8.0)
	pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pip.color    = type_col if entry.discovered else COL_UNKNOWN
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(pip)

	var name_lbl := Label.new()
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not entry.discovered:
		if is_hi:
			## Pulse hint: "there's something here". The \u25ba that used to lead this line is not in
			## m5x7 \u2014 it was pulling in a vector fallback whose taller line box pushed the whole
			## row's text down past its own bottom border.
			name_lbl.text = "?  discover"
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

	line.add_child(name_lbl)

	## State tags. Both designs earn their place by SHAPE here, not by preference:
	##  \u00b7 NEW is the ribbon, because it is authored at a fixed 48x14 with a clipped label and so
	##    fits a 16px row. A pill carrying the same word is 23 tall (m5x7 at 16 has a 23px line
	##    box) and would collide with the rows above and below.
	##  \u00b7 The state markers are ICON pills at 18x8, for the same reason plus a second one: m5x7
	##    has no \u2605 glyph, so the old mastery star was silently rendering in Godot's vector font
	##    (see level_up_screen.gd). A trophy is the pack's own answer.
	if CodexManager.is_unseen(combo_id):
		_add_mark(line, Icons.ribbon(Icons.Tag.RED, "NEW"), "NEW", COL_MASTERED)
	if entry.is_mastered():
		_add_mark(line, Icons.pill(Icons.Tag.GOLD, "", Icons.general(Icons.TROPHY)),
			"MAX", COL_MASTERED)
	elif entry.discovered and not entry.revealed:
		_add_mark(line, Icons.pill(Icons.Tag.TAN, "", Icons.general(Icons.QUESTION)),
			"?", COL_DIM)

	# Invisible button overlay for click + hover
	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.focus_mode = Control.FOCUS_ALL
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
		_set_state_tag("", "", COL_DIM, Icons.Tag.CREAM)
		if _detail_new != null:
			_detail_new.visible = false
		_detail_mods.text          = ""
		_detail_desc.text          = ""
		_detail_prog_row.visible   = false
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

	if _detail_new != null:
		_detail_new.visible = CodexManager.is_unseen(_selected_id)

	## State tag. The colours are this panel's business, not the tag helper's \u2014 same split as the
	## armory's rarity-coloured slots \u2014 and they climb the sheet's own ramp with the state:
	## cream (inert) \u2192 tan \u2192 blue \u2192 gold.
	if not entry.discovered:
		_set_state_tag("UNKNOWN", "equip both mods", COL_UNKNOWN, Icons.Tag.CREAM)
	elif not entry.revealed:
		_set_state_tag("DISCOVERED", "trigger it in a run", COL_DISCOVERED, Icons.Tag.TAN)
	elif entry.is_mastered():
		_set_state_tag("MASTERED", "", COL_MASTERED, Icons.Tag.GOLD)
	else:
		_set_state_tag("REVEALED", "", COL_REVEALED, Icons.Tag.BLUE)

	# Required mods
	var mod_names: Array[String] = []
	for mod_id: StringName in combo.required_mods:
		var mod_data: Dictionary = ModApplicability.get_mod(str(mod_id))
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
	_detail_prog_row.visible   = show_progress
	_detail_prog_label.visible = show_progress

	if show_progress:
		var prog := entry.mastery_progress()
		_detail_prog_fill.anchor_right = prog
		_detail_prog_fill.offset_right = 0.0
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
		## No leading \u2605 \u2014 m5x7 has no glyph for it and it was falling back to a vector font. The
		## gold does the work the star was there for.
		_detail_mastery_bonus.text = "MASTERY BONUS: " + entry.mastery_bonus_description


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

## A 1px rule from the grid sheet, falling back to a flat ColorRect-alike when the pack is not
## present (`assets/minifantasy/` is gitignored, so a fresh clone has no sheet).
func _rule(horizontal: bool, col: Color) -> Control:
	var np: NinePatchRect = Icons.grid_rule(horizontal, col)
	if np != null:
		return np
	var flat := ColorRect.new()
	flat.color = col
	flat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return flat


## A detail-column label. No font size override: 16 is the project theme's default and the only
## size m5x7 renders crisply below 32.
func _detail_label(text: String, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", col)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


## Puts the grid sheet's box frame on a Panel/PanelContainer, or a 1px flat border if the sheet
## is missing.
func _apply_grid_frame(p: Control, col: Color, small: bool) -> void:
	var sb: StyleBoxTexture = Icons.grid_box(col, small)
	if sb != null:
		p.add_theme_stylebox_override("panel", sb)
		return
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color.TRANSPARENT
	flat.set_border_width_all(1)
	flat.border_color = col
	p.add_theme_stylebox_override("panel", flat)


## Adds a tag to a row's marker column, or the plain-text marker it replaces if the sheet is
## missing, so a row never loses its state entirely.
func _add_mark(parent: HBoxContainer, tag: Control, fallback: String, col: Color) -> void:
	if tag != null:
		tag.size_flags_horizontal = Control.SIZE_SHRINK_END
		parent.add_child(tag)
		return
	var lbl := Label.new()
	lbl.text = fallback
	lbl.add_theme_color_override("font_color", col)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)


## Rebuilds the detail pane's state row: a tag carrying the state word, then the instruction that
## goes with it as plain text beside it.
func _set_state_tag(state: String, hint: String, col: Color, tag_colour: int) -> void:
	for child in _detail_state.get_children():
		_detail_state.remove_child(child)
		if child != _detail_state_hint:
			child.queue_free()

	if state != "":
		var tag: Control = Icons.pill(tag_colour, state)
		if tag == null:
			var lbl := _detail_label("[ %s ]" % state, col)
			lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tag = lbl
		_detail_state.add_child(tag)

	_detail_state_hint.text = hint
	_detail_state_hint.add_theme_color_override("font_color", col)
	_detail_state.add_child(_detail_state_hint)


## A filter/sort button. Shares the row's width evenly instead of carrying a hardcoded one, so
## the row cannot run off the panel when a caption changes length.
func _row_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_ALL
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_text = true
	return btn


func _style_btn_flat(btn: Button, normal_col: Color, hover_col: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = hover_col if state in ["hover", "pressed", "focus"] else normal_col
		if state == "focus":
			sb.set_border_width_all(1)
			sb.border_color = COL_BORDER
		else:
			sb.set_border_width_all(0)
		sb.set_content_margin_all(2)
		btn.add_theme_stylebox_override(state, sb)
