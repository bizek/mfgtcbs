extends CanvasLayer

## HUD — Health bar, XP bar, level display, haul counter, instability vignette,
## extraction window countdown, HAUL AT RISK warning, and combo discovery popups.

## ── Minifantasy UI theme (Grim set) ──────────────────────────────────────────
## Bars/panels are sourced from the Minifantasy UI Overhaul "Grim" sheet — the
## same sheet that backs the project-wide Theme (assets/ui/grim_theme.tres, built
## by tools/build_ui_theme.gd).
##
## This was the CLASSIC sheet until 2026-08-08, and it was the last surface in the
## game still on it. The gap-3 theme pass did not cause that split, it made it
## visible: every menu, panel, button, tab and focus ring came from Grim while the
## one surface a player stares at for a whole run came from a different art set.
## Classic's plates are opaque tan slabs; Grim's are near-black with a rivet-dot
## edge, which is what a HUD over a dark cave wants.
##
## The five capsule fills are 42x6 on a 912px colour column stride (Classic's were
## 40x6 on 256). Measured off the sheet, not eyeballed — the four thinner variants
## at y=1854/1887/1919 are the same bar at 3/2/1px if a slimmer meter is ever
## wanted. To retheme again, only these rects + UI_SHEET_PATH change.
const UI_SHEET_PATH: String = "res://assets/minifantasy/Minifantasy_UI _Overhaul_v1.0/_Minifantasy_UI_Overhaul_Assets/Grim_Minifantasy_UI/_Grim_UI.png"
const FILL_RED: Rect2 = Rect2(67.0, 1821.0, 42.0, 6.0)
const FILL_BLUE: Rect2 = Rect2(979.0, 1821.0, 42.0, 6.0)
const FILL_YELLOW: Rect2 = Rect2(1891.0, 1821.0, 42.0, 6.0)
const FILL_GREEN: Rect2 = Rect2(2803.0, 1821.0, 42.0, 6.0)
const FILL_PURPLE: Rect2 = Rect2(3715.0, 1821.0, 42.0, 6.0)
## PANELS group, colour column 0, ornament row R0 — the plain plate with a rivet-dot
## edge. R0 rather than R1/R2 on purpose: the ornament rows are a hierarchy, and a
## HUD pill is the plainest thing in the game, not a hero panel. Same rect and 5px
## margin the theme's "PanelDense" variation uses, so the HUD agrees with the menus.
## One rect serves both the square and the pill — it is a nine-patch, so the aspect
## ratio comes from the target size, and Grim has no dedicated 48x16 pill.
const PANEL_SQUARE: Rect2 = Rect2(112.0, 160.0, 48.0, 48.0)
const PANEL_PILL: Rect2 = Rect2(112.0, 160.0, 48.0, 48.0)
const PANEL_MARGIN: int = 5
const NUB_RED: Rect2 = Rect2(120.0, 1821.0, 4.0, 6.0)       ## capsule end-cap gems
const NUB_BLUE: Rect2 = Rect2(1032.0, 1821.0, 4.0, 6.0)
const BOSS_BAR_W: float = 192.0
var _ui_sheet: Texture2D = null

## ── Phase dial (Legacy Minifantasy clock sheet) ──────────────────────────────
## The only asset in the whole pack with no Grim-overhaul equivalent
## (docs/ui_pack_inventory.md "Legacy tree"). 272x64, 16px-native cells: a
## static face at (16,32)-16x16, a 16-frame red hand row at y=0, and a
## 16-frame blue hand row at y=16 — a full clockwise sweep in 16 steps.
const CLOCK_SHEET_PATH: String = "res://assets/minifantasy/Minifantasy_UI _Overhaul_v1.0/Legacy_Assets/Minifantasy_Userinterface_Assets_(OLD__VERSION)/Miscellany/Clock/Minifantasy_GuiClock.png"
const CLOCK_FACE_RECT: Rect2 = Rect2(16.0, 32.0, 16.0, 16.0)
const CLOCK_HAND_FRAMES: int = 16
const CLOCK_HAND_RED_Y: float = 0.0
const CLOCK_HAND_BLUE_Y: float = 16.0
var _clock_sheet: Texture2D = null

