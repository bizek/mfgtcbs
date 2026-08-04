extends Control
class_name FirstRunOverlay

## First-run onboarding overlay — one-time contextual tooltip cues for a new
## player's first Caves run. No TutorialManager (see docs/release_pipeline.md
## "Tutorial" decision): gated entirely by ProgressionManager.first_run_complete
## and wired off existing EventBus/GameManager/ExtractionManager/player signals.
## Added as a procedural child of HUD, same pattern as ComboDiscoveryPopup.

const DISPLAY_DURATION: float = 5.0
const COMBAT_NUDGE_DELAY: float = 5.0

## Cues that dismiss early once the prompted action is pressed, in addition to
## the normal timer.
const DISMISS_ACTIONS: Dictionary = {
	"rmb_special": ["heavy_attack"],
	"skills_qe": ["skill_q", "skill_e"],
	"dash": ["dash"],
}

var player_ref: Node2D = null
var _active: bool = false

var _shown: Dictionary = {}         ## cue_id -> true once displayed
var _queue: Array[Dictionary] = []  ## pending { id, text, anchor }
var _current_id: String = ""
var _dismiss_timer: Timer = null

## Combat/action tracking for the RMB / Q-E / dash nudges.
var _combat_engaged_at: float = -1.0
var _used_actions: Dictionary = {}
var _run_time: float = 0.0

var _panel: PanelContainer = null
var _label: RichTextLabel = null

## Scaled font size, snapped to the m5x7 pixel grid — see Settings.snap_font_size for why a
## raw multiply cannot be used here (0.85 and 1.25 both produce off-grid, and sub-16 fuses).
func _ts(base_size: int) -> int:
	return Settings.scaled_font_size(base_size)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_active = not ProgressionManager.first_run_complete
	if not _active:
		return
	_build_ui()
	GameManager.run_failed.connect(func(_abandoned: bool): _on_run_ended())
	GameManager.extraction_successful.connect(_on_run_ended)
	GameManager.instability_changed.connect(_on_instability_changed)
	GameManager.extraction_window_opened.connect(_on_extraction_window_opened)
	EventBus.on_kill.connect(_on_kill)
	EventBus.on_pickup.connect(_on_pickup)
	EventBus.on_hit_dealt.connect(_on_combat_signal)
	EventBus.on_hit_received.connect(_on_combat_signal)
	InputGlyphs.device_changed.connect(_on_device_changed)

func setup(player: Node2D) -> void:
	player_ref = player
	if not _active:
		return
	player_ref.leveled_up.connect(_on_leveled_up)
	_queue_cue("spawn", "", "center")
	_queue_cue("depth_meter",
		"The depth meter (left edge) tracks your descent — find the portal below.",
		"corner")

func _process(delta: float) -> void:
	if not _active:
		return
	_run_time += delta

	for action in ["heavy_attack", "skill_q", "skill_e", "dash"]:
		if Input.is_action_just_pressed(action):
			_used_actions[action] = true

	## Early-dismiss the current cue if its prompted action just fired.
	if _current_id != "" and DISMISS_ACTIONS.has(_current_id):
		var actions: Array = DISMISS_ACTIONS[_current_id]
		for action in actions:
			if Input.is_action_just_pressed(action):
				_dismiss_timer.stop()
				_on_dismiss_timeout()
				break

	if _combat_engaged_at >= 0.0 and _run_time - _combat_engaged_at >= COMBAT_NUDGE_DELAY:
		if not _used_actions.get("heavy_attack", false):
			_queue_cue("rmb_special", "", "corner")
		if not (_used_actions.get("skill_q", false) or _used_actions.get("skill_e", false)):
			_queue_cue("skills_qe", "", "corner")
		_combat_engaged_at = -1.0  ## nudges resolved, stop re-checking

func _on_combat_signal(source, target, _hit_data = null) -> void:
	if player_ref == null:
		return
	if _combat_engaged_at < 0.0 and (source == player_ref or target == player_ref):
		_combat_engaged_at = _run_time
	if target == player_ref and not _used_actions.get("dash", false):
		_queue_cue("dash", "", "corner")

func _on_kill(killer, _victim) -> void:
	if killer == player_ref:
		_queue_cue("first_kill_xp", "Enemies drop XP — walk over it to collect and level up.", "corner")

func _on_pickup(entity, pickup_type: String) -> void:
	if entity != player_ref:
		return
	if pickup_type == "weapon":
		_queue_cue("pickup_item", "New weapon picked up — it replaces your active one.", "corner")
	else:
		_queue_cue("pickup_item", "Mod picked up — slot it in at the hub for a permanent bonus.", "corner")

