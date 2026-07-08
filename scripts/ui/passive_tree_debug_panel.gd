extends CanvasLayer
## Temporary debug panel for the passive skill tree.
## P key toggles open / closed from any scene.
## Wire into a scene by adding as a child node or instantiating in _ready().
## Pass a player Node2D via setup() to get live re-apply after allocations (arena only).

const PIXEL_FONT := preload("res://assets/fonts/m5x7.ttf")

const C_BG      := Color(0.055, 0.050, 0.040, 0.96)
const C_CARD    := Color(0.082, 0.075, 0.063)
const C_CARD_HI := Color(0.130, 0.118, 0.098)
const C_BORDER  := Color(0.165, 0.145, 0.125)
const C_AMBER   := Color(0.831, 0.447, 0.102)
const C_AMBER_HI := Color(0.941, 0.565, 0.188)
const C_AMBER_LO := Color(0.353, 0.173, 0.031)
const C_GREEN   := Color(0.220, 0.580, 0.220)
const C_DIM     := Color(0.380, 0.330, 0.270)
const C_T0      := Color(0.800, 0.690, 0.565)
const C_T1      := Color(0.541, 0.408, 0.282)
const C_RED     := Color(0.659, 0.118, 0.063)

const FS_HEADER := 16
const FS_TAB    := 14
const FS_NODE   := 12

var _player_ref: Node2D = null

var _panel: Control
var _points_label: Label
var _node_list: VBoxContainer
var _current_branch: String = "core"
var _visible: bool = false

const BRANCHES: Array[String] = ["core", "might", "finesse", "arcana", "bridge"]
const BRANCH_LABELS: Array[String] = ["Core", "Might", "Finesse", "Arcana", "Bridges"]


func _ready() -> void:
	layer = 126
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()


func setup(player: Node2D) -> void:
	_player_ref = player


# ── Input ──────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_P:
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	_visible = not _visible
	_panel.visible = _visible
	if _visible:
		_refresh()


# ── Panel construction ─────────────────────────────────────────────────────────

func _build_panel() -> void:
	## Backdrop that blocks clicks through to the game while open
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.50)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = overlay
	_panel.visible = false
	add_child(_panel)

	## Outer panel: 500×310 centered in the 640×360 design viewport
	var outer := PanelContainer.new()
	outer.set_anchors_preset(Control.PRESET_CENTER)
	outer.custom_minimum_size = Vector2(500, 310)
	outer.offset_left  = -250
	outer.offset_right =  250
	outer.offset_top   = -155
	outer.offset_bottom = 155
	var sb_outer := StyleBoxFlat.new()
	sb_outer.bg_color = C_BG
	sb_outer.border_color = C_AMBER
	sb_outer.set_border_width_all(1)
	sb_outer.set_content_margin_all(0)
	outer.add_theme_stylebox_override("panel", sb_outer)
	_panel.add_child(outer)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 0)
	outer.add_child(root_vbox)

	## Header row
	root_vbox.add_child(_build_header())

	## Separator
	var sep := HSeparator.new()
	_style_sep(sep)
	root_vbox.add_child(sep)

	## Body row: branch tabs left + node list right
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(body)

	body.add_child(_build_branch_tabs())

	var vsep := VSeparator.new()
	_style_sep(vsep)
	body.add_child(vsep)

	body.add_child(_build_node_area())


func _build_header() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_CARD
	sb.set_content_margin_all(6)
	hbox.add_theme_stylebox_override("panel", sb)

	var title := Label.new()
	title.text = "Passive Tree  [P]"
	title.add_theme_font_override("font", PIXEL_FONT)
	title.add_theme_font_size_override("font_size", FS_HEADER)
	title.add_theme_color_override("font_color", C_AMBER)
	hbox.add_child(title)

	_points_label = Label.new()
	_points_label.text = "Points: 0"
	_points_label.add_theme_font_override("font", PIXEL_FONT)
	_points_label.add_theme_font_size_override("font_size", FS_HEADER)
	_points_label.add_theme_color_override("font_color", C_T0)
	_points_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_points_label)

	var respec_btn := _make_btn("RESPEC ALL", C_RED, Color(0.820, 0.157, 0.063))
	respec_btn.pressed.connect(_on_respec)
	hbox.add_child(respec_btn)

	## Add some points button (dev shortcut — gives 20 points)
	var add_pts_btn := _make_btn("+20 pts", C_T1, C_T0)
	add_pts_btn.pressed.connect(_on_add_points)
	hbox.add_child(add_pts_btn)

	return hbox


