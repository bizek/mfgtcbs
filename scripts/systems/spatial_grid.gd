class_name SpatialGrid
extends RefCounted
## Fixed-cell spatial partitioning for fast proximity queries.
## Entities register by faction. Queries return candidates in nearby cells.
## Rebuilt every frame — simple, immune to teleport/tween edge cases.
##
## Grid covers arena bounds (-800,-600) to (800,600) with 64px cells.
## Faction indices: 0 = player/allies, 1 = enemies.

const CELL_SIZE := 64.0
const ORIGIN_X := -800.0
const ORIGIN_Y := -600.0
const COLS := 25   ## ceil(1600 / 64)
const ROWS := 19   ## ceil(1200 / 64)
const TOTAL_CELLS := COLS * ROWS  ## 475

## Per-faction cell storage: flat array indexed by cell_y * COLS + cell_x
var _cells: Array = [[], []]  ## [player_cells, enemy_cells]
var _dirty: Array = [[], []]
var _all: Array = [[], []]    ## [all_players, all_enemies]


func _init() -> void:
	for f in 2:
		var cells: Array = []
		cells.resize(TOTAL_CELLS)
		for i in TOTAL_CELLS:
			cells[i] = []
		_cells[f] = cells
		_dirty[f] = []
		_all[f] = []


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
		if ny < 0 or ny >= ROWS:
			continue
		for dx in range(-1, 2):
			var nx := cx + dx
			if nx < 0 or nx >= COLS:
				continue
			var cell: Array = cells[ny * COLS + nx]
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
		if ny < 0 or ny >= ROWS:
			continue
		for dx in range(-rings, rings + 1):
			var nx := cx + dx
			if nx < 0 or nx >= COLS:
				continue
			var cell: Array = cells[ny * COLS + nx]
			for e in cell:
				if pos.distance_squared_to(e.global_position) <= range_sq:
					results.append(e)
	return results


func find_nearest(pos: Vector2, faction: int) -> Node2D:
	var best: Node2D = null
	var best_dist_sq := INF
	var cx := _col(pos.x)
	var cy := _row(pos.y)
	var cells: Array = _cells[faction]
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
				var cell: Array = cells[ny * COLS + nx]
				for e in cell:
					var d_sq := pos.distance_squared_to(e.global_position)
					if d_sq < best_dist_sq:
						best_dist_sq = d_sq
						best = e
						found_in_ring = true
		if found_in_ring and ring > 0:
			break
	return best


func find_nearest_n(pos: Vector2, faction: int, count: int, range_sq: float) -> Array:
	var candidates := get_nearby_in_range(pos, faction, range_sq)
	candidates.sort_custom(func(a, b):
		return pos.distance_squared_to(a.position) < pos.distance_squared_to(b.position))
	if count > 0 and candidates.size() > count:
		return candidates.slice(0, count)
	return candidates


func find_furthest(pos: Vector2, faction: int) -> Node2D:
	var best: Node2D = null
	var best_dist_sq := -1.0
	for e in _all[faction]:
		var d_sq := pos.distance_squared_to(e.global_position)
		if d_sq > best_dist_sq:
			best_dist_sq = d_sq
			best = e
	return best


# --- Internal ---

func _insert(entity: Node2D, faction: int) -> void:
	var key := _cell_key(entity.position)
	_cells[faction][key].append(entity)
	_dirty[faction].append(key)


func _clear_dirty(faction: int) -> void:
	var cells: Array = _cells[faction]
	var dirty: Array = _dirty[faction]
	for key in dirty:
		cells[key].clear()
	dirty.clear()


func _cell_key(pos: Vector2) -> int:
	return _row(pos.y) * COLS + _col(pos.x)


func _col(x: float) -> int:
	return clampi(int((x - ORIGIN_X) / CELL_SIZE), 0, COLS - 1)


func _row(y: float) -> int:
	return clampi(int((y - ORIGIN_Y) / CELL_SIZE), 0, ROWS - 1)
