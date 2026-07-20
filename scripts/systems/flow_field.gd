class_name FlowField
extends Node2D
## Shared flow-field pathfinding over LDtk walkability grids.
##
## One BFS distance flood from the player's cell serves every enemy: enemies
## read their steering direction from the cell they stand in (one array lookup)
## instead of running per-agent pathfinding. Scene-owned, child of
## CombatOrchestrator; ticked right after the SpatialGrid rebuild.
##
## Data flow: LdtkLoader retains per-layer solid masks (nav_masks) →
## BlockManager.register_nav_with() feeds them here with world offsets →
## finalize() rasterizes everything onto one nav grid → tick() re-floods
## when the player crosses into a new cell.
##
## Nav cells are 8px (the LDtk collision grid), conservatively coarsened:
## a nav cell is walkable only if NO covered source cell is solid. This
## resolution is required — cliff rims carry 2px-thick PropCollision trim,
## and at 16px that trim sealed entire choke corridors (caught 2026-07-18).
## The flood is amortized across frames (FLOOD_BUDGET_USEC) with a
## double-buffered distance field, so the cell count never spikes one frame.
##
## When no terrain is registered (base arena), every query falls back to
## straight-line-to-target — identical to pre-flow-field behavior.

const NAV_CELL: float = 8.0
const UNREACHED: int = -1
## Rebuild at most this often (player can cross cells fast when dashing).
const MIN_REBUILD_INTERVAL: float = 0.2
## Max flood work per frame; a full descent flood (~49k cells, ~15 ms debug)
## spreads across ~5-6 frames while queries keep reading the published field.
const FLOOD_BUDGET_USEC: int = 2500

var target: Node2D = null
var overlay_enabled: bool = false
var last_rebuild_ms: float = 0.0     ## Cost of the most recent BFS flood (perf telemetry)
var last_rasterize_ms: float = 0.0   ## Cost of finalize() rasterization (load-time, one-off)

## Grid geometry (world px origin + cell dimensions), set by finalize()
var _origin: Vector2 = Vector2.ZERO
var _cols: int = 0
var _rows: int = 0
var _total: int = 0
var _active: bool = false

## Static walkability: 1 = solid, built once per level load
var _solid: PackedByteArray = PackedByteArray()
## BFS distance from player cell (in cells); UNREACHED = not connected.
## _dist is the published field queries read; _dist_back is what the
## in-progress flood writes. Swapped by reference when a flood completes.
var _dist: PackedInt32Array = PackedInt32Array()
var _dist_back: PackedInt32Array = PackedInt32Array()
## Lazily-computed flow directions, invalidated each rebuild
var _flow: PackedVector2Array = PackedVector2Array()
var _flow_valid: PackedByteArray = PackedByteArray()
## Preallocated BFS ring queue (each cell enqueued at most once)
var _queue: PackedInt32Array = PackedInt32Array()

## Pending registrations (consumed by finalize())
var _blocks: Array[Dictionary] = []
var _circles: Array[Dictionary] = []

## Rebuild scheduling + amortized flood state
var _since_rebuild: float = 999.0
var _last_target_cell: int = -2
var _pending_rebuild: bool = false
var _flooding: bool = false
var _flood_head: int = 0
var _flood_tail: int = 0
var _flood_work_usec: int = 0


func _ready() -> void:
	z_index = 100  ## Debug overlay draws above tiles/props


# ─── Registration (level load) ────────────────────────────────────────────────

func set_target(t: Node2D) -> void:
	target = t


func clear_blocks() -> void:
	_blocks.clear()
	_circles.clear()
	_active = false
	_last_target_cell = -2


func register_block(solid_mask: PackedByteArray, cw: int, ch: int,
		grid_size: int, world_origin: Vector2) -> void:
	if cw <= 0 or ch <= 0 or solid_mask.size() != cw * ch:
		push_warning("[FlowField] Rejecting block mask with bad dims (cw=%d ch=%d mask=%d)"
				% [cw, ch, solid_mask.size()])
		return
	_blocks.append({
		"mask": solid_mask, "cw": cw, "ch": ch,
		"gs": float(grid_size), "origin": world_origin,
	})


func register_solid_circle(world_pos: Vector2, radius: float) -> void:
	if radius > 0.0:
		_circles.append({"pos": world_pos, "radius": radius})