func _build_branch_tabs() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_CARD
	sb.set_content_margin_all(4)
	vbox.add_theme_stylebox_override("panel", sb)
	vbox.custom_minimum_size = Vector2(80, 0)

	for i in BRANCHES.size():
		var branch: String = BRANCHES[i]
		var label: String = BRANCH_LABELS[i]
		var btn := Button.new()
		btn.text = label
		btn.add_theme_font_override("font", PIXEL_FONT)
		btn.add_theme_font_size_override("font_size", FS_TAB)
		btn.flat = false
		_style_tab_btn(btn, branch == _current_branch)
		btn.pressed.connect(_on_branch_tab.bind(branch, btn))
		vbox.add_child(btn)
		btn.set_meta("branch", branch)
		btn.set_meta("is_tab", true)

	## Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	return vbox


func _build_node_area() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_node_list = VBoxContainer.new()
	_node_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_node_list.add_theme_constant_override("separation", 2)
	var sb := StyleBoxFlat.new()
	sb.set_content_margin_all(4)
	_node_list.add_theme_stylebox_override("panel", sb)
	scroll.add_child(_node_list)

	return scroll


# ── Refresh logic ──────────────────────────────────────────────────────────────

func _refresh() -> void:
	var pts: int = ProgressionManager.get_passive_points()
	_points_label.text = "Points: %d" % pts

	## Rebuild node list for current branch
	for child in _node_list.get_children():
		_node_list.remove_child(child)
		child.queue_free()

	## Update tab button styles
	for child in _panel.get_children():
		_update_tab_styles_recursive(child)

	## Build rows for current branch
	for node_id: String in PassiveTreeData.NODES:
		var node: Dictionary = PassiveTreeData.NODES[node_id]
		if node.get("branch", "") != _current_branch:
			continue
		_node_list.add_child(_build_node_row(node_id, node))


func _update_tab_styles_recursive(ctrl: Control) -> void:
	if ctrl.has_meta("is_tab"):
		_style_tab_btn(ctrl, ctrl.get_meta("branch") == _current_branch)
	for child in ctrl.get_children():
		if child is Control:
			_update_tab_styles_recursive(child)


func _build_node_row(node_id: String, node: Dictionary) -> HBoxContainer:
	var ranks: int  = ProgressionManager.get_node_ranks(node_id)
	var max_r: int  = node.get("max_ranks", 1)
	var cost:  int  = node.get("cost", 1)
	var can:   bool = ProgressionManager.can_allocate(node_id)
	var maxed: bool = ranks >= max_r
	var kind:  String = node.get("kind", "")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var sb := StyleBoxFlat.new()
	sb.set_content_margin_all(2)
	if maxed:
		sb.bg_color = Color(0.10, 0.18, 0.10)
	elif kind == "keystone":
		sb.bg_color = Color(0.16, 0.12, 0.05)
	elif kind == "notable":
		sb.bg_color = Color(0.10, 0.09, 0.07)
	else:
		sb.bg_color = C_CARD
	row.add_theme_stylebox_override("panel", sb)

	## Allocate button
	var alloc_btn := Button.new()
	alloc_btn.text = "+" if not maxed else "✓"
	alloc_btn.custom_minimum_size = Vector2(22, 16)
	alloc_btn.disabled = maxed or not can
	alloc_btn.add_theme_font_override("font", PIXEL_FONT)
	alloc_btn.add_theme_font_size_override("font_size", FS_NODE)
	_color_btn(alloc_btn, C_GREEN if not maxed else C_DIM, C_GREEN if not maxed else C_DIM)
	alloc_btn.pressed.connect(_on_allocate.bind(node_id))
	row.add_child(alloc_btn)

	## Name
	var name_lbl := Label.new()
	var name_text: String = node.get("name", node_id)
	if kind == "keystone":
		name_text = "★ " + name_text
	elif kind == "notable":
		name_text = "● " + name_text
	name_lbl.text = name_text
	name_lbl.add_theme_font_override("font", PIXEL_FONT)
	name_lbl.add_theme_font_size_override("font_size", FS_NODE)
	var c_name: Color = C_AMBER if kind == "keystone" else (C_T0 if kind == "notable" else C_T1)
	if maxed:
		c_name = C_GREEN
	elif not can and ranks == 0:
		c_name = C_DIM
	name_lbl.add_theme_color_override("font_color", c_name)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	## Ranks / cost
	var rank_lbl := Label.new()
	rank_lbl.text = "%d/%d  [%dpt]" % [ranks, max_r, cost]
	rank_lbl.add_theme_font_override("font", PIXEL_FONT)
	rank_lbl.add_theme_font_size_override("font_size", FS_NODE)
	rank_lbl.add_theme_color_override("font_color", C_DIM)
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(rank_lbl)

	return row


