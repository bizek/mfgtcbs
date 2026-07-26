extends CanvasLayer

## HUD — Health bar, XP bar, level display, loot counter, instability vignette,
## extraction window countdown, LOOT AT RISK warning, and combo discovery popups.

## ── Minifantasy UI theme (Classic set) ───────────────────────────────────────
## Bars/panels are sourced from the Minifantasy UI Overhaul "Classic" sheet.
## The five 40x6 capsule fills sit on a 256px column stride; panels are
## nine-patch regions. To retheme, only these rects + UI_SHEET_PATH change.
const UI_SHEET_PATH: String = "res://assets/minifantasy/Minifantasy_UI _Overhaul_v1.0/_Minifantasy_UI_Overhaul_Assets/Classic_Minifantasy_UI/_Classic_UI.png"
const FILL_RED: Rect2 = Rect2(340.0, 709.0, 40.0, 6.0)
const FILL_BLUE: Rect2 = Rect2(596.0, 709.0, 40.0, 6.0)
const FILL_YELLOW: Rect2 = Rect2(852.0, 709.0, 40.0, 6.0)
const FILL_GREEN: Rect2 = Rect2(1108.0, 709.0, 40.0, 6.0)
const FILL_PURPLE: Rect2 = Rect2(1364.0, 709.0, 40.0, 6.0)
const PANEL_SQUARE: Rect2 = Rect2(64.0, 384.0, 48.0, 48.0)  ## nine-patch, 6px borders
const PANEL_PILL: Rect2 = Rect2(64.0, 352.0, 48.0, 16.0)    ## nine-patch, 5px borders
const NUB_RED: Rect2 = Rect2(392.0, 709.0, 4.0, 6.0)        ## capsule end-cap gems
const NUB_BLUE: Rect2 = Rect2(648.0, 709.0, 4.0, 6.0)
const BOSS_BAR_W: float = 192.0
var _ui_sheet: Texture2D = null

## Scales a base font size by the accessibility text-size setting (Small/Normal/Large).
func _ts(base_size: int) -> int:
	return int(roundf(base_size * Settings.get_text_scale()))

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
var _first_run_overlay: FirstRunOverlay = null

## ── Keystone indicator (top-right area, shown when player holds a keystone) ──
var _keystone_indicator: Control = null
## ── Boss health bars (guardian + bosses share this system) ───────────────────
## Keyed by boss id. Entry: { root: Control, bar: ProgressBar, label: Label,
##                            color: Color, display_name: String, y_offset: float }
var _boss_bars: Dictionary = {}
## Legacy guardian refs (now resolve into _boss_bars["guardian"]).
var _guardian_bar_root: Control = null
var _guardian_hp_bar: ProgressBar = null
var _guardian_hp_label: Label = null
## ── Phase indicators (top-center) ────────────────────────────────────────────
var _phase_flash_label: Label = null
var _extraction_warning_label: Label = null
## ── Skill slots (Q/E cooldown keycaps, bottom-center) ────────────────────────
## slot:String -> { root, veil, key, key_text, prev_remaining }
var _skill_slots: Dictionary = {}
## ── Depth meter (descent mode, left edge below instability) ──────────────────
var _depth_tracker: DepthTracker = null
var _depth_meter_root: Control = null
var _depth_fill: ColorRect = null
var _depth_tween: Tween = null
var _depth_tweened_to: float = 0.0
var _depth_tick_nodes: Array[Control] = []

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
	GameManager.boss_state_changed.connect(_on_boss_state_changed)
	GameManager.final_boss_spawned.connect(_on_final_boss_spawned)
	GameManager.final_boss_defeated.connect(_on_final_boss_defeated)

	_apply_minifantasy_theme()
	_build_skill_slots()
	_build_buff_chips()
	_build_keystone_indicator()
	_build_guardian_health_bar()
	_build_phase_flash_label()
	_build_extraction_warning_label()
	_build_depth_meter()
	_build_combo_discovery_popup()
	_build_first_run_overlay()
	GameManager.phase_started.connect(_on_phase_started)

