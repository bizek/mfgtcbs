extends Node

## AchievementManager — Autoload. Detects achievement unlocks, persists them via
## ProgressionManager (additive save keys: achievements_unlocked, total_gold_earned),
## and shows a queued toast overlay. Owns the single unlock signal Steam sync (task 24)
## hooks into.
##
## Detection rule: accumulated stats are compared at run-end (check_run_end, called
## explicitly by the results screens right after they call ProgressionManager.record_*)
## and once on hub load — never per-frame. A couple of achievements are event-shaped
## (first boss kill fires immediately off GameManager.final_boss_defeated).

signal achievement_unlocked(id: String)

var _no_damage_this_run: bool = true
var _toast_queue: Array[String] = []
var _toast_animating: bool = false

var _toast_layer: CanvasLayer = null
var _toast_root: Control = null
var _toast_icon: Label = null
var _toast_title: Label = null
var _toast_name: Label = null
var _toast_bar: ColorRect = null


func _ready() -> void:
	GameManager.run_started.connect(_on_run_started)
	GameManager.final_boss_defeated.connect(_on_boss_defeated)
	EventBus.on_hit_dealt.connect(_on_hit_dealt)
	_build_toast()
	## Hub boot / relaunch — catch any threshold crossed by data migrated from an
	## older save (e.g. a save edited outside a run).
	check_thresholds()


func _on_run_started() -> void:
	_no_damage_this_run = true


func _on_hit_dealt(_source, target, _hit_data) -> void:
	if target != null and is_instance_valid(target) and target.is_in_group("player"):
		_no_damage_this_run = false


func _on_boss_defeated() -> void:
	try_unlock("first_boss_kill")


## Called explicitly by the results screens (extraction_success_screen.gd, win_screen.gd,
## game_over_screen.gd) right after they call ProgressionManager.record_extraction /
## record_death, so this always sees post-run stats — never racing signal connection order.
func check_run_end(outcome: String) -> void:
	if outcome == "extraction":
		try_unlock("first_extraction")
		if GameManager.last_run_was_win and ProgressionManager.game_cleared:
			try_unlock("game_cleared")
		if _no_damage_this_run and GameManager.get_effective_phase() >= 2:
			try_unlock("untouchable")
	check_thresholds()


func check_thresholds() -> void:
	## Event achievements with persisted state that pre-existing saves may already
	## satisfy (e.g. a save with extractions from before this feature shipped).
	if ProgressionManager.successful_extractions >= 1:
		try_unlock("first_extraction")
	if ProgressionManager.game_cleared:
		try_unlock("game_cleared")
	for id in AchievementData.ORDER:
		var def: Dictionary = AchievementData.ALL[id]
		if def.get("kind", "") != "threshold":
			continue
		if is_unlocked(id):
			continue
		var progress: Vector2 = get_progress(id)
		if progress.x >= progress.y:
			try_unlock(id)


## Returns [current, target] for threshold achievements; [0, 1] for event-shaped ones.
func get_progress(id: String) -> Vector2:
	var def: Dictionary = AchievementData.ALL.get(id, {})
	match def.get("stat_key", ""):
		"total_kills":
			return Vector2(float(ProgressionManager.total_kills), float(def.threshold))
		"successful_extractions":
			return Vector2(float(ProgressionManager.successful_extractions), float(def.threshold))
		"roster_size":
			return Vector2(float(ProgressionManager.unlocked_characters.size()), float(CharacterData.ORDER.size()))
		"cleared_characters":
			return Vector2(float(ProgressionManager.cleared_characters.size()), float(def.threshold))
		"combos_discovered":
			return Vector2(float(CodexManager.get_all_discovered().size()), float(def.threshold))
		"total_gold_earned":
			return Vector2(ProgressionManager.total_gold_earned, float(def.threshold))
		_:
			return Vector2(0.0, 1.0)


func is_unlocked(id: String) -> bool:
	return id in ProgressionManager.achievements_unlocked