## Scales a base font size by the accessibility text-size setting (Small/Normal/Large).
## Scaled font size, snapped to the m5x7 pixel grid — see Settings.snap_font_size for why a
## raw multiply cannot be used here (0.85 and 1.25 both produce off-grid, and sub-16 fuses).
func _ts(base_size: int) -> int:
	return Settings.scaled_font_size(base_size)

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
## ── Town portal indicator (directly under the keystone pill) ─────────────────
var _town_portal_indicator: Control = null
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
## ── Phase dial (top-right, below the timer/kills panel) ──────────────────────
var _phase_dial_root: Control = null
var _phase_dial_hand_atlas: AtlasTexture = null
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
	GameManager.town_portal_changed.connect(_on_town_portal_changed)
	GameManager.guardian_state_changed.connect(_on_guardian_state_changed)
	GameManager.boss_state_changed.connect(_on_boss_state_changed)
	GameManager.final_boss_spawned.connect(_on_final_boss_spawned)
	GameManager.final_boss_defeated.connect(_on_final_boss_defeated)

	_apply_minifantasy_theme()
	_build_skill_slots()
	_build_buff_chips()
	_build_keystone_indicator()
	_build_town_portal_indicator()
	_build_guardian_health_bar()
	_build_phase_flash_label()
	_build_extraction_warning_label()
	_build_phase_dial()
	_build_depth_meter()
	_build_chain_meter()
	_build_combo_discovery_popup()
	_build_first_run_overlay()
	GameManager.phase_started.connect(_on_phase_started)
	InputGlyphs.device_changed.connect(func(_v: bool): _refresh_skill_slot_keys())
	Settings.bindings_changed.connect(_refresh_skill_slot_keys)
	EventBus.on_combo_step.connect(_on_combo_step)

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
	if _town_portal_indicator:
		_town_portal_indicator.visible = GameManager.player_has_town_portal

	_update_skill_slots()
	_update_buff_chips()

	## Phase countdown warning / Core phase notice
	if _extraction_warning_label != null:
		var time_remaining: float = GameManager.phase_duration - GameManager.phase_timer
		if GameManager.phase_number >= GameManager.MAX_PHASES:
			## Phase 5: no timed exit — show a permanent notice
			_extraction_warning_label.text = "THE CORE - NO TIMED EXIT"
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

	## Phase dial — hand sweeps once around the face over the whole 5-phase run.
	## Reads GameManager.phase_number/phase_timer (wall-clock), never
	## get_effective_phase() (descent depth) — Ben's call, 2026-08-15: the dial
	## reads run position, the depth meter already owns spatial depth. In the
	## training room phase_timer never advances (GameManager._process bails on
	## training_mode), so the hand just sits at frame 0 — correct, not a bug.
	if _phase_dial_hand_atlas != null:
		var phase_frac: float = clampf(
				GameManager.phase_timer / maxf(GameManager.phase_duration, 0.001), 0.0, 1.0)
		var run_frac: float = clampf(
				(float(GameManager.phase_number - 1) + phase_frac) / float(GameManager.MAX_PHASES),
				0.0, 1.0)
		var frame: int = int(round(run_frac * float(CLOCK_HAND_FRAMES - 1)))
		## Blue hand normally; swaps to red while the extraction window is open —
		## the same "it's time" cue as the countdown label and flash overlay.
		var hand_y: float = CLOCK_HAND_RED_Y if GameManager.extraction_window_active else CLOCK_HAND_BLUE_Y
		var new_region := Rect2(16.0 + float(frame) * 16.0, hand_y, 16.0, 16.0)
		if new_region != _phase_dial_hand_atlas.region:
			_phase_dial_hand_atlas.region = new_region

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

	_update_chain_meter(delta)
	_update_low_hp(delta)

func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d/%d" % [int(current), int(maximum)]
	## Low-health tint on the fill itself. The bar was one fixed red at every value, so the only
	## thing separating "fine" from "one hit from losing the haul" was the length of a 160px bar
	## read at 1/3 scale. See _update_low_hp() for the screen-edge half of the cue.
	var ratio: float = current / maximum if maximum > 0.0 else 0.0
	_low_hp_strength = 0.0
	if ratio < LOW_HP_THRESHOLD:
		_low_hp_strength = clampf((LOW_HP_THRESHOLD - ratio) / (LOW_HP_THRESHOLD - LOW_HP_CRITICAL), 0.0, 1.0)
	health_bar.self_modulate = Color(1.0, 1.0, 1.0).lerp(LOW_HP_BAR_TINT, _low_hp_strength)

