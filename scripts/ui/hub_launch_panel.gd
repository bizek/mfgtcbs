@tool
extends Control

## Launch Pad panel — shows current loadout and hosts the BEGIN DESCENT button.

signal close_requested

## Preloaded under a local alias rather than the bare class_name — see hub_roster_panel.gd.
const Icons := preload("res://scripts/ui/ui_icons.gd")

const _FS_LG := 16
const _FS_MD := 16
const _FS_SM := 16
const _FS_XS := 16

const _C_DIM   := Color(0.314, 0.235, 0.157)   ## row labels / section headers
const _C_BODY  := Color(0.800, 0.690, 0.565)   ## ordinary values
const _C_EMPTY := Color(0.42, 0.40, 0.44)      ## an unfilled slot
const _C_WARN  := Color(0.831, 0.447, 0.102)   ## "you left something behind"
const _C_RULE  := Color(0.165, 0.145, 0.125)

## 307, not the base scene's 267 — the same height the Workshop panel already uses, so this
## is an existing size in the family rather than a new one. The panel had ~78px of dead black
## between the brief and BEGIN DESCENT; that space now carries the equipped class mods and a
## readiness line, and 267 could not hold both for every character. Worst case is real: a
## character whose passive_desc wraps to two lines (The Shade's is 79 chars) spends 31 of those
## 78px on the brief alone, which left 47 — not enough for a labelled three-slot section.
## The panel sizes itself to its content between these bounds (see _fit_to_content), because
## its height genuinely varies: The Drifter has no passive line at all, while The Demon carries
## a two-line passive AND a full three-mod loadout. A single fixed height cannot serve both —
## pick the tall one and short characters get the dead space back, pick the short one and the
## fullest loadout hides a mod behind a scrollbar.
##
## MAX is not a taste call: the hub's glyph bar starts at y=346, and a centred panel of height
## h ends at (360 + h) / 2, so 320 is the tallest that still clears it (ends at 340).
const _PANEL_H_MIN := 267   ## the base scene's own height
const _PANEL_H_MAX := 320
const _PANEL_H_START := 315

## 17, not 20. The text is 13px, so 20 was 7px of air per row; at 17 the brief keeps a
## comfortable rhythm and gives back the height the class-mod section needs.
const _ROW_H := 17

@onready var _base:    HubPanelBase = $PanelBase
@onready var _content: Control      = $PanelBase/ContentContainer

var _scroll: ScrollContainer = null
var _body:   VBoxContainer   = null

func _ready() -> void:
	_base.close_requested.connect(func(): close_requested.emit())
	if Engine.is_editor_hint():
		return
	## Runtime only: center_in_viewport() measures the viewport, and in the editor that is the
	## editor's own, which would misplace the preview.
	_base.size.y = _PANEL_H_START
	_base.center_in_viewport()
	## No populate() here — hub._open_panel() calls it the moment it adds us to the tree,
	## so a self-populate built the whole panel TWICE on every open. (Ben 2026-07-30.)