func setup(player: Node2D) -> void:
	player_ref = player
	player_ref.health_changed.connect(_on_health_changed)
	player_ref.xp_changed.connect(_on_xp_changed)
	player_ref.leveled_up.connect(_on_leveled_up)
	_on_health_changed(player_ref.health.current_hp, player_ref.health.max_hp)
	_on_xp_changed(player_ref.xp, player_ref._xp_to_next_level())
	level_label.text = "Lv%d" % player_ref.level
	_refresh_skill_slot_keys()
	if _first_run_overlay != null:
		_first_run_overlay.setup(player)

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

	_update_skill_slots()
	_update_buff_chips()

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

	## Depth meter — tween fill bar when progress advances
	if _depth_tracker != null and _depth_fill != null:
		var target: float = _depth_tracker.depth_progress
		if target > _depth_tweened_to + 0.001:
			_depth_tweened_to = target
			if _depth_tween != null:
				_depth_tween.kill()
			const METER_H: float = 200.0
			_depth_tween = create_tween()
			_depth_tween.tween_property(_depth_fill, "size:y",
				METER_H * target, 0.3).set_ease(Tween.EASE_OUT)

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
	## Instability reads atmospherically — no meter. A tier-colored vignette
	## creeps in from ~50 instability, plus the LOOT AT RISK warning at Volatile+.
	var tier: Dictionary = LootTables.get_instability_tier(new_value)
	var col: Color = tier.color

	var vig_alpha: float = clampf((new_value - 50.0) / 100.0, 0.0, 1.0) * 0.32
	var vig_col := Color(col.r * 0.7, col.g * 0.1, col.b * 0.1, vig_alpha)
	vig_top.color    = vig_col
	vig_bottom.color = vig_col
	vig_left.color   = vig_col
	vig_right.color  = vig_col

	## LOOT AT RISK label — visible at Volatile+ (71+)
	loot_at_risk_label.visible = new_value >= 71.0

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

## ── Minifantasy UI theme ─────────────────────────────────────────────────────

func _sheet() -> Texture2D:
	if _ui_sheet == null:
		_ui_sheet = load(UI_SHEET_PATH)
	return _ui_sheet

## Colored capsule fill for a ProgressBar (3px end caps preserved on stretch).
func _bar_fill_stylebox(region: Rect2) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _sheet()
	sb.region_rect = region
	sb.texture_margin_left = 3.0
	sb.texture_margin_right = 3.0
	return sb

## Dark recessed track with a thin bronze rim; 1px content margin so the 6px
## capsule fill sits pixel-perfect inside an 8px-tall bar.
func _bar_track_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.05, 0.04, 0.92)
	sb.border_color = Color(0.30, 0.22, 0.14)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(1.0)
	return sb

## Nearest sheet capsule color for an arbitrary boss color.
func _fill_region_for_color(c: Color) -> Rect2:
	if c.r > 0.5 and c.b > 0.5:
		return FILL_PURPLE
	if c.r > 0.5 and c.g > 0.45:
		return FILL_YELLOW
	if c.g > 0.5:
		return FILL_GREEN
	if c.b > 0.5:
		return FILL_BLUE
	return FILL_RED

## Framed nine-patch panel, inserted directly after `after` in tree order so it
## renders behind the content that follows it.
func _add_ui_panel(rect: Rect2, after: CanvasItem) -> NinePatchRect:
	var p := NinePatchRect.new()
	p.texture = _sheet()
	p.region_rect = PANEL_SQUARE
	p.patch_margin_left = 6
	p.patch_margin_top = 6
	p.patch_margin_right = 6
	p.patch_margin_bottom = 6
	p.position = rect.position
	p.size = rect.size
	p.modulate = Color(0.72, 0.66, 0.58, 0.94)  ## dim the bronze toward the cave palette
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	if after != null:
		move_child(p, after.get_index() + 1)
	return p