func try_unlock(id: String) -> bool:
	if not AchievementData.ALL.has(id):
		return false
	if is_unlocked(id):
		return false
	ProgressionManager.achievements_unlocked.append(id)
	ProgressionManager.save_data()
	achievement_unlocked.emit(id)
	_queue_toast(id)
	return true


# ── Toast overlay ─────────────────────────────────────────────────────────────
## A CanvasLayer parented directly to this autoload — autoloads and the current
## scene share the same root Viewport, so this renders on top across both the
## arena (HUD) and the hub without needing separate wiring in either scene.

func _build_toast() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.name = "AchievementToastLayer"
	_toast_layer.layer = 90
	_toast_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_toast_layer)

	_toast_root = Control.new()
	_toast_root.name = "AchievementToast"
	_toast_root.anchor_left = 0.5
	_toast_root.anchor_right = 0.5
	_toast_root.offset_left = -110.0
	_toast_root.offset_right = 110.0
	_toast_root.offset_top = 14.0
	_toast_root.offset_bottom = 58.0
	_toast_root.scale = Vector2.ZERO
	_toast_root.modulate.a = 0.0
	_toast_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_toast_layer.add_child(_toast_root)

	var bg := Panel.new()
	bg.size = Vector2(220.0, 44.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.075, 0.1, 0.96)
	style.border_color = Color(0.831, 0.447, 0.102)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.anti_aliasing = false   ## rounded StyleBoxFlats default to AA, which feathers a sub-pixel fringe on every edge — off-grid in a 640x360 pixel UI
	bg.add_theme_stylebox_override("panel", style)
	_toast_root.add_child(bg)

	_toast_bar = ColorRect.new()
	_toast_bar.color = Color(0.831, 0.447, 0.102)
	_toast_bar.position = Vector2(0.0, 0.0)
	_toast_bar.size = Vector2(220.0, 3.0)
	_toast_root.add_child(_toast_bar)

	_toast_icon = Label.new()
	_toast_icon.position = Vector2(8.0, 6.0)
	_toast_icon.size = Vector2(24.0, 32.0)
	_toast_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_root.add_child(_toast_icon)

	_toast_title = Label.new()
	_toast_title.text = "ACHIEVEMENT UNLOCKED"
	_toast_title.position = Vector2(38.0, 6.0)
	_toast_title.size = Vector2(176.0, 14.0)
	_toast_title.add_theme_color_override("font_color", Color(0.65, 0.65, 0.72))
	_toast_root.add_child(_toast_title)

	_toast_name = Label.new()
	_toast_name.position = Vector2(38.0, 20.0)
	_toast_name.size = Vector2(176.0, 20.0)
	_toast_name.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
	_toast_root.add_child(_toast_name)


func _queue_toast(id: String) -> void:
	_toast_queue.append(id)
	_process_toast_queue()


func _process_toast_queue() -> void:
	if _toast_animating or _toast_queue.is_empty():
		return
	_toast_animating = true
	var id: String = _toast_queue.pop_front()
	await _animate_toast(id)
	_toast_animating = false
	_process_toast_queue()


func _animate_toast(id: String) -> void:
	var def: Dictionary = AchievementData.ALL.get(id, {})
	_toast_icon.text = str(def.get("icon", "★"))
	_toast_name.text = str(def.get("title", id))
	var col: Color = def.get("color", Color(1.0, 0.85, 0.0))
	_toast_bar.color = col
	_toast_icon.add_theme_color_override("font_color", col)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(_toast_root, "scale", Vector2.ONE, 0.25)
	tween.tween_property(_toast_root, "modulate:a", 1.0, 0.25)
	tween.set_parallel(false)
	tween.tween_interval(2.2)
	tween.set_parallel(true)
	tween.tween_property(_toast_root, "modulate:a", 0.0, 0.4)
	tween.tween_property(_toast_root, "offset_top", 4.0, 0.4)
	await tween.finished

	_toast_root.offset_top = 14.0
	_toast_root.scale = Vector2.ZERO
	_toast_root.modulate.a = 0.0
