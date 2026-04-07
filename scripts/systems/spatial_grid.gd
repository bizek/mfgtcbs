class_name SpatialGrid
extends RefCounted
## Fixed-cell spatial partitioning for fast proximity queries.
## Replaces per-frame get_nodes_in_group("enemies") iteration with cell-based
## lookups. Rebuilt every frame — simple, immune to teleport edge cases.
##
## Grid covers the arena bounds (-800,-600) to (800,600) with 64px cells.
## 25 cols x 19 rows = 475 cells.

const CELL_SIZE := 64.0
const ORIGIN_X := -800.0
const ORIGIN_Y := -600.0
const COLS := 25   ## ceil(1600 / 64)
const ROWS := 19   ## ceil(1200 / 64)
const TOTAL_CELLS := COLS * ROWS  ## 475

## Cell storage: flat array indexed by cell_y * COLS + cell_x
var _cells: Array = []
## Track which cells were written to, so clear only touches occupied cells
var _dirty: Array[int] = []
## All alive entities from last rebuild (avoids repeated group queries)
var _all: Array = []


func _init() -> void:
	_cells.resize(TOTAL_CELLS)
	for i in TOTAL_CELLS:
		_cells[i] = []


## Call once per frame before any targeting/combat logic.
## Pass the full list of enemies from get_nodes_in_group("enemies").
func rebuild(entities: Array) -> void:
	_clear_dirty()
	_all = []

	for e in entities:
		if not is_instance_valid(e):
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		_all.append(e)
		_insert(e)


## Returns the alive-entity list from last rebuild. Do NOT modify.
func get_all() -> Array:
	return _all


## Returns all entities in the cell containing pos plus its 8 neighbors.
## Callers do final distance checks on the returned candidates.
func get_nearby(pos: Vector2) -> Array:
	var results: Array = []
	var cx := _col(pos.x)
	var cy := _row(pos.y)

	for dy in range(-1, 2):
		var ny := cy + dy
		if ny < 0 or ny >= ROWS:
			continue
		for dx in range(-1, 2):
			var nx := cx + dx
			if nx < 0 or nx >= COLS:
				continue
			var cell: Array = _cells[ny * COLS + nx]
			for e in cell:
				results.append(e)
	return results


## Returns entities within squared distance of pos. Checks enough neighbor
## rings to cover the range. For ranges <= CELL_SIZE, checks 3x3.
func get_nearby_in_range(pos: Vector2, range_px: float) -> Array:
	var range_sq: float = range_px * range_px
	var results: Array = []
	var cx := _col(pos.x)
	var cy := _row(pos.y)
	var rings: int = 1 + int(range_px / CELL_SIZE)

	for dy in range(-rings, rings + 1):
		var ny := cy + dy
		if ny < 0 or ny >= ROWS:
			continue
		for dx in range(-rings, rings + 1):
			var nx := cx + dx
			if nx < 0 or nx >= COLS:
				continue
			var cell: Array = _cells[ny * COLS + nx]
			for e in cell:
				if pos.distance_squared_to(e.global_position) <= range_sq:
					results.append(e)
	return results


## Returns the nearest alive entity, or null.
## Starts with the center cell, expands outward ring by ring.
func find_nearest(pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist_sq := INF
	var cx := _col(pos.x)
	var cy := _row(pos.y)

	var max_ring := maxi(maxi(cx, COLS - 1 - cx), maxi(cy, ROWS - 1 - cy))
	for ring in range(0, max_ring + 1):
		var found_in_ring := false
		for dy in range(-ring, ring + 1):
			var ny := cy + dy
			if ny < 0 or ny >= ROWS:
				continue
			for dx in range(-ring, ring + 1):
				if ring > 0 and abs(dx) < ring and abs(dy) < ring:
					continue
				var nx := cx + dx
				if nx < 0 or nx >= COLS:
					continue
				var cell: Array = _cells[ny * COLS + nx]
				for e in cell:
					var d_sq := pos.distance_squared_to(e.global_position)
					if d_sq < best_dist_sq:
						best_dist_sq = d_sq
						best = e
						found_in_ring = true
		if found_in_ring and ring > 0:
			break
	return best


# --- Internal ---

func _insert(entity: Node2D) -> void:
	var key := _cell_key(entity.global_position)
	_cells[key].append(entity)
	_dirty.append(key)


func _clear_dirty() -> void:
	for key in _dirty:
		_cells[key].clear()
	_dirty.clear()


func _cell_key(pos: Vector2) -> int:
	return _row(pos.y) * COLS + _col(pos.x)


func _col(x: float) -> int:
	return clampi(int((x - ORIGIN_X) / CELL_SIZE), 0, COLS - 1)


func _row(y: float) -> int:
	return clampi(int((y - ORIGIN_Y) / CELL_SIZE), 0, ROWS - 1)
