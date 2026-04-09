extends Node2D
class_name CombatFeedbackManager
## Pooled floating combat numbers. Renders all active numbers via _draw() —
## zero Label nodes, zero Tweens, single CanvasItem draw call.
##
## Replaces per-hit DamageNumber scene instantiation with a parallel-array pool.
## At high enemy density (150+), dozens of damage numbers spawn per second;
## pooling eliminates the instantiate/queue_free churn entirely.
##
## Owned by MainArena. Listens to EventBus.on_hit_dealt for auto-spawning.

const POOL_SIZE := 128
const FLOAT_DISTANCE := 28.0
const FLOAT_DURATION := 0.75
const FADE_DELAY := 0.25
const NORMAL_SIZE := 9
const CRIT_SIZE := 14
const HEAL_SIZE := 10
const OUTLINE_SIZE := 1
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.85)

const NORMAL_COLOR := Color(1.0, 1.0, 1.0)
const CRIT_COLOR := Color(1.0, 0.9, 0.1)
const HEAL_COLOR := Color(0.3, 1.0, 0.3)

## Crit styling
const CRIT_FLOAT_DURATION := 0.95
const CRIT_SCALE_PEAK := 1.4
const CRIT_DRIFT_SPEED := 5.0

var font: Font = null

# --- Pool state ---
var _count: int = 0
var _free_list: Array[int] = []

# --- Parallel arrays ---
var _positions: PackedVector2Array
var _colors: PackedColorArray
var _elapsed: PackedFloat32Array
var _alive: PackedByteArray
var _texts: Array[String] = []
var _is_crit: PackedByteArray
var _crit_dir: PackedFloat32Array


func _ready() -> void:
	## Top-level so positions are world-space (numbers float above enemies)
	top_level = true
	z_index = 10

	## Try to load the project's pixel font; fall back to default
	if ResourceLoader.exists("res://assets/fonts/m5x7.ttf"):
		font = load("res://assets/fonts/m5x7.ttf")
	else:
		font = ThemeDB.fallback_font

	_init_pool()

	## Auto-wire to EventBus signals (replaces legacy CombatManager.damage_dealt)
	EventBus.on_hit_dealt.connect(_on_hit_dealt)
	EventBus.on_dodge.connect(_on_dodge)


func _init_pool() -> void:
	_positions.resize(POOL_SIZE)
	_colors.resize(POOL_SIZE)
	_elapsed.resize(POOL_SIZE)
	_alive.resize(POOL_SIZE)
	_is_crit.resize(POOL_SIZE)
	_crit_dir.resize(POOL_SIZE)
	_texts.resize(POOL_SIZE)
	for i in POOL_SIZE:
		_alive[i] = 0
		_is_crit[i] = 0
		_crit_dir[i] = 0.0
		_texts[i] = ""


func _claim_slot() -> int:
	if not _free_list.is_empty():
		return _free_list.pop_back()
	if _count < POOL_SIZE:
		var slot := _count
		_count += 1
		return slot
	return -1


func _release_slot(i: int) -> void:
	_alive[i] = 0
	_is_crit[i] = 0
	_texts[i] = ""
	_free_list.append(i)


# --- Update ---

func _process(delta: float) -> void:
	var any_active := false
	var base_speed: float = FLOAT_DISTANCE / FLOAT_DURATION

	for i in _count:
		if not _alive[i]:
			continue
		any_active = true
		_elapsed[i] += delta

		var t: float = _elapsed[i]
		var is_crit: bool = _is_crit[i] == 1
		var duration: float = CRIT_FLOAT_DURATION if is_crit else FLOAT_DURATION

		# Float upward
		_positions[i].y -= base_speed * delta

		# Crit lateral drift
		if is_crit:
			_positions[i].x += _crit_dir[i] * CRIT_DRIFT_SPEED * delta

		# Expire
		if t >= duration:
			_release_slot(i)
			continue

		# Fade alpha after delay
		var fade_delay: float = FADE_DELAY
		if t > fade_delay:
			var fade_duration: float = duration - fade_delay
			var fade_t: float = (t - fade_delay) / fade_duration
			var c: Color = _colors[i]
			c.a = 1.0 - fade_t
			_colors[i] = c

	if any_active:
		queue_redraw()


# --- Rendering ---

func _draw() -> void:
	if not font:
		return
	for i in _count:
		if not _alive[i]:
			continue
		var pos := _positions[i]
		var col := _colors[i]
		var text := _texts[i]
		var is_crit: bool = _is_crit[i] == 1

		var size: int = CRIT_SIZE if is_crit else NORMAL_SIZE

		# Crit scale pulse
		if is_crit:
			var t_norm: float = _elapsed[i] / CRIT_FLOAT_DURATION
			if t_norm < 0.2:
				var p: float = t_norm / 0.2
				size = roundi(float(CRIT_SIZE) * (1.0 + (CRIT_SCALE_PEAK - 1.0) * p))
			elif t_norm < 0.5:
				size = roundi(float(CRIT_SIZE) * CRIT_SCALE_PEAK)
			else:
				var p: float = (t_norm - 0.5) / 0.5
				size = roundi(float(CRIT_SIZE) * (CRIT_SCALE_PEAK - (CRIT_SCALE_PEAK - 1.0) * p * p))

		var outline_col := Color(OUTLINE_COLOR.r, OUTLINE_COLOR.g, OUTLINE_COLOR.b, col.a)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, size, OUTLINE_SIZE, outline_col)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, size, col)


# --- Spawn helpers ---

func spawn_number(pos: Vector2, text: String, color: Color, is_crit: bool = false) -> void:
	var i := _claim_slot()
	if i < 0:
		return
	_alive[i] = 1
	_positions[i] = pos + Vector2(randf_range(-8.0, 8.0), -12.0)
	_elapsed[i] = 0.0
	_texts[i] = text
	_colors[i] = color
	_is_crit[i] = 1 if is_crit else 0
	_crit_dir[i] = (-1.0 if randf() < 0.5 else 1.0) if is_crit else 0.0
	queue_redraw()


## Convenience: spawn a heal number
func spawn_heal(pos: Vector2, amount: float) -> void:
	spawn_number(pos, str(int(amount)), HEAL_COLOR)


# --- Signal handler ---

func _on_hit_dealt(source, target, hit_data) -> void:
	if not is_instance_valid(target):
		return
	if not hit_data is HitData:
		return
	var was_crit: bool = hit_data.is_crit
	var amount: float = hit_data.amount
	var color := CRIT_COLOR if was_crit else NORMAL_COLOR
	spawn_number(target.global_position, str(int(amount)), color, was_crit)


func _on_dodge(_source, target, _hit_data) -> void:
	if not is_instance_valid(target):
		return
	spawn_number(target.global_position, "DODGE", Color(0.8, 0.8, 0.8), false)
