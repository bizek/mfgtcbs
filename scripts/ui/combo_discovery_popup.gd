extends Control
class_name ComboDiscoveryPopup

## Combo discovery notification system
## Listens for combo_first_triggered signal and displays a popup with animation queue
## Added as a child of the HUD (which is a CanvasLayer), so this is a Control node

## Color mapping for different combo types
const COLOR_MAP: Dictionary = {
	0: Color(0.85, 0.85, 0.85),  ## BEHAVIOR_BEHAVIOR → Silver/White
	1: Color.WHITE,               ## BEHAVIOR_ELEMENTAL → determined by element
	2: Color.WHITE,               ## ELEMENTAL_ELEMENTAL → gradient
	3: Color(1.0, 0.85, 0.0),    ## STAT_INTERACTION → Gold
	4: Color(1.0, 0.85, 0.0),    ## TRIPLE_LEGENDARY → Gold (with glow)
}

## Element colors
const ELEMENT_COLORS: Dictionary = {
	"fire": Color(1.0, 0.6, 0.0),      ## Orange
	"cryo": Color(0.2, 0.8, 1.0),      ## Cyan
	"shock": Color(1.0, 1.0, 0.0),     ## Yellow
	"bleed": Color(0.7, 0.1, 0.1),     ## Dark red
}

## Where the popup rests inside the (now full-screen) root, and how far it floats as it fades.
## Named because the reset at the end of _animate_popup has to restore exactly this — it used to
## reset to 0, which walked the popup 40px up the screen after the first discovery.
const _REST_Y: float  = 40.0
const _DRIFT_Y: float = 20.0

## Popup animation queue
var _popup_queue: Array[Dictionary] = []
var _is_animating: bool = false

## Popup UI elements
var _popup_root: Control = null
var _combo_name_label: Label = null
var _combo_subtitle_label: Label = null
var _accent_color_rect: ColorRect = null

func _ready() -> void:
	# Create the popup UI hierarchy
	_create_popup_ui()

	# Connect to the combo effect resolver signal in the next frame
	# This allows the scene tree to fully initialize first.
	# The node can be torn down DURING that one-frame await — the Training Room's live class swap
	# reloads the arena, which frees this popup mid-coroutine. Resuming then leaves us detached and
	# get_tree() null, so bail before touching it (Ben, crash on Devout -> Verdant swap).
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_connect_to_resolver()


func _create_popup_ui() -> void:
	## THIS node is a Control parented to the HUD's CanvasLayer, so it has no rect of its own —
	## a Control's anchors resolve against its parent Control, and a CanvasLayer is not one, so
	## it sat at 0x0. _popup_root below centres itself with 0.5 anchors, and those resolved
	## against that empty rect: the popup centred on x=0 and rendered half off the LEFT EDGE of
	## the screen. It had never once been on screen. (Found 2026-08-12 by forcing it visible in
	## the Training Room; measured at global x=-120.)
	##
	## A Control whose parent is not a Control anchors against the viewport instead, so
	## PRESET_FULL_RECT gives the 640x360 rect that _popup_root's anchors need.
	##
	## set_anchors_AND_OFFSETS_preset, not set_anchors_preset: the latter sets the anchors and
	## then rewrites the offsets to preserve the rect the node already had, which here was 0x0 —
	## it produced anchors 0,0,1,1 with offsets 0,0,-640,-360, a correctly-anchored empty box.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	## MOUSE_FILTER_IGNORE is not optional now that this covers the whole screen: combat is
	## manual cursor-aim, so a Control that answers to the mouse over the play field eats attacks.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Create the popup UI hierarchy
	_popup_root = Control.new()
	_popup_root.name = "ComboDiscoveryPopup"
	_popup_root.anchor_left = 0.5
	_popup_root.anchor_right = 0.5
	_popup_root.offset_left = -120.0
	_popup_root.offset_right = 120.0
	_popup_root.offset_top = _REST_Y
	_popup_root.offset_bottom = _REST_Y + 60.0
	## Scale animates from zero; without a centred pivot it grows out of its own top-left corner
	## instead of popping in place.
	_popup_root.pivot_offset = Vector2(120.0, 30.0)
	_popup_root.scale = Vector2.ZERO
	_popup_root.modulate.a = 0.0
	_popup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_popup_root)

	## Background panel
	var bg := Panel.new()
	bg.size = Vector2(240.0, 50.0)
	bg.add_theme_stylebox_override("panel", _create_panel_style())
	## Panel defaults to MOUSE_FILTER_STOP — see the note above.
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_root.add_child(bg)

	## Accent bar at top
	_accent_color_rect = ColorRect.new()
	_accent_color_rect.color = Color.WHITE
	_accent_color_rect.size = Vector2(240.0, 3.0)
	_accent_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_root.add_child(_accent_color_rect)

	## Combo name label
	_combo_name_label = Label.new()
	_combo_name_label.text = "COMBO DISCOVERED"
	_combo_name_label.position = Vector2(10.0, 5.0)
	_combo_name_label.size = Vector2(220.0, 20.0)
	_combo_name_label.add_theme_color_override("font_color", Color.WHITE)
	_combo_name_label.custom_minimum_size = Vector2(220.0, 0.0)
	_popup_root.add_child(_combo_name_label)

	## Subtitle label
	_combo_subtitle_label = Label.new()
	_combo_subtitle_label.text = "COMBO DISCOVERED!"
	_combo_subtitle_label.position = Vector2(10.0, 28.0)
	_combo_subtitle_label.size = Vector2(220.0, 12.0)
	_combo_subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_combo_subtitle_label.custom_minimum_size = Vector2(220.0, 0.0)
	_popup_root.add_child(_combo_subtitle_label)


