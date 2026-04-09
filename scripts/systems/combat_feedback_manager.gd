extends Node2D
## Pooled floating combat numbers. Renders all active numbers via _draw() —
## zero Label nodes, zero Tweens, single CanvasItem draw call.
## Composite numbers: multiple damage procs on the same target in the same
## frame merge into one number with per-segment type colors (e.g. "10+1").

const POOL_SIZE := 128
const FLOAT_DISTANCE := 10.0
const FLOAT_DURATION := 0.6
const FADE_DELAY := 0.2
const FONT_SIZE := 7
const OUTLINE_SIZE := 1
const OUTLINE_COLOR := Color.BLACK
const DAMAGE_COLOR := Color.WHITE
const ABILITY_COLOR := Color(0.9, 0.9, 1.0)
const HEAL_COLOR := Color(0.3, 1.0, 0.3)
const ABSORB_COLOR := Color.WHITE
const IMMUNE_COLOR := Color.WHITE
const SEPARATOR_COLOR := Color(0.6, 0.6, 0.6)

# Damage type color palette
const TYPE_COLORS := {
	"Physical": Color.WHITE,
	"Fire": Color(1.0, 0.3, 0.3),
	"Lightning": Color(1.0, 0.85, 0.1),
	"Ice": Color(0.3, 0.5, 1.0),
	"Void": Color(0.73, 0.47, 1.0),
	"True": Color.WHITE,
}

# Crit styling
const CRIT_SCALE_MAX := 1.5
const CRIT_FLOAT_DURATION := 0.78
const CRIT_DRIFT_SPEED := 6.0
const CRIT_MAX_ROTATION := 0.15
const CRIT_BRIGHTNESS_BOOST := 0.4
const CRIT_GLOW_ALPHA := 0.6

var font: Font = null  ## Set externally or preloaded

# --- Pool state ---
var _count: int = 0
var _free_list: Array[int] = []

# --- Parallel arrays ---
var _positions: PackedVector2Array
var _elapsed: PackedFloat32Array
var _alive: PackedByteArray
var _is_crit: PackedByteArray
var _crit_dir: PackedFloat32Array
var _segments: Array = []

# --- Hit buffer: accumulates damage events per target per frame ---
var _hit_buffer: Dictionary = {}


func _ready() -> void:
	_init_pool()
	EventBus.on_hit_dealt.connect(_on_hit_dealt)
	EventBus.on_heal.connect(_on_heal)
	EventBus.on_absorb.connect(_on_absorb)
	if not font:
		font = ThemeDB.fallback_font


func _init_pool() -> void:
	_positions.resize(POOL_SIZE)
	_elapsed.resize(POOL_SIZE)
	_alive.resize(POOL_SIZE)
	_is_crit.resize(POOL_SIZE)
	_crit_dir.resize(POOL_SIZE)
	_segments.resize(POOL_SIZE)
	for i in POOL_SIZE:
		_alive[i] = 0
		_is_crit[i] = 0
		_crit_dir[i] = 0.0
		_segments[i] = []


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
	_segments[i] = []
	_free_list.append(i)


# --- Crit helpers ---

func _crit_scale(t: float) -> float:
	if t < 0.2:
		var p: float = t / 0.2
		var ease_p: float = 2.0 * p * p if p < 0.5 else 1.0 - 2.0 * (1.0 - p) * (1.0 - p)
		return 1.0 + (CRIT_SCALE_MAX - 1.0) * ease_p
	elif t < 0.55:
		return CRIT_SCALE_MAX
	else:
		var p: float = (t - 0.55) / 0.45
		return CRIT_SCALE_MAX - (CRIT_SCALE_MAX - 1.0) * p * p


func _crit_float_speed(t: float) -> float:
	if t < 0.15:
		return 1.0
	elif t < 0.55:
		return 0.1
	else:
		return 1.0


