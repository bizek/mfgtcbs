class_name UnitEditorWindow
extends Window

## Unit Editor — a standalone balance-tuning application, in its own OS window.
##
## ── Why a Window and not another F-key panel ──────────────────────────────────
##
## The game renders at 640x360 and integer-upscales to 1920x1080. Every existing dev tool
## lives inside that buffer, which is why they size text at 9-14px and scroll heavily — the
## training panel is 170px wide because that is what fits. A comprehensive editor does not
## fit in 640x360 at any font size worth reading.
##
## A `Window` node is not subject to the main viewport's stretch. It gets its own size, its
## own content scale and ordinary anti-aliased vector text at native resolution, so the
## pixel-grid rules in CLAUDE.md (m5x7 at 16/32, integer scale, no fractional sizes) simply
## do not apply in here — they are about the 640x360 buffer, and this is not in it. The
## game keeps running in the main window while you tune, which is the entire point: change
## a number on one monitor, watch it land on the other.
##
## Subwindow embedding is turned OFF while the editor is open (`gui_embed_subwindows`), and
## restored on close — embedded is the Godot default, and an embedded Window would render
## back inside the 640x360 viewport, which is what this exists to escape.
##
## ── What it edits ─────────────────────────────────────────────────────────────
##
## Nothing directly. It reads BalanceRegistry for the catalogue of tunables and writes
## BalanceOverrides for the values; the game's seams read that layer. So the editor has no
## knowledge of any particular stat, and a field added to the registry appears here with no
## change to this file.

const MIN_SIZE := Vector2i(1000, 640)
const DEFAULT_SIZE := Vector2i(1440, 900)
const NAV_WIDTH: int = 280
const LABEL_WIDTH: int = 210
const FS: int = 14
const FS_SMALL: int = 12
const FS_TITLE: int = 20

## Palette. Dark, low-chroma, with one accent for "this differs from shipped" — the single
## most important thing the eye needs to find on a dense screen.
const C_BG := Color(0.086, 0.094, 0.110)
const C_PANEL := Color(0.122, 0.133, 0.153)
const C_ROW := Color(0.145, 0.157, 0.180)
const C_EDGE := Color(0.239, 0.259, 0.294)
const C_TEXT := Color(0.855, 0.875, 0.906)
const C_DIM := Color(0.514, 0.549, 0.600)
const C_ACCENT := Color(1.000, 0.741, 0.310)
const C_ACCENT_BG := Color(0.247, 0.196, 0.086)
const C_OK := Color(0.427, 0.804, 0.514)
const C_WARN := Color(0.949, 0.478, 0.412)

var player_ref: Node2D = null

var _nav: Tree = null
var _inspector: VBoxContainer = null
var _subject_title: Label = null
var _subject_sub: Label = null
var _search: LineEdit = null
var _profile_btn: OptionButton = null
var _changes_lbl: Label = null
var _status_lbl: Label = null
var _live_btn: CheckBox = null
var _save_btn: Button = null

var _cat: String = BalanceRegistry.CAT_CHARACTER
var _subject: String = ""
var _searching: bool = false
## Guard against the write-triggers-refresh-triggers-write loop that value_changed on a
## rebuilt control would otherwise cause.
var _rebuilding: bool = false
var _embed_was: bool = true


func _ready() -> void:
	title = "Unit Editor — Extraction Survivors"
	size = DEFAULT_SIZE
	min_size = MIN_SIZE
	unresizable = false
	exclusive = false
	transient = false
	## The editor must keep working while the game is paused (and the game must keep
	## running while the editor has focus).
	process_mode = Node.PROCESS_MODE_ALWAYS
	content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	close_requested.connect(_on_close)
	## Built hidden. A Window added to the tree is visible by default, and the arena creates
	## this at startup whether or not it will ever be opened.
	visible = false
	## NOTE: `gui_embed_subwindows` is deliberately NOT touched here. It is a property of the
	## whole root viewport, and flipping it at scene load would change how every other
	## subwindow in the game behaves for a tool the session may never open. It is flipped in
	## reopen() and restored in _on_close(), so the side effect lasts exactly as long as the
	## editor is on screen.
	_embed_was = get_tree().root.gui_embed_subwindows

	_build()
	_select_first()
	_refresh_header()