func _on_xp_changed(current: float, needed: float) -> void:
	xp_bar.max_value = needed
	xp_bar.value = current

func _on_leveled_up(new_level: int) -> void:
	level_label.text = "Lv%d" % new_level

## HAUL is the player-facing name for GameManager.loot_carried — what you are carrying and stand
## to LOSE. Its counterpart is VAULT (ProgressionManager.resources), which is banked and safe.
## Those two were both called some flavour of "loot"/"resources" until 2026-08-03, which made the
## single most important distinction in the game read as a pair of synonyms. See the naming note
## on GameManager.loot_carried. "loot" survives as a verb and as the word for stuff on the ground —
## you loot things, and what you are carrying out is your haul.
func _on_loot_changed(new_value: float) -> void:
	loot_label.text = "HAUL: %d" % int(new_value)

func _on_instability_changed(new_value: float) -> void:
	## Instability reads atmospherically — no meter. A tier-colored vignette
	## creeps in from ~50 instability, plus the HAUL AT RISK warning at Volatile+.
	var tier: Dictionary = LootTables.get_instability_tier(new_value)
	var col: Color = tier.color

	var vig_alpha: float = clampf((new_value - 50.0) / 100.0, 0.0, 1.0) * 0.32
	var vig_col := Color(col.r * 0.7, col.g * 0.1, col.b * 0.1, vig_alpha)
	_vig_instability = vig_col
	_apply_vignette()

	## HAUL AT RISK label — visible at Volatile+ (71+)
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

func _clock_sheet_tex() -> Texture2D:
	if _clock_sheet == null:
		_clock_sheet = load(CLOCK_SHEET_PATH)
	return _clock_sheet

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
	sb.anti_aliasing = false   ## rounded StyleBoxFlats default to AA, which feathers a sub-pixel fringe on every edge — off-grid in a 640x360 pixel UI
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
	p.patch_margin_left = PANEL_MARGIN
	p.patch_margin_top = PANEL_MARGIN
	p.patch_margin_right = PANEL_MARGIN
	p.patch_margin_bottom = PANEL_MARGIN
	p.position = rect.position
	p.size = rect.size
	## No colour correction. The old value here dimmed Classic's bronze toward the
	## cave palette; Grim's plate is already near-black, so tinting it only muddies
	## the rivet edge. Alpha alone, to keep the play field readable through it.
	p.modulate = Color(1.0, 1.0, 1.0, 0.94)
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
	bg.patch_margin_left = PANEL_MARGIN
	bg.patch_margin_top = PANEL_MARGIN
	bg.patch_margin_right = PANEL_MARGIN
	bg.patch_margin_bottom = PANEL_MARGIN
	bg.size = Vector2(78.0, 16.0)
	bg.modulate = Color(1.0, 1.0, 1.0, 0.94)
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

## ── Town portal indicator ─────────────────────────────────────────────────────
## Sits directly under the keystone pill and copies its shape on purpose: both are "you are
## carrying a thing that opens a way out", and reading as a pair is the point. Carries its key
## prompt because, unlike the keystone, this one does nothing unless you press something.