func populate(pm: Node) -> void:
	for child in _content.get_children():
		child.queue_free()

	var char_id: String       = pm.selected_character
	var char_data: Dictionary = CharacterData.ALL.get(char_id, CharacterData.ALL["The Drifter"])
	var char_col: Color       = char_data.get("color", Color(0.92, 0.86, 0.60))
	var slot_count: int       = pm.starting_weapon_slots()   ## per-character loadouts: every character gets armory slots

	## ── Root layout ──────────────────────────────────────────────────────────
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("margin_left",   10)
	root.add_theme_constant_override("margin_top",     8)
	root.add_theme_constant_override("margin_right",  10)
	root.add_theme_constant_override("margin_bottom",  8)
	_content.add_child(root)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	root.add_child(vbox)

	## ── Scrolling body ───────────────────────────────────────────────────────
	## The cards scroll; the readiness line, the rule and BEGIN DESCENT do not. Per the
	## project rule, SHOW_AS_NEEDED rather than SHOW_NEVER — 307px holds every character
	## measured, but a future extra row must push a scrollbar rather than clip silently.
	## Keeping the button outside the scroll means it is reachable without scrolling no
	## matter how long the brief gets.
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical      = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode     = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(scroll)
	_scroll = scroll

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## Deliberately NOT SIZE_EXPAND_FILL vertically: the cards hug their content and every card
	## border sits tight against its own rows. _fit_to_content() takes the panel down to the
	## content instead, so there is no leftover height for anything to absorb. (Ben, flush.)
	body.add_theme_constant_override("separation", 6)
	scroll.add_child(body)
	_body = body

	## ── Loadout card ─────────────────────────────────────────────────────────
	var inner := _card(body, "DEPLOYMENT BRIEF")

	## ── Character row ────────────────────────────────────────────────────────
	_row(inner, "CHARACTER", char_data.get("display_name", char_id), char_col)

	## Class label (dim, sits below character name)
	var char_class: String = char_data.get("char_class", "")
	if char_class != "":
		_row(inner, "CLASS", char_class.to_upper(), Color(char_col.r * 0.55, char_col.g * 0.55, char_col.b * 0.55))

	## ── Weapon rows ──────────────────────────────────────────────────────────
	if slot_count >= 2:
		for s in range(1, slot_count + 1):
			var w: String = pm.get_character_weapon(char_id, s)
			if w.is_empty():
				w = "- none -"
			_row(inner, "SLOT %d" % s, w, Color(0.800, 0.690, 0.565))
	else:
		_row(inner, "WEAPON", pm.get_character_weapon(char_id, 1), _C_BODY)

	## The passive used to be built inside the single-slot branch, so buying an armory
	## expansion silently deleted it from the brief. It describes the character, not the
	## weapon layout, so it belongs on both paths.
	if char_id != "The Drifter":
		var passive_desc: String = char_data.get("passive_desc", "")
		if not passive_desc.is_empty():
			_row_passive(inner, "PASSIVE", passive_desc)

	## ── Class mods ───────────────────────────────────────────────────────────
	_build_class_mods(body, pm, char_id)

	## ── Readiness line ───────────────────────────────────────────────────────
	## Outside the scroll: an "unspent points" warning that can be scrolled out of view
	## is not a warning.
	_build_readiness(vbox, pm)

	## ── Separator ────────────────────────────────────────────────────────────
	var sep := ColorRect.new()
	sep.custom_minimum_size   = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sep.color                 = _C_RULE
	vbox.add_child(sep)

	## ── BEGIN DESCENT button ─────────────────────────────────────────────────
	var btn := Button.new()
	btn.text                  = "BEGIN DESCENT"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode            = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", _FS_LG)
	btn.add_theme_color_override("font_color",       Color(0.820, 0.157, 0.063))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.2))
	_style_begin_btn(btn)
	btn.pressed.connect(_start_run)
	vbox.add_child(btn)

	_fit_to_content()


## Shrinks or grows the panel to exactly what this character's brief needs.
##
## Deferred by one frame on purpose: the PASSIVE line autowraps, and an autowrapped Label does
## not know its own height until it has been given a width. Measuring before that pass reports
## one character per line — The Shade's 79-character passive measured 1205px tall, which is how
## this was caught rather than shipped.
##
## get_combined_minimum_size() rather than _body.size.y because it is the height the content
## WANTS, which is what the panel should be sized to. A ScrollContainer clamps its child's
## actual size to the visible area once the content overflows, so _body.size.y can never
## report how much too tall the content is — it saturates at the view height and the panel
## would stop growing exactly when it most needs to.
func _fit_to_content() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_base) or not is_instance_valid(_scroll) or not is_instance_valid(_body):
		return
	var delta: float = _body.get_combined_minimum_size().y - _scroll.size.y
	var target: float = clampf(_base.size.y + delta, float(_PANEL_H_MIN), float(_PANEL_H_MAX))
	if absf(target - _base.size.y) < 1.0:
		return
	_base.size.y = target
	_base.center_in_viewport()


## Bordered card with a titled header rule, returning the VBox to add rows into.
##
## PanelContainer, not Panel: a bare Panel is not a container, so it never stretched the
## MarginContainer below it — the brief column sat at its own content minimum and the
## autowrapped PASSIVE line wrapped to a ~90px ribbon with half the card empty beside it.
## Latent since this panel was written; only became visible when the body font dropped to 16
## and the content minimum got narrower with it.
func _card(parent: Control, title: String, trailing: String = "") -> VBoxContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cs := StyleBoxFlat.new()
	cs.bg_color            = Color(0.082, 0.075, 0.063)
	cs.border_color        = _C_RULE
	cs.border_width_left   = 1
	cs.border_width_top    = 1
	cs.border_width_right  = 1
	cs.border_width_bottom = 1
	cs.set_content_margin_all(0)
	card.add_theme_stylebox_override("panel", cs)
	parent.add_child(card)

	var cm := MarginContainer.new()
	cm.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	cm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cm.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	cm.add_theme_constant_override("margin_left",   8)
	cm.add_theme_constant_override("margin_top",    6)
	cm.add_theme_constant_override("margin_right",  8)
	cm.add_theme_constant_override("margin_bottom", 6)
	card.add_child(cm)

	var inner := VBoxContainer.new()
	inner.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)
	cm.add_child(inner)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 5)
	inner.add_child(hdr)

	_lbl(hdr, title, _FS_SM, _C_DIM)

	var amber_rule := ColorRect.new()
	amber_rule.custom_minimum_size   = Vector2(0, 1)
	amber_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amber_rule.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	amber_rule.color                 = Color(0.831, 0.447, 0.102, 0.60)
	hdr.add_child(amber_rule)

	if trailing != "":
		_lbl(hdr, trailing, _FS_XS, _C_DIM)

	return inner