func finalize() -> void:
	## Rasterize all registered blocks + obstacle circles onto one nav grid.
	## Called once after registration; load-time cost, not a hot path.
	if _blocks.is_empty():
		_active = false
		return
	var t0: int = Time.get_ticks_usec()

	## Union bounds of all block rects, in world px.
	var min_p: Vector2 = Vector2(INF, INF)
	var max_p: Vector2 = Vector2(-INF, -INF)
	for b: Dictionary in _blocks:
		var org: Vector2 = b.origin
		var size := Vector2(float(b.cw) * b.gs, float(b.ch) * b.gs)
		min_p = min_p.min(org)
		max_p = max_p.max(org + size)
	_origin = min_p
	_cols = ceili((max_p.x - min_p.x) / NAV_CELL)
	_rows = ceili((max_p.y - min_p.y) / NAV_CELL)
	_total = _cols * _rows

	## A nav cell is walkable iff it has at least one covered source cell and
	## zero solid source cells. Uncovered cells (outside every block) = solid.
	var has_open: PackedByteArray = PackedByteArray()
	var has_solid: PackedByteArray = PackedByteArray()
	has_open.resize(_total)
	has_solid.resize(_total)
	for b: Dictionary in _blocks:
		var mask: PackedByteArray = b.mask
		var cw: int = b.cw
		var ch: int = b.ch
		var gs: float = b.gs
		var org: Vector2 = b.origin
		for sy in ch:
			var ny: int = int((org.y + (float(sy) + 0.5) * gs - _origin.y) / NAV_CELL)
			if ny < 0 or ny >= _rows:
				continue
			var row_base: int = ny * _cols
			var src_base: int = sy * cw
			for sx in cw:
				var nx: int = int((org.x + (float(sx) + 0.5) * gs - _origin.x) / NAV_CELL)
				if nx < 0 or nx >= _cols:
					continue
				if mask[src_base + sx] == 1:
					has_solid[row_base + nx] = 1
				else:
					has_open[row_base + nx] = 1

	_solid.resize(_total)
	for i in _total:
		_solid[i] = 1 if (has_solid[i] == 1 or has_open[i] == 0) else 0

	## Obstacle circles (entity-spawned props with collision): mark covered cells solid.
	for c: Dictionary in _circles:
		var cpos: Vector2 = c.pos
		var r: float = float(c.radius) + NAV_CELL * 0.5
		var x0: int = maxi(int((cpos.x - r - _origin.x) / NAV_CELL), 0)
		var x1: int = mini(int((cpos.x + r - _origin.x) / NAV_CELL), _cols - 1)
		var y0: int = maxi(int((cpos.y - r - _origin.y) / NAV_CELL), 0)
		var y1: int = mini(int((cpos.y + r - _origin.y) / NAV_CELL), _rows - 1)
		for cy in range(y0, y1 + 1):
			for cx in range(x0, x1 + 1):
				var center := _origin + Vector2((float(cx) + 0.5) * NAV_CELL, (float(cy) + 0.5) * NAV_CELL)
				if center.distance_to(cpos) <= r:
					_solid[cy * _cols + cx] = 1

	_dist.resize(_total)
	_dist.fill(UNREACHED)
	_dist_back.resize(_total)
	_flow.resize(_total)
	_flow_valid.resize(_total)
	_queue.resize(_total)

	_active = true
	_flooding = false
	_pending_rebuild = true
	_since_rebuild = 999.0
	last_rasterize_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	if GameManager.debug_mode:
		print("[FlowField] Grid %dx%d (%d cells) from %d blocks, %d circles — rasterized in %.2f ms"
				% [_cols, _rows, _total, _blocks.size(), _circles.size(), last_rasterize_ms])


# ─── Per-frame ────────────────────────────────────────────────────────────────

func tick(delta: float) -> void:
	## Called by CombatOrchestrator right after the SpatialGrid rebuild.
	## Starts a flood only when the player has crossed into a new nav cell
	## (rate-limited); the flood itself is sliced across frames under
	## FLOOD_BUDGET_USEC while queries keep reading the published field.
	if not _active or not is_instance_valid(target):
		return
	_since_rebuild += delta
	if _flooding:
		_continue_flood()
		return
	var tcell: int = _cell_index(target.global_position)
	if tcell != _last_target_cell:
		_pending_rebuild = true
	if _pending_rebuild and _since_rebuild >= MIN_REBUILD_INTERVAL:
		if _start_flood(tcell):
			_continue_flood()


func _start_flood(target_cell: int) -> bool:
	_pending_rebuild = false
	_since_rebuild = 0.0
	_last_target_cell = target_cell
	_flood_work_usec = 0
	_dist_back.fill(UNREACHED)
	var seed_cell: int = _find_seed(target_cell)
	if seed_cell < 0:
		return false  ## Target outside grid — keep the published field as-is
	_queue[0] = seed_cell
	_flood_head = 0
	_flood_tail = 1
	_dist_back[seed_cell] = 0
	_flooding = true
	return true


