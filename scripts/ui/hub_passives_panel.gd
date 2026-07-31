@tool
extends Control

## Passive Tree panel — spend banked passive points into the Core + 3-branch tree.
## Script-only panel; builds its own HubPanelBase at runtime (mirrors hub_research_panel).
##
## ZERO progression logic lives here: the panel only reads PassiveTreeData and calls the
## ProgressionManager API (get_passive_points / get_node_ranks / can_allocate / node_gate_met /
## node_gate_text / allocate / refund_all). Every state change rebuilds the whole grid, which
## guarantees a tier-gate that opens mid-session is reflected across all 59 nodes.

signal close_requested

const _PANEL_BASE_SCENE := preload("res://scenes/ui/hub_panel_base.tscn")

## ── Color palette ─────────────────────────────────────────────────────────────
const C_CARD      := Color(0.098, 0.092, 0.110)
const C_CARD_LOCK := Color(0.070, 0.066, 0.078)
const C_BORDER    := Color(0.180, 0.170, 0.200)
const C_DIM       := Color(0.360, 0.345, 0.400)
const C_TEXT      := Color(0.820, 0.815, 0.870)
const C_GOLD      := Color(0.945, 0.780, 0.320)
const C_WARN      := Color(0.925, 0.365, 0.345)   ## refusal text (own name — not the Might red)

## Header hint, and how long a refused-refund message replaces it before reverting.
const REFUND_HINT   := "Ⓧ / R-CLICK  refund 1"
const HINT_HOLD_SEC := 2.4

## Per-branch accent colors (headers, borders, connector lines).
const C_CORE    := Color(0.945, 0.780, 0.320)   ## amber/gold
const C_MIGHT   := Color(0.878, 0.396, 0.322)   ## ember red
const C_FINESSE := Color(0.376, 0.784, 0.549)   ## jade green
const C_ARCANA  := Color(0.639, 0.463, 0.925)   ## violet
const C_BRIDGE  := Color(0.706, 0.667, 0.588)   ## neutral stone

const FONT    := HubPanelBase.PIXEL_FONT
const FS_MD   := 19
const FS_SM   := 16
const FS_XS   := 14
const FS_TINY := 13

## Marquee for node text that overflows its card: waits, scrolls slowly to the
## end, pauses there, snaps back, repeats — only while the node is focused.
const MARQUEE_DELAY_S     := 0.8
const MARQUEE_SPEED_PX_S  := 20.0
const MARQUEE_END_PAUSE_S := 1.0

## char_class → affinity branch (flavor-only highlight, spec §1). Adding Druid/Cleric
## later is a one-line change here — no other code touches this table.
const CLASS_BRANCH := {
	"Fighter": "might", "Paladin": "might", "Barbarian": "might", "Cleric": "might",
	"Ranger": "finesse", "Rogue": "finesse", "Ninja": "finesse", "Gunslinger": "finesse",
	"Wizard": "arcana", "Demonologist": "arcana", "Blood Mage": "arcana", "Druid": "arcana",
	"Necromancer": "arcana",
}

const _COL_W: int = 122   ## branch column card width

## ── State ─────────────────────────────────────────────────────────────────────
var _base:          HubPanelBase    = null
var _pm:            Node            = null
var _scroll:        ScrollContainer = null
var _body:          VBoxContainer   = null   ## rebuilt content root inside the scroll
var _points_label:  Label           = null
var _lifetime_label: Label          = null
var _built:         bool            = false
var _affinity:      String          = ""
var _node_buttons:  Dictionary      = {}     ## node_id -> Button (for refocus after rebuild)
var _focus_node_id: String          = ""
var _refund_hint:   Label           = null   ## header hint; also carries the refusal reason
var _hint_timer:    float           = -1.0   ## >0 while the refusal message is up


