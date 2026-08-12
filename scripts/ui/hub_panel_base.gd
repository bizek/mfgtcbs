@tool
class_name HubPanelBase
extends Panel

## Shared base for all hub overlay panels.
## Provides panel chrome (background, title bar, close button) and helper utilities
## for building dynamic content. Each concrete panel instances this scene as a child,
## accesses ContentContainer to add rows, and forwards the close_requested signal.

## Preloaded under a local alias rather than the bare class_name, matching codex_grid_panel.gd —
## a class_name is unresolvable until the editor rescans, and this script is @tool so it is
## parsed in the editor too.
const Icons := preload("res://scripts/ui/ui_icons.gd")

const FONT_TITLE  := 16
## Was 19 — off the m5x7 pixel grid, and the reason the font pass exists at all.
## It survived that pass because `add_row()` below has no callers, so a grep for
## rendered sizes never reached it. Dead code still sets the default for whoever
## calls it next, so it is corrected rather than left as a trap.
const FONT_BODY   := 16
const FONT_DIM    := 16
const ROW_GAP     := 23
const LABEL_W     := 363
const LABEL_H     := 27
const PANEL_W     := 400
const PANEL_H     := 267
const TITLE_H     := 29
const CONTENT_H   := 238   ## PANEL_H - TITLE_H
## The Grim R1 plate's corner-bracket size (see tools/build_ui_theme.gd). Content
## pinned to the panel edge has to clear this much or it covers the frame.
const PLATE_INSET := 5

## Set these exports in each panel's scene file (Inspector) for per-panel identity.
@export var title_text: String  = "PANEL"
@export var accent_color: Color = Color(0.4, 0.4, 0.9)

## Emitted when the × button is pressed. Parent panel scripts forward this to hub.gd.
signal close_requested

func _ready() -> void:
	## Apply accent color to title bar and panel border (duplicating the resource
	## so each instance gets its own copy, not a shared one).
	$TitleBar.color = Color(
		accent_color.r * 0.25,
		accent_color.g * 0.25,
		accent_color.b * 0.25
	)
	$TitleBar/TitleLabel.text = title_text
	$TitleBar/TitleLabel.add_theme_color_override("font_color", accent_color)
	$TitleBar/TitleLabel.add_theme_font_size_override("font_size", FONT_TITLE)
	_apply_accent_to_panel()

	## The title bar is a full-bleed ColorRect pinned to the panel's top edge,
	## which sat on top of the frame and left the plate reading as an ornament on
	## three sides and a flat cut on the fourth. Inset by the plate's own corner
	## size so the frame closes all the way round. Done here rather than in the
	## scene because the five panel scenes cannot currently be saved without
	## losing nodes — see _apply_accent_to_panel().
	$TitleBar.offset_left = float(PLATE_INSET)
	$TitleBar.offset_right = -float(PLATE_INSET)
	$TitleBar.offset_top = float(PLATE_INSET)
	## The pack's close glyph rather than a text character. Applied here at runtime rather
	## than in the scene for the same reason as the plate and the title bar insets: the five
	## hub panel scenes cannot be saved without dropping nodes (see _apply_accent_to_panel()).
	## Falls back silently to whatever the scene already sets if the sheet is missing.
	Icons.apply_window_button($TitleBar/CloseButton, Icons.WinBtn.CLOSE)
	$TitleBar/CloseButton.pressed.connect(func():
		AudioManager.play_ui("sfx_ui_panel_close")
		close_requested.emit())
	if not Engine.is_editor_hint():
		AudioManager.play_ui("sfx_ui_panel_open")
		## Fallback focus so D-pad/stick navigation works the instant a panel
		## opens even if the concrete panel script never grabs its own focus.
		## hub.gd overrides this with a more useful first-content-control
		## focus once populate() has built the panel's real rows.
		UINav.focus_first(self)

	## Amber accent rule — 2px strip at the bottom edge of the title bar.
	var accent_rule := ColorRect.new()
	accent_rule.anchor_left   = 0.0
	accent_rule.anchor_right  = 1.0
	accent_rule.anchor_top    = 1.0
	accent_rule.anchor_bottom = 1.0
	accent_rule.offset_top    = -2.0
	accent_rule.offset_bottom = 0.0
	accent_rule.color         = Color(accent_color.r, accent_color.g, accent_color.b, 0.5)
	accent_rule.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	$TitleBar.add_child(accent_rule)

	## The close button's softened hover red used to be re-applied here on top of
	## the scene's own hover/pressed overrides. Because this is a @tool script the
	## editor ran it too, so saving the scene baked this exact colour into it —
	## which is how the duplication surfaced. The scene now carries the shipped
	## value and this block would only re-set what is already set, so it is gone.

	## Left-edge accent strip — 2px glow on the content area's left side.
	var left_strip := ColorRect.new()
	left_strip.anchor_left   = 0.0
	left_strip.anchor_right  = 0.0
	left_strip.anchor_top    = 0.0
	left_strip.anchor_bottom = 1.0
	left_strip.offset_right  = 2.0
	left_strip.color         = Color(accent_color.r, accent_color.g, accent_color.b, 0.18)
	left_strip.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	$ContentContainer.add_child(left_strip)