func _continue_flood() -> void:
	## One budgeted slice of the BFS. Aliasing members into locals costs one
	## copy-on-write per slice (a cheap memcpy) and is written back at the end;
	## the budget is checked every 256 pops to keep the hot loop tight.
	var t0: int = Time.get_ticks_usec()
	var dist := _dist_back
	var solid := _solid
	var queue := _queue
	var cols := _cols
	var head: int = _flood_head
	var tail: int = _flood_tail
	var row_max: int = _total - cols
	var pops: int = 0

	while head < tail:
		if (pops & 0xFF) == 0xFF and Time.get_ticks_usec() - t0 > FLOOD_BUDGET_USEC:
			break
		pops += 1
		var idx: int = queue[head]
		head += 1
		var d: int = dist[idx] + 1
		var x: int = idx % cols
		## Left
		if x > 0 and solid[idx - 1] == 0 and dist[idx - 1] == UNREACHED:
			dist[idx - 1] = d
			queue[tail] = idx - 1
			tail += 1
		## Right
		if x < cols - 1 and solid[idx + 1] == 0 and dist[idx + 1] == UNREACHED:
			dist[idx + 1] = d
			queue[tail] = idx + 1
			tail += 1
		## Up
		if idx >= cols and solid[idx - cols] == 0 and dist[idx - cols] == UNREACHED:
			dist[idx - cols] = d
			queue[tail] = idx - cols
			tail += 1
		## Down
		if idx < row_max and solid[idx + cols] == 0 and dist[idx + cols] == UNREACHED:
			dist[idx + cols] = d
			queue[tail] = idx + cols
			tail += 1

	_dist_back = dist
	_queue = queue
	_flood_head = head
	_flood_tail = tail
	_flood_work_usec += Time.get_ticks_usec() - t0

	if head >= tail:
		## Flood complete: publish by swapping the buffers (reference swap).
		_flooding = false
		var front := _dist
		_dist = _dist_back
		_dist_back = front
		_flow_valid.fill(0)
		last_rebuild_ms = float(_flood_work_usec) / 1000.0
		if overlay_enabled:
			queue_redraw()


func _find_seed(target_cell: int) -> int:
	## Player standing in a solid cell (knockback overlap, prop edge):
	## seed the flood from the nearest open cell instead.
	if target_cell >= 0 and target_cell < _total and _solid[target_cell] == 0:
		return target_cell
	if target_cell < 0 or target_cell >= _total:
		return -1
	var tx: int = target_cell % _cols
	var ty: int = int(target_cell / float(_cols))
	for ring in range(1, 9):
		for dy in range(-ring, ring + 1):
			var ny: int = ty + dy
			if ny < 0 or ny >= _rows:
				continue
			for dx in range(-ring, ring + 1):
				if absi(dx) != ring and absi(dy) != ring:
					continue
				var nx: int = tx + dx
				if nx < 0 or nx >= _cols:
					continue
				if _solid[ny * _cols + nx] == 0:
					return ny * _cols + nx
	return -1


# ─── Queries ──────────────────────────────────────────────────────────────────

func is_active() -> bool:
	return _active


func is_walkable(world_pos: Vector2) -> bool:
	## True when inactive (open arena — everything walkable).
	if not _active:
		return true
	var idx: int = _cell_index(world_pos)
	if idx < 0:
		return false
	return _solid[idx] == 0


func is_reachable(world_pos: Vector2) -> bool:
	## Connected to the player's current cell (as of the last rebuild).
	## True when inactive.
	if not _active:
		return true
	var idx: int = _cell_index(world_pos)
	if idx < 0:
		return false
	return _dist[idx] != UNREACHED


func get_distance_cells(world_pos: Vector2) -> int:
	## BFS distance to the player in nav cells; -1 = unreachable or inactive.
	if not _active:
		return -1
	var idx: int = _cell_index(world_pos)
	if idx < 0:
		return -1
	return _dist[idx]


func get_flow_direction(world_pos: Vector2) -> Vector2:
	## Steering direction toward the player from this position.
	## Falls back to straight-line-to-target when inactive, out of bounds,
	## or standing somewhere the field can't answer.
	var fallback: Vector2 = Vector2.ZERO
	if is_instance_valid(target):
		fallback = (target.global_position - world_pos).normalized()
	if not _active:
		return fallback
	var idx: int = _cell_index(world_pos)
	if idx < 0:
		return fallback
	if _solid[idx] == 0 and _dist[idx] != UNREACHED:
		if _dist[idx] == 0:
			return fallback  ## Same cell as player: close the last few px directly
		if _flow_valid[idx] == 1:
			return _flow[idx]
		var dir: Vector2 = _gradient_dir(idx)
		_flow[idx] = dir
		_flow_valid[idx] = 1
		return dir if dir != Vector2.ZERO else fallback
	## Solid or disconnected cell: escape toward the best nearby open cell.
	var esc: Vector2 = _escape_dir(idx, world_pos)
	return esc if esc != Vector2.ZERO else fallback