## The equipped class mods, which were invisible from this screen entirely — the panel a
## player presses to commit to a run showed the weapon but not the three mods riding on it.
func _build_class_mods(parent: Control, pm: Node, char_id: String) -> void:
	var slots: int   = pm.class_mod_slots(char_id)
	var equipped: Array = pm.get_character_mods(char_id)

	var filled: int = 0
	for i in slots:
		var mid: String = str(equipped[i]) if i < equipped.size() else ""
		if not mid.is_empty():
			filled += 1

	var inner := _card(parent, "CLASS MODS", "%d / %d" % [filled, slots])
	inner.add_theme_constant_override("separation", 3)

	## Nothing equipped at all is one statement, not three identical empty rows — it reads
	## better and it is what keeps the tallest character (a two-line passive plus this card)
	## inside the panel without scrolling.
	if filled == 0:
		var none_lbl := _lbl(inner, "none equipped - fit mods in the ARMORY", _FS_MD, _C_EMPTY)
		none_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return

	for i in slots:
		var mod_id: String = str(equipped[i]) if i < equipped.size() else ""

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 4)
		hb.custom_minimum_size = Vector2(0, 15)
		inner.add_child(hb)

		if mod_id.is_empty():
			## A gap in an otherwise-filled loadout IS worth a per-slot row — it is the
			## actionable case, and it is only reachable once at least one mod is fitted.
			var empty := _lbl(hb, "- empty -", _FS_MD, _C_EMPTY)
			empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			continue

		var mdata: Dictionary = ClassModData.ALL.get(mod_id, {})
		var name_lbl := _lbl(hb, "* " + str(mdata.get("name", mod_id)), _FS_MD,
				mdata.get("color", _C_BODY))
		## Must be allowed to SHRINK, and the row to fill, or the HBox sizes to the label's
		## full text width and pushes the pill past the card edge — the same failure the
		## armory hit at x=665 in a 640px viewport. clip_text lowers the minimum so the pill
		## always lands inside, whatever a future mod is called.
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.clip_text             = true

		## Same tag art the armory and the haul manifest use, so all three screens say
		## "rare" the same way. Falls back to the bare name when the sheet is missing.
		var tag: Control = Icons.rarity_tag(ClassModData.rarity_of(mod_id))
		if tag != null:
			tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hb.add_child(tag)


## One line above the button: where this run goes, and what the player is about to leave
## behind. Unspent passive points are the case worth catching — the tree is a separate panel
## and it is entirely possible to bank 50+ points across runs without noticing.
func _build_readiness(parent: Control, pm: Node) -> void:
	var level_id: int      = GameManager.current_level
	var level: Dictionary  = LevelData.LEVELS.get(level_id, {})
	var dest: String       = str(level.get("name", "Unknown")).to_upper()
	var block_ct: int      = int(level.get("blocks", {}).get("count", 0))
	var where: String      = "%s  (%d BLOCKS)" % [dest, block_ct] if block_ct > 0 else dest

	## Row 1 — where this run goes, and the warning.
	var r1 := _readiness_row(parent)
	_lbl(r1, "DESTINATION", _FS_XS, _C_DIM)

	## More than one biome authored = the destination becomes a choice. A plain button that
	## cycles rather than a pair of arrows: there are two biomes today and the row has no width
	## for chrome. LevelData.playable_ids() is the source of truth, so a new biome appears here
	## as soon as its waves and blocks exist.
	var choices: Array[int] = LevelData.playable_ids()
	if choices.size() > 1:
		var btn := Button.new()
		btn.text = where
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_ALL
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.clip_text = true
		btn.add_theme_font_size_override("font_size", _FS_XS)
		btn.add_theme_color_override("font_color", _C_BODY)
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.55))
		_style_dest_btn(btn)
		btn.pressed.connect(func() -> void:
			var ids: Array[int] = LevelData.playable_ids()
			var idx: int = ids.find(GameManager.current_level)
			GameManager.set_level(ids[(idx + 1) % ids.size()] if idx != -1 else ids[0])
			AudioManager.play_ui("sfx_ui_click")
			populate(pm))
		r1.add_child(btn)
	else:
		var dest_lbl := _lbl(r1, where, _FS_XS, _C_BODY)
		dest_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var unspent: int = pm.get_passive_points()
	if unspent > 0:
		_lbl(r1, "! %d PASSIVE PTS UNSPENT" % unspent, _FS_XS, _C_WARN)

	## A second row (vault + insurance) was built here and then removed: the hub's glyph bar
	## starts at y=346, so a centred panel can be at most 320 tall, and the extra 21px of
	## pinned height pushed the fullest character's third class mod behind a scrollbar. Vault
	## and insurance both read clearly in the Workshop; a mod you cannot see on the screen you
	## launch from does not. Measured, not assumed — see _fit_to_content().