func _build_town_portal_indicator() -> void:
	var root := Control.new()
	root.name = "TownPortalIndicator"
	root.position = Vector2(480.0, 20.0)
	root.visible = false
	_town_portal_indicator = root
	add_child(root)

	var bg := NinePatchRect.new()
	bg.texture = _sheet()
	bg.region_rect = PANEL_PILL
	bg.patch_margin_left = PANEL_MARGIN
	bg.patch_margin_top = PANEL_MARGIN
	bg.patch_margin_right = PANEL_MARGIN
	bg.patch_margin_bottom = PANEL_MARGIN
	bg.size = Vector2(78.0, 16.0)
	bg.modulate = Color(1.0, 1.0, 1.0, 0.94)
	root.add_child(bg)

	var rune := ColorRect.new()
	rune.color = Color(0.62, 0.78, 1.0)
	rune.size = Vector2(8.0, 8.0)
	rune.position = Vector2(3.0, 4.0)
	root.add_child(rune)

	var lbl := Label.new()
	lbl.text = "PORTAL [T]"
	lbl.position = Vector2(14.0, 2.0)
	## 12 to match the keystone pill it pairs with, and to fit a 16px pill. Belongs to the
	## known-fuzzy HUD sublabel batch waiting on m3x6 — not a new offender.
	lbl.add_theme_font_size_override("font_size", _ts(12))
	lbl.add_theme_color_override("font_color", Color(0.32, 0.20, 0.06))
	root.add_child(lbl)

	var pulse := root.create_tween().set_loops()
	pulse.tween_property(rune, "modulate:a", 0.45, 0.8)
	pulse.tween_property(rune, "modulate:a", 1.0, 0.8)


func _on_town_portal_changed(has_portal: bool) -> void:
	if _town_portal_indicator == null:
		return
	_town_portal_indicator.visible = has_portal
	if not has_portal:
		return
	var t := _town_portal_indicator.create_tween()
	t.tween_property(_town_portal_indicator, "modulate:a", 0.2, 0.05)
	t.tween_property(_town_portal_indicator, "modulate:a", 1.0, 0.20)

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
	lbl.add_theme_font_size_override("font_size", _ts(32))
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	lbl.modulate.a = 0.0
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
	add_child(lbl)
	_extraction_warning_label = lbl

## ── Phase dial ────────────────────────────────────────────────────────────────

