class_name BlockManager
extends Node

## BlockManager — assembles a descent from modular LDtk block variants.
##
## Scene-owned child of MainArena (not an autoload). Created when descent_mode
## is active for the current level.
##
## Usage:
##   var bm := BlockManager.new()
##   add_child(bm)
##   var result := bm.build_descent(ldtk_project_path, block_count, block_level_ids)
##   # result.ok, result.player_spawn, result.total_height, etc.

signal block_entered(block_index: int)

const BLOCK_PREFIX: String = "Block_Caves_"

var block_bounds: Array[Rect2] = []
var block_count: int = 0
var total_height: float = 0.0
var level_width: float = 648.0

var _loaders: Array[Node2D] = []
var _event_anchors: Array[Dictionary] = []
var _spawn_zones_collected: Array[Dictionary] = []
var _extractions_collected: Array[Dictionary] = []
var _player_spawn_pos: Vector2 = Vector2.ZERO
var _portal_pos: Vector2 = Vector2.ZERO

var _debug_overlay_visible: bool = false
var _debug_draw_node: Node2D = null

## Persistent across descent runs — keyed by block_id.
## First run loads + packs; subsequent runs instantiate instantly.
static var _block_scene_cache: Dictionary = {}


func build_descent(ldtk_project_path: String, desired_block_count: int,
		available_block_ids: Array[String],
		entry_block_id: String = "",
		portal_block_id: String = "",
		merchant_block_id: String = "",
		merchant_depth_ratio: float = 0.5) -> Dictionary:
	block_bounds.clear()
	_loaders.clear()
	_event_anchors.clear()
	_spawn_zones_collected.clear()
	_extractions_collected.clear()
	block_count = desired_block_count

	var sequence: Array[String] = _build_block_sequence(
		available_block_ids, desired_block_count,
		entry_block_id, portal_block_id, merchant_block_id, merchant_depth_ratio)

	var y_offset: float = 0.0
	var errors: Array[String] = []
	var warnings: Array[String] = []

	for i in range(sequence.size()):
		var block_id: String = sequence[i]
		var loaded: Dictionary = _load_block(ldtk_project_path, block_id, i)
		if loaded.is_empty():
			errors.append("Block %d (%s) failed to load" % [i, block_id])
			continue

		var loader: Node2D = loaded.node
		var result: Dictionary = loaded.result

		for w: String in result.warnings:
			warnings.append("Block %d: %s" % [i, w])

		loader.position.y = y_offset
		_loaders.append(loader)

		var block_h: float = float(result.pxHei)
		var block_w: float = float(result.pxWid)
		level_width = block_w
		block_bounds.append(Rect2(0.0, y_offset, block_w, block_h))

		if i == 0:
			if not is_nan(result.player_spawn_pos.x):
				_player_spawn_pos = result.player_spawn_pos
			else:
				_player_spawn_pos = Vector2(block_w * 0.5, 24.0)

		for sz: Dictionary in result.spawn_zones:
			var offset_rect: Rect2 = sz.rect
			offset_rect.position.y += y_offset
			_spawn_zones_collected.append({
				"rect": offset_rect,
				"phase": sz.phase,
				"density": sz.density,
				"pool_override": sz.get("enemy_pool_override", ""),
				"min_distance_from_player": sz.get("min_distance_from_player", 300.0),
			})

		for marker: Dictionary in result.markers:
			if marker.tag == "EventTrigger":
				var anchor := marker.duplicate()
				anchor.position = Vector2(marker.position.x, marker.position.y + y_offset)
				anchor["block_index"] = i
				anchor["depth_ratio"] = 0.0  ## fixed up after loop when total_height is known
				_event_anchors.append(anchor)

		for ext: Dictionary in result.extractions:
			var offset_ext := ext.duplicate()
			offset_ext.position = Vector2(ext.position.x, ext.position.y + y_offset)
			offset_ext["block_index"] = i
			_extractions_collected.append(offset_ext)

		y_offset += block_h
		if not loaded.get("from_cache", false):
			await get_tree().process_frame

	total_height = y_offset

	## Fix up depth_ratios now that total_height is known
	for anchor: Dictionary in _event_anchors:
		anchor["depth_ratio"] = anchor["position"].y / maxf(total_height, 1.0)

	_portal_pos = Vector2(level_width * 0.5, total_height - 24.0)

	_setup_debug_overlay()

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"player_spawn": _player_spawn_pos,
		"portal_pos": _portal_pos,
		"total_height": total_height,
		"level_width": level_width,
		"block_count": block_bounds.size(),
	}


func get_event_anchors() -> Array[Dictionary]:
	return _event_anchors


func get_extractions() -> Array[Dictionary]:
	return _extractions_collected


func register_spawn_zones_with(spawn_manager: Node) -> void:
	spawn_manager.clear_spawn_zones()
	for sz: Dictionary in _spawn_zones_collected:
		spawn_manager.register_spawn_zone(
			sz.rect,
			sz.phase,
			sz.density,
			sz.pool_override,
			sz.min_distance_from_player,
		)


func get_block_index_at_y(world_y: float) -> int:
	for i in range(block_bounds.size()):
		var bounds: Rect2 = block_bounds[i]
		if world_y >= bounds.position.y and world_y < bounds.end.y:
			return i
	if world_y >= total_height and not block_bounds.is_empty():
		return block_bounds.size() - 1
	return 0


func get_portal_position() -> Vector2:
	return _portal_pos


func toggle_debug_overlay() -> void:
	_debug_overlay_visible = not _debug_overlay_visible
	if _debug_draw_node != null:
		_debug_draw_node.visible = _debug_overlay_visible
		_debug_draw_node.queue_redraw()