func _ready() -> void:
	_base = _PANEL_BASE_SCENE.instantiate()
	_base.title_text   = "PASSIVE TREE"
	_base.accent_color = C_ARCANA
	add_child(_base)
	_base.close_requested.connect(func(): close_requested.emit())
	if Engine.is_editor_hint():
		return
	_build_scaffold()
	## No populate() here — hub._open_panel() calls it the moment it adds us to the tree, so a
	## self-populate built the whole panel TWICE on every open. Measured on the passive tree
	## (the worst case at 59 nodes / ~1175 controls): 112ms per open, of which half was the
	## duplicate pass. Every hub panel had the same shape. (Ben 2026-07-30.)


func populate(pm: Node) -> void:
	_pm = pm
	_affinity = _affinity_for_selected()
	if _built:
		_rebuild()


# ── Scaffold (built once) ──────────────────────────────────────────────────────

func _build_scaffold() -> void:
	var content := _base.get_content()

	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_theme_constant_override("margin_left",   9)
	outer.add_theme_constant_override("margin_top",    5)
	outer.add_theme_constant_override("margin_right",  9)
	outer.add_theme_constant_override("margin_bottom", 5)
	content.add_child(outer)

	var root_vbox := VBoxContainer.new()
	root_vbox.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 4)
	outer.add_child(root_vbox)

	## ── Header bar: unspent points (prominent) + lifetime (subtle) + respec
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	hdr.custom_minimum_size = Vector2(0, 20)
	root_vbox.add_child(hdr)

	_points_label = _lbl(hdr, "PTS 0", FS_MD, C_GOLD)
	_lifetime_label = _lbl(hdr, "lifetime 0", FS_TINY, C_DIM)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(spacer)

	## Single-rank refund hint (Ⓧ on pad, right-click on mouse). Doubles as the refusal line —
	## a refused refund turns this red with the gate that would break, then it reverts.
	_refund_hint = _lbl(hdr, REFUND_HINT, FS_TINY, C_DIM)

	var respec := Button.new()
	respec.text             = "RESPEC"
	respec.focus_mode       = Control.FOCUS_ALL
	respec.custom_minimum_size = Vector2(58, 0)
	respec.add_theme_font_override("font", FONT)
	respec.add_theme_font_size_override("font_size", FS_XS)
	respec.add_theme_color_override("font_color",       C_TEXT)
	respec.add_theme_color_override("font_hover_color", C_GOLD)
	_style_btn(respec, Color(0.16, 0.10, 0.10, 0.85), Color(0.42, 0.16, 0.14, 0.90), C_MIGHT)
	respec.pressed.connect(_on_respec)
	hdr.add_child(respec)

	## ── Accent rule under the header
	var rule := ColorRect.new()
	rule.custom_minimum_size   = Vector2(0, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.color                 = Color(C_ARCANA.r, C_ARCANA.g, C_ARCANA.b, 0.45)
	root_vbox.add_child(rule)

	## ── ScrollContainer fills the rest (vertical scroll only — tree overflows)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(_scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 6)
	_scroll.add_child(_body)

	_built = true


# ── Full rebuild on every state change ─────────────────────────────────────────

func _rebuild() -> void:
	if not _built or _pm == null:
		return
	_node_buttons.clear()
	for child in _body.get_children():
		child.queue_free()

	_points_label.text   = "PTS %d" % _pm.get_passive_points()
	_lifetime_label.text = "lifetime %d" % _pm.lifetime_passive_points

	_build_core_section(_body)
	_build_branch_columns(_body)
	_build_bridge_section(_body)

	UINav.wire_scroll_follow(_scroll)

	## Restore focus to the just-clicked node if it still exists, so controller
	## navigation isn't dumped after an allocate rebuild.
	if _focus_node_id != "" and _node_buttons.has(_focus_node_id):
		var b: Button = _node_buttons[_focus_node_id]
		if is_instance_valid(b):
			## Maxed nodes stay focusable (just unpressable), so focus can
			## remain on the node you just finished instead of hopping away.
			b.call_deferred("grab_focus")
		else:
			## The node just maxed out and was rebuilt disabled/FOCUS_NONE.
			## Hand focus to the nearest still-selectable node instead of
			## dropping it — a dead cursor stranded controller users until
			## they switched tabs.
			var ids: Array = _node_buttons.keys()
			var idx: int = ids.find(_focus_node_id)
			var fallback: Button = null
			for offset in range(1, ids.size()):
				for dir in [-1, 1]:
					var j: int = idx + dir * offset
					if j >= 0 and j < ids.size():
						var cand: Button = _node_buttons[ids[j]]
						if is_instance_valid(cand) and not cand.disabled \
								and cand.focus_mode == Control.FOCUS_ALL:
							fallback = cand
							break
				if fallback != null:
					break
			if fallback != null:
				fallback.call_deferred("grab_focus")
			else:
				UINav.refocus_if_lost(self)


# ── Core section (11 nodes, tier 0, 3-wide grid) ───────────────────────────────

func _build_core_section(parent: Control) -> void:
	_section_header(parent, "CORE", C_CORE, _affinity == "core")

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)

	for node_id: String in _sorted_ids("core"):
		_build_node(grid, node_id, C_CORE, _COL_W)