func _build_phase_dial() -> void:
	## Small clock face + rotating hand, directly under the timer/kills panel
	## (Rect2(566,2,72,40)) and clear of the keystone/portal pill column at
	## x=480-558. 16px art drawn at 2x (32px) — legible without crowding the
	## corner. No numeral on the dial by design; the countdown text stays with
	## the existing extraction-warning label.
	var root := Control.new()
	root.name = "PhaseDial"
	root.position = Vector2(602.0, 44.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_phase_dial_root = root

	var bg := NinePatchRect.new()
	bg.texture = _sheet()
	bg.region_rect = PANEL_SQUARE
	bg.patch_margin_left = PANEL_MARGIN
	bg.patch_margin_top = PANEL_MARGIN
	bg.patch_margin_right = PANEL_MARGIN
	bg.patch_margin_bottom = PANEL_MARGIN
	bg.size = Vector2(36.0, 36.0)
	bg.modulate = Color(1.0, 1.0, 1.0, 0.94)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var face_atlas := AtlasTexture.new()
	face_atlas.atlas = _clock_sheet_tex()
	face_atlas.region = CLOCK_FACE_RECT
	var face := TextureRect.new()
	face.texture = face_atlas
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.position = Vector2(2.0, 2.0)
	face.size = Vector2(32.0, 32.0)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(face)

	_phase_dial_hand_atlas = AtlasTexture.new()
	_phase_dial_hand_atlas.atlas = _clock_sheet_tex()
	_phase_dial_hand_atlas.region = Rect2(16.0, CLOCK_HAND_BLUE_Y, 16.0, 16.0)
	var hand := TextureRect.new()
	hand.texture = _phase_dial_hand_atlas
	hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hand.stretch_mode = TextureRect.STRETCH_SCALE
	hand.position = Vector2(2.0, 2.0)
	hand.size = Vector2(32.0, 32.0)
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hand)

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
	flash_text("BOSS INCOMING - %s" % display_name.to_upper(),
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
	## Ranger quiver stance (E). These two carry no duration, so their chip fill sits full for as
	## long as the head is loaded — that's the intended read: a stance, not a timer.
	"quiver_fire": "FIRE",       "quiver_frost": "FROST",
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
		bg.patch_margin_left = PANEL_MARGIN
		bg.patch_margin_top = PANEL_MARGIN
		bg.patch_margin_right = PANEL_MARGIN
		bg.patch_margin_bottom = PANEL_MARGIN
		bg.size = Vector2(SKILL_SLOT, SKILL_SLOT)
		bg.modulate = Color(1.0, 1.0, 1.0, 0.94)
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
		root.add_child(key)

		## Glyph art for the bound input, centred over the slot. A TextureRect
		## rather than folding art into `key` because `key` doubles as the
		## cooldown countdown — keeping them separate means the countdown path
		## stays a plain Label and only visibility swaps between the two.
		##
		## STRETCH_SCALE, not KEEP_CENTERED: the pack's keycaps are 7x8 source
		## pixels, so drawing them 1:1 in a 22px slot left the letter inside about
		## 3x4 and unreadable, while two thirds of the slot sat empty. _fit_glyph_icon
		## sizes it to the largest INTEGER multiple that fits — a fractional scale
		## would alias pixel art straight back into mush.
		var icon := TextureRect.new()
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		root.add_child(icon)

		_skill_slots[slot] = {
			"root": root, "veil": veil, "key": key, "icon": icon,
			"key_text": "Q" if slot == "skill_q" else "E",
			"icon_tex": null,
			"prev_remaining": 0.0,
		}

## ── Combo chain meter (bottom-centre, above the buff row) ────────────────────
## Chain depth and the live cancel window — the two things a player acts on while comboing.
##
## Why this exists: until 2026-08-19 chain depth had exactly ONE output channel in the whole
## game, AudioManager's pitch ladder on EventBus.on_combo_step. The player-sprite pulse fired at
## every depth with identical brightness, so the mechanic the game is built around was legible
## by ear only. Turn SFX down, or be hard of hearing, and it vanished.
##
## Pips report depth; the bar under them drains with the cancel window, which is the actionable
## half (press NOW). Both are polled from the player rather than accumulated from signals — see
## player.get_combo_depth() for why a signal-counting version desyncs on every interrupted chain.
const CHAIN_PIP: float = 5.0
const CHAIN_PIP_GAP: float = 2.0
const CHAIN_MAX_PIPS: int = 8
const CHAIN_BAR_H: float = 2.0
const CHAIN_BAR_PAD: float = 2.0
const CHAIN_Y: float = BUFF_BAR_Y - CHAIN_PIP - CHAIN_BAR_H - CHAIN_BAR_PAD - 4.0
## Chain over: hold the shape briefly and fade rather than snapping to nothing. A chain ENDING is
## information too, and a hard cut on the frame the graph resets reads as a glitch.
const CHAIN_FADE_RATE: float = 3.2
const CHAIN_PIP_LOW: Color = Color(0.86, 0.88, 0.92)    ## opener — cool, quiet
const CHAIN_PIP_HIGH: Color = Color(1.0, 0.78, 0.29)    ## deep chain — gold, matches the body pulse
const CHAIN_WINDOW_COLOR: Color = Color(1.0, 0.93, 0.66)
const CHAIN_FLASH_DECAY: float = 3.6

var _chain_root: Control = null
var _chain_pips: Array[ColorRect] = []
var _chain_track: ColorRect = null
var _chain_fill: ColorRect = null
var _chain_shown_depth: int = 0
var _chain_alpha: float = 0.0
var _chain_flash: float = 0.0     ## finisher pop, decays to 0


func _build_chain_meter() -> void:
	var root := Control.new()
	root.name = "ChainMeter"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = Vector2(0.0, CHAIN_Y)
	root.visible = false
	add_child(root)
	_chain_root = root

	for i in range(CHAIN_MAX_PIPS):
		var pip := ColorRect.new()
		pip.size = Vector2(CHAIN_PIP, CHAIN_PIP)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.visible = false
		root.add_child(pip)
		_chain_pips.append(pip)

	## Track first, fill second — the fill draws over it. Both are sized per frame with the pip
	## row so the meter reads as one object at every depth.
	var track := ColorRect.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(track)
	_chain_track = track

	var fill := ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fill)
	_chain_fill = fill


## Finisher pop. The finisher IS the chain's payoff, and it is the one step the pip row cannot
## express on its own — the graph resets immediately after it lands, so without this the meter's
## last frame looks like any other step before it fades out.
func _on_combo_step(entity: Node2D, _depth: int, is_finisher: bool) -> void:
	if entity != player_ref or not is_finisher:
		return
	_chain_flash = 1.0


