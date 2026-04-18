class_name TelegraphManager
extends Node
## Manages boss/enemy attack wind-up telegraphs. Ad-hoc Node2D instances
## (no pool — at most a handful live at a time). Mirrors VfxManager lifecycle
## semantics so headless replay/test runs short-circuit VFX.
##
## API:
##   spawn(effect, source, target) -> Telegraph2D
##   cancel(source, telegraph_id)  — cancels matching live telegraphs
##   cleanup_entity(entity)         — cancels any telegraph whose source == entity

var _active: Array[Telegraph2D] = []


func _is_headless() -> bool:
	var cm: Node2D = get_parent()
	return cm and cm.get("is_headless") and cm.is_headless


func spawn(effect: SpawnTelegraphEffect, source: Node2D, target: Node2D) -> Telegraph2D:
	## Creates a Telegraph2D, parents it to the current scene (not the caster),
	## configures it, and returns it. Returns null in headless mode.
	if _is_headless():
		return null
	if effect == null:
		return null
	var tel := Telegraph2D.new()
	tel.configure(effect, source, target)
	var parent: Node = get_tree().current_scene if get_tree() else null
	if parent == null:
		parent = get_parent()
	parent.add_child(tel)
	_active.append(tel)
	tel.tree_exited.connect(_on_telegraph_freed.bind(tel))
	return tel


func cancel(source: Node2D, telegraph_id: String) -> void:
	## Free any active telegraphs matching both source and id.
	for tel in _active.duplicate():
		if not is_instance_valid(tel):
			continue
		if tel.source == source and tel.telegraph_id == telegraph_id:
			tel.queue_free()


func cleanup_entity(entity: Node2D) -> void:
	## Free any active telegraphs whose source is the given entity.
	## Called when an enemy dies or its choreography is interrupted.
	for tel in _active.duplicate():
		if not is_instance_valid(tel):
			continue
		if tel.source == entity:
			tel.queue_free()


func _on_telegraph_freed(tel: Telegraph2D) -> void:
	_active.erase(tel)