func setup(player: Node2D) -> void:
	player_ref = player


## Open or close. The ONLY entry point callers should use, so both directions always pair the
## `gui_embed_subwindows` flip with its restore — an earlier version had main_arena call
## `hide()` directly, which left the whole game's subwindow mode flipped after F12 closed it.
func toggle() -> void:
	if visible:
		_on_close()
	else:
		reopen()


func _on_close() -> void:
	hide()
	var root_vp: Viewport = get_tree().root
	if root_vp:
		root_vp.gui_embed_subwindows = _embed_was


## Reopen without losing state — the launcher calls this rather than rebuilding.
func reopen() -> void:
	var root_vp: Viewport = get_tree().root
	_embed_was = root_vp.gui_embed_subwindows
	root_vp.gui_embed_subwindows = false
	show()
	grab_focus()
	_refresh_nav()
	_refresh_inspector()
	_refresh_header()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event
		if k.keycode == KEY_F12 or k.keycode == KEY_ESCAPE:
			## Closing from inside the editor, where `visible` is necessarily true — call
			## _on_close directly rather than toggle(), which would be a no-op race if the
			## arena's own F12 handler also ran this frame.
			_on_close()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_S and k.ctrl_pressed:
			_do_save()
			get_viewport().set_input_as_handled()


# ─── Theme ────────────────────────────────────────────────────────────────────

## The editor's own theme, deliberately overriding the project's.
##
## `project.godot [gui] theme/custom` sets m5x7 at 16 game-wide, and theme resolution would
## hand it to this window too. m5x7 is a 16px-native pixel font built for the 640x360
## buffer; at native window resolution in a dense grid it is the wrong tool. So this sets
## its own default font — the ordinary anti-aliased vector face, which is what a desktop
## application should render in and what stays readable at 12-14px without any of the
## pixel-grid gymnastics.
##
## Note this does NOT use DebugUI.crisp_vector_font(): that exists to survive the 3x integer
## upscale by disabling anti-aliasing, and there is no upscale here. Plain AA is better.
func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = ThemeDB.fallback_font
	t.default_font_size = FS

	t.set_stylebox("panel", "PanelContainer", _box(C_PANEL, C_EDGE))
	t.set_stylebox("panel", "Panel", _box(C_PANEL, C_EDGE))

	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c: Color = C_ROW
		if state == "hover":
			c = C_EDGE
		elif state == "pressed":
			c = C_ACCENT_BG
		elif state == "disabled":
			c = C_PANEL
		var sb := _box(c, C_EDGE, 3)
		sb.content_margin_left = 10.0
		sb.content_margin_right = 10.0
		sb.content_margin_top = 4.0
		sb.content_margin_bottom = 4.0
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", C_DIM)

	var le := _box(Color(0.071, 0.078, 0.094), C_EDGE, 3)
	le.content_margin_left = 6.0
	le.content_margin_right = 6.0
	le.content_margin_top = 3.0
	le.content_margin_bottom = 3.0
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", _box(Color(0.071, 0.078, 0.094), C_ACCENT, 3))
	t.set_color("font_color", "LineEdit", C_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", C_DIM)
	t.set_color("caret_color", "LineEdit", C_ACCENT)

	t.set_color("font_color", "Label", C_TEXT)
	t.set_color("font_color", "Tree", C_TEXT)
	t.set_stylebox("panel", "Tree", _box(Color(0.098, 0.106, 0.125), C_EDGE))
	t.set_stylebox("selected", "Tree", _box(C_ACCENT_BG, C_ACCENT, 2))
	t.set_stylebox("selected_focus", "Tree", _box(C_ACCENT_BG, C_ACCENT, 2))
	t.set_color("font_selected_color", "Tree", Color.WHITE)
	t.set_color("guide_color", "Tree", Color(1, 1, 1, 0.05))

	t.set_color("font_color", "CheckBox", C_TEXT)
	t.set_stylebox("panel", "ScrollContainer", _box(C_BG, C_BG))
	return t


static func _box(bg: Color, border: Color, radius: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	## Rounded StyleBoxFlat defaults anti_aliasing ON, which feathers every edge. Harmless
	## at native res but it muddies a 1px border, and CLAUDE.md calls it out project-wide.
	sb.anti_aliasing = false
	return sb


# ─── Layout ───────────────────────────────────────────────────────────────────

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 10)
	root.add_theme_constant_override("margin_right", 10)
	root.add_theme_constant_override("margin_top", 8)
	root.add_theme_constant_override("margin_bottom", 8)
	root.theme = _make_theme()
	add_child(root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	root.add_child(col)

	col.add_child(_build_header())
	col.add_child(_rule())

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = NAV_WIDTH
	col.add_child(split)
	split.add_child(_build_nav())
	split.add_child(_build_inspector())

	col.add_child(_rule())
	col.add_child(_build_footer())


func _build_header() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)

	var title_lbl := Label.new()
	title_lbl.text = "UNIT EDITOR"
	title_lbl.add_theme_font_size_override("font_size", FS_TITLE)
	title_lbl.add_theme_color_override("font_color", C_ACCENT)
	h.add_child(title_lbl)

	_search = LineEdit.new()
	_search.placeholder_text = "search every tunable…  (name or path)"
	_search.custom_minimum_size = Vector2(340, 0)
	_search.clear_button_enabled = true
	_search.text_changed.connect(_on_search)
	h.add_child(_search)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)

	var pl := Label.new()
	pl.text = "profile"
	pl.add_theme_color_override("font_color", C_DIM)
	pl.add_theme_font_size_override("font_size", FS_SMALL)
	h.add_child(pl)

	_profile_btn = OptionButton.new()
	_profile_btn.custom_minimum_size = Vector2(150, 0)
	_profile_btn.item_selected.connect(_on_profile_picked)
	h.add_child(_profile_btn)
	h.add_child(_btn("+", _on_new_profile, "Create a profile seeded from this one"))

	_changes_lbl = Label.new()
	_changes_lbl.add_theme_color_override("font_color", C_ACCENT)
	h.add_child(_changes_lbl)

	_save_btn = _btn("SAVE  (Ctrl+S)", _do_save, "Write balance_overrides.json")
	h.add_child(_save_btn)
	h.add_child(_btn("REVERT ALL", _do_revert_all, "Clear every override in this profile"))
	return h


