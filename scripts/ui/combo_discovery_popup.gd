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
	# This allows the scene tree to fully initialize first
	await get_tree().process_frame
	_connect_to_resolver()


func _create_popup_ui() -> void:
	## Create the popup UI hierarchy
	_popup_root = Control.new()
	_popup_root.name = "ComboDiscoveryPopup"
	_popup_root.anchor_left = 0.5
	_popup_root.anchor_right = 0.5
	_popup_root.offset_left = -120.0
	_popup_root.offset_right = 120.0
	_popup_root.offset_top = 40.0
	_popup_root.offset_bottom = 100.0
	_popup_root.scale = Vector2.ZERO
	_popup_root.modulate.a = 0.0
	add_child(_popup_root)

	## Background panel
	var bg := Panel.new()
	bg.size = Vector2(240.0, 50.0)
	bg.add_theme_stylebox_override("panel", _create_panel_style())
	_popup_root.add_child(bg)

	## Accent bar at top
	_accent_color_rect = ColorRect.new()
	_accent_color_rect.color = Color.WHITE
	_accent_color_rect.size = Vector2(240.0, 3.0)
	_popup_root.add_child(_accent_color_rect)

	## Combo name label
	_combo_name_label = Label.new()
	_combo_name_label.text = "COMBO DISCOVERED"
	_combo_name_label.position = Vector2(10.0, 5.0)
	_combo_name_label.size = Vector2(220.0, 20.0)
	_combo_name_label.add_theme_font_size_override("font_size", 14)
	_combo_name_label.add_theme_color_override("font_color", Color.WHITE)
	if ResourceLoader.exists("res://assets/fonts/m5x7.ttf"):
		_combo_name_label.add_theme_font_override("font", load("res://assets/fonts/m5x7.ttf"))
	_combo_name_label.custom_minimum_size = Vector2(220.0, 0.0)
	_popup_root.add_child(_combo_name_label)

	## Subtitle label
	_combo_subtitle_label = Label.new()
	_combo_subtitle_label.text = "COMBO DISCOVERED!"
	_combo_subtitle_label.position = Vector2(10.0, 28.0)
	_combo_subtitle_label.size = Vector2(220.0, 12.0)
	_combo_subtitle_label.add_theme_font_size_override("font_size", 10)
	_combo_subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	if ResourceLoader.exists("res://assets/fonts/m5x7.ttf"):
		_combo_subtitle_label.add_theme_font_override("font", load("res://assets/fonts/m5x7.ttf"))
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
	var root = get_tree().root
	if not root:
		push_error("ComboDiscoveryPopup: Could not get tree root")
		return

	## Get the main scene (MainArena)
	var main_scene = root.get_child(0) if root.get_child_count() > 0 else null
	if not main_scene:
		push_error("ComboDiscoveryPopup: Could not get main scene")
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

	_is_animating = false
	_process_queue()  ## Process next in queue


func _animate_popup(popup_data: Dictionary) -> void:
	## Animate in, hold, animate out
	_combo_name_label.text = popup_data["combo_name"]
	_combo_subtitle_label.text = popup_data["subtitle"]
	_accent_color_rect.color = popup_data["color"]

	var tween := create_tween()

	## Animate in: scale up + fade in (0.3s)
	tween.set_parallel(true)
	tween.tween_property(_popup_root, "scale", Vector2.ONE, 0.3)
	tween.tween_property(_popup_root, "modulate:a", 1.0, 0.3)

	## Hold for 2 seconds
	tween.set_parallel(false)
	tween.tween_interval(2.0)

	## Animate out: fade out + drift up (0.5s)
	tween.set_parallel(true)
	tween.tween_property(_popup_root, "modulate:a", 0.0, 0.5)
	tween.tween_property(_popup_root, "position:y", -20.0, 0.5)
	tween.set_parallel(false)

	## Reset position for next popup
	_popup_root.position.y = 0.0
	_popup_root.scale = Vector2.ZERO
	_popup_root.modulate.a = 0.0
