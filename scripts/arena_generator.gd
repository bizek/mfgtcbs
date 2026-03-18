extends Node2D
class_name ArenaGenerator

## ArenaGenerator — Prototype-only procedural arena layout.
## Builds wall collision bounds, scatters cover obstacles, marks the fixed
## extraction position, and paints spawn-zone hints at the arena edges.
## Not intended to ship — exists purely to validate gameplay feel.

const ARENA_HALF_W: float = 800.0
const ARENA_HALF_H: float = 600.0

## Visual wall border is 3 tiles × 16 px = 48 px. Collision sits just inside it.
const WALL_THICKNESS: float = 48.0

## Obstacles
const OBSTACLE_COUNT: int = 18
const OBS_MIN_SIZE: float = 24.0
const OBS_MAX_SIZE: float = 64.0

## Extraction point is fixed: bottom-centre, comfortably inside the play area.
const EXTRACTION_POSITION := Vector2(0.0, 460.0)
## Keep a clear radius around the extraction point so it's never buried in rubble.
const EXTRACTION_CLEAR_RADIUS: float = 110.0
## Keep a clear radius around player spawn (centre of arena).
const SPAWN_CLEAR_RADIUS: float = 100.0

var rng := RandomNumberGenerator.new()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func generate(seed_val: int = 0) -> void:
	rng.seed = seed_val if seed_val != 0 else randi()
	_build_wall_collision()
	_scatter_obstacles()
	_mark_spawn_zone_hints()
	_place_extraction_marker()

func get_extraction_position() -> Vector2:
	return global_position + EXTRACTION_POSITION

# ---------------------------------------------------------------------------
# Wall collision
# ---------------------------------------------------------------------------

func _build_wall_collision() -> void:
	## Four axis-aligned segments that line up with the visual tile border.
	## Using individual bodies so each wall is a clean rectangle.
	var playable_w: float = (ARENA_HALF_W - WALL_THICKNESS) * 2.0
	var playable_h: float = (ARENA_HALF_H - WALL_THICKNESS) * 2.0

	var segments: Array = [
		## [centre_position, size]
		[Vector2(0.0, -ARENA_HALF_H + WALL_THICKNESS * 0.5), Vector2(ARENA_HALF_W * 2.0, WALL_THICKNESS)],  ## top
		[Vector2(0.0,  ARENA_HALF_H - WALL_THICKNESS * 0.5), Vector2(ARENA_HALF_W * 2.0, WALL_THICKNESS)],  ## bottom
		[Vector2(-ARENA_HALF_W + WALL_THICKNESS * 0.5, 0.0), Vector2(WALL_THICKNESS, ARENA_HALF_H * 2.0)],  ## left
		[Vector2( ARENA_HALF_W - WALL_THICKNESS * 0.5, 0.0), Vector2(WALL_THICKNESS, ARENA_HALF_H * 2.0)],  ## right
	]

	for seg in segments:
		var body := StaticBody2D.new()
		body.position = seg[0]

		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = seg[1]
		col.shape = rect
		body.add_child(col)

		add_child(body)

# ---------------------------------------------------------------------------
# Obstacle scatter
# ---------------------------------------------------------------------------

func _scatter_obstacles() -> void:
	## Usable interior — inset by wall thickness plus half max obstacle size.
	var x_limit: float = ARENA_HALF_W - WALL_THICKNESS - OBS_MAX_SIZE * 0.5 - 8.0
	var y_limit: float = ARENA_HALF_H - WALL_THICKNESS - OBS_MAX_SIZE * 0.5 - 8.0

	var placed: Array[Rect2] = []
	var placed_count: int = 0
	var attempts: int = 400  ## Cap to avoid infinite loop

	while placed_count < OBSTACLE_COUNT and attempts > 0:
		attempts -= 1

		var x: float = rng.randf_range(-x_limit, x_limit)
		var y: float = rng.randf_range(-y_limit, y_limit)
		var w: float = rng.randf_range(OBS_MIN_SIZE, OBS_MAX_SIZE)
		var h: float = rng.randf_range(OBS_MIN_SIZE, OBS_MAX_SIZE)
		var candidate := Rect2(x - w * 0.5, y - h * 0.5, w, h)

		## Clear zone around player spawn (arena centre)
		if Vector2(x, y).length() < SPAWN_CLEAR_RADIUS:
			continue

		## Clear zone around fixed extraction point
		if Vector2(x, y).distance_to(EXTRACTION_POSITION) < EXTRACTION_CLEAR_RADIUS:
			continue

		## Reject overlaps with already-placed obstacles (plus small padding gap)
		var blocked: bool = false
		for existing in placed:
			if candidate.intersects(existing.grow(6.0)):
				blocked = true
				break
		if blocked:
			continue

		placed.append(candidate)
		_spawn_obstacle(Vector2(x, y), Vector2(w, h))
		placed_count += 1