## Outlined label centered inside a bar (numbers live in the bar itself).
func _add_bar_inner_label(bar: ProgressBar, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _ts(font_size))
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/fonts/m5x7.ttf"):
		lbl.add_theme_font_override("font", load("res://assets/fonts/m5x7.ttf"))
	bar.add_child(lbl)
	return lbl

## Small capsule-gem ornament half-hanging off the bar's right end.
func _add_bar_end_nub(bar: ProgressBar, region: Rect2) -> void:
	var at := AtlasTexture.new()
	at.atlas = _sheet()
	at.region = region
	var tr := TextureRect.new()
	tr.texture = at
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.anchor_top = 0.5
	tr.anchor_bottom = 0.5
	tr.offset_left = -3.0
	tr.offset_right = 5.0
	tr.offset_top = -6.0
	tr.offset_bottom = 6.0
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(tr)

func _apply_minifantasy_theme() -> void:
	## Floating framed bars with the numbers inside them — no backing panel.
	var tl_bg: ColorRect = $TopLeftBG
	tl_bg.visible = false
	var tl: VBoxContainer = $TopLeft
	tl.offset_left = 4.0
	tl.offset_top = 4.0
	tl.offset_right = 168.0

	health_bar.add_theme_stylebox_override("background", _bar_track_stylebox())
	health_bar.add_theme_stylebox_override("fill", _bar_fill_stylebox(FILL_RED))
	health_bar.custom_minimum_size = Vector2(160.0, 14.0)
	health_label.visible = false
	health_label = _add_bar_inner_label(health_bar, 12)
	_add_bar_end_nub(health_bar, NUB_RED)

	xp_bar.add_theme_stylebox_override("background", _bar_track_stylebox())
	xp_bar.add_theme_stylebox_override("fill", _bar_fill_stylebox(FILL_BLUE))
	xp_bar.custom_minimum_size = Vector2(160.0, 12.0)
	level_label.visible = false
	level_label = _add_bar_inner_label(xp_bar, 12)
	level_label.text = "Lv1"
	_add_bar_end_nub(xp_bar, NUB_BLUE)

	extraction_bar.add_theme_stylebox_override("background", _bar_track_stylebox())
	extraction_bar.add_theme_stylebox_override("fill", _bar_fill_stylebox(FILL_GREEN))
	extraction_bar.custom_minimum_size = Vector2(180.0, 8.0)

	## Timer/kills keep their small framed plate top-right.
	var tr_bg: ColorRect = $TopRightBG
	tr_bg.visible = false
	_add_ui_panel(Rect2(566.0, 2.0, 72.0, 40.0), tr_bg)
	var trv: VBoxContainer = $TopRight
	trv.offset_left = -70.0
	trv.offset_top = 7.0
	trv.offset_right = -8.0

## ── Keystone indicator ────────────────────────────────────────────────────────

func _build_keystone_indicator() -> void:
	## Small golden panel, top-right, below the kills label
	## Positioned at x=360, y=2 (just left of kills counter area)
	var root := Control.new()
	root.name = "KeystoneIndicator"
	root.position = Vector2(480.0, 2.0)
	root.visible = false
	_keystone_indicator = root
	add_child(root)

	var bg := NinePatchRect.new()
	bg.texture = _sheet()
	bg.region_rect = PANEL_PILL
	bg.patch_margin_left = 5
	bg.patch_margin_top = 5
	bg.patch_margin_right = 5
	bg.patch_margin_bottom = 5
	bg.size = Vector2(78.0, 16.0)
	bg.modulate = Color(0.72, 0.66, 0.58, 0.94)
	root.add_child(bg)

	var gem := ColorRect.new()
	gem.color = Color(1.0, 0.88, 0.10)
	gem.size = Vector2(8.0, 8.0)
	gem.position = Vector2(3.0, 4.0)
	root.add_child(gem)

	var lbl := Label.new()
	lbl.text = "KEYSTONE"
	lbl.position = Vector2(14.0, 2.0)
	lbl.add_theme_font_size_override("font_size", _ts(12))
	lbl.add_theme_color_override("font_color", Color(0.32, 0.20, 0.06))
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

