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
	ExtractionManager.extraction_channel_started.connect(_on_extraction_started)
	ExtractionManager.extraction_channel_progress.connect(_on_extraction_progress)
	ExtractionManager.extraction_interrupted.connect(_on_extraction_interrupted)
	ExtractionManager.extraction_complete.connect(_on_extraction_complete)

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

	## LOOT AT RISK warning (blinks at Unsettled tier and above)
	if GameManager.instability >= 31.0 and GameManager.loot_carried > 0.0:
		loot_at_risk_label.visible = true
		loot_at_risk_label.modulate.a = 0.55 + 0.45 * sin(_blink_timer * 4.0)
	else:
		loot_at_risk_label.visible = false

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

func _on_instability_changed(new_value: float) -> void:
	## Drive vignette intensity and color from instability tier.
	## Stable(0-30): invisible. Unsettled(31-70): faint dark red.
	## Volatile(71-120): deeper red. Critical(121+): intense pulsing red.
	var alpha: float
	var red: float

	if new_value <= 30.0:
		alpha = 0.0
		red = 0.5
	elif new_value <= 70.0:
		var t: float = (new_value - 30.0) / 40.0
		alpha = lerpf(0.0, 0.18, t)
		red = 0.6
	elif new_value <= 120.0:
		var t: float = (new_value - 70.0) / 50.0
		alpha = lerpf(0.18, 0.35, t)
		red = 0.75
	else:
		var t: float = minf((new_value - 120.0) / 80.0, 1.0)
		alpha = lerpf(0.35, 0.55, t)
		red = 0.9

	var vc := Color(red, 0.0, 0.0, alpha)
	vig_top.color = vc
	vig_bottom.color = vc
	vig_left.color = vc
	vig_right.color = vc

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
