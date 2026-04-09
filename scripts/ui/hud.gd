extends CanvasLayer

## HUD — Health bar, XP bar, level display, loot counter, instability vignette,
## extraction window countdown, and LOOT AT RISK warning.

@onready var health_bar: ProgressBar = $TopLeft/HPRow/HealthBar
@onready var health_label: Label = $TopLeft/HPRow/HealthLabel
@onready var xp_bar: ProgressBar = $TopLeft/XPRow/XPBar
@onready var level_label: Label = $TopLeft/XPRow/LevelLabel
@onready var loot_label: Label = $TopLeft/LootLabel
@onready var timer_label: Label = $TopRight/TimerLabel
@onready var kills_label: Label = $TopRight/KillsLabel
@onready var extraction_window_label: Label = $ExtractionWindowLabel
@onready var loot_at_risk_label: Label = $LootAtRiskLabel
@onready var extraction_container: VBoxContainer = $ExtractionContainer
@onready var extraction_label: Label = $ExtractionContainer/ExtractionLabel
@onready var extraction_bar: ProgressBar = $ExtractionContainer/ExtractionBar
@onready var extraction_window_bg: ColorRect = $ExtractionWindowBG
@onready var extraction_arrow_label: Label = $ExtractionArrowLabel
@onready var extraction_flash: ColorRect = $ExtractionFlashOverlay
@onready var vig_top: ColorRect = $VigTop
@onready var vig_bottom: ColorRect = $VigBottom
@onready var vig_left: ColorRect = $VigLeft
@onready var vig_right: ColorRect = $VigRight

var player_ref: Node2D = null
var _blink_timer: float = 0.0

## ── Keystone indicator (top-right area, shown when player holds a keystone) ──
var _keystone_indicator: Control = null
## ── Guardian health bar (shown prominently when guardian is nearby) ──────────
var _guardian_bar_root: Control = null
var _guardian_hp_bar: ProgressBar = null
var _guardian_hp_label: Label = null
## ── Phase indicators (top-center) ────────────────────────────────────────────
var _phase_label: Label = null
var _phase_flash_label: Label = null
var _extraction_warning_label: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	extraction_container.visible = false
	extraction_window_label.visible = false
	extraction_window_bg.visible = false
	extraction_arrow_label.visible = false
	extraction_flash.visible = false
	loot_at_risk_label.visible = false

	GameManager.loot_changed.connect(_on_loot_changed)
	GameManager.instability_changed.connect(_on_instability_changed)
	GameManager.extraction_window_opened.connect(_on_extraction_window_opened)
	GameManager.extraction_window_closed.connect(_on_extraction_window_closed)
	GameManager.player_died.connect(_on_player_died_hud)
	ExtractionManager.extraction_channel_started.connect(_on_extraction_started)
	ExtractionManager.extraction_channel_progress.connect(_on_extraction_progress)
	ExtractionManager.extraction_interrupted.connect(_on_extraction_interrupted)
	ExtractionManager.extraction_complete.connect(_on_extraction_complete)
	GameManager.keystone_picked_up.connect(_on_keystone_picked_up)
	GameManager.guardian_state_changed.connect(_on_guardian_state_changed)

	_build_keystone_indicator()
	_build_guardian_health_bar()
	_build_phase_label()
	_build_phase_flash_label()
	_build_extraction_warning_label()
	GameManager.phase_started.connect(_on_phase_started)

func setup(player: Node2D) -> void:
	player_ref = player
	player_ref.health_changed.connect(_on_health_changed)
	player_ref.xp_changed.connect(_on_xp_changed)
	player_ref.leveled_up.connect(_on_leveled_up)
	_on_health_changed(player_ref.stats.hp, player_ref.get_stat("max_hp"))
	_on_xp_changed(player_ref.xp, player_ref._xp_to_next_level())
	level_label.text = "Lv%d" % player_ref.level