## Flat, borderless until hovered/focused — the row is a status line, not a form, so the
## destination should read as text that happens to be clickable.
func _style_dest_btn(btn: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		var hot: bool = state in ["hover", "pressed", "focus"]
		sb.bg_color = Color(0.20, 0.14, 0.06) if hot else Color(0, 0, 0, 0)
		if state == "focus":
			sb.set_border_width_all(1)
			sb.border_color = _C_WARN
		else:
			sb.set_border_width_all(0)
		sb.set_content_margin(SIDE_LEFT, 3)
		sb.set_content_margin(SIDE_RIGHT, 3)
		sb.set_content_margin(SIDE_TOP, 0)
		sb.set_content_margin(SIDE_BOTTOM, 0)
		btn.add_theme_stylebox_override(state, sb)


func _readiness_row(parent: Control) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.custom_minimum_size = Vector2(0, 15)
	parent.add_child(hb)
	return hb


func _start_run() -> void:
	## The descent is worth a beat longer than a menu hop — this and the results
	## screen are the two transitions a player crosses on every single run.
	SceneTransition.change_scene("res://scenes/main_arena.tscn", 0.35, 0.3)


func _row(parent: Control, label: String, value: String, val_col: Color) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.custom_minimum_size = Vector2(0, _ROW_H)
	parent.add_child(hb)

	var lbl := Label.new()
	lbl.text                = label
	lbl.custom_minimum_size = Vector2(72, 0)
	lbl.add_theme_font_size_override("font_size", _FS_XS)
	lbl.add_theme_color_override("font_color", _C_DIM)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(lbl)

	var val := Label.new()
	val.text                  = value
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.add_theme_font_size_override("font_size", _FS_MD)
	val.add_theme_color_override("font_color", val_col)
	val.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	hb.add_child(val)


func _row_passive(parent: Control, label: String, desc: String) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	parent.add_child(hb)

	var lbl := Label.new()
	lbl.text                = label
	lbl.custom_minimum_size = Vector2(72, 0)
	lbl.add_theme_font_size_override("font_size", _FS_XS)
	lbl.add_theme_color_override("font_color", Color(0.314, 0.235, 0.157))
	lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(lbl)

	var val := Label.new()
	val.text                  = desc
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
	val.add_theme_font_size_override("font_size", _FS_XS)
	val.add_theme_color_override("font_color", Color(0.541, 0.408, 0.282))
	hb.add_child(val)


func _style_begin_btn(btn: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		var hot: bool = state in ["hover", "pressed", "focus"]
		sb.bg_color            = Color(0.353, 0.173, 0.031) if hot else Color(0.082, 0.075, 0.063)
		sb.border_width_left   = 1
		sb.border_width_top    = 1
		sb.border_width_right  = 1
		sb.border_width_bottom = 1
		sb.border_color        = Color(1.0, 0.55, 0.2) if state == "focus" else Color(0.690, 0.353, 0.082)
		sb.set_content_margin(SIDE_TOP,    6)
		sb.set_content_margin(SIDE_BOTTOM, 6)
		sb.set_content_margin(SIDE_LEFT,   8)
		sb.set_content_margin(SIDE_RIGHT,  8)
		btn.add_theme_stylebox_override(state, sb)


func _lbl(parent: Control, text: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(l)
	return l