# ── Three branch columns (Might / Finesse / Arcana) ────────────────────────────

func _build_branch_columns(parent: Control) -> void:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 4)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(cols)

	_build_one_column(cols, "might",   "MIGHT",   C_MIGHT)
	_build_one_column(cols, "finesse", "FINESSE", C_FINESSE)
	_build_one_column(cols, "arcana",  "ARCANA",  C_ARCANA)


func _build_one_column(parent: Control, branch: String, title: String, accent: Color) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.custom_minimum_size = Vector2(_COL_W, 0)
	parent.add_child(col)

	var is_affinity: bool = _affinity == branch
	_section_header(col, title, accent, is_affinity)

	var prev_tier: int = -1
	for node_id: String in _sorted_ids(branch):
		var tier: int = int(PassiveTreeData.NODES[node_id].get("tier", 0))
		if prev_tier != -1 and tier != prev_tier:
			_tier_connector(col, accent)
		prev_tier = tier
		_build_node(col, node_id, accent, _COL_W)


# ── Bridge section (3 nodes, span between branches) ────────────────────────────

func _build_bridge_section(parent: Control) -> void:
	_section_header(parent, "BRIDGES", C_BRIDGE, false)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)

	for node_id: String in _sorted_ids("bridge"):
		_build_node(grid, node_id, C_BRIDGE, _COL_W)


# ── Node card (a Button so it's clickable + controller-focusable) ──────────────

