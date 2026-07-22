extends CanvasLayer

## AnimLabPanel — Ben's animation workbench (F10, debug mode only).
##
## Edits how the current character's animations are sliced and timed, without touching code.
## Everything saves to res://data/anim_overrides.json and rebuilds the live player instantly.
##
## Three axes of control:
##   TRIM/TIME   from/to sheet columns + fps.
##   STAGES      cut a held ability into intro (plays once) / loop (repeats while held) /
##               outro (plays on release). Any channel body with a "loop" stage picks this up
##               automatically — no per-ability code.
##   DIRECTION   each facing row can carry its own trim, fps, sheet ROW and HIT FRAME, so a
##               pack whose rows disagree (or whose contact lands on a different frame facing
##               left vs right) can be corrected per direction.
##
## The frame strip under the preview is the hit-frame tool: it draws one cell per frame, marks
## the hit frame gold, tracks the playing frame in white, and clicking a cell pins the hit
## there. PAUSE + ◀ ▶ step frame by frame so the impact can be lined up exactly.
##
## Ranges are inclusive, 0-based columns. Hit frame is an index into the TRIMMED animation
## (-1 = keep whatever the kit code authored).

const STAGES: Array[String] = ["whole", "intro", "loop", "outro"]
const SEQUENCE_ITEM: int = 4
## Facing option order; index 0 = "all" (edit the anim as a whole). The four DIAGONALS come from
## a normal sheet; the four CARDINALS only render for anims wired with an orthogonal companion
## sheet ({"ortho": …}) or flagged {"cardinal": true} — for other anims their preview just falls
## back to the nearest diagonal. DIR_ROWS holds each facing's DEFAULT sheet row (diagonals per the
## quadrant order, cardinals per CharacterSpriteFactory.CARDINAL_ROWS); a facing override only
## writes "row" when it differs from this default.
const FACINGS: Array[String] = ["all", "down_right", "down_left", "up_right", "up_left",
		"down", "up", "left", "right"]
const FACING_LABELS: Array[String] = ["ALL DIRS", "DOWN-RIGHT", "DOWN-LEFT", "UP-RIGHT", "UP-LEFT",
		"DOWN", "UP", "LEFT", "RIGHT"]
const DIR_ROWS: Dictionary = {"down_right": 0, "down_left": 1, "up_right": 2, "up_left": 3,
		"down": 0, "up": 1, "right": 2, "left": 3}
const FS: int = 11        ## body font size — matches DebugPanel; the pixel font is NOT used
const FS_TITLE: int = 12  ## here because m5x7 below its native size renders illegibly
const CONTENT_W: float = 224.0   ## usable width inside the scrollbar; nothing may exceed it
const NO_ANIM: String = "(use columns)"   ## stage falls back to a from/to slice
const NO_FX: String = "(no overlay)"