## ── Boss / Guardian health bars ───────────────────────────────────────────────
## Shared system. Guardian uses id="guardian" at y=40. Minibosses, bosses, and
## the final boss register on first show via _on_boss_state_changed.

func _build_guardian_health_bar() -> void:
	## Pre-register the guardian bar so its layout is stable across runs.
	var entry := _build_boss_bar(
			"guardian", "GUARDIAN", Color(0.80, 0.12, 0.12), 4.0)
	_guardian_bar_root = entry.root
	_guardian_hp_bar = entry.bar
	_guardian_hp_label = entry.label

func _build_boss_bar(id: String, display_name: String, color: Color,
		y_offset: float) -> Dictionary:
	## Framed capsule bar pinned top-center, boss name + HP% centered INSIDE
	## the bar. Registered in _boss_bars by id.
	var root := Control.new()
	root.name = "BossBar_" + id
	root.position = Vector2((640.0 - BOSS_BAR_W) * 0.5, y_offset)
	root.visible = false
	add_child(root)

	var bar := ProgressBar.new()
	bar.name = "BossHPBar"
	bar.custom_minimum_size = Vector2(BOSS_BAR_W, 16.0)
	bar.size = Vector2(BOSS_BAR_W, 16.0)
	bar.position = Vector2(0.0, 0.0)
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _bar_track_stylebox())
	bar.add_theme_stylebox_override("fill",
			_bar_fill_stylebox(_fill_region_for_color(color)))
	root.add_child(bar)

	var label := _add_bar_inner_label(bar, 12)
	label.name = "BossLabel"
	label.text = display_name

	var entry := {
		"root": root,
		"bar": bar,
		"label": label,
		"color": color,
		"display_name": display_name,
		"y_offset": y_offset,
	}
	_boss_bars[id] = entry
	return entry

func _update_boss_bar(id: String, hp: float, max_hp: float) -> void:
	var entry: Dictionary = _boss_bars.get(id, {})
	if entry.is_empty():
		return
	entry.bar.max_value = max_hp
	entry.bar.value = hp
	var hp_pct: int = int(round(hp / max_hp * 100.0))
	if entry.label:
		entry.label.text = "%s  %d%%" % [entry.display_name, hp_pct]

func _on_guardian_state_changed(hp: float, max_hp: float, show_bar: bool) -> void:
	## Legacy signal for the guardian — routes through the shared bar system.
	var entry: Dictionary = _boss_bars.get("guardian", {})
	if entry.is_empty():
		return
	entry.root.visible = show_bar
	if show_bar and max_hp > 0.0:
		_update_boss_bar("guardian", hp, max_hp)

func _on_boss_state_changed(id: String, hp: float, max_hp: float, show_bar: bool,
		display_name: String, color: Color) -> void:
	## Unified signal for any boss (minibosses, final boss, etc). Creates the
	## bar on first show if not registered. id is the key used to update later.
	if id == "":
		return
	if not _boss_bars.has(id):
		if not show_bar:
			return
		var y_offset: float = _next_boss_bar_y_offset(id)
		_build_boss_bar(id, display_name, color, y_offset)
	var entry: Dictionary = _boss_bars[id]
	entry.root.visible = show_bar
	if show_bar and max_hp > 0.0:
		_update_boss_bar(id, hp, max_hp)