# ── Callbacks ──────────────────────────────────────────────────────────────────

func _on_branch_tab(branch: String, _btn: Button) -> void:
	_current_branch = branch
	_refresh()


func _on_allocate(node_id: String) -> void:
	if ProgressionManager.allocate(node_id):
		_reapply_tree()
		_refresh()


func _on_respec() -> void:
	ProgressionManager.refund_all()
	_reapply_tree()
	_refresh()


func _on_add_points() -> void:
	ProgressionManager.bank_passive_points(20)
	_refresh()


func _reapply_tree() -> void:
	## If a player node is wired (arena), re-apply the tree immediately so changes
	## take effect without restarting the run. Safe to call multiple times — stat
	## mods are stripped (remove_by_source_prefix) and re-added; behavior statuses
	## are max_stacks=1 so re-apply just refreshes the permanent entry.
	if is_instance_valid(_player_ref) and _player_ref.has_method("_apply_passive_tree"):
		_player_ref.modifier_component.remove_by_source_prefix("passive_tree")
		_player_ref.call("_apply_passive_tree")


# ── Helpers ────────────────────────────────────────────────────────────────────

func _make_btn(text_str: String, col_normal: Color, col_hover: Color) -> Button:
	var btn := Button.new()
	btn.text = text_str
	btn.add_theme_font_override("font", PIXEL_FONT)
	btn.add_theme_font_size_override("font_size", FS_TAB)
	_color_btn(btn, col_normal, col_hover)
	return btn


func _color_btn(btn: Button, col_normal: Color, col_hover: Color) -> void:
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = col_normal.darkened(0.55)
	sb_n.border_color = col_normal
	sb_n.set_border_width_all(1)
	sb_n.set_content_margin_all(3)
	btn.add_theme_stylebox_override("normal", sb_n)
	var sb_h := StyleBoxFlat.new()
	sb_h.bg_color = col_hover.darkened(0.30)
	sb_h.border_color = col_hover
	sb_h.set_border_width_all(1)
	sb_h.set_content_margin_all(3)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_h)
	var sb_d := StyleBoxFlat.new()
	sb_d.bg_color = Color(0.08, 0.07, 0.06)
	sb_d.border_color = Color(0.15, 0.13, 0.11)
	sb_d.set_border_width_all(1)
	sb_d.set_content_margin_all(3)
	btn.add_theme_stylebox_override("disabled", sb_d)


func _style_tab_btn(btn: Button, active: bool) -> void:
	_color_btn(btn, C_AMBER if active else C_T1, C_AMBER_HI)


func _style_sep(sep: Control) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BORDER
	if sep is HSeparator:
		sep.add_theme_stylebox_override("separator", sb)
	elif sep is VSeparator:
		sep.add_theme_stylebox_override("separator", sb)