func _segment_outline_color(seg: Array, is_crit: bool, slot: int) -> Color:
	var col: Color = seg[1]
	if is_crit:
		var t_norm: float = _elapsed[slot] / CRIT_FLOAT_DURATION
		var glow_t: float = clampf(t_norm, 0.0, 1.0)
		var glow_alpha: float = CRIT_GLOW_ALPHA * (1.0 - glow_t) * col.a
		var base: Color = seg[2]
		return Color(
			lerpf(base.r, OUTLINE_COLOR.r, glow_t),
			lerpf(base.g, OUTLINE_COLOR.g, glow_t),
			lerpf(base.b, OUTLINE_COLOR.b, glow_t),
			maxf(glow_alpha, OUTLINE_COLOR.a * col.a)
		)
	else:
		return Color(OUTLINE_COLOR, col.a)


# --- Update ---

func _process(delta: float) -> void:
	# Flush hit buffer -> spawn composite numbers
	for target_id in _hit_buffer:
		var entries: Array = _hit_buffer[target_id]
		if entries.is_empty():
			continue
		var target_pos: Vector2 = entries[0].pos
		var any_crit := false
		var segments: Array = []
		for j in entries.size():
			if j > 0:
				segments.append(["+", SEPARATOR_COLOR, SEPARATOR_COLOR])
			segments.append([entries[j].text, entries[j].color, entries[j].color])
			if entries[j].is_crit:
				any_crit = true
		_spawn_composite(target_pos, segments, any_crit)
	_hit_buffer.clear()

	var any_active := false
	var base_float_speed: float = FLOAT_DISTANCE / FLOAT_DURATION

	for i in _count:
		if not _alive[i]:
			continue
		any_active = true
		_elapsed[i] += delta
		var t: float = _elapsed[i]
		var is_crit: bool = _is_crit[i] == 1
		var duration: float = CRIT_FLOAT_DURATION if is_crit else FLOAT_DURATION
		var fade_delay: float = FADE_DELAY * (CRIT_FLOAT_DURATION / FLOAT_DURATION) if is_crit else FADE_DELAY

		var speed_mult: float = _crit_float_speed(t / duration) if is_crit else 1.0
		_positions[i].y -= base_float_speed * speed_mult * delta

		if is_crit:
			_positions[i].x += _crit_dir[i] * CRIT_DRIFT_SPEED * delta
			var t_norm: float = t / duration
			if t_norm < 0.55:
				var bright_t: float = t_norm / 0.55
				var boost: float = CRIT_BRIGHTNESS_BOOST * (1.0 - bright_t * bright_t)
				for seg in _segments[i]:
					var base: Color = seg[2]
					var h: float = base.h
					var s: float = base.s
					var v: float = minf(base.v + boost, 1.0)
					seg[1] = Color.from_hsv(h, s, v, _get_alpha(i, t, duration, fade_delay))
			else:
				for seg in _segments[i]:
					seg[1] = Color(seg[2].r, seg[2].g, seg[2].b, _get_alpha(i, t, duration, fade_delay))

		if t >= duration:
			_release_slot(i)
			continue

		if not is_crit and t > fade_delay:
			var fade_duration: float = duration - fade_delay
			var fade_t: float = (t - fade_delay) / fade_duration
			var alpha: float = 1.0 - fade_t
			for seg in _segments[i]:
				seg[1].a = alpha

	if any_active:
		queue_redraw()


func _get_alpha(i: int, t: float, duration: float, fade_delay: float) -> float:
	if t > fade_delay:
		var fade_duration: float = duration - fade_delay
		var fade_t: float = (t - fade_delay) / fade_duration
		return 1.0 - fade_t
	return 1.0


# --- Rendering ---