func _update_chain_meter(delta: float) -> void:
	if _chain_root == null:
		return
	var depth: int = 0
	var ratio: float = 0.0
	if player_ref != null and is_instance_valid(player_ref):
		depth = player_ref.get_combo_depth()
		ratio = player_ref.get_combo_window_ratio()

	if depth > 0:
		_chain_shown_depth = depth
		_chain_alpha = 1.0
	else:
		_chain_alpha = maxf(_chain_alpha - delta * CHAIN_FADE_RATE, 0.0)
	_chain_flash = maxf(_chain_flash - delta * CHAIN_FLASH_DECAY, 0.0)

	if _chain_alpha <= 0.0 or _chain_shown_depth <= 0:
		_chain_root.visible = false
		return
	_chain_root.visible = true

	var shown: int = mini(_chain_shown_depth, CHAIN_MAX_PIPS)
	var row_w: float = float(shown) * CHAIN_PIP + maxf(float(shown - 1), 0.0) * CHAIN_PIP_GAP
	## No hand-rounding of x — snap_2d_transforms_to_pixel already rounds every canvas item's
	## origin, and rounding on top of that is exactly what CLAUDE.md's pixel-grid note warns off.
	var x0: float = 320.0 - row_w * 0.5

	for i in range(CHAIN_MAX_PIPS):
		var pip: ColorRect = _chain_pips[i]
		if i >= shown:
			pip.visible = false
			continue
		pip.visible = true
		pip.position = Vector2(x0 + float(i) * (CHAIN_PIP + CHAIN_PIP_GAP), 0.0)
		## Ramp across the pips actually lit, not across CHAIN_MAX_PIPS — a 3-node kit should
		## reach its own top colour on its finisher instead of stopping a third of the way up a
		## ramp scaled for the longest chain in the game.
		var t: float = float(i) / maxf(float(shown - 1), 1.0)
		var c: Color = CHAIN_PIP_LOW.lerp(CHAIN_PIP_HIGH, t)
		if _chain_flash > 0.0:
			c = c.lerp(Color(1.0, 1.0, 1.0), _chain_flash * 0.75)
		c.a = _chain_alpha
		pip.color = c

	var bar_pos := Vector2(x0, CHAIN_PIP + CHAIN_BAR_PAD)
	_chain_track.position = bar_pos
	_chain_track.size = Vector2(row_w, CHAIN_BAR_H)
	_chain_track.color = Color(0.0, 0.0, 0.0, 0.55 * _chain_alpha)
	_chain_fill.position = bar_pos
	_chain_fill.size = Vector2(row_w * ratio, CHAIN_BAR_H)
	var fc: Color = CHAIN_WINDOW_COLOR
	fc.a = _chain_alpha
	_chain_fill.color = fc


## ── Low health ───────────────────────────────────────────────────────────────
## The health bar never changed appearance at any value until 2026-08-19: _on_health_changed()
## set max_value, value and a label, and stopped. In an extraction game where dying costs the
## whole haul, "you are about to die" is the highest-stakes signal there is, and it was readable
## only by parsing a 160px bar in the top-left corner while looking at the middle of the screen.
const LOW_HP_THRESHOLD: float = 0.35   ## cue starts here
const LOW_HP_CRITICAL: float = 0.10    ## cue is at full strength here
const LOW_HP_BAR_TINT: Color = Color(1.0, 0.42, 0.36)
const LOW_HP_COLOR: Color = Color(0.72, 0.05, 0.05)
const LOW_HP_VIG_ALPHA: float = 0.34
const LOW_HP_PULSE_HZ: float = 1.3
const LOW_HP_PULSE_DEPTH: float = 0.55

var _vig_instability: Color = Color(0.0, 0.0, 0.0, 0.0)
var _low_hp_strength: float = 0.0
var _low_hp_phase: float = 0.0


func _update_low_hp(delta: float) -> void:
	if _low_hp_strength <= 0.0:
		## One last compose so the red does not stick on the frame the player heals out of it.
		if _low_hp_phase != 0.0:
			_low_hp_phase = 0.0
			_apply_vignette()
		return
	## Beat faster the closer to death it gets — the RHYTHM carries the urgency, which is what
	## keeps this separable from the instability haze at a glance rather than by hue alone.
	_low_hp_phase = fmod(_low_hp_phase + delta * LOW_HP_PULSE_HZ * (1.0 + _low_hp_strength * 0.6), 1.0)
	_apply_vignette()


