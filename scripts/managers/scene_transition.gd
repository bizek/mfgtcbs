extends CanvasLayer

## SceneTransition — the one way to change scenes.
##
## Every scene change in the game used to be a hard cut: nine bare
## change_scene_to_file() calls, no fade anywhere. The two a player crosses every
## single run — hub → descent and results → hub — are the ones that made the game
## read as a prototype.
##
## Usage:
##   SceneTransition.change_scene("res://scenes/hub.tscn")
##
## Do NOT call change_scene_to_file() directly for player-facing navigation.
## (scripts/ui/training_panel.gd is the deliberate exception — the training room's
## own reload path is documented in CLAUDE.md and must not grow an await.)

## Above every other CanvasLayer in the project: hub panels and results screens
## are 10, merchant/sacrifice 60, achievement toasts 90.
const LAYER: int = 128

const FADE_OUT: float = 0.18
const FADE_IN: float = 0.22

var _veil: ColorRect = null
var _busy: bool = false


func _ready() -> void:
	## ALWAYS, because three of the callers change scenes from a paused tree —
	## the results screens run behind get_tree().paused = true.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER

	_veil = ColorRect.new()
	_veil.color = Color.BLACK
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.modulate.a = 0.0
	_veil.visible = false
	add_child(_veil)


## Fade to black, swap, fade back. Returns immediately if a transition is already
## running, so a double-click on a menu button cannot queue two scene loads.
func change_scene(path: String, fade_out: float = FADE_OUT, fade_in: float = FADE_IN) -> void:
	if _busy:
		return
	if not ResourceLoader.exists(path):
		push_error("SceneTransition: no scene at %s — not changing" % path)
		return
	_busy = true

	await _fade(0.0, 1.0, fade_out)

	## A scene change always lands in a running tree. Callers used to each remember
	## this; centralising it means the next screen cannot forget.
	get_tree().paused = false
	get_tree().change_scene_to_file(path)

	## change_scene_to_file is deferred — the swap and the new scene's _ready()
	## happen at idle, so give it two frames before revealing anything.
	await get_tree().process_frame
	await get_tree().process_frame
	await _wait_for_scene_ready()

	await _fade(1.0, 0.0, fade_in)
	_veil.visible = false
	_busy = false


## A scene whose _ready() spans several frames (MainArena builds the descent block by block)
## declares `is_scene_ready`; keep the veil down until it flips. Scenes without the property are
## ready as soon as they exist. READY_TIMEOUT is a backstop so a build that dies halfway can
## never leave the player staring at a black screen — the error is in the log either way.
const READY_TIMEOUT: float = 10.0

func _wait_for_scene_ready() -> void:
	## Real time, like the fades: a leftover hit-stop time_scale must not stall the backstop.
	var deadline: int = Time.get_ticks_msec() + int(READY_TIMEOUT * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var scene: Node = get_tree().current_scene
		if scene == null or not ("is_scene_ready" in scene) or scene.is_scene_ready:
			return
		await get_tree().process_frame
	push_warning("SceneTransition: %s never reported ready — revealing anyway"
			% get_tree().current_scene.name)


func _fade(from: float, to: float, duration: float) -> void:
	_veil.modulate.a = from
	_veil.visible = true
	if duration <= 0.0:
		_veil.modulate.a = to
		return
	var tween := create_tween()
	## ignore_time_scale because the game drives Engine.time_scale for hit-stop and
	## the training room's slow-mo — without it a fade triggered during either one
	## stretches to match.
	tween.set_ignore_time_scale(true)
	tween.tween_property(_veil, "modulate:a", to, duration)
	await tween.finished
