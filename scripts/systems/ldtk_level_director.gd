class_name LdtkLevelDirector
extends Node

## LdtkLevelDirector — consumes LdtkLoader result.regions and drives:
##   • PreBoss kill quota → emits boss_should_spawn when met
##   • Boss region enter_seal → spawns invisible barrier walls behind the player
##   • Exit unlock → immediate (boss-less) or deferred to EventBus.on_kill(boss)
##
## Usage:
##   var dir := LdtkLevelDirector.new()
##   add_child(dir)
##   dir.activate(result.regions, result.boss_id, result.boss_spawn_pos, player)
##   dir.boss_should_spawn.connect(_on_boss_should_spawn)
##   dir.exit_should_unlock.connect(_on_exit_should_unlock)

signal boss_should_spawn(boss_id: String, spawn_pos: Vector2)
signal exit_should_unlock

## Collision layer 3 — walls block player (layer 1) and enemies (layer 2).
const WALL_COLLISION_LAYER: int = 3
## Thickness of the seal barrier in pixels.
const SEAL_THICKNESS: float = 16.0

var _regions: Array = []
var _boss_id: String = ""
var _boss_spawn_pos: Vector2 = Vector2.ZERO
var _player_ref: Node2D = null

## PreBoss tracking
var _preboss_active: bool = false       ## true once player enters any PreBoss region
var _preboss_kill_counts: Dictionary = {}  ## region id → kill count

## Boss seal tracking
var _boss_region_entered: bool = false
var _boss_seal_bodies: Array[Node] = []
var _boss_spawn_triggered: bool = false


func activate(regions: Array, boss_id: String, boss_spawn_pos: Vector2, player: Node2D) -> void:
	_regions = regions
	_boss_id = boss_id
	_boss_spawn_pos = boss_spawn_pos
	_player_ref = player

	## Boss-less level: exit is available immediately.
	if boss_id == "":
		exit_should_unlock.emit()
		return

	## Wire boss kill listener (unlocks exit on boss death).
	EventBus.on_kill.connect(_on_kill)

	## Initialize kill counters for each PreBoss region.
	for r in _regions:
		if r.kind == "PreBoss" and int(r.kill_quota) > 0:
			var key: String = _region_key(r)
			_preboss_kill_counts[key] = 0


func _process(_delta: float) -> void:
	if _player_ref == null or not is_instance_valid(_player_ref):
		return

	var ppos: Vector2 = _player_ref.global_position

	## Check for PreBoss region entry to arm kill tracking.
	if not _preboss_active:
		for r in _regions:
			if r.kind == "PreBoss" and (r.rect as Rect2).has_point(ppos):
				_preboss_active = true
				break

	## Check for Boss region entry to spawn seal barrier.
	if not _boss_region_entered:
		for r in _regions:
			if r.kind == "Boss" and bool(r.enter_seal) and (r.rect as Rect2).has_point(ppos):
				_boss_region_entered = true
				_spawn_seal_barriers(r.rect)
				break


## Called by EventBus.on_kill; handles both kill-quota and boss-kill/exit-unlock.
func _on_kill(killer: Node, victim: Node) -> void:
	if not victim.is_in_group("enemies"):
		return

	## Boss kill → unlock exit.
	if victim.is_in_group("bosses") or victim.is_in_group("final_boss"):
		exit_should_unlock.emit()
		return

	## PreBoss kill quota — only count once player is inside a PreBoss region.
	if not _preboss_active:
		return

	var victim_pos: Vector2 = victim.global_position
	for r in _regions:
		if r.kind != "PreBoss" or int(r.kill_quota) <= 0:
			continue
		if not (r.rect as Rect2).has_point(victim_pos):
			continue
		var key: String = _region_key(r)
		_preboss_kill_counts[key] = int(_preboss_kill_counts.get(key, 0)) + 1
		if _preboss_kill_counts[key] >= int(r.kill_quota):
			_trigger_boss_spawn()
			return


func _trigger_boss_spawn() -> void:
	if _boss_spawn_triggered:
		return
	_boss_spawn_triggered = true
	boss_should_spawn.emit(_boss_id, _boss_spawn_pos)


func _spawn_seal_barriers(boss_rect: Rect2) -> void:
	## Spawn two invisible StaticBody2D walls across the top edge of the Boss region.
	## Left half and right half, centered on the boundary line, so they tile cleanly.
	var y_center: float = boss_rect.position.y + SEAL_THICKNESS * 0.5
	var half_w: float = boss_rect.size.x * 0.5

	for i in 2:
		var x_center: float = boss_rect.position.x + half_w * (0.5 + float(i))
		_spawn_seal_body(Vector2(x_center, y_center), Vector2(half_w, SEAL_THICKNESS))


func _spawn_seal_body(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center
	body.collision_layer = WALL_COLLISION_LAYER
	body.collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	get_parent().add_child(body)
	_boss_seal_bodies.append(body)


func remove_seal() -> void:
	for b in _boss_seal_bodies:
		if is_instance_valid(b):
			b.queue_free()
	_boss_seal_bodies.clear()


func _region_key(r: Dictionary) -> String:
	var rid: String = str(r.get("id", ""))
	return rid if rid != "" else str(r.get("rect", ""))