func _spawn_obstacle(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos

	## Collision shape
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	body.add_child(col)

	## Visual — stone-rubble colour, slightly varied hue per obstacle
	var hue_shift: float = rng.randf_range(-0.02, 0.02)
	var base := Color(0.28, 0.24, 0.19, 1.0)
	var visual := ColorRect.new()
	visual.color = Color(base.r + hue_shift, base.g + hue_shift, base.b, 1.0)
	visual.size = size
	visual.position = -size * 0.5  ## centre the rect on the body
	body.add_child(visual)

	## Thin top edge highlight so obstacles read as 3D blocks at a glance
	var highlight := ColorRect.new()
	highlight.color = Color(0.45, 0.40, 0.33, 0.7)
	highlight.size = Vector2(size.x, 3.0)
	highlight.position = Vector2(-size.x * 0.5, -size.y * 0.5)
	body.add_child(highlight)

	add_child(body)

# ---------------------------------------------------------------------------
# Spawn-zone edge hints
# ---------------------------------------------------------------------------

func _mark_spawn_zone_hints() -> void:
	## Very faint red bands just inside the wall border on all four sides.
	## Gives the player a read on "enemies come from the edges."
	## Purely decorative — spawning logic is in EnemySpawnManager.
	var inner_x: float = -ARENA_HALF_W + WALL_THICKNESS
	var inner_y: float = -ARENA_HALF_H + WALL_THICKNESS
	var play_w: float = (ARENA_HALF_W - WALL_THICKNESS) * 2.0
	var play_h: float = (ARENA_HALF_H - WALL_THICKNESS) * 2.0
	var band: float = 36.0
	var tint := Color(0.85, 0.08, 0.08, 0.10)

	var rects: Array = [
		Rect2(inner_x, inner_y,            play_w, band),   ## top band
		Rect2(inner_x, ARENA_HALF_H - WALL_THICKNESS - band, play_w, band),  ## bottom band
		Rect2(inner_x,            inner_y, band, play_h),   ## left band
		Rect2(ARENA_HALF_W - WALL_THICKNESS - band, inner_y, band, play_h),  ## right band
	]

	for r in rects:
		var hint := ColorRect.new()
		hint.color = tint
		hint.size = r.size
		hint.position = r.position
		add_child(hint)

# ---------------------------------------------------------------------------
# Extraction marker (always present, dims before window opens)
# ---------------------------------------------------------------------------

func _place_extraction_marker() -> void:
	## Show the player where to go — dim until the extraction window opens.
	var marker := Node2D.new()
	marker.name = "ExtractionMarker"
	marker.position = EXTRACTION_POSITION

	## Outer pulse ring (will be animated via _process if needed — static for now)
	var ring := ColorRect.new()
	ring.color = Color(0.0, 0.6, 0.25, 0.15)
	ring.size = Vector2(96.0, 96.0)
	ring.position = Vector2(-48.0, -48.0)
	marker.add_child(ring)

	## Dashed border effect — 4 thin rects forming a square outline
	var border_color := Color(0.0, 0.7, 0.3, 0.3)
	var bw: float = 96.0
	var bt: float = 2.0
	for side in 4:
		var b := ColorRect.new()
		b.color = border_color
		match side:
			0: b.size = Vector2(bw, bt); b.position = Vector2(-bw * 0.5, -bw * 0.5)
			1: b.size = Vector2(bw, bt); b.position = Vector2(-bw * 0.5,  bw * 0.5 - bt)
			2: b.size = Vector2(bt, bw); b.position = Vector2(-bw * 0.5, -bw * 0.5)
			3: b.size = Vector2(bt, bw); b.position = Vector2( bw * 0.5 - bt, -bw * 0.5)
		marker.add_child(b)

	## Small "EXTRACT" hint label — subtle, not glowing yet
	var lbl := Label.new()
	lbl.text = "EXTRACT"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-32.0, -68.0)
	lbl.modulate = Color(0.0, 0.8, 0.35, 0.35)
	lbl.add_theme_font_size_override("font_size", 9)
	marker.add_child(lbl)

	add_child(marker)