func _build_nav() -> Control:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(NAV_WIDTH, 0)
	_nav = Tree.new()
	_nav.hide_root = true
	_nav.allow_reselect = true
	_nav.custom_minimum_size = Vector2(NAV_WIDTH - 20, 0)
	_nav.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_nav.item_selected.connect(_on_nav_selected)
	pc.add_child(_nav)
	return pc


func _build_inspector() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_subject_title = Label.new()
	_subject_title.add_theme_font_size_override("font_size", FS_TITLE - 2)
	_subject_title.add_theme_color_override("font_color", C_TEXT)
	col.add_child(_subject_title)

	_subject_sub = Label.new()
	_subject_sub.add_theme_font_size_override("font_size", FS_SMALL)
	_subject_sub.add_theme_color_override("font_color", C_DIM)
	col.add_child(_subject_sub)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	## SHOW_AS_NEEDED per CLAUDE.md — SHOW_NEVER clips silently instead of scrolling, which
	## is how a panel loses controls without anyone noticing.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	col.add_child(scroll)

	_inspector = VBoxContainer.new()
	_inspector.add_theme_constant_override("separation", 2)
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_inspector)
	return col


func _build_footer() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)

	_live_btn = CheckBox.new()
	_live_btn.text = "live apply"
	_live_btn.button_pressed = true
	_live_btn.tooltip_text = ("Rebuild the running player after every edit.\n"
			+ "Off = edits accumulate and only land when you press APPLY NOW.")
	h.add_child(_live_btn)

	h.add_child(_btn("APPLY NOW", _do_apply, "Push the current overrides into the running game"))
	h.add_child(_btn("BAKE TO SOURCE", _do_bake,
			"Rewrite the .gd data files with these values and clear the overrides."))
	h.add_child(_btn("PRUNE", _do_prune,
			"Drop overrides that no longer match any field, and ones equal to shipped."))

	_status_lbl = Label.new()
	_status_lbl.add_theme_font_size_override("font_size", FS_SMALL)
	_status_lbl.add_theme_color_override("font_color", C_DIM)
	_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_lbl.text = "ready"
	h.add_child(_status_lbl)
	return h


func _rule() -> Control:
	var r := ColorRect.new()
	r.color = C_EDGE
	r.custom_minimum_size = Vector2(0, 1)
	return r