## Compose the two things that tint the screen edges. They are DIFFERENT signals and must not look
## alike: instability is a steady tier-coloured haze that creeps in across a run, low health is a
## pulse. Same four rects, blended here rather than written directly — _on_instability_changed()
## used to own them outright, so any second writer would have flickered against it frame by frame.
func _apply_vignette() -> void:
	var c: Color = _vig_instability
	if _low_hp_strength > 0.0:
		## Pulse DEPTH scales with the screen-flash accessibility slider; its BASE does not. Turn
		## flashes all the way off and the warning goes STEADY rather than going away — a player
		## who needs flashing reduced still needs to know they are dying.
		var pulse: float = LOW_HP_PULSE_DEPTH * Settings.screen_flash_intensity
		var beat: float = 1.0 - pulse + pulse * (0.5 + 0.5 * sin(_low_hp_phase * TAU))
		var a: float = _low_hp_strength * LOW_HP_VIG_ALPHA * beat
		c = Color(
			maxf(c.r, LOW_HP_COLOR.r),
			lerpf(c.g, LOW_HP_COLOR.g, _low_hp_strength),
			lerpf(c.b, LOW_HP_COLOR.b, _low_hp_strength),
			maxf(c.a, a))
	vig_top.color = c
	vig_bottom.color = c
	vig_left.color = c
	vig_right.color = c


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
		bg.patch_margin_left = PANEL_MARGIN
		bg.patch_margin_top = PANEL_MARGIN
		bg.patch_margin_right = PANEL_MARGIN
		bg.patch_margin_bottom = PANEL_MARGIN
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
	## Device-aware slot glyphs — the pack's button/keycap art where it exists,
	## the text glyph otherwise. Re-run on device switches and rebinds so the
	## slots never go stale.
	for slot in _skill_slots:
		var entry: Dictionary = _skill_slots[slot]
		var glyph: String = InputGlyphs.action_glyph(slot)
		if glyph == "?":
			glyph = "Q" if slot == "skill_q" else "E"
		entry.key_text = glyph
		entry.icon_tex = InputGlyphs.action_glyph_texture(slot)
		entry.icon.texture = entry.icon_tex
		_fit_glyph_icon(entry.icon, SKILL_SLOT)
		_show_skill_key(entry, true)


## Scale a glyph AtlasTexture up to fill `box`, centred, at an INTEGER factor.
##
## The pack's keycaps are tiny — 7x8 for a letter key, ~15x13 for a wide one — and
## a TextureRect drawing them 1:1 in a 22px slot renders the letter at about 3x4px,
## which is not readable at any window size. This is not a font-size problem: every
## HUD label is already 16 on the m5x7 grid. It is art drawn at a third of its slot.
##
## Integer factors only. A fractional scale on pixel art drops or doubles rows
## unevenly, which is the same failure m5x7 has off its 16px grid.
func _fit_glyph_icon(icon: TextureRect, box: float, margin: float = 2.0) -> void:
	if icon.texture == null:
		return
	var src: Vector2 = icon.texture.get_size()
	if src.x <= 0.0 or src.y <= 0.0:
		return
	var usable: float = box - margin * 2.0
	var factor: int = maxi(1, int(floor(minf(usable / src.x, usable / src.y))))
	var drawn: Vector2 = src * float(factor)
	icon.size = drawn
	## Round the offset so the art still lands on whole pixels after centring.
	icon.position = ((Vector2(box, box) - drawn) * 0.5).floor()


## Swaps a slot between its glyph (art if the pack has it, else text) and the
## cooldown countdown, which is always text.
func _show_skill_key(entry: Dictionary, ready: bool) -> void:
	var has_art: bool = ready and entry.get("icon_tex") != null
	entry.icon.visible = has_art
	entry.key.text = "" if has_art else entry.key_text

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
			_show_skill_key(entry, false)
			entry.key.text = str(ceili(remaining))
			entry.key.add_theme_color_override("font_color", Color(0.72, 0.68, 0.60))
		else:
			_show_skill_key(entry, true)
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