func _process(delta: float) -> void:
	_blink_timer += delta

	## Timer and kill count
	var total_seconds: int = int(GameManager.run_time)
	timer_label.text = "%d:%02d" % [total_seconds / 60, total_seconds % 60]
	kills_label.text = "K:%d" % GameManager.kills

	## Extraction window countdown
	if GameManager.extraction_window_active:
		extraction_window_label.visible = true
		extraction_window_bg.visible = true
		var t: float = GameManager.extraction_window_timer
		extraction_window_label.text = "EXTRACT  %ds" % int(ceilf(t))
		if t <= 5.0:
			var blink: float = 0.55 + 0.45 * sin(_blink_timer * 10.0)
			extraction_window_label.modulate.a = blink
			extraction_window_bg.color.a = 0.6 + 0.3 * sin(_blink_timer * 10.0)
		else:
			extraction_window_label.modulate.a = 1.0
			extraction_window_bg.color.a = 0.9
		_update_extraction_arrow()
	else:
		extraction_window_label.visible = false
		extraction_window_bg.visible = false
		extraction_arrow_label.visible = false

	## Keystone indicator visibility
	if _keystone_indicator:
		_keystone_indicator.visible = GameManager.player_has_keystone

	## Phase countdown warning / Core phase notice
	if _extraction_warning_label != null:
		var time_remaining: float = GameManager.phase_duration - GameManager.phase_timer
		if GameManager.phase_number >= GameManager.MAX_PHASES:
			## Phase 5: no timed exit — show a permanent notice
			_extraction_warning_label.text = "THE CORE — NO TIMED EXIT"
			_extraction_warning_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			_extraction_warning_label.visible = true
			_extraction_warning_label.modulate.a = 1.0
		elif time_remaining <= 10.0 and time_remaining > 0.0 and not GameManager.extraction_window_active:
			## Last 10 seconds before extraction window opens — blink warning
			_extraction_warning_label.text = "EXTRACTION IN %d" % ceili(time_remaining)
			_extraction_warning_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
			_extraction_warning_label.visible = fmod(_blink_timer, 1.0) > 0.5
		else:
			_extraction_warning_label.visible = false

func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d/%d" % [int(current), int(maximum)]

func _on_xp_changed(current: float, needed: float) -> void:
	xp_bar.max_value = needed
	xp_bar.value = current

func _on_leveled_up(new_level: int) -> void:
	level_label.text = "Lv%d" % new_level

func _on_loot_changed(new_value: float) -> void:
	loot_label.text = "LOOT: %d" % int(new_value)

func _on_instability_changed(_new_value: float) -> void:
	pass  ## Vignette / LOOT AT RISK removed — instability is tracked silently via loot counter

func _on_extraction_started() -> void:
	extraction_container.visible = true
	extraction_bar.value = 0.0
	extraction_label.text = "EXTRACTING..."

func _on_extraction_progress(percent: float) -> void:
	extraction_bar.value = percent * 100.0
	var remaining: float = ExtractionManager.channel_duration - ExtractionManager.channel_timer
	extraction_label.text = "EXTRACTING  %.1fs" % maxf(remaining, 0.0)

func _on_extraction_interrupted() -> void:
	extraction_container.visible = false

func _on_extraction_complete() -> void:
	extraction_container.visible = false

func _on_player_died_hud() -> void:
	## Clean up any in-progress extraction UI so it doesn't overlay the game over screen
	extraction_container.visible = false

func _on_extraction_window_opened() -> void:
	extraction_flash.color.a = 0.0
	extraction_flash.visible = true
	var tween := create_tween()
	tween.tween_property(extraction_flash, "color:a", 0.5, 0.07)
	tween.tween_property(extraction_flash, "color:a", 0.0, 0.55)
	tween.tween_callback(func(): extraction_flash.visible = false)

func _on_extraction_window_closed() -> void:
	extraction_arrow_label.visible = false
	extraction_window_bg.visible = false

## ── Keystone indicator ────────────────────────────────────────────────────────