func _btn(text: String, cb: Callable, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(cb)
	return b


# ─── Navigation ───────────────────────────────────────────────────────────────

func _refresh_nav() -> void:
	if _nav == null:
		return
	_nav.clear()
	var root: TreeItem = _nav.create_item()
	for cat: Dictionary in BalanceRegistry.categories():
		var cid: String = cat["id"]
		var ci: TreeItem = _nav.create_item(root)
		ci.set_text(0, str(cat["label"]))
		ci.set_selectable(0, false)
		ci.set_custom_color(0, C_ACCENT)
		ci.set_metadata(0, {"cat": cid, "subject": ""})
		for subj: Dictionary in BalanceRegistry.subjects(cid):
			var sid: String = subj["id"]
			var si: TreeItem = _nav.create_item(ci)
			var n: int = _override_count_for(cid, sid)
			si.set_text(0, ("%s  ● %d" % [str(subj["label"]), n]) if n > 0 else str(subj["label"]))
			si.set_custom_color(0, C_ACCENT if n > 0 else C_TEXT)
			si.set_tooltip_text(0, str(subj.get("sub", "")))
			si.set_metadata(0, {"cat": cid, "subject": sid})
			if cid == _cat and sid == _subject:
				si.select(0)
		ci.collapsed = cid != _cat


## How many fields in a subject differ from shipped — the dot in the nav.
##
## Counted by prefix rather than by walking every field, because walking means rebuilding
## each kit's combo graphs, and doing that for all twelve on every nav refresh is a visible
## stall. Prefix counting is exact for every domain here since subject ids are unique within
## their category.
func _override_count_for(cat: String, subject: String) -> int:
	var prefixes: Array[String] = []
	match cat:
		BalanceRegistry.CAT_CHARACTER:
			prefixes.append("character/%s/" % subject)
			prefixes.append("player_stat/%s/" % subject)
		BalanceRegistry.CAT_PLAYER:
			if subject == BalanceRegistry.SUBJ_HITBOX:
				prefixes.append("hitbox/")
			else:
				prefixes.append("player_stat/%s/" % BalanceOverrides.GLOBAL)
		BalanceRegistry.CAT_CHAIN:
			prefixes.append("chain/%s/" % subject)
		BalanceRegistry.CAT_WEAPON:
			prefixes.append("weapon/%s/" % subject)
		BalanceRegistry.CAT_ENEMY:
			prefixes.append("enemy/%s/" % subject)
		BalanceRegistry.CAT_DIFFICULTY:
			prefixes.append("difficulty/")
	var n: int = 0
	for p: String in BalanceOverrides.overridden_paths():
		for pre: String in prefixes:
			if p.begins_with(pre):
				n += 1
				break
	return n


func _select_first() -> void:
	var subs: Array[Dictionary] = BalanceRegistry.subjects(BalanceRegistry.CAT_CHARACTER)
	if not subs.is_empty():
		_subject = str(subs[0]["id"])
	_refresh_nav()
	_refresh_inspector()


func _on_nav_selected() -> void:
	var item: TreeItem = _nav.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if not (meta is Dictionary):
		return
	var m: Dictionary = meta
	if str(m.get("subject", "")) == "":
		return
	_cat = str(m["cat"])
	_subject = str(m["subject"])
	_searching = false
	if _search:
		_search.text = ""
	_refresh_inspector()


# ─── Inspector ────────────────────────────────────────────────────────────────

func _refresh_inspector() -> void:
	if _inspector == null:
		return
	_rebuilding = true
	for c in _inspector.get_children():
		c.queue_free()

	var fields: Array[BalanceField] = []
	if _searching:
		fields = _search_results()
		_subject_title.text = "SEARCH"
		_subject_sub.text = "%d match%s for \"%s\"" % [fields.size(),
				("" if fields.size() == 1 else "es"), _search.text]
	else:
		fields = BalanceRegistry.fields(_cat, _subject)
		var info: Dictionary = _subject_info()
		_subject_title.text = str(info.get("label", _subject))
		_subject_sub.text = "%s   ·   %d tunables" % [str(info.get("sub", "")), fields.size()]

	var section: String = ""
	for f: BalanceField in fields:
		if f.section != section:
			section = f.section
			_inspector.add_child(_section_header(section))
		_inspector.add_child(_field_row(f))

	if fields.is_empty():
		var empty := Label.new()
		empty.text = "nothing here"
		empty.add_theme_color_override("font_color", C_DIM)
		_inspector.add_child(empty)
	_rebuilding = false


func _subject_info() -> Dictionary:
	for subj: Dictionary in BalanceRegistry.subjects(_cat):
		if str(subj["id"]) == _subject:
			return subj
	return {}


func _section_header(text: String) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 10)
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", FS_SMALL)
	l.add_theme_color_override("font_color", C_ACCENT)
	m.add_child(l)
	return m