## Carries each panel's identity colour into its frame.
##
## This used to be one line — duplicate the stylebox, set `border_color` — which
## worked only because the scene hard-overrode `panel` with a StyleBoxFlat. That
## override is gone (2026-08-07) so the panel plate now comes from the project
## theme's Grim art, and `as StyleBoxFlat` on a StyleBoxTexture returns **null**,
## which would have crashed on the very next line. Both shapes are handled here
## because a texture stylebox has no border colour to set.
func _apply_accent_to_panel() -> void:
	## Five hub panel scenes (roster, launch, records, workshop, armory) each
	## baked a *copy* of the old flat plate onto their own `PanelBase` instance
	## back when the base scene carried one. Those copies sit in front of the
	## project theme, so removing the base's override alone changed nothing —
	## the panels kept rendering their stale local copy.
	##
	## They are stripped here rather than edited out of the five .tscn files
	## because saving any of those scenes is currently destructive: they parent
	## their content into `PanelBase/ContentContainer`, a node that belongs to
	## the instanced sub-scene, and a save drops every one of those children
	## (measured: 278 lines / 27 nodes lost from hub_roster_panel.tscn). Doing it
	## at runtime costs one call, covers all five, and covers any panel added later.
	##
	## Runtime only: in the editor this would show a removal that a subsequent
	## Ctrl+S would try to persist, which is the exact save that loses nodes.
	if not Engine.is_editor_hint():
		remove_theme_stylebox_override("panel")

	var base: StyleBox = get_theme_stylebox("panel")
	if base == null:
		return
	var style: StyleBox = base.duplicate()
	if style is StyleBoxFlat:
		(style as StyleBoxFlat).border_color = accent_color
	elif style is StyleBoxTexture:
		## The Grim plate is a near-black fill inside a bone outline, and
		## modulate multiplies — so black stays black and only the outline takes
		## the accent. The accent has to be lifted most of the way to white
		## first: multiplying the bone outline by a raw Color(0.45, 0.52, 0.95)
		## lands it around 0.35 luminance, which on a black fill reads as grime
		## rather than as identity. 0.7 keeps the outline near its own brightness
		## and lets the hue through — checked on screen, not guessed.
		##
		## Alpha 0.97 preserves what the old flat plate had: the hub is faintly
		## visible through the panel, so it reads as an overlay rather than a
		## hole cut in the screen. The Grim art is fully opaque on its own.
		var tint: Color = accent_color.lerp(Color.WHITE, 0.7)
		tint.a = 0.97
		(style as StyleBoxTexture).modulate_color = tint
	add_theme_stylebox_override("panel", style)

## Returns the Content area Control where panels add their dynamic rows.
func get_content() -> Control:
	return $ContentContainer


## Centres this panel in the viewport.
##
## The five .tscn panels bake their position into their own root node (`offset_left = 120`
## for a 400-wide panel, `offset_top` set so the panel is vertically centred for its height:
## 47 at 267 tall, 27 at 307). The two script-built panels — research and passives — have no
## scene to carry those offsets, so from the day they were written they rendered pinned to the
## top-left corner while every other panel sat centred. Switching panels with LB/RB made the
## window jump across the screen. Found 2026-08-11 by screenshotting all seven stations.
##
## The base is positioned rather than its parent because the concrete panel's root is a bare
## 0x0 Control: that is exactly the arrangement the scene panels use (root at 120,47 with the
## base at 0,0 inside it), so this reproduces their geometry instead of inventing a second one.
## Anchors are not used — they resolve against that 0x0 parent and would centre on nothing.
func center_in_viewport() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var s: Vector2 = size
	## size is authored on the instanced scene, but read defensively: a caller that
	## centres before the first layout pass would otherwise centre a 0x0 rect.
	if s.x <= 0.0 or s.y <= 0.0:
		s = Vector2(PANEL_W, PANEL_H)
	## round(), not floor() — at 400x267 in a 640x360 viewport the exact centre is
	## y=46.5, and the scene panels round it up to 47. Matching them keeps the two
	## panel families pixel-identical rather than one off by a row.
	position = ((vp - s) * 0.5).round()


## Ⓑ / Esc always closes the panel, regardless of what has focus — the
## controller-nav safety net so a bad focus_neighbor chain can never trap a
## player inside a panel with no way back out.
func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		AudioManager.play_ui("sfx_ui_panel_close")
		close_requested.emit()
		get_viewport().set_input_as_handled()

# ── Shared UI helpers ─────────────────────────────────────────────────────────

## Strips Godot's default button chrome and applies a clean flat style.
## normal_col / hover_col are the bg fills; left_pad is x content margin.
func style_btn(btn: Button, normal_col: Color, hover_col: Color,
		left_pad: int = 4) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = hover_col if state in ["hover", "pressed", "focus"] else normal_col
		if state == "focus":
			sb.set_border_width_all(1)
			sb.border_color = accent_color
		else:
			sb.set_border_width_all(0)
		sb.set_content_margin(SIDE_LEFT,   left_pad)
		sb.set_content_margin(SIDE_RIGHT,  left_pad)
		sb.set_content_margin(SIDE_TOP,    0)
		sb.set_content_margin(SIDE_BOTTOM, 0)
		btn.add_theme_stylebox_override(state, sb)

## Adds a text label at (12, y) in parent's local space. y is relative to the
## top of ContentContainer (i.e., subtract TITLE_H from old panel-root y values).
func add_row(parent: Control, text: String, y: float,
		color: Color = Color(0.82, 0.82, 0.87), font_size: int = FONT_BODY) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = Vector2(12, y)
	lbl.size = Vector2(LABEL_W, LABEL_H)
	parent.add_child(lbl)
