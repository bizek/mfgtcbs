extends CanvasLayer

## HUD — Health bar, XP bar, level display, game timer, kill count

@onready var health_bar: ProgressBar = $TopBar/HealthBar
@onready var health_label: Label = $TopBar/HealthLabel
@onready var xp_bar: ProgressBar = $XPContainer/XPBar
@onready var level_label: Label = $XPContainer/LevelLabel
@onready var timer_label: Label = $TopBar/TimerLabel
@onready var kills_label: Label = $TopBar/KillsLabel
@onready var extraction_bar: ProgressBar = $ExtractionContainer/ExtractionBar
@onready var extraction_label: Label = $ExtractionContainer/ExtractionLabel

var player_ref: Node2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	extraction_bar.visible = false
	extraction_label.visible = false

	## Connect to manager signals
	GameManager.phase_timer_updated.connect(_on_phase_timer_updated)
	ExtractionManager.extraction_channel_started.connect(_on_extraction_started)
	ExtractionManager.extraction_channel_progress.connect(_on_extraction_progress)
	ExtractionManager.extraction_interrupted.connect(_on_extraction_interrupted)
	ExtractionManager.extraction_complete.connect(_on_extraction_complete)

func setup(player: Node2D) -> void:
	player_ref = player
	player_ref.health_changed.connect(_on_health_changed)
	player_ref.xp_changed.connect(_on_xp_changed)
	player_ref.leveled_up.connect(_on_leveled_up)

	## Initialize display
	_on_health_changed(player_ref.stats.hp, player_ref.get_stat("max_hp"))
	_on_xp_changed(player_ref.xp, player_ref._xp_to_next_level())
	level_label.text = "Lv %d" % player_ref.level

func _process(_delta: float) -> void:
	## Update timer and kills from GameManager
	var total_seconds: int = int(GameManager.run_time)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]
	kills_label.text = "Kills: %d" % GameManager.kills

func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [int(current), int(maximum)]

func _on_xp_changed(current: float, needed: float) -> void:
	xp_bar.max_value = needed
	xp_bar.value = current

func _on_leveled_up(new_level: int) -> void:
	level_label.text = "Lv %d" % new_level

func _on_phase_timer_updated(_time_remaining: float) -> void:
	pass ## Timer display handled in _process

func _on_extraction_started() -> void:
	extraction_bar.visible = true
	extraction_label.visible = true
	extraction_bar.value = 0.0
	extraction_label.text = "EXTRACTING..."

func _on_extraction_progress(percent: float) -> void:
	extraction_bar.value = percent * 100.0

func _on_extraction_interrupted() -> void:
	extraction_bar.visible = false
	extraction_label.visible = false

func _on_extraction_complete() -> void:
	extraction_bar.visible = false
	extraction_label.visible = false
