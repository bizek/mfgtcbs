class_name VfxManager
extends Node
## Manages visual effect lifecycle: ability VFX (one-shot) and status VFX (looping).
## Listens to EventBus signals directly. Child of combat_manager.

var _status_vfx: Dictionary = {}  ## entity -> {status_id -> Array[VfxEffect]}


func _ready() -> void:
	EventBus.on_ability_used.connect(_on_ability_used)
	EventBus.on_status_applied.connect(_on_status_applied)
	EventBus.on_status_expired.connect(_on_status_expired)
	EventBus.on_cleanse.connect(_on_cleanse)


func _is_headless() -> bool:
	var cm: Node2D = get_parent()
	return cm and cm.get("is_headless") and cm.is_headless


func cleanup_entity(entity: Node2D) -> void:
	_status_vfx.erase(entity)


func _on_ability_used(entity: Node2D, ability) -> void:
	if not is_instance_valid(entity) or ability.vfx_layers.is_empty():
		return
	if _is_headless():
		return
	for layer in ability.vfx_layers:
		var offset = Vector2(layer.offset)
		if entity.get("sprite") and entity.sprite and entity.sprite.flip_h:
			offset.x = -offset.x
		var fx = VfxEffect.create(layer.sprite_frames, layer.animation, false,
				layer.z_index, offset, layer.scale)
		entity.add_child(fx)


func _on_status_applied(_source: Node2D, target: Node2D, status_id: String, _stacks: int) -> void:
	if not is_instance_valid(target):
		return
	if _is_headless():
		return
	var status_def = target.status_effect_component.get_definition(status_id)
	if not status_def:
		return
	# Looping VFX: spawn once on first application, skip on stack refresh
	if not status_def.vfx_layers.is_empty():
		if not (_status_vfx.has(target) and _status_vfx[target].has(status_id)):
			for layer in status_def.vfx_layers:
				var offset = Vector2(layer.offset)
				if target.get("sprite") and target.sprite and target.sprite.flip_h:
					offset.x = -offset.x
				_add_status_vfx(target, status_id, layer, offset)
	# One-shot stack VFX: spawn on every application/stack
	for layer in status_def.on_stack_vfx_layers:
		var offset = Vector2(layer.offset)
		if target.get("sprite") and target.sprite and target.sprite.flip_h:
			offset.x = -offset.x
		var fx = VfxEffect.create(layer.sprite_frames, layer.animation, false,
				layer.z_index, offset, layer.scale)
		target.add_child(fx)


func _on_status_expired(entity: Node2D, status_id: String) -> void:
	if not is_instance_valid(entity):
		return
	_remove_status_vfx(entity, status_id)


func _on_cleanse(_source: Node2D, target: Node2D, status_id: String) -> void:
	if not is_instance_valid(target):
		return
	_remove_status_vfx(target, status_id)


func _add_status_vfx(entity: Node2D, status_id: String, layer: Resource,
		offset: Vector2) -> void:
	var fx: VfxEffect
	if layer.start_animation != "" or layer.end_animation != "":
		fx = VfxEffect.create_phased(layer.sprite_frames, layer.animation,
				layer.start_animation, layer.end_animation,
				layer.z_index, offset, layer.scale)
	else:
		fx = VfxEffect.create(layer.sprite_frames, layer.animation, true,
				layer.z_index, offset, layer.scale)
	entity.add_child(fx)
	if not _status_vfx.has(entity):
		_status_vfx[entity] = {}
	if not _status_vfx[entity].has(status_id):
		_status_vfx[entity][status_id] = []
	_status_vfx[entity][status_id].append(fx)


func _remove_status_vfx(entity: Node2D, status_id: String) -> void:
	if not _status_vfx.has(entity):
		return
	if not _status_vfx[entity].has(status_id):
		return
	var fx_list: Array = _status_vfx[entity][status_id]
	for fx in fx_list:
		if is_instance_valid(fx):
			fx.stop_effect()
	_status_vfx[entity].erase(status_id)