func _create_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.set_corner_radius_all(4)
	return style


func _connect_to_resolver() -> void:
	## Find CombatOrchestrator and its ComboEffectResolver child
	## Scene structure: MainArena/CombatOrchestrator/ComboEffectResolver
	var tree := get_tree()
	if tree == null:
		return   ## detached (scene torn down) — nothing to connect to

	## The main scene, NOT root.get_child(0): every autoload is a child of root and they are added
	## FIRST, so get_child(0) returned an autoload (EventBus) and the orchestrator lookup below
	## always missed. That is why "CombatOrchestrator not found in scene" fired on every load and
	## combo-discovery popups never actually appeared.
	var main_scene := tree.current_scene
	if not main_scene:
		push_warning("ComboDiscoveryPopup: no current scene")
		return

	## Find CombatOrchestrator
	var combat_orchestrator = main_scene.get_node_or_null("CombatOrchestrator")
	if not combat_orchestrator:
		push_warning("ComboDiscoveryPopup: CombatOrchestrator not found in scene")
		return

	## Find ComboEffectResolver
	var resolver = combat_orchestrator.get_node_or_null("ComboEffectResolver")
	if not resolver:
		push_warning("ComboDiscoveryPopup: ComboEffectResolver not found")
		return

	## Connect to signals
	if not resolver.combo_first_triggered.is_connected(_on_combo_first_triggered):
		resolver.combo_first_triggered.connect(_on_combo_first_triggered)
	if not resolver.triple_combo_first_triggered.is_connected(_on_triple_combo_first_triggered):
		resolver.triple_combo_first_triggered.connect(_on_triple_combo_first_triggered)


func _on_combo_first_triggered(combo_id: StringName, combo_name: String, combo_type: int) -> void:
	## Queue the popup animation
	var color = _get_color_for_combo(combo_id, combo_type)
	var subtitle = "COMBO DISCOVERED!"
	_popup_queue.append({
		"combo_name": combo_name,
		"subtitle": subtitle,
		"color": color,
		"is_triple": false
	})
	_process_queue()


func _on_triple_combo_first_triggered(combo_id: StringName, combo_name: String) -> void:
	## Triple combos get a special subtitle and glow effect
	var color = Color(1.0, 0.85, 0.0)  ## Gold
	_popup_queue.append({
		"combo_name": combo_name,
		"subtitle": "LEGENDARY COMBO DISCOVERED!",
		"color": color,
		"is_triple": true
	})
	_process_queue()