func _next_boss_bar_y_offset(id: String) -> float:
	## Slot policy: bars fill the top-center rows (y=4, then 22px steps).
	## Only rows currently occupied by a VISIBLE bar are skipped.
	if id == "final_boss":
		return 4.0
	var used: Dictionary = {}
	for key in _boss_bars.keys():
		var entry: Dictionary = _boss_bars[key]
		if entry.root and entry.root.visible:
			used[entry.y_offset] = true
	var candidate: float = 4.0
	while used.has(candidate):
		candidate += 22.0
	return candidate

## ── Phase flash ──────────────────────────────────────────────────────────────

func _build_phase_flash_label() -> void:
	## Large centred flash label that briefly announces the new phase name.
	## Starts invisible; fades out after being triggered by _on_phase_started.
	var lbl := Label.new()
	lbl.name = "PhaseFlashLabel"
	lbl.text = ""
	lbl.position = Vector2(120.0, 147.0)
	lbl.size = Vector2(400.0, 40.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _ts(27))
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	lbl.modulate.a = 0.0
	if ResourceLoader.exists("res://assets/fonts/m5x7.ttf"):
		lbl.add_theme_font_override("font", load("res://assets/fonts/m5x7.ttf"))
	add_child(lbl)
	_phase_flash_label = lbl

func _build_extraction_warning_label() -> void:
	## Blinking 10-second countdown before the extraction window opens.
	## Sits just below the boss-bar row, top-center.
	var lbl := Label.new()
	lbl.name = "ExtractionWarningLabel"
	lbl.text = ""
	lbl.position = Vector2(220.0, 24.0)
	lbl.size = Vector2(200.0, 12.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _ts(14))
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.visible = false
	if ResourceLoader.exists("res://assets/fonts/m5x7.ttf"):
		lbl.add_theme_font_override("font", load("res://assets/fonts/m5x7.ttf"))
	add_child(lbl)
	_extraction_warning_label = lbl

func flash_text(text: String, color: Color = Color(1.0, 0.9, 0.7),
		duration: float = 1.5) -> void:
	## Public helper: reuse the phase flash label for any centered announcement.
	## Cancels whatever was animating there and runs a new fade.
	if _phase_flash_label == null:
		return
	_phase_flash_label.text = text
	_phase_flash_label.add_theme_color_override("font_color", color)
	_phase_flash_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(_phase_flash_label, "modulate:a", 0.0, duration)

func _on_final_boss_spawned(display_name: String) -> void:
	flash_text("BOSS INCOMING — %s" % display_name.to_upper(),
			Color(1.0, 0.3, 0.25), 1.8)

func _on_final_boss_defeated() -> void:
	flash_text("EXTRACTION UNLOCKED", Color(0.3, 1.0, 0.55), 1.5)

## ── Skill slots (Q/E cooldowns) ──────────────────────────────────────────────
## Two Minifantasy keycap slots, bottom-center. Ready: bright key letter. Cooling:
## dark veil drains downward + the letter is replaced by the seconds countdown.

const SKILL_SLOT: float = 22.0
const SKILL_SLOT_GAP: float = 4.0
const SKILL_SLOT_Y: float = 360.0 - SKILL_SLOT - 6.0

## ── Buff tracker (chips centered above the Q/E slots) ────────────────────────
const BUFF_CHIP_W: float = 36.0
const BUFF_CHIP_H: float = 13.0
const BUFF_CHIP_GAP: float = 3.0
const BUFF_BAR_Y: float = SKILL_SLOT_Y - BUFF_CHIP_H - 5.0
const BUFF_MAX_CHIPS: int = 8
## status_id -> short chip label. Anything unlisted falls back to the id, upper-cased.
const BUFF_NAMES: Dictionary = {
	"steeled": "STEELED",        "aegis": "AEGIS",          "blessed": "BLESSED",
	"fleetfoot": "SWIFT",        "mana_surge": "SURGE",     "blood_surge": "SURGE",
	"blood_power": "PACT",       "battle_fury": "FURY",     "honed_edge": "HONED",
	"loaded_chambers": "LOADED", "concealed": "HIDDEN",     "slippery": "SLIPPERY",
	"aegis_shield": "SHIELD",    "hallowed": "HALLOWED",
}