func _build_node(parent: Control, node_id: String, accent: Color, width: int) -> void:
	var node: Dictionary = PassiveTreeData.NODES.get(node_id, {})
	if node.is_empty():
		return

	var ranks:    int    = _pm.get_node_ranks(node_id)
	var max_r:    int    = int(node.get("max_ranks", 1))
	var cost:     int    = int(node.get("cost", 1))
	var kind:     String = node.get("kind", "")
	var can_buy:  bool   = _pm.can_allocate(node_id)
	var gate_met: bool   = _pm.node_gate_met(node_id)
	var is_maxed: bool   = ranks >= max_r
	## Locked = tier/bridge gate not satisfied. Distinct from "gate met but broke".
	var is_locked: bool  = not is_maxed and not gate_met
	var is_avail:  bool   = can_buy   ## points + gate + not maxed

	var is_keystone: bool = kind == "keystone"
	var is_notable:  bool = kind == "notable"
	var border_w:    int  = 2 if is_keystone else 1
	var min_h:       int  = 58 if is_keystone else (52 if is_notable else 48)

	## Card colors by state.
	var bg_col:     Color = C_CARD
	var border_col: Color = C_BORDER
	var name_col:   Color = C_TEXT
	if is_maxed:
		bg_col     = Color(accent.r * 0.28, accent.g * 0.28, accent.b * 0.28, 1.0)
		border_col = C_GOLD
		name_col   = C_GOLD
	elif is_avail:
		border_col = accent
		name_col   = Color(accent.r * 0.55 + 0.45, accent.g * 0.55 + 0.45, accent.b * 0.55 + 0.45)
	elif is_locked:
		bg_col     = C_CARD_LOCK
		border_col = C_BORDER
		name_col   = C_DIM
	else:   ## gate met, not enough points
		border_col = Color(accent.r, accent.g, accent.b, 0.35)
		name_col   = Color(C_TEXT.r, C_TEXT.g, C_TEXT.b, 0.65)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(width, min_h)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## Every node is focusable — maxed/locked/broke nodes just can't be pressed
	## (disabled and focus are independent). Skipping them made the selector
	## bounce over gaps and stranded it once a branch's bottom node maxed out.
	btn.focus_mode  = Control.FOCUS_ALL
	btn.disabled    = not is_avail
	btn.tooltip_text = "%s\n%s\nCost %d/rank" % [node.get("name", node_id), node.get("desc", ""), cost]
	_style_node_btn(btn, bg_col, border_col, accent, border_w)
	parent.add_child(btn)
	_node_buttons[node_id] = btn

	if is_avail:
		var cap_id: String = node_id
		btn.pressed.connect(func(): _on_node_pressed(cap_id))

	## Content overlay — mouse-transparent so the Button receives the click.
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 1)
	vb.offset_left   = 5
	vb.offset_right  = -4
	vb.offset_top    = 3
	vb.offset_bottom = -3
	btn.add_child(vb)

	## Line 1: name (+ kind marker) ......... rank r/max
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 2)
	vb.add_child(top)

	var display_name: String = node.get("name", node_id)
	if is_keystone:
		display_name = "★ " + display_name
	elif is_notable:
		display_name = "◆ " + display_name
	var name_clip := _marquee_lbl(top, display_name, FS_TINY, name_col)

	var rank_col: Color = C_GOLD if is_maxed else (accent if ranks > 0 else C_DIM)
	_lbl(top, "%d/%d" % [ranks, max_r], FS_TINY, rank_col)

	## Line 2: effect text (marquee-scrolls on focus when it overflows;
	## full text also in the tooltip for mouse users)
	var eff_clip := _marquee_lbl(vb, node.get("desc", ""), FS_TINY,
		C_DIM if (is_locked) else Color(name_col.r, name_col.g, name_col.b, 0.85))

	if btn.focus_mode == Control.FOCUS_ALL:
		btn.set_meta("marquee_wrappers", [name_clip, eff_clip])
		btn.focus_entered.connect(_on_node_focus_entered.bind(btn))
		btn.focus_exited.connect(_stop_marquee.bind(btn))

	## Right-click refunds one rank (gui_input fires even on disabled buttons,
	## so maxed nodes can be refunded too).
	var refund_id: String = node_id
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_RIGHT:
			_on_node_refund(refund_id))

	## Line 3: state
	var state_text: String
	var state_col:  Color
	if is_maxed:
		state_text = "MAXED"
		state_col  = C_GOLD
	elif is_locked:
		state_text = _pm.node_gate_text(node_id)
		state_col  = C_DIM
	elif is_avail:
		state_text = "◆ %d PT" % cost
		state_col  = accent
	else:
		state_text = "%d PT" % cost
		state_col  = Color(C_DIM.r, C_DIM.g, C_DIM.b, 1.0)
	var st := _lbl(vb, state_text, FS_TINY, state_col)
	st.clip_text = true


# ── Interaction ────────────────────────────────────────────────────────────────

func _on_node_pressed(node_id: String) -> void:
	if _pm.allocate(node_id):
		_focus_node_id = node_id
		AudioManager.play_ui("sfx_ui_purchase")
		_rebuild()