## One clickable cell per frame: gold = hit frame, white outline = frame playing now.
class FrameStrip extends Control:
	signal frame_clicked(index: int)

	var frame_count: int = 0
	var current_frame: int = 0
	var hit_frame: int = -1

	func _ready() -> void:
		custom_minimum_size = Vector2(0.0, 12.0)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		if frame_count <= 0:
			return
		var w: float = size.x / float(frame_count)
		for i in range(frame_count):
			var r := Rect2(i * w + 1.0, 0.0, maxf(w - 2.0, 1.0), size.y)
			var col := Color(0.22, 0.22, 0.28)
			if i == hit_frame:
				col = Color(1.0, 0.78, 0.20)
			draw_rect(r, col)
			if i == current_frame:
				draw_rect(r, Color(1.0, 1.0, 1.0), false, 1.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT and frame_count > 0:
			var w: float = size.x / float(frame_count)
			frame_clicked.emit(clampi(int(event.position.x / w), 0, frame_count - 1))


var player_ref: Node2D = null

var _panel: PanelContainer = null
var _anim_select: OptionButton = null
var _input_select: OptionButton = null
var _usage_label: Label = null
var _dir_select: OptionButton = null
var _dir_on: CheckBox = null
var _stage_select: OptionButton = null
var _stage_on: CheckBox = null
var _stage_anim_select: OptionButton = null
var _stage_fx_select: OptionButton = null
var _png_select: OptionButton = null
var _import_info: Label = null
var _preview: AnimatedSprite2D = null
var _preview_box: Panel = null
var _strip: FrameStrip = null
var _frame_label: Label = null
var _info_label: Label = null
var _from_spin: SpinBox = null
var _to_spin: SpinBox = null
var _fps_spin: SpinBox = null
var _row_spin: SpinBox = null
var _hit_spin: SpinBox = null
var _pause_btn: Button = null
var _status_label: Label = null

var _char_id: String = ""
var _sheet_cols: int = 0
var _sheet_rows: int = 0
var _default_count: int = 0
var _default_fps: float = 10.0
var _cur_stage: String = "whole"
var _cur_facing: String = "all"
var _paused: bool = false
var _loading: bool = false

## Edit state for the selected anim.
##   _base: {from, to, fps, hit_frame}
##   _stage_ranges / _stage_on_flags: stage segments
##   _dirs: facing -> {from, to, fps, row, hit_frame}; only facings in _dir_on_flags are saved
var _base: Dictionary = {}
var _stage_ranges: Dictionary = {}
var _stage_on_flags: Dictionary = {}
var _stage_raw: Dictionary = {}
var _stage_dirty: Dictionary = {}
var _dirs: Dictionary = {}
var _dir_on_flags: Dictionary = {}
## anim name -> ["LMB chain step 2 (tap LMB) [finisher]", …]; and the flat input picker list.
var _usage: Dictionary = {}
var _input_entries: Array = []
## stage -> animation name it plays whole ("" = use the from/to columns), and its overlay.
var _stage_anim: Dictionary = {}
var _stage_fx: Dictionary = {}
## Scanned PNG paths from the character's asset pack, for the import row.
var _png_paths: Array = []


func _ready() -> void:
	layer = 127
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()


func setup(player: Node2D) -> void:
	player_ref = player
	_char_id = ProgressionManager.selected_character
	_populate_anims()


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.debug_mode:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		_panel.visible = not _panel.visible
		if _panel.visible:
			## The training room can swap character out from under us.
			if _char_id != ProgressionManager.selected_character:
				_char_id = ProgressionManager.selected_character
				_populate_anims()
			else:
				_reload_selected()


func _process(_delta: float) -> void:
	if not _panel.visible or _preview == null or _preview.sprite_frames == null:
		return
	var total: int = _preview.sprite_frames.get_frame_count(_preview.animation)
	var cur: int = _preview.frame
	var hit: int = int(_hit_spin.value)
	_frame_label.text = "frame %d / %d%s" % [cur, maxi(total - 1, 0),
			"   ** HIT **" if cur == hit else ""]
	if _strip:
		_strip.current_frame = cur
		_strip.hit_frame = hit
		_strip.frame_count = total
		_strip.queue_redraw()
	## Flash the preview backdrop on the impact frame so it reads in motion, not just paused.
	if _preview_box:
		var sb: StyleBoxFlat = _preview_box.get_theme_stylebox("panel")
		if sb:
			sb.bg_color = Color(0.34, 0.26, 0.08) if cur == hit else Color(0.10, 0.10, 0.14)


# ─── Panel construction ───────────────────────────────────────────────────────

func _build_panel() -> void:
	var pc := PanelContainer.new()
	## Pin to the viewport's RIGHT edge and grow leftward, so the panel can never overrun the
	## right side no matter how wide its content wants to be (Ben, 2026-07-20 — it kept
	## clipping). The content is width-capped separately by CONTENT_W.
	pc.anchor_left = 1.0
	pc.anchor_right = 1.0
	pc.anchor_top = 0.0
	pc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pc.offset_right = -4.0
	pc.offset_top = 10.0
	pc.visible = false
	_panel = pc
	add_child(pc)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.04, 0.08, 0.95)
	bg.set_corner_radius_all(3)
	bg.set_content_margin_all(5.0)
	pc.add_theme_stylebox_override("panel", bg)

	## Scrolls so the panel can never run off a 360px-tall viewport (CLAUDE.md: SHOW_AS_NEEDED,
	## never clip).
	## CONTENT_W is the usable width inside the scrollbar. No child may declare a minimum
	## wider than this or the whole column overflows to the right — that's what clipped v2.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(CONTENT_W + 14.0, 330.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	pc.add_child(scroll)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.custom_minimum_size = Vector2(CONTENT_W, 0.0)
	scroll.add_child(v)

	v.add_child(_label("ANIMATION LAB  (F10)", FS_TITLE, Color(1.0, 0.85, 0.3)))

	## Input-first picker: choose the press/hold you want to edit and it jumps to the
	## animation that press actually plays. (Anim names alone don't tell you which button
	## triggers them — Ben, 2026-07-20.)
	v.add_child(_label("pick by input:", FS, Color(0.6, 0.65, 0.7)))
	_input_select = _option([], _on_input_picked)
	_input_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_input_select)

	v.add_child(_label("or by animation:", FS, Color(0.6, 0.65, 0.7)))
	_anim_select = _option([], func(_i: int) -> void: _reload_selected())
	_anim_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_anim_select)

	_usage_label = _wrap_label(Color(0.55, 0.85, 1.0))
	v.add_child(_usage_label)

	_preview_box = Panel.new()
	_preview_box.custom_minimum_size = Vector2(CONTENT_W, 74.0)
	var box_bg := StyleBoxFlat.new()
	box_bg.bg_color = Color(0.10, 0.10, 0.14, 1.0)
	box_bg.set_corner_radius_all(2)
	_preview_box.add_theme_stylebox_override("panel", box_bg)
	v.add_child(_preview_box)
	_preview = AnimatedSprite2D.new()
	_preview.position = Vector2(CONTENT_W * 0.5, 40.0)
	_preview.scale = Vector2(2.0, 2.0)
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview_box.add_child(_preview)

	## Hit-frame timeline.
	_strip = FrameStrip.new()
	_strip.custom_minimum_size = Vector2(CONTENT_W, 12.0)
	_strip.size_flags_horizontal = Control.SIZE_FILL
	_strip.frame_clicked.connect(_on_strip_clicked)
	v.add_child(_strip)

	var play_row := HBoxContainer.new()
	play_row.add_theme_constant_override("separation", 3)
	v.add_child(play_row)
	_frame_label = _label("frame 0 / 0", FS, Color(0.85, 0.85, 0.9))
	_frame_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_row.add_child(_frame_label)
	play_row.add_child(_button("<", func() -> void: _step(-1), 20.0))
	_pause_btn = _button("||", _toggle_pause, 22.0)
	play_row.add_child(_pause_btn)
	play_row.add_child(_button(">", func() -> void: _step(1), 20.0))

	_info_label = _wrap_label(Color(0.6, 0.65, 0.7))
	v.add_child(_info_label)

	## Direction row.
	var dir_row := HBoxContainer.new()
	dir_row.add_theme_constant_override("separation", 3)
	v.add_child(dir_row)
	_dir_select = _option(FACING_LABELS, _on_dir_changed)
	_dir_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dir_row.add_child(_dir_select)
	_dir_on = _check("edit", _on_dir_toggled)
	dir_row.add_child(_dir_on)

	## Stage row.
	var stage_row := HBoxContainer.new()
	stage_row.add_theme_constant_override("separation", 3)
	v.add_child(stage_row)
	var stage_items: Array[String] = []
	for s in STAGES:
		stage_items.append(s.to_upper())
	stage_items.append("SEQUENCE")
	_stage_select = _option(stage_items, _on_stage_changed)
	_stage_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_row.add_child(_stage_select)
	_stage_on = _check("on", _on_stage_toggled)
	stage_row.add_child(_stage_on)

	## A stage can play a WHOLE other animation (its own PNG) instead of a slice of this
	## sheet, with its own overlay — e.g. dome intro, then DomeCycle looping under it.
	var sanim_row := HBoxContainer.new()
	sanim_row.add_theme_constant_override("separation", 3)
	v.add_child(sanim_row)
	sanim_row.add_child(_label("plays", FS, Color(0.85, 0.85, 0.9)))
	_stage_anim_select = _option([], _on_stage_anim_picked)
	_stage_anim_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sanim_row.add_child(_stage_anim_select)

	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 3)
	v.add_child(sfx_row)
	sfx_row.add_child(_label("  + fx", FS, Color(0.85, 0.85, 0.9)))
	_stage_fx_select = _option([], _on_stage_fx_picked)
	_stage_fx_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_row.add_child(_stage_fx_select)

	var range_row := HBoxContainer.new()
	range_row.add_theme_constant_override("separation", 3)
	v.add_child(range_row)
	_from_spin = _spin(range_row, "From", 0.0, 0.0, 63.0, 1.0)
	_to_spin = _spin(range_row, "To", 0.0, 0.0, 63.0, 1.0)

	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 3)
	v.add_child(time_row)
	_fps_spin = _spin(time_row, "FPS", 10.0, 1.0, 60.0, 0.5)
	_row_spin = _spin(time_row, "Row", 0.0, 0.0, 7.0, 1.0)

	var hit_row := HBoxContainer.new()
	hit_row.add_theme_constant_override("separation", 3)
	v.add_child(hit_row)
	_hit_spin = _spin(hit_row, "Hit", -1.0, -1.0, 63.0, 1.0)
	hit_row.add_child(_button("SET HIT = FRAME", _set_hit_to_current))

	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 3)
	v.add_child(act_row)
	act_row.add_child(_button("REPLAY", _replay_preview))
	act_row.add_child(_button("APPLY+SAVE", _apply_and_save))
	act_row.add_child(_button("CLEAR", _clear_override))

	_status_label = _wrap_label(Color(0.5, 0.9, 0.5))
	v.add_child(_status_label)

	## ── Import a PNG from the character's own asset pack ──────────────────────
	v.add_child(_label("─ import sheet ─", FS, Color(0.7, 0.6, 0.35)))
	_png_select = _option([], func(_i: int) -> void: _refresh_import_info())
	v.add_child(_png_select)
	_import_info = _wrap_label(Color(0.6, 0.65, 0.7))
	v.add_child(_import_info)
	var imp_row := HBoxContainer.new()
	imp_row.add_theme_constant_override("separation", 3)
	v.add_child(imp_row)
	imp_row.add_child(_button("SCAN PACK", _scan_pack))
	imp_row.add_child(_button("IMPORT AS ANIM", _import_selected_png))