func _on_leveled_up(_new_level: int) -> void:
	_queue_cue("level_up", "Level up! Pick an upgrade.", "corner")

func _on_instability_changed(new_value: float) -> void:
	if new_value > 0.0:
		_queue_cue("instability", "Instability is rising (top meter) — push too far and your haul gets risky.", "corner")

func _on_extraction_window_opened() -> void:
	_queue_cue("extraction_window", "Extraction window open — channel at the portal to extract.", "corner")

func _on_run_ended() -> void:
	if not ProgressionManager.first_run_complete:
		ProgressionManager.first_run_complete = true
		ProgressionManager.save_data()
	_active = false

## ── Queue / display ──────────────────────────────────────────────────────────

func _queue_cue(id: String, text: String, anchor: String) -> void:
	if not _active or _shown.has(id) or _current_id == id:
		return
	for cue: Dictionary in _queue:
		if cue.id == id:
			return
	_queue.append({"id": id, "text": text, "anchor": anchor})
	if _current_id == "":
		_show_next()

func _show_next() -> void:
	if _queue.is_empty():
		_current_id = ""
		return
	var cue: Dictionary = _queue.pop_front()
	_current_id = cue.id
	_shown[cue.id] = true
	var text: String = _cue_text(cue.id)
	if text == "":
		text = cue.text
	_display(text, cue.anchor)


## Device-aware wording for the cues that name physical inputs. Resolved at
## display time (not queue time) so the text matches whatever the player is
## actually holding; cues without an entry here use their static queue text.
##
## Every input these cues name is a real bound action, so they all resolve
## through action_glyph_bb() — art on both devices, and honest after a rebind,
## which the old hardcoded "LMB"/"Q/E"/"Space" keyboard strings were not. Only
## the stick wording still branches, since a stick has no keyboard counterpart.
func _cue_text(id: String) -> String:
	var pad: bool = InputGlyphs.using_joypad
	match id:
		"spawn":
			var move: String = "Left stick moves, right stick aims." if pad \
					else "WASD to move, aim with your mouse."
			return "%s\n%s chains your combo — tap to chain, hold to channel." \
					% [move, InputGlyphs.action_glyph_bb("light_attack")]
		"rmb_special":
			return "Try your %s special attack." % InputGlyphs.action_glyph_bb("heavy_attack")
		"skills_qe":
			return "Your %s/%s class skills hit hard — try them out." \
					% [InputGlyphs.action_glyph_bb("skill_q"), InputGlyphs.action_glyph_bb("skill_e")]
		"dash":
			return "Getting hit? %s dashes you clear (brief i-frames)." \
					% InputGlyphs.action_glyph_bb("dash")
	return ""


func _on_device_changed(_is_joypad: bool) -> void:
	## Live-swap the wording if the player changes device mid-cue.
	if not _active or _current_id == "" or _panel == null or not _panel.visible:
		return
	var text: String = _cue_text(_current_id)
	if text != "":
		_label.text = "[center]%s[/center]" % text

func _display(text: String, anchor: String) -> void:
	_label.text = "[center]%s[/center]" % text
	_label.custom_minimum_size = Vector2(300.0 if anchor == "center" else 200.0, 0.0)
	_panel.visible = true
	_panel.modulate.a = 0.0
	await get_tree().process_frame  ## let the PanelContainer resize to fit the label
	if anchor == "center":
		_panel.position = Vector2((640.0 - _panel.size.x) * 0.5, 120.0)
	else:
		_panel.position = Vector2(4.0, 360.0 - _panel.size.y - 4.0)
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.2)
	_dismiss_timer.start(DISPLAY_DURATION)

func _on_dismiss_timeout() -> void:
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		_panel.visible = false
		_show_next()
	)

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "FirstRunCuePanel"
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.04, 0.92)
	sb.border_color = Color(0.55, 0.38, 0.18)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(6.0)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	## RichTextLabel so cues can show the player's actual bound inputs as the
	## pack's keycap/button art instead of naming them in prose.
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.custom_minimum_size = Vector2(200.0, 0.0)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("normal_font_size", _ts(14))
	_label.add_theme_color_override("default_color", Color(0.94, 0.87, 0.75))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_label.add_theme_constant_override("outline_size", 2)
	if ResourceLoader.exists("res://assets/fonts/m5x7.ttf"):
		_label.add_theme_font_override("normal_font", load("res://assets/fonts/m5x7.ttf"))
	_panel.add_child(_label)

	_dismiss_timer = Timer.new()
	_dismiss_timer.one_shot = true
	_dismiss_timer.timeout.connect(_on_dismiss_timeout)
	add_child(_dismiss_timer)
