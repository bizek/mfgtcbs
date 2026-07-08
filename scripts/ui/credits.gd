extends Control

## Credits — Auto-scrolling credits roll. Any key/click or the Skip button
## returns to the hub immediately; otherwise it returns automatically once
## the scroll finishes.

@onready var scroll: ScrollContainer = $Scroll
@onready var roll: VBoxContainer = $Scroll/Roll
@onready var skip_button: Button = $SkipButton

const SCROLL_SPEED: float = 24.0 ## pixels/sec
const FONT_PATH: String = "res://assets/fonts/m5x7.ttf"

var _finished: bool = false
var _returning: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	skip_button.pressed.connect(_return_to_hub)
	_apply_font()
	skip_button.grab_focus.call_deferred()

func _apply_font() -> void:
	if not ResourceLoader.exists(FONT_PATH):
		return
	var font := load(FONT_PATH)
	for child in roll.get_children():
		if child is Label:
			child.add_theme_font_override("font", font)
	skip_button.add_theme_font_override("font", font)

func _process(delta: float) -> void:
	if _finished:
		return
	scroll.scroll_vertical += int(SCROLL_SPEED * delta)
	var max_scroll: int = roll.size.y - scroll.size.y
	if max_scroll > 0 and scroll.scroll_vertical >= max_scroll:
		_finished = true
		_return_to_hub()

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed) \
			or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventJoypadButton and event.pressed):
		_return_to_hub()

func _return_to_hub() -> void:
	if _returning:
		return
	_returning = true
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