func _gradient_dir(idx: int) -> Vector2:
	## Direction = toward the lowest-distance neighbor (8-way, no corner cutting).
	var x: int = idx % _cols
	var y: int = int(idx / float(_cols))
	var best_d: int = _dist[idx]
	var best_dx: int = 0
	var best_dy: int = 0
	for dy in range(-1, 2):
		var ny: int = y + dy
		if ny < 0 or ny >= _rows:
			continue
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			if nx < 0 or nx >= _cols:
				continue
			var nidx: int = ny * _cols + nx
			if _solid[nidx] == 1:
				continue
			## Diagonal steps must not cut wall corners.
			if dx != 0 and dy != 0:
				if _solid[y * _cols + nx] == 1 or _solid[ny * _cols + x] == 1:
					continue
			var nd: int = _dist[nidx]
			if nd != UNREACHED and nd < best_d:
				best_d = nd
				best_dx = dx
				best_dy = dy
	if best_dx == 0 and best_dy == 0:
		return Vector2.ZERO
	return Vector2(float(best_dx), float(best_dy)).normalized()


func _escape_dir(idx: int, world_pos: Vector2) -> Vector2:
	## From a solid/disconnected cell, head for the nearest open reachable cell.
	var x: int = idx % _cols
	var y: int = int(idx / float(_cols))
	var best_d: int = 2147483647
	var best_idx: int = -1
	for ring in range(1, 5):
		for dy in range(-ring, ring + 1):
			var ny: int = y + dy
			if ny < 0 or ny >= _rows:
				continue
			for dx in range(-ring, ring + 1):
				if absi(dx) != ring and absi(dy) != ring:
					continue
				var nx: int = x + dx
				if nx < 0 or nx >= _cols:
					continue
				var nidx: int = ny * _cols + nx
				if _solid[nidx] == 0 and _dist[nidx] != UNREACHED and _dist[nidx] < best_d:
					best_d = _dist[nidx]
					best_idx = nidx
		if best_idx >= 0:
			break
	if best_idx < 0:
		return Vector2.ZERO
	var bx: int = best_idx % _cols
	var by: int = int(best_idx / float(_cols))
	var center := _origin + Vector2((float(bx) + 0.5) * NAV_CELL, (float(by) + 0.5) * NAV_CELL)
	return (center - world_pos).normalized()


func _cell_index(world_pos: Vector2) -> int:
	## -1 when outside the grid.
	var cx: int = int((world_pos.x - _origin.x) / NAV_CELL)
	var cy: int = int((world_pos.y - _origin.y) / NAV_CELL)
	if world_pos.x < _origin.x or world_pos.y < _origin.y or cx >= _cols or cy >= _rows:
		return -1
	return cy * _cols + cx


# ─── Debug overlay ────────────────────────────────────────────────────────────

func toggle_overlay() -> void:
	overlay_enabled = not overlay_enabled
	queue_redraw()


func _draw() -> void:
	if not overlay_enabled or not _active or not GameManager.debug_mode:
		return
	if not is_instance_valid(target):
		return
	const VIEW_CELLS: int = 40  ## ~320px halo around the player
	var tc: int = _cell_index(target.global_position)
	if tc < 0:
		return
	var tx: int = tc % _cols
	var ty: int = int(tc / float(_cols))
	var x0: int = maxi(tx - VIEW_CELLS, 0)
	var x1: int = mini(tx + VIEW_CELLS, _cols - 1)
	var y0: int = maxi(ty - VIEW_CELLS, 0)
	var y1: int = mini(ty + VIEW_CELLS, _rows - 1)
	var solid_col := Color(1.0, 0.2, 0.2, 0.20)
	var pocket_col := Color(0.6, 0.6, 0.6, 0.25)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var idx: int = cy * _cols + cx
			var cell_org := _origin + Vector2(float(cx) * NAV_CELL, float(cy) * NAV_CELL)
			if _solid[idx] == 1:
				draw_rect(Rect2(cell_org, Vector2(NAV_CELL, NAV_CELL)), solid_col, true)
			elif _dist[idx] == UNREACHED:
				## Walkable but disconnected from the player (enclosed pocket)
				draw_rect(Rect2(cell_org, Vector2(NAV_CELL, NAV_CELL)), pocket_col, true)
			else:
				var center := cell_org + Vector2(NAV_CELL * 0.5, NAV_CELL * 0.5)
				var dir: Vector2 = _gradient_dir(idx)
				if dir == Vector2.ZERO:
					continue
				var shade: float = clampf(1.0 - float(_dist[idx]) / 80.0, 0.25, 1.0)
				var col := Color(0.4, 1.0, 0.5, 0.55 * shade)
				var tip: Vector2 = center + dir * 6.0
				draw_line(center, tip, col, 1.0)
				draw_circle(tip, 1.2, col)
