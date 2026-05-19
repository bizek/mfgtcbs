class_name DepthTracker
extends Node

## DepthTracker — computes descent progress (0.0–1.0) from player Y vs
## BlockManager.block_bounds. Watermarked: value only ever increases.
## Scene-owned child of MainArena; not an autoload.

signal block_entered(block_index: int)
signal depth_milestone_reached(percent: float)

var depth_progress: float = 0.0

const MILESTONES: Array = [0.25, 0.50, 0.75, 1.00]

var _block_manager: BlockManager = null
var _player: Node2D = null
var _last_block_index: int = -1
var _milestones_hit: Array[bool] = [false, false, false, false]


func setup(block_manager: BlockManager, player: Node2D) -> void:
	_block_manager = block_manager
	_player = player
	depth_progress = 0.0
	_last_block_index = -1
	for i: int in range(_milestones_hit.size()):
		_milestones_hit[i] = false


func _process(_delta: float) -> void:
	if _block_manager == null or _player == null:
		return
	if _block_manager.block_bounds.is_empty():
		return

	var player_y: float = _player.global_position.y
	var n_blocks: int = _block_manager.block_bounds.size()
	var block_idx: int = _block_manager.get_block_index_at_y(player_y)
	var bounds: Rect2 = _block_manager.block_bounds[block_idx]

	var within: float = clampf(
		(player_y - bounds.position.y) / maxf(bounds.size.y, 1.0), 0.0, 1.0)
	var raw: float = (float(block_idx) + within) / float(n_blocks)

	if raw > depth_progress:
		depth_progress = raw

	if block_idx != _last_block_index:
		_last_block_index = block_idx
		block_entered.emit(block_idx)

	for i: int in range(MILESTONES.size()):
		if not _milestones_hit[i] and depth_progress >= float(MILESTONES[i]):
			_milestones_hit[i] = true
			depth_milestone_reached.emit(float(MILESTONES[i]))