func _build_keystone_indicator() -> void:
	## Small golden panel, top-right, below the kills label
	## Positioned at x=360, y=2 (just left of kills counter area)
	var root := Control.new()
	root.name = "KeystoneIndicator"
	root.position = Vector2(360.0, 2.0)
	root.visible = false
	_keystone_indicator = root
	add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.10, 0.03, 0.90)
	bg.size = Vector2(78.0, 16.0)
	root.add_child(bg)

	var accent := ColorRect.new()
	accent.color = Color(0.95, 0.80, 0.12)
	accent.size = Vector2(78.0, 1.0)
	root.add_child(accent)

	var gem := ColorRect.new()
	gem.color = Color(1.0, 0.88, 0.10)
	gem.size = Vector2(8.0, 8.0)
	gem.position = Vector2(3.0, 4.0)
	root.add_child(gem)

	var lbl := Label.new()
	lbl.text = "KEYSTONE"
	lbl.position = Vector2(14.0, 2.0)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.22))
	if ResourceLoader.exists("res://assets/fonts/m5x7.ttf"):
		lbl.add_theme_font_override("font", load("res://assets/fonts/m5x7.ttf"))
	root.add_child(lbl)

	## Gem spin
	var spin := root.create_tween().set_loops()
	spin.tween_property(gem, "rotation", TAU, 2.0)

func _on_keystone_picked_up() -> void:
	if _keystone_indicator:
		_keystone_indicator.visible = true
		## Brief flash
		var t := _keystone_indicator.create_tween()
		t.tween_property(_keystone_indicator, "modulate:a", 0.2, 0.05)
		t.tween_property(_keystone_indicator, "modulate:a", 1.0, 0.20)

## ── Guardian health bar ───────────────────────────────────────────────────────

func _build_guardian_health_bar() -> void:
	## Prominent health bar shown below center-screen when guardian is nearby.
	## Styled in dark red to match the guardian's ominous theme.
	var root := Control.new()
	root.name = "GuardianHealthBar"
	root.position = Vector2(120.0, 40.0)   ## Below the main HUD rows
	root.visible = false
	_guardian_bar_root = root
	add_child(root)

	const BAR_W: float = 240.0
	const BAR_H: float = 10.0

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.04, 0.04, 0.92)
	bg.size = Vector2(BAR_W + 4.0, BAR_H + 18.0)
	bg.position = Vector2(-2.0, -2.0)
	root.add_child(bg)

	var label := Label.new()
	label.name = "GuardianLabel"
	label.text = "GUARDIAN"
	label.position = Vector2(0.0, 0.0)
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.90, 0.28, 0.22))
	if ResourceLoader.exists("res://assets/fonts/m5x7.ttf"):
		label.add_theme_font_override("font", load("res://assets/fonts/m5x7.ttf"))
	root.add_child(label)
	_guardian_hp_label = label

	var bar := ProgressBar.new()
	bar.name = "GuardianHPBar"
	bar.size = Vector2(BAR_W, BAR_H)
	bar.position = Vector2(0.0, 12.0)
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.18, 0.06, 0.06)
	bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.80, 0.12, 0.12)
	bar.add_theme_stylebox_override("fill", bar_fill)

	root.add_child(bar)
	_guardian_hp_bar = bar

func _on_guardian_state_changed(hp: float, max_hp: float, show_bar: bool) -> void:
	if _guardian_bar_root == null:
		return
	_guardian_bar_root.visible = show_bar
	if show_bar and max_hp > 0.0:
		_guardian_hp_bar.max_value = max_hp
		_guardian_hp_bar.value = hp
		var hp_pct: int = int(round(hp / max_hp * 100.0))
		if _guardian_hp_label:
			_guardian_hp_label.text = "GUARDIAN  %d / %d  (%d%%)" % [int(hp), int(max_hp), hp_pct]

## ── Phase label + flash ──────────────────────────────────────────────────────

