class_name SpatialGrid
extends RefCounted
## Fixed-cell spatial partitioning for fast proximity queries.
## Entities register by faction. Queries return candidates in nearby cells.
## Rebuilt every frame — simple, immune to teleport/tween edge cases.
##
## Faction indices: 0 = player/allies, 1 = enemies.
##
## ── Bounds come from the level, not from constants (2026-09-23) ──────────────────
## This grid used to be hardcoded to the flat arena (-800,-600)..(800,600). Descent mode is
## Rect2(0, 0, ~648, block_count * 480) — ~4800px tall — so everything below y=600 (most of a
## run) clamped into the bottom row of cells. Queries stayed range-checked, so nothing broke
## loudly: separation, AoE and projectile hit tests just scanned the whole row, getting slower
## the deeper the player went, and find_nearest() (which stops searching early) returned a far
## enemy over a near one. ProjectileManager had already been given set_world_bounds() for the
## same reason; the grid never was.
##
## CombatOrchestrator.set_world_bounds() now sizes this grid from MainArena._get_level_bounds()
## once the level is built. Until then it covers the flat arena, which is what the training
## room and the procedural fallback use.

const CELL_SIZE := 64.0
## The flat arena (training room, procedural fallback) — used until set_bounds() is called.
const DEFAULT_BOUNDS := Rect2(-800.0, -600.0, 1600.0, 1200.0)
## Slack around the level rect so entities briefly outside it (spawn edges, displacement
## overshoot) still land in their true cell instead of clamping onto the border.
const MARGIN := CELL_SIZE

var _origin: Vector2 = Vector2.ZERO
var _cols: int = 0
var _rows: int = 0

## Per-faction cell storage: flat array indexed by cell_y * _cols + cell_x
var _cells: Array = [[], []]  ## [player_cells, enemy_cells]
var _dirty: Array = [[], []]
var _all: Array = [[], []]    ## [all_players, all_enemies]


func _init() -> void:
	set_bounds(DEFAULT_BOUNDS)


## Resize the grid to cover `world` (plus MARGIN). Drops the current contents — the next
## rebuild() repopulates them, so this is safe to call at any point between ticks.
func set_bounds(world: Rect2) -> void:
	var covered: Rect2 = world.grow(MARGIN)
	_origin = covered.position
	_cols = maxi(1, ceili(covered.size.x / CELL_SIZE))
	_rows = maxi(1, ceili(covered.size.y / CELL_SIZE))
	var total: int = _cols * _rows
	for f in 2:
		var cells: Array = []
		cells.resize(total)
		for i in total:
			cells[i] = []
		_cells[f] = cells
		_dirty[f] = []
		_all[f] = []


func get_bounds() -> Rect2:
	return Rect2(_origin, Vector2(_cols, _rows) * CELL_SIZE)


func rebuild(players: Array, enemies: Array) -> void:
	_clear_dirty(0)
	_clear_dirty(1)
	_all[0] = []
	_all[1] = []

	for e in players:
		if is_instance_valid(e) and e.is_alive:
			if e.get("is_untargetable") and e.is_untargetable:
				continue
			_all[0].append(e)
			_insert(e, 0)

	for e in enemies:
		if is_instance_valid(e) and e.is_alive:
			if e.get("is_untargetable") and e.is_untargetable:
				continue
			_all[1].append(e)
			_insert(e, 1)


func get_all(faction: int) -> Array:
	return _all[faction]


func get_nearby(pos: Vector2, faction: int) -> Array:
	var results: Array = []
	var cx := _col(pos.x)
	var cy := _row(pos.y)
	var cells: Array = _cells[faction]
	for dy in range(-1, 2):
		var ny := cy + dy
		if ny < 0 or ny >= _rows:
			continue
		for dx in range(-1, 2):
			var nx := cx + dx
			if nx < 0 or nx >= _cols:
				continue
			var cell: Array = cells[ny * _cols + nx]
			for e in cell:
				results.append(e)
	return results