func _draw() -> void:
	if not font:
		return
	for i in _count:
		if not _alive[i]:
			continue
		var base_pos := _positions[i]
		var is_crit: bool = _is_crit[i] == 1

		var size: int = FONT_SIZE
		var rotation: float = 0.0
		if is_crit:
			var t_norm: float = _elapsed[i] / CRIT_FLOAT_DURATION
			var s: float = _crit_scale(clampf(t_norm, 0.0, 1.0))
			size = roundi(float(FONT_SIZE) * s)
			rotation = _crit_dir[i] * CRIT_MAX_ROTATION * clampf(t_norm * 2.0, 0.0, 1.0)

		if rotation != 0.0:
			draw_set_transform(base_pos, rotation)
			var cursor := Vector2.ZERO
			for seg in _segments[i]:
				var text: String = seg[0]
				var col: Color = seg[1]
				var outline_col: Color = _segment_outline_color(seg, is_crit, i)
				draw_string_outline(font, cursor, text, HORIZONTAL_ALIGNMENT_LEFT,
						-1, size, OUTLINE_SIZE, outline_col)
				draw_string(font, cursor, text, HORIZONTAL_ALIGNMENT_LEFT,
						-1, size, col)
				cursor.x += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			draw_set_transform(Vector2.ZERO, 0.0)
		else:
			var cursor := base_pos
			for seg in _segments[i]:
				var text: String = seg[0]
				var col: Color = seg[1]
				var outline_col: Color = _segment_outline_color(seg, is_crit, i)
				draw_string_outline(font, cursor, text, HORIZONTAL_ALIGNMENT_LEFT,
						-1, size, OUTLINE_SIZE, outline_col)
				draw_string(font, cursor, text, HORIZONTAL_ALIGNMENT_LEFT,
						-1, size, col)
				cursor.x += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


# --- Spawn helpers ---

func _spawn_composite(target_pos: Vector2, segments: Array, is_crit: bool) -> void:
	var total_width := 0.0
	for seg in segments:
		total_width += font.get_string_size(seg[0], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var center_offset: float = total_width / 2.0

	var i := _claim_slot()
	if i < 0:
		return
	_alive[i] = 1
	_positions[i] = target_pos + Vector2(-center_offset + randf_range(-3.0, 3.0), 0.0)
	_elapsed[i] = 0.0
	_is_crit[i] = 1 if is_crit else 0
	_segments[i] = segments

	if is_crit:
		for seg in segments:
			var base: Color = seg[2]
			var h: float = base.h
			var s: float = base.s
			var v: float = minf(base.v + CRIT_BRIGHTNESS_BOOST, 1.0)
			seg[1] = Color.from_hsv(h, s, v)
		_crit_dir[i] = -1.0 if randf() < 0.5 else 1.0
	else:
		_crit_dir[i] = 0.0

	queue_redraw()


func _spawn_number(pos: Vector2, text: String, color: Color, is_crit: bool = false) -> void:
	_spawn_composite(pos, [[text, color, color]], is_crit)


# --- EventBus handlers ---

func _is_headless() -> bool:
	var cm: Node2D = get_parent()
	return cm and cm.get("is_headless") and cm.is_headless


func _on_hit_dealt(_source: Variant, target: Variant, hit_data: Variant) -> void:
	if not is_instance_valid(target):
		return
	if _is_headless():
		return
	var amount: float
	if hit_data is HitData:
		amount = hit_data.amount
	else:
		amount = hit_data.get("amount", 0.0)
	if amount <= 0.0:
		return
	var color := DAMAGE_COLOR
	if hit_data is HitData and hit_data.ability and hit_data.ability.get("priority") and hit_data.ability.priority > 0:
		color = ABILITY_COLOR
	if hit_data is HitData and TYPE_COLORS.has(hit_data.damage_type):
		color = TYPE_COLORS[hit_data.damage_type]
	var is_crit := false
	if hit_data is HitData and hit_data.is_crit:
		is_crit = true

	var tid: int = target.get_instance_id()
	if not _hit_buffer.has(tid):
		_hit_buffer[tid] = []
	_hit_buffer[tid].append({
		text = str(roundi(amount)),
		color = color,
		is_crit = is_crit,
		pos = target.position + Vector2(0, -20)
	})


func _on_heal(_source: Variant, target: Variant, amount: float) -> void:
	if not is_instance_valid(target):
		return
	if _is_headless():
		return
	if amount <= 0.0:
		return
	_spawn_number(target.position + Vector2(0, -20), str(roundi(amount)), HEAL_COLOR)


func _on_absorb(entity: Variant, _hit_data: Variant, absorbed: float) -> void:
	if not is_instance_valid(entity):
		return
	if _is_headless():
		return
	if absorbed <= 0.0:
		return
	_spawn_number(entity.position + Vector2(0, -20), "Absorbed", ABSORB_COLOR)