func _build_phase_label() -> void:
	## Persistent phase name strip, top-center (x=140–340, y=2). Font 12 → 48px at 4×.
	var lbl := Label.new()
	lbl.name = "PhaseLabel"
	lbl.text = "PHASE 1: THE THRESHOLD"
	lbl.position = Vector2(140.0, 2.0)
	lbl.size = Vector2(200.0, 14.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.modulate = Color(1.0, 1.0, 1.0, 0.75)
	if ResourceLoader.exists("res://assets/fonts/m5x7.ttf"):
		lbl.add_theme_font_override("font", load("res://assets/fonts/m5x7.ttf"))
	add_child(lbl)
	_phase_label = lbl

func _build_phase_flash_label() -> void:
	## Large centred flash label that briefly announces the new phase name.
	## Starts invisible; fades out after being triggered by _on_phase_started.
	var lbl := Label.new()
	lbl.name = "PhaseFlashLabel"
	lbl.text = ""
	lbl.position = Vector2(40.0, 110.0)
	lbl.size = Vector2(400.0, 40.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	lbl.modulate.a = 0.0
	if ResourceLoader.exists("res://assets/fonts/m5x7.ttf"):
		lbl.add_theme_font_override("font", load("res://assets/fonts/m5x7.ttf"))
	add_child(lbl)
	_phase_flash_label = lbl

func _build_extraction_warning_label() -> void:
	## Blinking 10-second countdown before the extraction window opens.
	## Sits one text-row below the phase label (y=15). Same centre column.
	var lbl := Label.new()
	lbl.name = "ExtractionWarningLabel"
	lbl.text = ""
	lbl.position = Vector2(140.0, 15.0)
	lbl.size = Vector2(200.0, 12.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
	lbl.visible = false
	if ResourceLoader.exists("res://assets/fonts/m5x7.ttf"):
		lbl.add_theme_font_override("font", load("res://assets/fonts/m5x7.ttf"))
	add_child(lbl)
	_extraction_warning_label = lbl

func _on_phase_started(phase: int) -> void:
	## Update the persistent phase strip
	if _phase_label:
		_phase_label.text = "PHASE %d: %s" % [phase, GameManager.PHASE_NAMES[phase - 1]]
	## Trigger the centred flash announcement
	if _phase_flash_label:
		_phase_flash_label.text = GameManager.PHASE_NAMES[phase - 1]
		_phase_flash_label.modulate.a = 1.0
		var tween := create_tween()
		tween.tween_interval(0.5)               ## Hold at full opacity briefly
		tween.tween_property(_phase_flash_label, "modulate:a", 0.0, 1.5)
	## Hide the warning label immediately — new phase timer starts fresh
	if _extraction_warning_label:
		_extraction_warning_label.visible = false

func _update_extraction_arrow() -> void:
	if ExtractionManager.extraction_point == null or not is_instance_valid(ExtractionManager.extraction_point):
		extraction_arrow_label.visible = false
		return
	var world_pos: Vector2 = ExtractionManager.extraction_point.global_position
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var margin: float = 52.0
	var on_screen: bool = screen_pos.x >= margin and screen_pos.x <= vp_size.x - margin \
		and screen_pos.y >= margin and screen_pos.y <= vp_size.y - margin
	if on_screen:
		extraction_arrow_label.visible = false
		return
	extraction_arrow_label.visible = true
	var dir: Vector2 = (screen_pos - vp_size * 0.5).normalized()
	var angle: float = dir.angle()
	var arrows: Array[String] = ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	var idx: int = int(round(fposmod(angle, TAU) / (TAU / 8.0))) % 8
	var clamped_pos: Vector2 = Vector2(
		clampf(screen_pos.x, margin, vp_size.x - margin),
		clampf(screen_pos.y, margin, vp_size.y - margin)
	)
	extraction_arrow_label.text = arrows[idx] + " PORTAL"
	extraction_arrow_label.position = clamped_pos - Vector2(64.0, 10.0)
