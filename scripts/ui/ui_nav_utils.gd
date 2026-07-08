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


## Returns a copy of `base` with a bright, obviously-visible border — use for
## a button's "focus" theme override so D-pad/stick selection is legible
## without requiring a hover.
static func focus_ring(base: StyleBoxFlat, accent: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = base.duplicate()
	sb.border_color = accent
	sb.set_border_width_all(maxi(2, maxi(sb.border_width_left, sb.border_width_top)))
	return sb


## Connects every focusable descendant of `scroll`'s content to
## ensure_control_visible so D-pad navigation scrolls the list along with
## focus instead of leaving the selection off-screen.
static func wire_scroll_follow(scroll: ScrollContainer) -> void:
	_wire_scroll_recursive(scroll, scroll)


static func _wire_scroll_recursive(node: Node, scroll: ScrollContainer) -> void:
	if node is Control and node != scroll:
		var c: Control = node
		if c.focus_mode == Control.FOCUS_ALL:
			c.focus_entered.connect(scroll.ensure_control_visible.bind(c))
	for child in node.get_children():
		_wire_scroll_recursive(child, scroll)