## Default theme font only — m5x7 below its native size is what made v1 unreadable.
func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Wrapping label constrained to the column width — long text must never widen the panel.
func _wrap_label(color: Color) -> Label:
	var l := _label("", FS, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(CONTENT_W, 0.0)
	l.size_flags_horizontal = Control.SIZE_FILL
	return l


func _button(text: String, cb: Callable, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", FS)
	if min_w > 0.0:
		b.custom_minimum_size = Vector2(min_w, 15.0)
	b.pressed.connect(cb)
	return b


func _option(items: Array, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.add_theme_font_size_override("font_size", FS)
	## Without these, an OptionButton's MINIMUM width grows to its longest item — a long input
	## label ("LMB chain step 2 (tap LMB) [finisher] ▸ bash") would then force the whole panel
	## wider than the viewport and clip the right edge (Ben, 2026-07-20). Clip instead.
	o.fit_to_longest_item = false
	o.clip_text = true
	o.custom_minimum_size = Vector2(60.0, 16.0)
	for it in items:
		o.add_item(str(it))
	o.item_selected.connect(cb)
	return o


func _check(text: String, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.add_theme_font_size_override("font_size", FS)
	c.toggled.connect(cb)
	return c


func _spin(parent: HBoxContainer, label_text: String, value: float,
		min_v: float, max_v: float, step: float) -> SpinBox:
	parent.add_child(_label(label_text, FS, Color(0.85, 0.85, 0.9)))
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(56.0, 15.0)
	s.add_theme_font_size_override("font_size", FS)
	## SpinBox renders through an internal LineEdit — without this the numbers keep the
	## theme's default (much larger) size, which is what made v1 look mismatched.
	s.get_line_edit().add_theme_font_size_override("font_size", FS)
	s.value_changed.connect(func(_v: float) -> void:
		if _loading:
			return
		_commit_edits()
		_replay_preview())
	parent.add_child(s)
	return s


# ─── State ────────────────────────────────────────────────────────────────────

## Walk the player's LIVE kit graphs and record which input plays which animation, so the
## panel can answer "what does this button press actually play?" — and so picking a press
## jumps straight to the right animation. Reads the built kit (class mods included), not the
## factory source.
func _build_usage() -> void:
	_usage = {}
	_input_entries = []
	if player_ref == null or not is_instance_valid(player_ref):
		return
	var graphs: Array = [
		["LMB chain", player_ref.get("_combo_ability")],
		["RMB tap", player_ref.get("_combo_heavy")],
		["RMB hold", player_ref.get("_combo_channel")],
	]
	var sc = player_ref.get("skill_component")
	if sc:
		graphs.append(["Q skill", sc.get_skill("skill_q")])
		graphs.append(["E skill", sc.get_skill("skill_e")])

	for g in graphs:
		var gname: String = g[0]
		var ab = g[1]
		if ab == null or ab.choreography == null:
			continue
		var phases: Array = ab.choreography.phases
		## Which inputs branch INTO each phase index.
		var incoming: Dictionary = {}
		for i in range(phases.size()):
			for b in phases[i].branches:
				if b.next_phase < 0:
					continue
				var lbl: String = _branch_label(b.condition)
				if lbl == "":
					continue
				if not incoming.has(b.next_phase):
					incoming[b.next_phase] = []
				if not incoming[b.next_phase].has(lbl):
					incoming[b.next_phase].append(lbl)

		for i in range(phases.size()):
			var ph: ChoreographyPhase = phases[i]
			if ph.animation == "":
				continue
			var desc: String = gname
			desc += " start" if i == 0 else " step %d" % i
			if incoming.has(i):
				desc += " (%s)" % ", ".join(incoming[i])
			if ph.is_finisher:
				desc += " [finisher]"
			if ph.hold_anim_on_reentry:
				desc += " [HOLD BODY: stages apply]"
			if not _usage.has(ph.animation):
				_usage[ph.animation] = []
			_usage[ph.animation].append(desc)
			_input_entries.append({"label": desc, "anim": ph.animation})


func _branch_label(c: Resource) -> String:
	if c is ConditionInputBuffered:
		return "tap LMB" if c.action == "light_attack" else "tap RMB"
	if c is ConditionInputHeld:
		var btn: String = "LMB" if c.action == "light_attack" else "RMB"
		return ("release " + btn) if c.negate else ("hold " + btn)
	return ""


## What plays this animation, plus whether stages are meaningful for it.
func _refresh_usage_label(anim: String) -> void:
	if _usage_label == null:
		return
	var lines: Array = _usage.get(anim, [])
	if lines.is_empty():
		## Overlay sheets ("<anim>_fx") ride their base animation rather than a phase.
		if anim.ends_with("_fx") and _usage.has(anim.trim_suffix("_fx")):
			_usage_label.text = "overlay for '%s' — plays with it" % anim.trim_suffix("_fx")
		else:
			_usage_label.text = "not used by this character's kit"
		return
	_usage_label.text = "plays on: " + "  ·  ".join(lines)


func _populate_anims() -> void:
	_build_usage()
	_anim_select.clear()
	var anims: Dictionary = CharacterData.ALL.get(_char_id, {}).get("sprite", {}).get("anims", {})
	var names: Array = anims.keys()
	names.sort()
	for n in names:
		_anim_select.add_item(str(n))
	## Input picker mirrors the kit order (LMB chain → RMB tap → RMB hold → Q → E).
	_input_select.clear()
	for e in _input_entries:
		_input_select.add_item("%s  ▸ %s" % [e.label, e.anim])
	if _anim_select.item_count > 0:
		_anim_select.select(0)
		_reload_selected()


## Fill the stage "plays" / "+ fx" pickers with every animation this character can use
## (data-table entries plus PNGs imported through this panel).
func _populate_stage_anim_options() -> void:
	if _stage_anim_select == null:
		return
	var names: Array = CharacterSpriteFactory.all_anim_specs(_char_id).keys()
	names.sort()
	_stage_anim_select.clear()
	_stage_fx_select.clear()
	_stage_anim_select.add_item(NO_ANIM)
	_stage_fx_select.add_item(NO_FX)
	for n in names:
		_stage_anim_select.add_item(str(n))
		_stage_fx_select.add_item(str(n))


func _select_option(ob: OptionButton, text: String, fallback: int = 0) -> void:
	for i in range(ob.item_count):
		if ob.get_item_text(i) == text:
			ob.select(i)
			return
	ob.select(fallback)


func _on_stage_anim_picked(index: int) -> void:
	if _loading or _cur_stage in ["whole", "sequence"] or _cur_facing != "all":
		return
	var t: String = _stage_anim_select.get_item_text(index)
	_stage_anim[_cur_stage] = "" if t == NO_ANIM else t
	_stage_dirty[_cur_stage] = true
	_stage_on_flags[_cur_stage] = true
	_loading = true
	_stage_on.button_pressed = true
	_loading = false
	_replay_preview()


func _on_stage_fx_picked(index: int) -> void:
	if _loading or _cur_stage in ["whole", "sequence"] or _cur_facing != "all":
		return
	var t: String = _stage_fx_select.get_item_text(index)
	_stage_fx[_cur_stage] = "" if t == NO_FX else t
	_stage_dirty[_cur_stage] = true
	_stage_on_flags[_cur_stage] = true


# ─── PNG import ───────────────────────────────────────────────────────────────

## Every .png under the character's asset pack (the folder above General_Animations), so
## unused sheets in Special_Animations/ can be wired up without editing characters.gd.
func _scan_pack() -> void:
	_png_paths.clear()
	_png_select.clear()
	var base: String = str(_sprite_meta().get("dir", ""))
	if base == "":
		_status_label.text = "character has no sprite dir"
		return
	var root: String = base.trim_suffix("/").get_base_dir()
	_collect_pngs(root, _png_paths, 0)
	_png_paths.sort()
	for p in _png_paths:
		## Show the tail of the path — pack roots are very long.
		_png_select.add_item(str(p).replace(root + "/", ""))
	_status_label.text = "found %d PNGs" % _png_paths.size()
	_refresh_import_info()


func _collect_pngs(dir_path: String, out: Array, depth: int) -> void:
	if depth > 4 or out.size() > 400:
		return
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry: String = d.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = d.get_next()
			continue
		var full: String = dir_path + "/" + entry
		if d.current_is_dir():
			## Skip the packs' GIF preview and shadow folders — never gameplay frames.
			if entry != "GIFs" and entry != "Shadows":
				_collect_pngs(full, out, depth + 1)
		elif entry.ends_with(".png"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()


func _selected_png() -> String:
	var i: int = _png_select.selected
	if i < 0 or i >= _png_paths.size():
		return ""
	return str(_png_paths[i])


## Derive a snake_case anim name from a sheet filename, dropping the pack's long prefixes.
func _derive_anim_name(path: String) -> String:
	var base: String = path.get_file().get_basename()
	base = base.replace("Minifantasy_", "").replace("TrueHeroes", "")
	var out: String = ""
	for i in range(base.length()):
		var c: String = base[i]
		if c == "_" or c == "-" or c == " ":
			out += "_"
			continue
		if c.to_upper() == c and c.to_lower() != c and out.length() > 0 \
				and not out.ends_with("_"):
			out += "_"
		out += c.to_lower()
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.strip_edges().trim_prefix("_").trim_suffix("_")


func _refresh_import_info() -> void:
	var p: String = _selected_png()
	if p == "" or _import_info == null:
		return
	var frame_size: int = int(_sprite_meta().get("frame_size", 32))
	var tex: Texture2D = load(p) if ResourceLoader.exists(p) else null
	if tex == null:
		_import_info.text = "cannot load that PNG"
		return
	_import_info.text = "-> '%s'  %d cols x %d rows" % [
			_derive_anim_name(p),
			int(tex.get_width() / float(frame_size)),
			int(tex.get_height() / float(frame_size))]


## Register the selected PNG as a usable animation for this character. It then behaves exactly
## like a data-table animation: trimmable, stageable, selectable as a stage's "plays" source.
func _import_selected_png() -> void:
	var p: String = _selected_png()
	if p == "":
		_status_label.text = "scan, then pick a PNG"
		return
	var frame_size: int = int(_sprite_meta().get("frame_size", 32))
	var tex: Texture2D = load(p) if ResourceLoader.exists(p) else null
	if tex == null:
		_status_label.text = "cannot load that PNG"
		return
	var cols: int = int(tex.get_width() / float(frame_size))
	var name: String = _derive_anim_name(p)
	if name == "":
		_status_label.text = "could not derive a name"
		return
	if CharacterSpriteFactory.save_custom_anim(_char_id, name, p, cols, 16.0):
		_rebuild_player()
		_populate_anims()
		_select_option(_anim_select, name)
		_reload_selected()
		_status_label.text = "imported '%s' (%d fr) — now selectable" % [name, cols]
	else:
		_status_label.text = "SAVE FAILED (not writable)"


func _on_input_picked(index: int) -> void:
	if index < 0 or index >= _input_entries.size():
		return
	var target: String = str(_input_entries[index].anim)
	for i in range(_anim_select.item_count):
		if _anim_select.get_item_text(i) == target:
			_anim_select.select(i)
			_reload_selected()
			return
	_status_label.text = "no sheet entry for '%s'" % target


func _selected_anim() -> String:
	if _anim_select.item_count == 0:
		return ""
	return _anim_select.get_item_text(_anim_select.selected)


func _sprite_meta() -> Dictionary:
	return CharacterData.ALL.get(_char_id, {}).get("sprite", {})


func _anim_sheet_path() -> String:
	var meta: Dictionary = _sprite_meta()
	var spec: Array = meta.get("anims", {}).get(_selected_anim(), [])
	if spec.size() < 3:
		return ""
	## For a CARDINAL facing on an anim with an orthogonal companion sheet, preview THAT sheet —
	## its rows are the cardinals. (A {"cardinal": true} sheet has no ortho: its cardinals live in
	## the main sheet, so the default path below is already correct.)
	if _cur_facing in ["down", "up", "left", "right"] and spec.size() >= 4 and spec[3] is Dictionary:
		var o: String = str(spec[3].get("ortho", ""))
		if o != "":
			return o if o.begins_with("res://") else str(meta.get("dir", "")) + o
	var raw: String = str(spec[0])
	return raw if raw.begins_with("res://") else str(meta.get("dir", "")) + raw


func _reload_selected() -> void:
	var anim: String = _selected_anim()
	if anim == "":
		return
	var meta: Dictionary = _sprite_meta()
	var spec: Array = meta.get("anims", {}).get(anim, [])
	if spec.size() < 3:
		return
	_cur_facing = "all"   ## reset before measuring the sheet, so dims come from the MAIN sheet
	var frame_size: int = int(meta.get("frame_size", 32))
	_default_count = int(spec[1])
	_default_fps = float(spec[2])
	_sheet_cols = 0
	_sheet_rows = 0
	var path: String = _anim_sheet_path()
	if path != "" and ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		if tex:
			_sheet_cols = int(tex.get_width() / float(frame_size))
			_sheet_rows = int(tex.get_height() / float(frame_size))

	var ov: Dictionary = CharacterSpriteFactory.get_anim_override(_char_id, anim)
	_base = {
		"from": int(ov.get("from", 0)),
		"to": int(ov.get("to", _default_count - 1)),
		"fps": float(ov.get("fps", _default_fps)),
		"hit_frame": int(ov.get("hit_frame", -1)),
	}

	## Stages.
	_stage_ranges = {"whole": [int(_base.from), int(_base.to)]}
	_stage_on_flags = {}
	_stage_raw = {}
	_stage_dirty = {}
	var saved_stages = ov.get("stages", {})
	var thirds: int = maxi(int(_default_count / 3.0), 1)
	_stage_anim = {}
	_stage_fx = {}
	for i in range(1, STAGES.size()):
		var s: String = STAGES[i]
		_stage_anim[s] = ""
		_stage_fx[s] = ""
		if saved_stages is Dictionary and saved_stages.has(s):
			var r = saved_stages[s]
			_stage_raw[s] = r
			if r is Dictionary:
				_stage_ranges[s] = [int(r.get("from", 0)), int(r.get("to", 0))]
				_stage_anim[s] = str(r.get("anim", ""))
				_stage_fx[s] = str(r.get("fx", ""))
			else:
				_stage_ranges[s] = [int(r[0]), int(r[1])]
			_stage_on_flags[s] = true
		else:
			var lo: int = (i - 1) * thirds
			var hi: int = (thirds * i - 1) if i < 3 else (_default_count - 1)
			_stage_ranges[s] = [lo, maxi(hi, lo)]
	_populate_stage_anim_options()

	## Per-direction entries.
	_dirs = {}
	_dir_on_flags = {}
	var saved_dirs = ov.get("dirs", {})
	for facing in DIR_ROWS:
		var d: Dictionary = {
			"from": int(_base.from), "to": int(_base.to), "fps": float(_base.fps),
			"row": int(DIR_ROWS[facing]), "hit_frame": int(_base.hit_frame),
		}
		if saved_dirs is Dictionary and saved_dirs.has(facing) and saved_dirs[facing] is Dictionary:
			var sd: Dictionary = saved_dirs[facing]
			for k in ["from", "to", "fps", "row", "hit_frame"]:
				if sd.has(k):
					d[k] = float(sd[k]) if k == "fps" else int(sd[k])
			_dir_on_flags[facing] = true
		_dirs[facing] = d

	_loading = true
	_stage_select.select(0)
	_cur_stage = "whole"
	_dir_select.select(0)
	_cur_facing = "all"
	_load_edits_into_spins()
	_loading = false

	var notes: String = ""
	if not _stage_on_flags.is_empty():
		notes += " staged:%d" % _stage_on_flags.size()
	if not _dir_on_flags.is_empty():
		notes += " dirs:%d" % _dir_on_flags.size()
	_info_label.text = "%dx%d sheet · table %d fr @ %.0f%s" % [
			_sheet_cols, _sheet_rows, _default_count, _default_fps, notes]
	_refresh_usage_label(anim)
	_replay_preview()


## Push the current selection's values into the spinboxes.
func _load_edits_into_spins() -> void:
	var was: bool = _loading
	_loading = true
	if _cur_facing != "all":
		var d: Dictionary = _dirs[_cur_facing]
		_from_spin.value = float(d.from)
		_to_spin.value = float(d.to)
		_fps_spin.value = float(d.fps)
		_row_spin.value = float(d.row)
		_hit_spin.value = float(d.hit_frame)
		_row_spin.editable = true
		_dir_on.button_pressed = _dir_on_flags.has(_cur_facing)
		_dir_on.disabled = false
	else:
		var r: Array = _stage_ranges.get(_cur_stage, [int(_base.from), int(_base.to)])
		_from_spin.value = float(r[0])
		_to_spin.value = float(r[1])
		_fps_spin.value = float(_base.fps)
		_row_spin.value = 0.0
		_hit_spin.value = float(_base.hit_frame)
		_row_spin.editable = false   ## row only means something for a specific facing
		_dir_on.button_pressed = false
		_dir_on.disabled = true
	_stage_on.button_pressed = _cur_stage == "whole" or _stage_on_flags.has(_cur_stage)
	_stage_on.disabled = _cur_stage == "whole" or _cur_facing != "all"
	_stage_select.disabled = _cur_facing != "all"
	## "plays / + fx" only apply to a real stage on the all-directions view.
	var stage_editable: bool = _cur_facing == "all" and not (_cur_stage in ["whole", "sequence"])
	_stage_anim_select.disabled = not stage_editable
	_stage_fx_select.disabled = not stage_editable
	if stage_editable:
		var a: String = str(_stage_anim.get(_cur_stage, ""))
		var fx: String = str(_stage_fx.get(_cur_stage, ""))
		_select_option(_stage_anim_select, a if a != "" else NO_ANIM)
		_select_option(_stage_fx_select, fx if fx != "" else NO_FX)
	else:
		_stage_anim_select.select(0)
		_stage_fx_select.select(0)
	_loading = was


## Pull spinbox values back into whichever slot is selected.
func _commit_edits() -> void:
	if _cur_facing != "all":
		var d: Dictionary = _dirs[_cur_facing]
		d.from = int(_from_spin.value)
		d.to = int(_to_spin.value)
		d.fps = _fps_spin.value
		d.row = int(_row_spin.value)
		d.hit_frame = int(_hit_spin.value)
		## Touching a direction's numbers is the intent to author it.
		_dir_on_flags[_cur_facing] = true
		_loading = true
		_dir_on.button_pressed = true
		_loading = false
		return
	if _cur_stage != "sequence":
		var now: Array = [int(_from_spin.value), int(_to_spin.value)]
		if _stage_ranges.get(_cur_stage, []) != now:
			_stage_dirty[_cur_stage] = true
		_stage_ranges[_cur_stage] = now
		if _cur_stage == "whole":
			_base.from = now[0]
			_base.to = now[1]
	_base.fps = _fps_spin.value
	_base.hit_frame = int(_hit_spin.value)


func _on_dir_changed(index: int) -> void:
	_commit_edits()
	_cur_facing = FACINGS[index]
	_load_edits_into_spins()
	_replay_preview()


func _on_dir_toggled(pressed: bool) -> void:
	if _loading or _cur_facing == "all":
		return
	if pressed:
		_dir_on_flags[_cur_facing] = true
	else:
		_dir_on_flags.erase(_cur_facing)


func _on_stage_changed(index: int) -> void:
	_commit_edits()
	if index == SEQUENCE_ITEM:
		_cur_stage = "sequence"
		_loading = true
		_stage_on.button_pressed = false
		_stage_on.disabled = true
		_loading = false
		_replay_preview()
		return
	_cur_stage = STAGES[index]
	_load_edits_into_spins()
	_replay_preview()


func _on_stage_toggled(pressed: bool) -> void:
	if _loading or _cur_stage == "whole" or _cur_stage == "sequence":
		return
	if pressed:
		_stage_on_flags[_cur_stage] = true
	else:
		_stage_on_flags.erase(_cur_stage)


# ─── Preview ──────────────────────────────────────────────────────────────────

func _preview_row() -> int:
	if _cur_facing != "all":
		return clampi(int(_row_spin.value), 0, maxi(_sheet_rows - 1, 0))
	## "All dirs" previews the front-right row, the same one the base slice uses.
	return clampi(int(_sprite_meta().get("dir_row", 0)), 0, maxi(_sheet_rows - 1, 0))


## Sheet path / frame count / fps for any registered animation (table or imported).
func _spec_for(anim: String) -> Dictionary:
	var specs: Dictionary = CharacterSpriteFactory.all_anim_specs(_char_id)
	if not specs.has(anim):
		return {}
	var sp: Array = specs[anim]
	if sp.size() < 3:
		return {}
	var raw: String = str(sp[0])
	var p: String = raw if raw.begins_with("res://") else str(_sprite_meta().get("dir", "")) + raw
	if not ResourceLoader.exists(p):
		return {}
	return {"path": p, "count": int(sp[1]), "fps": float(sp[2])}


## Append one stage's frames to the preview list, following its "plays" animation when set.
func _append_stage_cells(stage: String, row: int, cells: Array) -> void:
	var frame_size: int = int(_sprite_meta().get("frame_size", 32))
	var s_anim: String = str(_stage_anim.get(stage, ""))
	if s_anim != "":
		var sp: Dictionary = _spec_for(s_anim)
		if sp.is_empty():
			return
		var t: Texture2D = load(sp.path)
		for i in range(int(sp.count)):
			cells.append([t, i, row, frame_size])
		return
	var r: Array = _stage_ranges.get(stage, [])
	if r.size() != 2:
		return
	var tex: Texture2D = load(_anim_sheet_path())
	if tex == null:
		return
	for i in range(clampi(int(r[0]), 0, _sheet_cols - 1), clampi(int(r[1]), 0, _sheet_cols - 1) + 1):
		cells.append([tex, i, row, frame_size])


func _replay_preview() -> void:
	var frame_size: int = int(_sprite_meta().get("frame_size", 32))
	var row: int = _preview_row()
	## Each cell is [texture, column, row, frame_size] so a preview can span several sheets
	## (a staged channel's segments may each come from their own PNG).
	var cells: Array = []
	var fps: float = maxf(_fps_spin.value, 1.0)
	var editing_stage: bool = _cur_facing == "all" and not (_cur_stage in ["whole", "sequence"])

	if _cur_facing == "all" and _cur_stage == "sequence":
		for s in ["intro", "loop", "outro"]:
			if _stage_on_flags.has(s):
				_append_stage_cells(s, row, cells)
		if cells.is_empty():
			_status_label.text = "no stages authored yet"
			return
	elif editing_stage and str(_stage_anim.get(_cur_stage, "")) != "":
		## Stage plays a whole other animation — preview THAT, at its own speed.
		var sp: Dictionary = _spec_for(str(_stage_anim[_cur_stage]))
		if sp.is_empty():
			_status_label.text = "stage anim '%s' has no sheet" % _stage_anim[_cur_stage]
			return
		var t: Texture2D = load(sp.path)
		fps = float(sp.fps)
		for i in range(int(sp.count)):
			cells.append([t, i, row, frame_size])
	else:
		var path: String = _anim_sheet_path()
		if path == "" or _sheet_cols <= 0 or not ResourceLoader.exists(path):
			return
		var tex: Texture2D = load(path)
		if tex == null:
			return
		var first: int = clampi(int(_from_spin.value), 0, _sheet_cols - 1)
		var last: int = clampi(int(_to_spin.value), first, _sheet_cols - 1)
		for i in range(first, last + 1):
			cells.append([tex, i, row, frame_size])

	var frames := SpriteFrames.new()
	frames.clear_all()
	frames.add_animation(&"lab")
	frames.set_animation_loop(&"lab", true)
	frames.set_animation_speed(&"lab", fps)
	for c in cells:
		var cell := AtlasTexture.new()
		cell.atlas = c[0]
		var fs: int = int(c[3])
		var src_rows: int = int(c[0].get_height() / float(fs)) if c[0] else 1
		cell.region = Rect2(int(c[1]) * fs, mini(int(c[2]), maxi(src_rows - 1, 0)) * fs, fs, fs)
		cell.filter_clip = true
		frames.add_frame(&"lab", cell)
	_preview.sprite_frames = frames
	_preview.play(&"lab")
	if _paused:
		_preview.pause()


func _toggle_pause() -> void:
	_paused = not _paused
	if _paused:
		_preview.pause()
	else:
		_preview.play(&"lab")
	_pause_btn.text = ">>" if _paused else "||"


func _step(delta_frames: int) -> void:
	if _preview.sprite_frames == null:
		return
	if not _paused:
		_toggle_pause()
	var total: int = _preview.sprite_frames.get_frame_count(_preview.animation)
	if total <= 0:
		return
	_preview.frame = wrapi(_preview.frame + delta_frames, 0, total)


func _on_strip_clicked(index: int) -> void:
	## Clicking the timeline pins the hit frame there — the fastest way to line up impact.
	_loading = true
	_hit_spin.value = float(index)
	_loading = false
	_commit_edits()
	_status_label.text = "hit frame -> %d (apply to keep)" % index


func _set_hit_to_current() -> void:
	if _preview.sprite_frames == null:
		return
	_loading = true
	_hit_spin.value = float(_preview.frame)
	_loading = false
	_commit_edits()
	_status_label.text = "hit frame -> %d (apply to keep)" % _preview.frame


# ─── Save / apply ─────────────────────────────────────────────────────────────

func _apply_and_save() -> void:
	var anim: String = _selected_anim()
	if anim == "":
		return
	_commit_edits()
	var data: Dictionary = {
		"from": int(_base.from),
		"to": int(_base.to),
		"fps": float(_base.fps),
	}
	if int(_base.hit_frame) >= 0:
		data["hit_frame"] = int(_base.hit_frame)

	var stages: Dictionary = {}
	for s in _stage_on_flags:
		## Untouched stages go back verbatim (preserves cross-sheet {"sheet": …} entries).
		if _stage_raw.has(s) and not _stage_dirty.has(s):
			stages[s] = _stage_raw[s]
			continue
		## A stage that plays a whole other animation stores that instead of a column range.
		var s_anim: String = str(_stage_anim.get(s, ""))
		if s_anim != "":
			var entry_stage: Dictionary = {"anim": s_anim}
			var s_fx: String = str(_stage_fx.get(s, ""))
			if s_fx != "":
				entry_stage["fx"] = s_fx
			stages[s] = entry_stage
			continue
		var r: Array = _stage_ranges.get(s, [])
		if r.size() == 2:
			stages[s] = [int(r[0]), int(r[1])]
	if not stages.is_empty():
		data["stages"] = stages

	## Only write the fields a facing actually changes vs the anim-level values.
	var dirs: Dictionary = {}
	for facing in _dir_on_flags:
		var d: Dictionary = _dirs[facing]
		var entry: Dictionary = {}
		if int(d.from) != int(_base.from):
			entry["from"] = int(d.from)
		if int(d.to) != int(_base.to):
			entry["to"] = int(d.to)
		if not is_equal_approx(float(d.fps), float(_base.fps)):
			entry["fps"] = float(d.fps)
		if int(d.row) != int(DIR_ROWS[facing]):
			entry["row"] = int(d.row)
		if int(d.hit_frame) != int(_base.hit_frame):
			entry["hit_frame"] = int(d.hit_frame)
		if not entry.is_empty():
			dirs[facing] = entry
	if not dirs.is_empty():
		data["dirs"] = dirs

	## Nothing actually differs from the data table → drop the entry entirely.
	if data.from == 0 and data.to == _default_count - 1 \
			and is_equal_approx(data.fps, _default_fps) \
			and not data.has("hit_frame") and stages.is_empty() and dirs.is_empty():
		_clear_override()
		return
	if CharacterSpriteFactory.save_anim_override(_char_id, anim, data):
		_rebuild_player()
		var extra: String = ""
		if not stages.is_empty():
			extra += " +%d stages" % stages.size()
		if not dirs.is_empty():
			extra += " +%d dirs" % dirs.size()
		_status_label.text = "saved: %s%s" % [anim, extra]
	else:
		_status_label.text = "SAVE FAILED (not writable)"


func _clear_override() -> void:
	var anim: String = _selected_anim()
	if anim == "":
		return
	CharacterSpriteFactory.save_anim_override(_char_id, anim, {})
	_rebuild_player()
	_reload_selected()
	_status_label.text = "cleared: " + anim


func _rebuild_player() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	if player_ref.has_method("_apply_character_sprite"):
		player_ref._apply_character_sprite()
	if player_ref.has_method("_load_combo"):
		player_ref._load_combo()
	## The kit was rebuilt — re-derive which input plays what.
	_build_usage()
	_refresh_usage_label(_selected_anim())
