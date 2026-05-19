class_name EventSpawnManager
extends Node

## EventSpawnManager — scene-owned Node. Reads event anchors from BlockManager
## at descent start, assigns Merchant and SummonAltar to anchor positions, and
## exposes event depths for the HUD depth meter tick marks.
##
## Merchant: exactly 1 per descent, placed at anchor closest to 40-60% depth.
## Altar:    0-1 per descent (60% chance), placed at anchor near 15-50% depth.

var _merchant: Node2D = null
var _altar: Node2D = null
var _total_height: float = 1.0


func setup(block_manager: BlockManager, player: Node2D, parent: Node) -> void:
	_total_height = maxf(block_manager.total_height, 1.0)
	var anchors: Array[Dictionary] = block_manager.get_event_anchors()
	_assign_and_spawn(anchors, player, parent)


func _assign_and_spawn(anchors: Array[Dictionary], player: Node2D, parent: Node) -> void:
	if anchors.is_empty():
		return

	## Sort anchors by depth_ratio ascending
	var sorted: Array[Dictionary] = []
	for a: Dictionary in anchors:
		sorted.append(a.duplicate())
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("depth_ratio", 0.0)) < float(b.get("depth_ratio", 0.0)))

	## Merchant: prefer explicit "merchant" payload, fallback to closest anchor to 50% in [0.3–0.7]
	var merchant_anchor: Dictionary = {}
	var merchant_best: float = 1.0
	for a: Dictionary in sorted:
		var payload: String = str(a.get("payload", ""))
		if payload == "merchant":
			merchant_anchor = a
			break
		var dr: float = float(a.get("depth_ratio", 0.0))
		var dist: float = absf(dr - 0.5)
		if dr >= 0.3 and dr <= 0.7 and dist < merchant_best:
			merchant_best = dist
			merchant_anchor = a

	## Altar: prefer explicit "altar" payload, fallback to first anchor in [0.15–0.5]
	## that is different from the merchant anchor
	var altar_anchor: Dictionary = {}
	for a: Dictionary in sorted:
		if a == merchant_anchor:
			continue
		var payload: String = str(a.get("payload", ""))
		if payload == "altar":
			altar_anchor = a
			break
		var dr: float = float(a.get("depth_ratio", 0.0))
		if altar_anchor.is_empty() and dr >= 0.15 and dr <= 0.50:
			altar_anchor = a

	## Spawn merchant (always if anchor found)
	if not merchant_anchor.is_empty():
		var pos := Vector2(float(merchant_anchor.get("position", Vector2.ZERO).x),
			float(merchant_anchor.get("position", Vector2.ZERO).y))
		var m := Merchant.new()
		m.name = "Merchant"
		parent.add_child(m)
		m.setup(pos, player)
		_merchant = m

	## Spawn altar (60% chance if anchor found)
	if not altar_anchor.is_empty() and randf() < 0.6:
		var pos := Vector2(float(altar_anchor.get("position", Vector2.ZERO).x),
			float(altar_anchor.get("position", Vector2.ZERO).y))
		var a := SummonAltar.new()
		a.name = "SummonAltar"
		parent.add_child(a)
		a.setup(pos, player)
		_altar = a


func get_event_depths() -> Array[Dictionary]:
	## Returns event positions as depth percents for the HUD depth meter tick marks.
	var result: Array[Dictionary] = []
	if _merchant != null and is_instance_valid(_merchant):
		var pct: float = clampf(_merchant.global_position.y / _total_height, 0.0, 1.0)
		result.append({"percent": pct, "type": "merchant"})
	if _altar != null and is_instance_valid(_altar):
		var pct: float = clampf(_altar.global_position.y / _total_height, 0.0, 1.0)
		result.append({"percent": pct, "type": "altar"})
	return result