func _build_skill_slots() -> void:
	var slots: Array = ["skill_q", "skill_e"]
	for i in range(slots.size()):
		var slot: String = slots[i]
		var root := Control.new()
		root.name = "SkillSlot_" + slot
		root.position = Vector2(
				320.0 - SKILL_SLOT - SKILL_SLOT_GAP * 0.5 + float(i) * (SKILL_SLOT + SKILL_SLOT_GAP),
				SKILL_SLOT_Y)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.visible = false
		add_child(root)

		var bg := NinePatchRect.new()
		bg.texture = _sheet()
		bg.region_rect = PANEL_SQUARE
		bg.patch_margin_left = 6
		bg.patch_margin_top = 6
		bg.patch_margin_right = 6
		bg.patch_margin_bottom = 6
		bg.size = Vector2(SKILL_SLOT, SKILL_SLOT)
		bg.modulate = Color(0.72, 0.66, 0.58, 0.94)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bg)

		## Cooldown veil: full at cast, drains toward the bottom as the skill recharges.
		var veil := ColorRect.new()
		veil.color = Color(0.0, 0.0, 0.0, 0.62)
		veil.position = Vector2(2.0, 2.0)
		veil.size = Vector2(SKILL_SLOT - 4.0, SKILL_SLOT - 4.0)
		veil.visible = false
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(veil)

		var key := Label.new()
		key.set_anchors_preset(Control.PRESET_FULL_RECT)
		key.offset_right = SKILL_SLOT
		key.offset_bottom = SKILL_SLOT
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key.add_theme_font_size_override("font_size", _ts(14))
		key.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		key.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		key.add_theme_constant_override("outline_size", 2)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists("res://assets/fonts/m5x7.ttf"):
			key.add_theme_font_override("font", load("res://assets/fonts/m5x7.ttf"))
		root.add_child(key)

		_skill_slots[slot] = {
			"root": root, "veil": veil, "key": key,
			"key_text": "Q" if slot == "skill_q" else "E",
			"prev_remaining": 0.0,
		}

## ── Buff tracker ─────────────────────────────────────────────────────────────
## Pooled chips; each frame the pool is laid over the player's live status snapshot.
## Chip: pill ninepatch + short name + a thin fill bar draining with time_remaining.
var _buff_chips: Array[Dictionary] = []