## One editable row. The visual job here is that an overridden field must be findable at a
## glance in a list of sixty, so it gets a filled row, an accent label and a live "base → now".
func _field_row(f: BalanceField) -> Control:
	var pc := PanelContainer.new()
	var on: bool = f.is_overridden() and not f.is_derived()
	pc.add_theme_stylebox_override("panel",
			_box(C_ACCENT_BG if on else C_ROW, C_ACCENT if on else C_ROW, 3))

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	pc.add_child(h)

	var name_lbl := Label.new()
	name_lbl.text = f.label
	name_lbl.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	name_lbl.add_theme_color_override("font_color",
			C_DIM if f.is_derived() else (C_ACCENT if on else C_TEXT))
	name_lbl.tooltip_text = "%s\n\n%s" % [f.path, f.doc] if f.doc != "" else f.path
	h.add_child(name_lbl)

	## A derived field gets its value shown but not an editor — see BalanceField.derived_from.
	if f.is_derived():
		var val := Label.new()
		val.text = f.format_value(f.base)
		val.custom_minimum_size = Vector2(110, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.add_theme_color_override("font_color", C_DIM)
		h.add_child(val)
	else:
		h.add_child(_editor_for(f))

	var sfx := Label.new()
	sfx.text = f.suffix
	sfx.custom_minimum_size = Vector2(34, 0)
	sfx.add_theme_color_override("font_color", C_DIM)
	sfx.add_theme_font_size_override("font_size", FS_SMALL)
	h.add_child(sfx)

	var base_lbl := Label.new()
	if f.is_derived():
		base_lbl.text = f.derived_from
		base_lbl.add_theme_color_override("font_color", C_ACCENT)
	else:
		base_lbl.text = (f.delta_text() if on else "base %s" % f.format_value(f.base))
		base_lbl.add_theme_color_override("font_color", C_OK if on else C_DIM)
	base_lbl.custom_minimum_size = Vector2(230, 0)
	base_lbl.add_theme_font_size_override("font_size", FS_SMALL)
	h.add_child(base_lbl)

	## Single-line and clipped. An earlier version set autowrap AND clip_text together, which
	## rendered nothing at all — the row is one line tall, so wrapped text has nowhere to go.
	## The full text is on the label's tooltip either way.
	var doc := Label.new()
	doc.text = "" if f.is_derived() else f.doc
	doc.add_theme_font_size_override("font_size", FS_SMALL)
	doc.add_theme_color_override("font_color", C_DIM)
	doc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doc.clip_text = true
	doc.tooltip_text = f.doc
	h.add_child(doc)

	var apply_tag := Label.new()
	apply_tag.text = "" if f.is_derived() else ["", "rebuild", "restart"][int(f.apply)]
	apply_tag.custom_minimum_size = Vector2(58, 0)
	apply_tag.add_theme_font_size_override("font_size", FS_SMALL)
	apply_tag.add_theme_color_override("font_color", C_WARN if f.apply == BalanceField.Apply.RESTART else C_DIM)
	apply_tag.tooltip_text = _apply_tip(f.apply)
	h.add_child(apply_tag)

	var rev := _btn("↺", func() -> void: _revert_field(f), "Restore the shipped value")
	rev.disabled = not on or f.is_derived()
	rev.custom_minimum_size = Vector2(30, 0)
	h.add_child(rev)
	return pc


static func _apply_tip(a: BalanceField.Apply) -> String:
	match a:
		BalanceField.Apply.REBUILD:
			return "Takes effect when the player is rebuilt — automatic while 'live apply' is on."
		BalanceField.Apply.RESTART:
			return "Only affects entities spawned AFTER the change. Existing ones keep their old numbers."
	return "Takes effect immediately."


func _editor_for(f: BalanceField) -> Control:
	match f.kind:
		BalanceField.Kind.BOOL:
			var cb := CheckBox.new()
			cb.button_pressed = bool(f.current())
			cb.custom_minimum_size = Vector2(120, 0)
			cb.toggled.connect(func(v: bool) -> void: _write(f, v))
			return cb
		BalanceField.Kind.VEC2:
			var box := HBoxContainer.new()
			box.add_theme_constant_override("separation", 4)
			var cur: Vector2 = f.current()
			var sx := _spin(f, cur.x)
			var sy := _spin(f, cur.y)
			sx.value_changed.connect(func(v: float) -> void:
				_write(f, Vector2(v, float(sy.value))))
			sy.value_changed.connect(func(v: float) -> void:
				_write(f, Vector2(float(sx.value), v)))
			box.add_child(sx)
			var x := Label.new()
			x.text = "x"
			x.add_theme_color_override("font_color", C_DIM)
			box.add_child(x)
			box.add_child(sy)
			return box
		_:
			var sp := _spin(f, float(f.current()))
			sp.value_changed.connect(func(v: float) -> void: _write(f, v))
			return sp


func _spin(f: BalanceField, value: float) -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = f.minimum
	sp.max_value = f.maximum
	sp.step = f.step
	## Ranges are guidance, not walls. This is a tuning tool — finding out what an absurd
	## value feels like is a legitimate thing to want, and a spinbox that refuses is just in
	## the way. The hint ranges size the step and frame what is reasonable.
	sp.allow_greater = true
	sp.allow_lesser = true
	sp.value = value
	sp.custom_minimum_size = Vector2(110, 0)
	sp.select_all_on_focus = true
	return sp


func _write(f: BalanceField, value: Variant) -> void:
	if _rebuilding:
		return
	f.write(value)
	_after_change("%s = %s" % [f.label, f.format_value(value)])


func _revert_field(f: BalanceField) -> void:
	f.revert()
	_after_change("reverted %s" % f.label)
	_refresh_inspector()


## One place that runs after any write: push to the game, update the chrome.
func _after_change(msg: String) -> void:
	if _live_btn and _live_btn.button_pressed:
		_apply_to_game()
	_refresh_header()
	_refresh_nav()
	_set_status(msg)


# ─── Search ───────────────────────────────────────────────────────────────────

func _on_search(text: String) -> void:
	_searching = text.strip_edges().length() >= 2
	_refresh_inspector()


## Matches on label, path and section so "hammer", "dash_cooldown" and "paladin" all work.
## Results are re-sectioned by their path prefix, since a flat list of matches from six
## categories is meaningless without saying where each one lives.
func _search_results() -> Array[BalanceField]:
	var q: String = _search.text.strip_edges().to_lower()
	var out: Array[BalanceField] = []
	for f: BalanceField in BalanceRegistry.all_fields():
		if f.label.to_lower().contains(q) or f.path.to_lower().contains(q) \
				or f.section.to_lower().contains(q):
			var copy: BalanceField = f
			copy.section = _domain_of(f.path)
			out.append(copy)
	out.sort_custom(func(a: BalanceField, b: BalanceField) -> bool:
		if a.section == b.section:
			return a.label < b.label
		return a.section < b.section)
	return out


static func _domain_of(path: String) -> String:
	var parts: PackedStringArray = path.split("/")
	if parts.size() >= 2:
		return "%s · %s" % [parts[0].to_upper(), parts[1]]
	return parts[0].to_upper() if parts.size() > 0 else "?"


# ─── Apply / save ─────────────────────────────────────────────────────────────

## Push the override layer into the running game.
##
## Three tiers, because they reach the game differently:
##   enemies     — mutate the cached EnemyDefinitions (affects everything spawned after)
##   spawn/curve — re-read the plain vars that are not read per-use
##   player      — full in-place rebuild of stats, weapon, kit and hitbox
func _apply_to_game() -> void:
	EnemyRegistry.apply_balance_overrides()
	if EnemySpawnManager and EnemySpawnManager.has_method("apply_balance_overrides"):
		EnemySpawnManager.apply_balance_overrides()
	if player_ref and is_instance_valid(player_ref) and player_ref.has_method("debug_reload_balance"):
		player_ref.debug_reload_balance()


func _do_apply() -> void:
	_apply_to_game()
	_set_status("applied to the running game")


func _do_save() -> void:
	if BalanceOverrides.save():
		_set_status("saved %s (%d overrides)" % [BalanceOverrides.PATH, BalanceOverrides.override_count()])
	else:
		_set_status("SAVE FAILED — is this an exported build?", true)
	_refresh_header()


func _do_revert_all() -> void:
	var n: int = BalanceOverrides.override_count()
	BalanceOverrides.clear_all()
	_apply_to_game()
	_refresh_nav()
	_refresh_inspector()
	_refresh_header()
	_set_status("cleared %d override%s — not saved yet" % [n, "" if n == 1 else "s"])


## Drop overrides that can no longer do anything: paths that match no field (a renamed combo
## phase, a deleted weapon) and paths whose value equals shipped. Both are how an override
## file quietly fills with lies about what is actually tuned.
func _do_prune() -> void:
	var orphans: Array[String] = BalanceRegistry.orphaned_paths()
	var noops: Array[String] = BalanceRegistry.noop_paths()
	for p: String in orphans:
		BalanceOverrides.clear_value(p)
	for p: String in noops:
		BalanceOverrides.clear_value(p)
	_refresh_nav()
	_refresh_inspector()
	_refresh_header()
	_set_status("pruned %d orphaned, %d no-op" % [orphans.size(), noops.size()])


func _do_bake() -> void:
	var report: Dictionary = BalanceBaker.bake()
	_apply_to_game()
	_refresh_nav()
	_refresh_inspector()
	_refresh_header()
	var failed: Array = report.get("skipped", [])
	if failed.is_empty():
		_set_status("baked %d value%s into source · %d file%s rewritten" % [
			int(report.get("written", 0)), "" if int(report.get("written", 0)) == 1 else "s",
			int(report.get("files", 0)), "" if int(report.get("files", 0)) == 1 else "s"])
	else:
		_set_status("baked %d · %d NOT bakeable (kept as overrides) — see output log" % [
			int(report.get("written", 0)), failed.size()], true)
		for line: String in failed:
			print("[UnitEditor] not bakeable: ", line)


# ─── Profiles & chrome ────────────────────────────────────────────────────────

func _on_profile_picked(idx: int) -> void:
	if _rebuilding:
		return
	var name: String = _profile_btn.get_item_text(idx)
	if BalanceOverrides.set_active_profile(name):
		_apply_to_game()
		_refresh_nav()
		_refresh_inspector()
		_refresh_header()
		_set_status("profile: %s" % name)


func _on_new_profile() -> void:
	## Named by count rather than prompting: a modal text dialog for a throwaway A/B slot is
	## more friction than the thing is worth, and it can be renamed in the JSON.
	var n: int = BalanceOverrides.profile_names().size()
	var name: String = "tuning_%d" % n
	while BalanceOverrides.profile_names().has(name):
		n += 1
		name = "tuning_%d" % n
	BalanceOverrides.create_profile(name, true)
	_refresh_header()
	_set_status("new profile '%s' (copied from the last one)" % name)


func _refresh_header() -> void:
	_rebuilding = true
	if _profile_btn:
		_profile_btn.clear()
		var names: Array[String] = BalanceOverrides.profile_names()
		for i in range(names.size()):
			_profile_btn.add_item(names[i], i)
			if names[i] == BalanceOverrides.active_profile():
				_profile_btn.select(i)
	if _changes_lbl:
		var n: int = BalanceOverrides.override_count()
		var orphans: int = 0
		_changes_lbl.text = "%d override%s%s" % [n, "" if n == 1 else "s",
				"  ·  unsaved" if BalanceOverrides.is_dirty() else ""]
		_changes_lbl.add_theme_color_override("font_color",
				C_ACCENT if BalanceOverrides.is_dirty() else C_DIM)
		orphans = orphans
	if _save_btn:
		_save_btn.disabled = not BalanceOverrides.is_dirty()
	_rebuilding = false


func _set_status(msg: String, warn: bool = false) -> void:
	if _status_lbl == null:
		return
	_status_lbl.text = msg
	_status_lbl.add_theme_color_override("font_color", C_WARN if warn else C_DIM)