func _load_block(ldtk_path: String, block_id: String, slot: int) -> Dictionary:
	if BlockManager._block_scene_cache.has(block_id):
		var entry: Dictionary = BlockManager._block_scene_cache[block_id]
		var node: Node2D = (entry.packed as PackedScene).instantiate() as Node2D
		if node != null:
			node.name = "Block_%d" % slot
			add_child(node)
			return {node = node, result = entry.result, from_cache = true}
		## Instantiation failed — evict and fall through to full load
		BlockManager._block_scene_cache.erase(block_id)
		push_warning("[BlockManager] Cache instantiation failed for '%s', reloading." % block_id)

	var loader := LdtkLoader.new()
	loader.name = "Block_%d" % slot
	add_child(loader)
	var result: Dictionary = loader.load_level(ldtk_path, block_id)
	if not result.ok:
		loader.queue_free()
		return {}

	## Detach the LdtkLoader script before packing — typed Array[Node] vars on the
	## script don't survive PackedScene round-trips, leaving tiles blank on cache hits.
	## Detaching leaves a plain Node2D with TileMapLayer/StaticBody2D children intact.
	loader.set_script(null)
	var packed := PackedScene.new()
	if packed.pack(loader) == OK:
		BlockManager._block_scene_cache[block_id] = {packed = packed, result = result.duplicate(true)}

	return {node = loader, result = result, from_cache = false}


func _build_block_sequence(available: Array[String], count: int,
		entry_id: String, portal_id: String,
		merchant_id: String, merchant_depth: float) -> Array[String]:
	## Build the ordered sequence:
	##   [entry] + [inner shuffled/merchant] + [portal]
	## entry and portal are fixed; inner slots are shuffled from available.

	var normal_ids: Array[String] = []
	for bid: String in available:
		if bid != merchant_id and bid != entry_id and bid != portal_id:
			normal_ids.append(bid)

	if normal_ids.is_empty():
		push_error("[BlockManager] No normal block IDs available")
		return []

	## How many inner (shuffled) slots exist
	var inner_count: int = count
	if entry_id != "":
		inner_count -= 1
	if portal_id != "":
		inner_count -= 1
	inner_count = maxi(inner_count, 0)

	## Merchant goes at a fixed inner slot index (avoid slot 0 = right after entry)
	var merchant_slot: int = -1
	if merchant_id != "" and inner_count > 2:
		merchant_slot = clampi(int(inner_count * merchant_depth), 1, inner_count - 2)

	var sequence: Array[String] = []

	## Entry always first
	if entry_id != "":
		sequence.append(entry_id)

	## Shuffle inner slots
	var prev_id: String = entry_id
	for i in range(inner_count):
		if i == merchant_slot:
			sequence.append(merchant_id)
			prev_id = merchant_id
			continue

		var candidates: Array[String] = []
		for nid: String in normal_ids:
			if nid != prev_id:
				candidates.append(nid)
		if candidates.is_empty():
			candidates = normal_ids.duplicate()

		var chosen: String = candidates[randi() % candidates.size()]
		## Weight Open variants higher in first 3 inner slots
		if i < 3 and normal_ids.size() > 1:
			var open_id: String = ""
			for nid: String in candidates:
				if "Open" in nid:
					open_id = nid
					break
			if open_id != "" and randf() < 0.5:
				chosen = open_id

		sequence.append(chosen)
		prev_id = chosen

	## Portal always last
	if portal_id != "":
		sequence.append(portal_id)

	return sequence


func _setup_debug_overlay() -> void:
	if _debug_draw_node != null:
		_debug_draw_node.queue_free()

	_debug_draw_node = Node2D.new()
	_debug_draw_node.name = "BlockDebugOverlay"
	_debug_draw_node.z_index = 100
	_debug_draw_node.visible = _debug_overlay_visible
	add_child(_debug_draw_node)

	var draw_script := GDScript.new()
	draw_script.source_code = _get_debug_draw_source()
	draw_script.reload()
	_debug_draw_node.set_script(draw_script)
	_debug_draw_node.set("block_bounds", block_bounds)
	_debug_draw_node.set("event_anchors", _event_anchors)
	_debug_draw_node.set("portal_pos", _portal_pos)


func _get_debug_draw_source() -> String:
	return """extends Node2D

var block_bounds: Array = []
var event_anchors: Array = []
var portal_pos: Vector2 = Vector2.ZERO

func _draw() -> void:
	var colors: Array = [
		Color(1, 0, 0, 0.3), Color(0, 1, 0, 0.3), Color(0, 0, 1, 0.3),
		Color(1, 1, 0, 0.3), Color(1, 0, 1, 0.3), Color(0, 1, 1, 0.3),
	]
	for i in range(block_bounds.size()):
		var bounds: Rect2 = block_bounds[i]
		var col: Color = colors[i % colors.size()]
		draw_rect(Rect2(bounds.position.x, bounds.position.y, bounds.size.x, 2), col.lightened(0.3))
		draw_rect(Rect2(bounds.position.x, bounds.end.y - 2, bounds.size.x, 2), col.lightened(0.3))
		var label_pos := Vector2(4, bounds.position.y + 12)
		draw_string(ThemeDB.fallback_font, label_pos, "B" + str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col.lightened(0.5))

	for anchor in event_anchors:
		var pos: Vector2 = anchor["position"]
		draw_circle(pos, 6, Color(1, 0.8, 0, 0.7))
		draw_string(ThemeDB.fallback_font, pos + Vector2(8, 4), str(anchor.get("payload", "?")), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.8, 0))

	if portal_pos != Vector2.ZERO:
		draw_circle(portal_pos, 8, Color(0, 1, 0.5, 0.8))
		draw_string(ThemeDB.fallback_font, portal_pos + Vector2(10, 4), "PORTAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 1, 0.5))
"""