func _build_buff_chips() -> void:
	for i in range(BUFF_MAX_CHIPS):
		var root := Control.new()
		root.name = "BuffChip%d" % i
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.visible = false
		add_child(root)

		var bg := NinePatchRect.new()
		bg.texture = _sheet()
		bg.region_rect = PANEL_PILL
		bg.patch_margin_left = 5
		bg.patch_margin_top = 5
		bg.patch_margin_right = 5
		bg.patch_margin_bottom = 5
		bg.size = Vector2(BUFF_CHIP_W, BUFF_CHIP_H)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bg)

		var fill := ColorRect.new()
		fill.position = Vector2(2.0, BUFF_CHIP_H - 3.0)
		fill.size = Vector2(BUFF_CHIP_W - 4.0, 1.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(fill)

		var label := Label.new()
		label.position = Vector2.ZERO
		label.size = Vector2(BUFF_CHIP_W, BUFF_CHIP_H - 2.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", _ts(9))
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		label.add_theme_constant_override("outline_size", 1)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists("res://assets/fonts/m5x7.ttf"):
			label.add_theme_font_override("font", load("res://assets/fonts/m5x7.ttf"))
		root.add_child(label)

		_buff_chips.append({ "root": root, "bg": bg, "fill": fill, "label": label, "id": "" })


func _update_buff_chips() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	var sec = player_ref.get("status_effect_component")
	if sec == null:
		return
	var snapshot: Array[Dictionary] = sec.get_status_snapshot()
	## Stable order: buffs first, then debuffs, alphabetical within — chips don't shuffle.
	snapshot.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.is_positive != b.is_positive:
			return a.is_positive
		return String(a.id) < String(b.id))
	var count: int = mini(snapshot.size(), BUFF_MAX_CHIPS)
	var row_w: float = count * BUFF_CHIP_W + maxf(0.0, count - 1) * BUFF_CHIP_GAP
	for i in range(BUFF_MAX_CHIPS):
		var chip: Dictionary = _buff_chips[i]
		if i >= count:
			chip.root.visible = false
			chip.id = ""
			continue
		var s: Dictionary = snapshot[i]
		chip.root.position = Vector2(320.0 - row_w * 0.5 + i * (BUFF_CHIP_W + BUFF_CHIP_GAP), BUFF_BAR_Y)
		if chip.id != s.id:
			chip.id = s.id
			var chip_name: String = BUFF_NAMES.get(s.id, String(s.id).to_upper().left(7))
			chip.label.text = chip_name if s.stacks <= 1 else "%s x%d" % [chip_name, s.stacks]
			## Green pill for buffs, red for debuffs on the player.
			chip.bg.modulate = Color(0.55, 0.85, 0.55, 0.95) if s.is_positive else Color(0.95, 0.5, 0.5, 0.95)
			chip.fill.color = Color(0.55, 1.0, 0.55) if s.is_positive else Color(1.0, 0.55, 0.45)
			## Pop on appear.
			chip.root.modulate = Color(1.6, 1.6, 1.3, 1.0)
			var t: Tween = chip.root.create_tween()
			t.tween_property(chip.root, "modulate", Color.WHITE, 0.2)
		elif s.stacks > 1:
			var chip_name2: String = BUFF_NAMES.get(s.id, String(s.id).to_upper().left(7))
			chip.label.text = "%s x%d" % [chip_name2, s.stacks]
		var frac: float = 1.0
		if s.base_duration > 0.0 and s.time_remaining > 0.0:
			frac = clampf(s.time_remaining / s.base_duration, 0.0, 1.0)
		chip.fill.size.x = (BUFF_CHIP_W - 4.0) * frac
		chip.root.visible = true


func _refresh_skill_slot_keys() -> void:
	## Resolve the bound key names once per run (respects rebinds from the settings panel).
	for slot in _skill_slots:
		var entry: Dictionary = _skill_slots[slot]
		entry.key_text = _skill_key_text(slot, "Q" if slot == "skill_q" else "E")
		entry.key.text = entry.key_text

func _skill_key_text(action: String, fallback: String) -> String:
	if not InputMap.has_action(action):
		return fallback
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var code: int = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
			var txt: String = OS.get_keycode_string(code)
			if txt != "":
				return txt
	return fallback

func _update_skill_slots() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	var sc = player_ref.get("skill_component")
	for slot in _skill_slots:
		var entry: Dictionary = _skill_slots[slot]
		var has_skill: bool = sc != null and sc.has_skill(slot)
		entry.root.visible = has_skill
		if not has_skill:
			entry.prev_remaining = 0.0
			continue
		var remaining: float = sc.cooldown_remaining(slot)
		var frac: float = 0.0
		var ability: AbilityDefinition = sc.get_skill(slot)
		if ability != null and ability.cooldown_base > 0.0:
			frac = clampf(remaining / ability.cooldown_base, 0.0, 1.0)
		entry.veil.visible = frac > 0.0
		entry.veil.size.y = (SKILL_SLOT - 4.0) * frac
		if remaining > 0.0:
			entry.key.text = str(ceili(remaining))
			entry.key.add_theme_color_override("font_color", Color(0.72, 0.68, 0.60))
		else:
			entry.key.text = entry.key_text
			entry.key.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		## Ready pop: brief bright flash the moment the cooldown finishes.
		if entry.prev_remaining > 0.0 and remaining <= 0.0:
			var t: Tween = entry.root.create_tween()
			t.tween_property(entry.root, "modulate", Color(1.7, 1.7, 1.3, 1.0), 0.05)
			t.tween_property(entry.root, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.25)
		entry.prev_remaining = remaining

## ── Depth meter (descent mode) ───────────────────────────────────────────────

func _build_depth_meter() -> void:
	## Vertical fill bar on the left edge, below the instability meter.
	## Hidden by default; shown via setup_depth_tracker().
	## Viewport coords: x=2, y=90, 10px wide, 200px tall.
	const MX: float = 2.0
	const MY: float = 90.0
	const MW: float = 10.0
	const MH: float = 200.0
	const FW: float = 6.0

	var root := Control.new()
	root.name = "DepthMeter"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	add_child(root)
	_depth_meter_root = root

	## Track background
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.position = Vector2(MX, MY)
	bg.size = Vector2(MW, MH)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	## Fill (grows downward)
	var fill := ColorRect.new()
	fill.color = Color(0.55, 0.38, 0.18)  ## cave amber
	fill.position = Vector2(MX + 2.0, MY)
	fill.size = Vector2(FW, 0.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fill)
	_depth_fill = fill

	## 100% marker — 2px red line at the base of the track
	var end_marker := ColorRect.new()
	end_marker.color = Color(0.85, 0.18, 0.12)
	end_marker.position = Vector2(MX, MY + MH)
	end_marker.size = Vector2(MW, 2.0)
	end_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(end_marker)


func setup_depth_tracker(tracker: DepthTracker) -> void:
	_depth_tracker = tracker
	_depth_tweened_to = 0.0
	if _depth_meter_root != null:
		_depth_meter_root.visible = true
	if _depth_fill != null:
		_depth_fill.size.y = 0.0


func set_depth_event_ticks(ticks: Array[Dictionary]) -> void:
	## Place small tick marks on the depth meter for event locations.
	## Each dict needs: { percent: float, type: String }.
	## Clears previous ticks first.
	for node: Control in _depth_tick_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_depth_tick_nodes.clear()

	if _depth_meter_root == null:
		return

	const MX: float = 2.0
	const MY: float = 90.0
	const MW: float = 10.0
	const MH: float = 200.0

	var type_colors: Dictionary = {
		"merchant": Color(1.0, 0.85, 0.1),
		"altar": Color(0.7, 0.2, 1.0),
		"any": Color(0.5, 0.9, 0.5),
	}

	for tick: Dictionary in ticks:
		var pct: float = clampf(float(tick.get("percent", 0.0)), 0.0, 1.0)
		var type_key: String = str(tick.get("type", "any"))
		var col: Color = type_colors.get(type_key, Color(0.7, 0.7, 0.7))

		var dot := ColorRect.new()
		dot.color = col
		dot.position = Vector2(MX + MW, MY + pct * MH - 1.0)
		dot.size = Vector2(3.0, 3.0)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_depth_meter_root.add_child(dot)
		_depth_tick_nodes.append(dot)


func _on_phase_started(phase: int) -> void:
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


## ── Combo discovery popup ─────────────────────────────────────────────────────

func _build_combo_discovery_popup() -> void:
	## Instantiate the combo discovery popup as a child of this HUD
	var popup = ComboDiscoveryPopup.new()
	popup.name = "ComboDiscoveryPopup"
	add_child(popup)

## ── First-run onboarding overlay ──────────────────────────────────────────────

func _build_first_run_overlay() -> void:
	## Instantiate the first-run tooltip overlay as a child of this HUD.
	## No-ops internally once ProgressionManager.first_run_complete is true.
	var overlay = FirstRunOverlay.new()
	overlay.name = "FirstRunOverlay"
	add_child(overlay)
	_first_run_overlay = overlay

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