## Ⓧ refunds one rank from the focused node (controller path; mouse uses
## right-click via each button's gui_input).
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventJoypadButton and event.pressed \
			and event.button_index == JOY_BUTTON_X:
		var focus_owner := get_viewport().gui_get_focus_owner()
		for id: String in _node_buttons:
			if _node_buttons[id] == focus_owner:
				get_viewport().set_input_as_handled()
				_on_node_refund(id)
				return


func _on_node_refund(node_id: String) -> void:
	## refund_one validates gates: it refuses when removing this rank would
	## strand points spent further down the tree.
	if _pm.refund_one(node_id):
		_focus_node_id = node_id
		AudioManager.play_ui("sfx_ui_cancel")
		_rebuild()
		return

	## Refused. This used to fall off the end of the function and do NOTHING — no sound, no text,
	## no flash — so a correctly-refused refund was indistinguishable from a dead button. It is not
	## a rare path either (~1 in 13 attempts): it fires precisely when you try to pull a
	## foundational rank out from under a gated node. Say what broke. (Ben 2026-07-30.)
	AudioManager.play_ui("sfx_ui_error")
	var reason: String = _pm.refund_block_reason(node_id)
	if _refund_hint:
		_refund_hint.text = "CAN'T REFUND — %s" % reason if reason != "" else "CAN'T REFUND"
		_refund_hint.add_theme_color_override("font_color", C_WARN)
		_hint_timer = HINT_HOLD_SEC
	## Flash the node itself so the refusal is attached to what you clicked (merchant_shop pattern).
	var btn: Button = _node_buttons.get(node_id)
	if btn and is_instance_valid(btn):
		var t := btn.create_tween()
		t.tween_property(btn, "modulate", Color(1.0, 0.35, 0.35), 0.05)
		t.tween_property(btn, "modulate", Color.WHITE, 0.22)


func _process(delta: float) -> void:
	## Revert the header hint once the refusal message has had its moment.
	if _hint_timer <= 0.0:
		return
	_hint_timer -= delta
	if _hint_timer <= 0.0 and _refund_hint and is_instance_valid(_refund_hint):
		_refund_hint.text = REFUND_HINT
		_refund_hint.add_theme_color_override("font_color", C_DIM)


func _on_respec() -> void:
	_pm.refund_all()
	_focus_node_id = ""
	AudioManager.play_ui("sfx_ui_cancel")
	_rebuild()


# ── Helpers ────────────────────────────────────────────────────────────────────

## Node ids of a branch, sorted by tier then declaration order.
func _sorted_ids(branch: String) -> Array:
	var ids: Array = PassiveTreeData.nodes_in_branch(branch)
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(PassiveTreeData.NODES[a].get("tier", 0)) < int(PassiveTreeData.NODES[b].get("tier", 0)))
	return ids


func _affinity_for_selected() -> String:
	if _pm == null:
		return ""
	var char_id: String = _pm.selected_character
	var cdata: Dictionary = CharacterData.ALL.get(char_id, {})
	var cclass: String = cdata.get("char_class", "")
	return CLASS_BRANCH.get(cclass, "")


