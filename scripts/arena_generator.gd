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

## Obstacles — fixed 16px sprites scaled 3× = 48 game-unit rocks
const OBSTACLE_COUNT: int = 18
const ROCK_SCALE: float = 3.0
const ROCK_SIZE: float = 16.0 * ROCK_SCALE   ## 48 — visual footprint
const ROCK_COLL: float = 36.0                ## slightly smaller collision for fair play

const PROPS_PATH: String = "res://assets/minifantasy/Minifantasy_ForgottenPlains_v3.5_Commercial_Version/Minifantasy_ForgottenPlains_Assets/props/Minifantasy_ForgottenPlainsProps.png"

## Rock tile origins in the props sheet (each is 16×16). Confirmed opaque stone tiles.
const ROCK_TILES: Array[Vector2i] = [
	Vector2i(0,  0),  ## light grey stone
	Vector2i(16, 0),  ## lighter grey stone
	Vector2i(32, 0),  ## medium grey stone
	Vector2i(0,  16), ## dark grey boulder
	Vector2i(16, 16), ## dark grey boulder variant
]

## Extraction point is fixed: bottom-centre, comfortably inside the play area.
const EXTRACTION_POSITION := Vector2(0.0, 460.0)
## Guarded extraction — left-centre. Guardian stands here from run start.
const GUARDED_POSITION := Vector2(-600.0, 0.0)
## Locked extraction — right-centre. Sealed until player uses a Keystone.
const LOCKED_POSITION := Vector2(600.0, 0.0)
## Sacrifice extraction — top-centre. Always available; costs one carried item.
const SACRIFICE_POSITION := Vector2(0.0, -460.0)

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
	_place_guarded_marker()
	_place_locked_marker()
	_place_sacrifice_marker()

func get_extraction_position() -> Vector2:
	return global_position + EXTRACTION_POSITION

func get_guarded_position() -> Vector2:
	return global_position + GUARDED_POSITION

func get_locked_position() -> Vector2:
	return global_position + LOCKED_POSITION

func get_sacrifice_position() -> Vector2:
	return global_position + SACRIFICE_POSITION

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
		## Layer 1+2 (binary 11=3): player (mask=2) and enemies (mask=1) both collide with walls
		body.collision_layer = 3
		body.collision_mask = 0

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
	## Load props sheet once and share it across all rock sprites
	var props_img := Image.load_from_file(PROPS_PATH)
	if props_img == null:
		push_warning("ArenaGenerator: props sheet not found — skipping obstacles.")
		return

	var half: float = ROCK_SIZE * 0.5
	var x_limit: float = ARENA_HALF_W - WALL_THICKNESS - half - 8.0
	var y_limit: float = ARENA_HALF_H - WALL_THICKNESS - half - 8.0

	var placed: Array[Vector2] = []
	var placed_count: int = 0
	var attempts: int = 400

	while placed_count < OBSTACLE_COUNT and attempts > 0:
		attempts -= 1

		var x: float = rng.randf_range(-x_limit, x_limit)
		var y: float = rng.randf_range(-y_limit, y_limit)
		var pos := Vector2(x, y)

		## Clear zones — player spawn and all extraction points
		if pos.length() < SPAWN_CLEAR_RADIUS:
			continue
		if pos.distance_to(EXTRACTION_POSITION) < EXTRACTION_CLEAR_RADIUS:
			continue
		if pos.distance_to(GUARDED_POSITION) < EXTRACTION_CLEAR_RADIUS:
			continue
		if pos.distance_to(LOCKED_POSITION) < EXTRACTION_CLEAR_RADIUS:
			continue
		if pos.distance_to(SACRIFICE_POSITION) < EXTRACTION_CLEAR_RADIUS:
			continue

		## No overlaps (minimum gap between rock centres)
		var blocked: bool = false
		for p in placed:
			if pos.distance_to(p) < ROCK_SIZE + 8.0:
				blocked = true
				break
		if blocked:
			continue

		placed.append(pos)
		var tile_origin: Vector2i = ROCK_TILES[rng.randi() % ROCK_TILES.size()]
		_spawn_obstacle(pos, props_img, tile_origin)
		placed_count += 1

func _spawn_obstacle(pos: Vector2, props_img: Image, tile_origin: Vector2i) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	## Layer 1+2 (binary 11=3): player (mask=2) and enemies (mask=1) both collide
	body.collision_layer = 3
	body.collision_mask = 0

	## Collision — square, slightly inset from visual edges
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(ROCK_COLL, ROCK_COLL)
	col.shape = shape
	body.add_child(col)

	## Crop the 16×16 rock tile and build a texture from it
	var tile_img := props_img.get_region(Rect2i(tile_origin.x, tile_origin.y, 16, 16))
	var tex := ImageTexture.create_from_image(tile_img)

	## Sprite2D — centred, scaled up, nearest-neighbour for crisp pixels
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(ROCK_SCALE, ROCK_SCALE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(sprite)

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

	## Dim fill — shows the destination before the window opens
	var ring := ColorRect.new()
	ring.color = Color(0.0, 0.65, 0.28, 0.22)
	ring.size = Vector2(96.0, 96.0)
	ring.position = Vector2(-48.0, -48.0)
	marker.add_child(ring)

	## Border outline — 4 thin rects forming a square
	var border_color := Color(0.0, 0.75, 0.35, 0.45)
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

	## "EXTRACT" label — visible enough to orient the player, but clearly inactive
	var lbl := Label.new()
	lbl.text = "EXTRACT"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-32.0, -68.0)
	lbl.modulate = Color(0.0, 0.85, 0.38, 0.5)
	lbl.add_theme_font_size_override("font_size", 12)
	marker.add_child(lbl)

	add_child(marker)