func _get_color_for_combo(combo_id: StringName, combo_type: int) -> Color:
	## Determine color based on combo type
	match combo_type:
		0:  ## BEHAVIOR_BEHAVIOR → Silver
			return Color(0.85, 0.85, 0.85)
		1:  ## BEHAVIOR_ELEMENTAL → Extract element from combo_id
			return _get_element_color_from_combo(combo_id)
		2:  ## ELEMENTAL_ELEMENTAL → Gradient (use lighter cyan as default)
			return Color(0.4, 0.9, 1.0)
		3:  ## STAT_INTERACTION → Gold
			return Color(1.0, 0.85, 0.0)
		4:  ## TRIPLE_LEGENDARY → Gold
			return Color(1.0, 0.85, 0.0)
		_:
			return Color.WHITE


func _get_element_color_from_combo(combo_id: StringName) -> Color:
	## Map combo_id to element color
	## Patterns: fire combos contain "fire", cryo combos contain "freeze"/"frost"/"ice", etc.
	var id_str = str(combo_id).to_lower()

	if "fire" in id_str or "comet" in id_str or "flame" in id_str or "burning" in id_str:
		return ELEMENT_COLORS["fire"]
	elif "freeze" in id_str or "frost" in id_str or "ice" in id_str or "cryo" in id_str or "chilled" in id_str:
		return ELEMENT_COLORS["cryo"]
	elif "shock" in id_str or "arc" in id_str or "lightning" in id_str or "conductor" in id_str or "thunder" in id_str:
		return ELEMENT_COLORS["shock"]
	elif "bleed" in id_str or "razor" in id_str or "blood" in id_str or "searing" in id_str:
		return ELEMENT_COLORS["bleed"]

	# Fallback for mixed combos (e.g., frostfire)
	if "frost" in id_str and "fire" in id_str:
		return Color(0.6, 0.4, 1.0)  ## Purple blend

	return Color(0.8, 0.8, 0.8)  ## Default silver


func _process_queue() -> void:
	## Start processing the queue if not already animating
	if _is_animating or _popup_queue.is_empty():
		return

	_is_animating = true
	var popup_data = _popup_queue.pop_front()

	await _animate_popup(popup_data)

	## _animate_popup now genuinely awaits its tween, so this resumes ~2.8s later — by which
	## point the arena may have been reloaded out from under us.
	if not is_inside_tree():
		return
	_is_animating = false
	_process_queue()  ## Process next in queue


func _animate_popup(popup_data: Dictionary) -> void:
	## Animate in, hold, animate out
	_combo_name_label.text = popup_data["combo_name"]
	_combo_subtitle_label.text = popup_data["subtitle"]
	_accent_color_rect.color = popup_data["color"]

	## Start from the resting pose. This used to sit at the BOTTOM of the function, below the
	## tween setup — and because nothing awaited, it ran immediately rather than after the
	## animation. So every popup was shoved to y=0 the instant it was queued and then drifted
	## to -20, i.e. it played its whole animation off the top of the screen.
	_popup_root.position.y = _REST_Y
	_popup_root.scale      = Vector2.ZERO
	_popup_root.modulate.a = 0.0

	var tween := create_tween()

	## Animate in: scale up + fade in (0.3s)
	tween.set_parallel(true)
	tween.tween_property(_popup_root, "scale", Vector2.ONE, 0.3)
	tween.tween_property(_popup_root, "modulate:a", 1.0, 0.3)

	## Hold for 2 seconds
	tween.set_parallel(false)
	tween.tween_interval(2.0)

	## Animate out: fade out + drift up (0.5s), relative to the resting position rather than
	## to an absolute -20 that only made sense from y=0.
	tween.set_parallel(true)
	tween.tween_property(_popup_root, "modulate:a", 0.0, 0.5)
	tween.tween_property(_popup_root, "position:y", _REST_Y - _DRIFT_Y, 0.5)
	tween.set_parallel(false)

	## _process_queue awaits this call to serialise discoveries, but this function contained no
	## await, so it returned instantly and the "queue" never queued: two combos discovered in the
	## same swing started two tweens on the same node, and the second stomped the first.
	await tween.finished

	## The node can be freed during those 2.8s — the Training Room's live class swap reloads the
	## arena — so re-check before touching anything, same as _ready() does.
	if not is_instance_valid(_popup_root):
		return
	_popup_root.position.y = _REST_Y
	_popup_root.scale      = Vector2.ZERO
	_popup_root.modulate.a = 0.0
