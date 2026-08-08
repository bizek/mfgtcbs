class_name UINav
extends RefCounted

## Shared controller-navigation helpers for hub/menu panels.
## Godot's default ui_up/ui_down/ui_left/ui_right/ui_accept/ui_cancel actions
## already carry built-in joypad d-pad + left-stick + face-button bindings —
## the gap in this codebase was (a) buttons built with focus_mode = FOCUS_NONE,
## (b) nothing ever grabbing initial focus when a panel opens, and (c)
## ScrollContainers not following focus. This file plugs those three gaps.

## Grabs focus on the first focusable descendant of `root` (depth-first,
## sibling order). Skips a control literally named "CloseButton" on the
## first pass so panels default focus lands on real content, not the ×.
static func focus_first(root: Control) -> void:
	if root == null or not is_instance_valid(root):
		return
	var target := _find_focusable(root, true)
	if target == null:
		target = _find_focusable(root, false)
	if target != null:
		target.grab_focus.call_deferred()


static func _find_focusable(node: Node, skip_close: bool) -> Control:
	## Skip queue_free'd zombies: a populate() rebuild leaves the old rows in
	## the tree until end of frame, and focusing one silently drops focus to
	## nothing when it's deleted a frame later.
	if node.is_queued_for_deletion():
		return null
	if node is Control:
		var c: Control = node
		if c.focus_mode == Control.FOCUS_ALL and c.is_visible_in_tree() \
				and (not skip_close or c.name != "CloseButton"):
			return c
	for child in node.get_children():
		var found := _find_focusable(child, skip_close)
		if found != null:
			return found
	return null


## Call after a free-and-rebuild pass (populate/refresh): if keyboard/controller
## focus died with the freed nodes, land it back on the panel's first focusable
## so D-pad navigation doesn't dead-end. Deferred so it runs after the rebuild
## (and any queue_free deletions) settle.
static func refocus_if_lost(root: Control) -> void:
	if root == null or not is_instance_valid(root):
		return
	var tree := root.get_tree()
	if tree == null:
		return
	## Check on the NEXT frame, once queue_free deletions and any follow-up
	## rebuild passes have settled — a same-frame deferred check can win the
	## race against a later free and still end up focusing a dying node.
	tree.process_frame.connect(func(): _refocus_check(root), CONNECT_ONE_SHOT)


static func _refocus_check(root: Control) -> void:
	if root == null or not is_instance_valid(root) or not root.is_visible_in_tree():
		return
	var focus_owner := root.get_viewport().gui_get_focus_owner()
	if focus_owner == null or not is_instance_valid(focus_owner) \
			or focus_owner.is_queued_for_deletion() or not focus_owner.is_visible_in_tree():
		focus_first(root)


## Returns a copy of `base` with a bright, obviously-visible border — use for
## a button's "focus" theme override so D-pad/stick selection is legible
## without requiring a hover.
static func focus_ring(base: StyleBoxFlat, accent: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = base.duplicate()
	sb.border_color = accent
	sb.set_border_width_all(maxi(2, maxi(sb.border_width_left, sb.border_width_top)))
	return sb


## Focus overlay for buttons that would otherwise be hard to follow with a D-pad.
##
## Now defers to the project theme, which carries the UI pack's corner-bracket selector
## (`tools/build_ui_theme.gd` → _build_focus). That matters for correctness, not just looks: an
## override applied here WINS over the theme, so keeping the old flat 2px ring would have meant
## the pack art never appeared on any button that went through UINav — which is most of them.
##
## The `accent` parameter still does something: the theme's ring is duplicated and re-tinted, so
## a caller can mark a destructive or class-coloured control without inventing its own stylebox.
## A flat ring is still built when no theme ring is available, so this keeps working if the theme
## is ever unset.
static func apply_focus_ring(btn: Control, accent: Color = Color(1.0, 0.85, 0.3)) -> void:
	var themed: StyleBox = btn.get_theme_stylebox("focus", "Button")
	if themed is StyleBoxTexture:
		var ring := (themed as StyleBoxTexture).duplicate() as StyleBoxTexture
		ring.modulate_color = accent
		btn.add_theme_stylebox_override("focus", ring)
		return
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = accent
	sb.set_border_width_all(2)
	btn.add_theme_stylebox_override("focus", sb)


## Connects every focusable descendant of `scroll`'s content so D-pad
## navigation scrolls the list along with focus. The focused item is CENTERED
## in the viewport, not just nudged into view (ensure_control_visible):
## Godot's directional focus search skips controls clipped by a
## ScrollContainer, so if the next item sits even one row below the visible
## band, a D-pad press leaps to whatever unclipped focusable is nearest —
## usually a button outside the list. Keeping the focused item centered keeps
## its neighbors unclipped and reachable.
static func wire_scroll_follow(scroll: ScrollContainer) -> void:
	_wire_scroll_recursive(scroll, scroll)


static func _wire_scroll_recursive(node: Node, scroll: ScrollContainer) -> void:
	if node is Control and node != scroll:
		var c: Control = node
		if c.focus_mode == Control.FOCUS_ALL:
			c.focus_entered.connect(Callable(UINav, "_center_in_scroll").bind(scroll, c))
	for child in node.get_children():
		_wire_scroll_recursive(child, scroll)


static func _center_in_scroll(scroll: ScrollContainer, c: Control) -> void:
	## Next-frame, not just deferred: focus can land mid-rebuild, before the
	## container has laid out final positions — centering on stale geometry
	## clamps the scroll to a garbage offset (seen as "opens scrolled to the
	## bottom with focus at the top").
	var tree := scroll.get_tree()
	if tree == null:
		return
	tree.process_frame.connect(func(): _center_in_scroll_now(scroll, c), CONNECT_ONE_SHOT)


static func _center_in_scroll_now(scroll: ScrollContainer, c: Control) -> void:
	if not is_instance_valid(scroll) or not is_instance_valid(c) or not c.has_focus():
		return
	var content := scroll.get_child(0) as Control
	if content == null:
		return
	var rel := c.global_position - content.global_position
	scroll.scroll_vertical = int(rel.y + c.size.y * 0.5 - scroll.size.y * 0.5)
	scroll.scroll_horizontal = int(rel.x + c.size.x * 0.5 - scroll.size.x * 0.5)