# ---------------------------------------------------------------------------
# Guarded extraction marker (dimly visible; guardian spawned at run start)
# ---------------------------------------------------------------------------

func _place_guarded_marker() -> void:
	var marker := Node2D.new()
	marker.name = "GuardedExtractionMarker"
	marker.position = GUARDED_POSITION

	## Dim crimson fill — subtly different from timed (green)
	var ring := ColorRect.new()
	ring.color = Color(0.65, 0.08, 0.08, 0.18)
	ring.size = Vector2(96.0, 96.0)
	ring.position = Vector2(-48.0, -48.0)
	marker.add_child(ring)

	## Border outline in dark red
	var border_color := Color(0.80, 0.15, 0.10, 0.40)
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

	var lbl := Label.new()
	lbl.text = "GUARDED"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-32.0, -68.0)
	lbl.modulate = Color(0.80, 0.20, 0.15, 0.45)
	lbl.add_theme_font_size_override("font_size", 12)
	marker.add_child(lbl)

	add_child(marker)

# ---------------------------------------------------------------------------
# Locked extraction marker (chains visual — inactive until Keystone used)
# ---------------------------------------------------------------------------

func _place_locked_marker() -> void:
	var marker := Node2D.new()
	marker.name = "LockedExtractionMarker"
	marker.position = LOCKED_POSITION

	## Dark purple fill with low alpha
	var fill := ColorRect.new()
	fill.color = Color(0.32, 0.05, 0.55, 0.22)
	fill.size = Vector2(96.0, 96.0)
	fill.position = Vector2(-48.0, -48.0)
	marker.add_child(fill)

	## Chain-style thick border (purple)
	var border_color := Color(0.55, 0.15, 0.80, 0.55)
	var bw: float = 96.0
	var bt: float = 4.0
	for side in 4:
		var b := ColorRect.new()
		b.color = border_color
		match side:
			0: b.size = Vector2(bw, bt); b.position = Vector2(-bw * 0.5, -bw * 0.5)
			1: b.size = Vector2(bw, bt); b.position = Vector2(-bw * 0.5,  bw * 0.5 - bt)
			2: b.size = Vector2(bt, bw); b.position = Vector2(-bw * 0.5, -bw * 0.5)
			3: b.size = Vector2(bt, bw); b.position = Vector2( bw * 0.5 - bt, -bw * 0.5)
		marker.add_child(b)

	## Diagonal chain bars across centre
	for i in range(3):
		var bar := ColorRect.new()
		bar.color = Color(0.45, 0.10, 0.65, 0.50)
		bar.size = Vector2(80.0, 3.0)
		bar.position = Vector2(-40.0, -18.0 + i * 18.0)
		bar.rotation = deg_to_rad(25.0 + i * 5.0)
		marker.add_child(bar)

	var lbl := Label.new()
	lbl.text = "LOCKED"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-28.0, -68.0)
	lbl.modulate = Color(0.70, 0.30, 0.95, 0.50)
	lbl.add_theme_font_size_override("font_size", 12)
	marker.add_child(lbl)

	var key_lbl := Label.new()
	key_lbl.text = "[KEY]"
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_lbl.position = Vector2(-20.0, -58.0)
	key_lbl.modulate = Color(0.75, 0.60, 0.90, 0.40)
	key_lbl.add_theme_font_size_override("font_size", 11)
	marker.add_child(key_lbl)

	add_child(marker)

# ---------------------------------------------------------------------------
# Sacrifice extraction marker (ominous dark — always available)
# ---------------------------------------------------------------------------

func _place_sacrifice_marker() -> void:
	var marker := Node2D.new()
	marker.name = "SacrificeExtractionMarker"
	marker.position = SACRIFICE_POSITION

	## Deep blood-red fill with low alpha
	var fill := ColorRect.new()
	fill.color = Color(0.50, 0.02, 0.05, 0.20)
	fill.size = Vector2(96.0, 96.0)
	fill.position = Vector2(-48.0, -48.0)
	marker.add_child(fill)

	## Inward-pointed jagged border (dark crimson)
	var border_color := Color(0.75, 0.06, 0.08, 0.50)
	var bw: float = 96.0
	var bt: float = 3.0
	for side in 4:
		var b := ColorRect.new()
		b.color = border_color
		match side:
			0: b.size = Vector2(bw, bt); b.position = Vector2(-bw * 0.5, -bw * 0.5)
			1: b.size = Vector2(bw, bt); b.position = Vector2(-bw * 0.5,  bw * 0.5 - bt)
			2: b.size = Vector2(bt, bw); b.position = Vector2(-bw * 0.5, -bw * 0.5)
			3: b.size = Vector2(bt, bw); b.position = Vector2( bw * 0.5 - bt, -bw * 0.5)
		marker.add_child(b)

	var lbl := Label.new()
	lbl.text = "SACRIFICE"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-32.0, -68.0)
	lbl.modulate = Color(0.85, 0.12, 0.12, 0.45)
	lbl.add_theme_font_size_override("font_size", 12)
	marker.add_child(lbl)

	add_child(marker)