func get_nearby_in_range(pos: Vector2, faction: int, range_sq: float) -> Array:
	var results: Array = []
	var cx := _col(pos.x)
	var cy := _row(pos.y)
	var cells: Array = _cells[faction]
	var rings := 1 + int(sqrt(range_sq) / CELL_SIZE)
	for dy in range(-rings, rings + 1):
		var ny := cy + dy
		if ny < 0 or ny >= _rows:
			continue
		for dx in range(-rings, rings + 1):
			var nx := cx + dx
			if nx < 0 or nx >= _cols:
				continue
			var cell: Array = cells[ny * _cols + nx]
			for e in cell:
				if not is_instance_valid(e):
					continue
				if pos.distance_squared_to(e.global_position) <= range_sq:
					results.append(e)
	return results


## Ring search outward from pos's cell. It may stop only once nothing in an unscanned ring
## could beat the best found: every cell in ring r+1 is at least r * CELL_SIZE from pos. The
## previous rule ("stop after the first non-empty ring past 0") could return an enemy in a
## ring-1 corner (~2.8 cells away) over one on a ring-2 edge (~1.1 cells away).
func find_nearest(pos: Vector2, faction: int) -> Node2D:
	var best: Node2D = null
	var best_dist_sq := INF
	var cx := _col(pos.x)
	var cy := _row(pos.y)
	var cells: Array = _cells[faction]
	## A query point outside the grid is clamped onto its border, so ring distance no longer
	## bounds real distance — scan every ring rather than trust the early exit.
	var can_stop_early: bool = get_bounds().has_point(pos)
	var max_ring := maxi(maxi(cx, _cols - 1 - cx), maxi(cy, _rows - 1 - cy))
	for ring in range(0, max_ring + 1):
		for dy in range(-ring, ring + 1):
			var ny := cy + dy
			if ny < 0 or ny >= _rows:
				continue
			for dx in range(-ring, ring + 1):
				if ring > 0 and abs(dx) < ring and abs(dy) < ring:
					continue
				var nx := cx + dx
				if nx < 0 or nx >= _cols:
					continue
				var cell: Array = cells[ny * _cols + nx]
				for e in cell:
					if not is_instance_valid(e):
						continue
					var d_sq := pos.distance_squared_to(e.global_position)
					if d_sq < best_dist_sq:
						best_dist_sq = d_sq
						best = e
		if can_stop_early and best != null:
			var guaranteed: float = ring * CELL_SIZE
			if best_dist_sq <= guaranteed * guaranteed:
				break
	return best


func find_nearest_n(pos: Vector2, faction: int, count: int, range_sq: float) -> Array:
	var candidates := get_nearby_in_range(pos, faction, range_sq)
	candidates.sort_custom(func(a, b):
		return pos.distance_squared_to(a.global_position) < pos.distance_squared_to(b.global_position))
	if count > 0 and candidates.size() > count:
		return candidates.slice(0, count)
	return candidates


func find_furthest(pos: Vector2, faction: int) -> Node2D:
	var best: Node2D = null
	var best_dist_sq := -1.0
	for e in _all[faction]:
		if not is_instance_valid(e):
			continue
		var d_sq := pos.distance_squared_to(e.global_position)
		if d_sq > best_dist_sq:
			best_dist_sq = d_sq
			best = e
	return best


# --- Internal ---

## Bucketed by global_position — the same space every query measures in. This read
## entity.position, which only agrees while every entity's parent sits at the origin.
func _insert(entity: Node2D, faction: int) -> void:
	var key := _cell_key(entity.global_position)
	_cells[faction][key].append(entity)
	_dirty[faction].append(key)


func _clear_dirty(faction: int) -> void:
	var cells: Array = _cells[faction]
	var dirty: Array = _dirty[faction]
	for key in dirty:
		cells[key].clear()
	dirty.clear()


func _cell_key(pos: Vector2) -> int:
	return _row(pos.y) * _cols + _col(pos.x)


func _col(x: float) -> int:
	return clampi(int(floorf((x - _origin.x) / CELL_SIZE)), 0, _cols - 1)


func _row(y: float) -> int:
	return clampi(int(floorf((y - _origin.y) / CELL_SIZE)), 0, _rows - 1)