func _section_header(parent: Control, text: String, accent: Color, is_affinity: bool) -> void:
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 4)
	hbox.custom_minimum_size = Vector2(0, 14)
	parent.add_child(hbox)

	var label_text: String = ("» " + text + " «") if is_affinity else text
	var hl := _lbl(hbox, label_text, FS_SM, accent if is_affinity else Color(accent.r, accent.g, accent.b, 0.75))

	var rule := ColorRect.new()
	rule.custom_minimum_size   = Vector2(0, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	rule.color                 = Color(accent.r, accent.g, accent.b, 0.55 if is_affinity else 0.25)
	hbox.add_child(rule)


## Thin vertical connector between tier groups in a branch column.
func _tier_connector(parent: Control, accent: Color) -> void:
	var wrap := HBoxContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.alignment    = BoxContainer.ALIGNMENT_CENTER
	wrap.custom_minimum_size = Vector2(0, 6)
	parent.add_child(wrap)

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(2, 6)
	line.color               = Color(accent.r, accent.g, accent.b, 0.40)
	wrap.add_child(line)


## A clipped single-line label that can marquee-scroll horizontally. Returns
## the clipping wrapper; the inner Label rides in its "marquee_label" meta.
func _marquee_lbl(parent: Control, text: String, sz: int, col: Color) -> Control:
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(lbl)
	## Pre-tree measurement uses the fallback theme font (~2x wider than the
	## pixel font) — good enough as a placeholder, but re-measure on ready or
	## every fitting line looks like overflow.
	lbl.size = lbl.get_minimum_size()
	clip.custom_minimum_size = Vector2(0, lbl.size.y)
	lbl.ready.connect(func():
		lbl.size = lbl.get_minimum_size()
		clip.custom_minimum_size.y = lbl.size.y
	, CONNECT_ONE_SHOT)
	clip.set_meta("marquee_label", lbl)
	parent.add_child(clip)
	return clip


func _on_node_focus_entered(btn: Button) -> void:
	## Measure a frame later — focus often lands via deferred grab right after
	## a rebuild, before the card has its final width.
	get_tree().process_frame.connect(func():
		if is_instance_valid(btn) and btn.has_focus():
			_start_marquee(btn)
	, CONNECT_ONE_SHOT)


func _start_marquee(btn: Button) -> void:
	_stop_marquee(btn)
	var tweens: Array = []
	for clip: Control in btn.get_meta("marquee_wrappers", []):
		if not is_instance_valid(clip):
			continue
		var lbl: Label = clip.get_meta("marquee_label")
		lbl.size = lbl.get_minimum_size()  ## authoritative in-tree width
		var overflow: float = lbl.size.x - clip.size.x
		## Only scroll when text genuinely exits the frame; the scroll stops
		## exactly when the line's end reaches the right edge (mirroring the
		## start's left alignment).
		if overflow <= 2.0:
			continue
		var t := btn.create_tween().set_loops()
		t.tween_interval(MARQUEE_DELAY_S)
		t.tween_property(lbl, "position:x", -overflow, overflow / MARQUEE_SPEED_PX_S)
		t.tween_interval(MARQUEE_END_PAUSE_S)
		t.tween_callback(func(): lbl.position.x = 0.0)
		tweens.append(t)
	btn.set_meta("marquee_tweens", tweens)


func _stop_marquee(btn: Button) -> void:
	for t: Tween in btn.get_meta("marquee_tweens", []):
		if t != null and t.is_valid():
			t.kill()
	btn.set_meta("marquee_tweens", [])
	for clip: Control in btn.get_meta("marquee_wrappers", []):
		if is_instance_valid(clip):
			var lbl: Label = clip.get_meta("marquee_label")
			lbl.position.x = 0.0


func _lbl(parent: Control, text: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _style_node_btn(btn: Button, bg: Color, border: Color, accent: Color, border_w: int) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		if state in ["hover", "pressed"]:
			sb.bg_color = Color(bg.r + 0.06, bg.g + 0.06, bg.b + 0.07, 1.0)
		else:
			sb.bg_color = bg
		sb.border_color = accent if state == "focus" else border
		sb.set_border_width_all(2 if state == "focus" else border_w)
		sb.set_corner_radius_all(2)
		sb.set_content_margin_all(0)
		btn.add_theme_stylebox_override(state, sb)


func _style_btn(btn: Button, normal_bg: Color, hover_bg: Color, accent: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = hover_bg if state in ["hover", "pressed", "focus"] else normal_bg
		if state == "focus":
			sb.set_border_width_all(1)
			sb.border_color = accent
		else:
			sb.set_border_width_all(0)
		sb.set_content_margin_all(3)
		btn.add_theme_stylebox_override(state, sb)
