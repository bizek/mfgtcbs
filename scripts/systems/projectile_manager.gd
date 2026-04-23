class_name ProjectileManager
extends Node2D
## Centralized projectile manager. Parallel-array state and pooled rendering via _draw().
## Eliminates per-projectile Node2D overhead. All movement, hit detection, and
## rendering in one place. Owned by combat_manager. Consumes SpatialGrid for hit detection.

const POOL_SIZE := 256

## 8-direction names indexed by angle sector.
const DIR_NAMES: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

## World bounds for expiry (arena ±800 x ±600 with margin).
const BOUNDS_MIN_X := -850.0
const BOUNDS_MAX_X := 850.0
const BOUNDS_MIN_Y := -650.0
const BOUNDS_MAX_Y := 650.0

var spatial_grid: SpatialGrid
var combat_manager: Node2D

# --- Pool state ---
var _count: int = 0
var _free_list: Array[int] = []

# --- Parallel arrays: core state ---
var _positions: PackedVector2Array
var _velocities: PackedVector2Array
var _factions: PackedInt32Array
var _target_factions: PackedInt32Array
var _distances: PackedFloat32Array
var _hit_radius_sqs: PackedFloat32Array
var _alive: PackedByteArray
var _speeds: PackedFloat32Array
var _max_ranges: PackedFloat32Array
var _motion_types: PackedInt32Array  # 0=directional, 1=aimed, 2=homing

# --- References ---
var _configs: Array = []
var _sources: Array = []
var _abilities: Array = []
var _targets: Array = []

# --- Arc state ---
var _arc_starts: PackedVector2Array
var _arc_ends: PackedVector2Array
var _arc_times: PackedFloat32Array
var _arc_durations: PackedFloat32Array
var _arc_heights: PackedFloat32Array

# --- Pierce tracking ---
var _hit_lists: Array = []
var _pierce_counts: PackedInt32Array

# --- Bounce tracking ---
var _bounce_counts: PackedInt32Array

# --- Combo state ---
var _initial_pierce_counts: PackedInt32Array  ## Phase Bolt: restore pierce to this on bounce
var _has_bounced: PackedByteArray             ## Ice Ball / Spiral Orbit: non-zero if bounced ≥ once

# --- Rendering state ---
var _textures: Array = []
var _visual_scales: PackedVector2Array
var _rotations: PackedFloat32Array

# --- Animation state ---
var _anim_frame_idx: PackedInt32Array
var _anim_frame_timer: PackedFloat32Array

# --- Impact VFX config ---
var _impact_sprite_frames: Array = []
var _impact_animations: Array = []

const MOTION_DIRECTIONAL := 0
const MOTION_AIMED := 1
const MOTION_HOMING := 2


func _ready() -> void:
	_init_pool()


func _init_pool() -> void:
	_positions.resize(POOL_SIZE)
	_velocities.resize(POOL_SIZE)
	_factions.resize(POOL_SIZE)
	_target_factions.resize(POOL_SIZE)
	_distances.resize(POOL_SIZE)
	_hit_radius_sqs.resize(POOL_SIZE)
	_alive.resize(POOL_SIZE)
	_speeds.resize(POOL_SIZE)
	_max_ranges.resize(POOL_SIZE)
	_motion_types.resize(POOL_SIZE)

	_arc_starts.resize(POOL_SIZE)
	_arc_ends.resize(POOL_SIZE)
	_arc_times.resize(POOL_SIZE)
	_arc_durations.resize(POOL_SIZE)
	_arc_heights.resize(POOL_SIZE)

	_pierce_counts.resize(POOL_SIZE)
	_bounce_counts.resize(POOL_SIZE)
	_initial_pierce_counts.resize(POOL_SIZE)
	_has_bounced.resize(POOL_SIZE)
	_visual_scales.resize(POOL_SIZE)
	_rotations.resize(POOL_SIZE)
	_anim_frame_idx.resize(POOL_SIZE)
	_anim_frame_timer.resize(POOL_SIZE)

	_configs.resize(POOL_SIZE)
	_sources.resize(POOL_SIZE)
	_abilities.resize(POOL_SIZE)
	_targets.resize(POOL_SIZE)
	_hit_lists.resize(POOL_SIZE)
	_textures.resize(POOL_SIZE)
	_impact_sprite_frames.resize(POOL_SIZE)
	_impact_animations.resize(POOL_SIZE)

	for i in POOL_SIZE:
		_alive[i] = 0
		_anim_frame_idx[i] = 0
		_anim_frame_timer[i] = 0.0
		_configs[i] = null
		_sources[i] = null
		_abilities[i] = null
		_targets[i] = null
		_hit_lists[i] = []
		_textures[i] = null
		_impact_sprite_frames[i] = null
		_impact_animations[i] = ""
		_initial_pierce_counts[i] = 0
		_has_bounced[i] = 0


func _claim_slot() -> int:
	if not _free_list.is_empty():
		return _free_list.pop_back()
	if _count < POOL_SIZE:
		var slot := _count
		_count += 1
		return slot
	push_warning("ProjectileManager: pool exhausted (%d slots)" % POOL_SIZE)
	return -1


func _release_slot(i: int) -> void:
	_alive[i] = 0
	_sources[i] = null
	_abilities[i] = null
	_targets[i] = null
	_configs[i] = null
	_textures[i] = null
	_hit_lists[i].clear()
	_impact_sprite_frames[i] = null
	_initial_pierce_counts[i] = 0
	_has_bounced[i] = 0
	_free_list.append(i)


# --- Spawning ---

func spawn(source: Node2D, ability, config: ProjectileConfig,
		direction: Vector2, tracking_target: Node2D, offset: Vector2) -> void:
	var i := _claim_slot()
	if i < 0:
		return

	_alive[i] = 1
	_positions[i] = source.global_position + offset
	_speeds[i] = config.speed
	_max_ranges[i] = config.max_range
	_distances[i] = 0.0
	_hit_radius_sqs[i] = config.hit_radius * config.hit_radius
	_factions[i] = int(source.faction)
	_target_factions[i] = 1 if int(source.faction) == 0 else 0
	_velocities[i] = direction * config.speed
	if not config.use_directional_anims:
		_rotations[i] = direction.angle() + config.rotation_offset
	else:
		_rotations[i] = 0.0

	_configs[i] = config
	_sources[i] = source
	_abilities[i] = ability
	_targets[i] = tracking_target
	_hit_lists[i] = []
	_pierce_counts[i] = config.pierce_count
	_bounce_counts[i] = config.bounce_count
	_initial_pierce_counts[i] = config.pierce_count_base if config.pierce_resets_on_bounce else config.pierce_count
	_has_bounced[i] = 0

	match config.motion_type:
		"directional":
			_motion_types[i] = MOTION_DIRECTIONAL
		"aimed":
			_motion_types[i] = MOTION_AIMED
		"homing":
			_motion_types[i] = MOTION_HOMING
		_:
			_motion_types[i] = MOTION_DIRECTIONAL

	_arc_heights[i] = config.arc_height
	if config.arc_height > 0.0:
		_arc_starts[i] = _positions[i]
		if is_instance_valid(tracking_target):
			_arc_ends[i] = tracking_target.global_position
		else:
			var range_dist := config.max_range if config.max_range > 0.0 else 200.0
			_arc_ends[i] = _positions[i] + direction * range_dist
		var initial_dist := _positions[i].distance_to(_arc_ends[i])
		_arc_durations[i] = initial_dist / maxf(config.speed, 1.0)
		_arc_times[i] = 0.0

	_visual_scales[i] = config.visual_scale
	_anim_frame_idx[i] = 0
	_anim_frame_timer[i] = 0.0
	_textures[i] = _resolve_texture(config, direction)
	_impact_sprite_frames[i] = config.impact_sprite_frames
	_impact_animations[i] = config.impact_animation if config.impact_animation != "" else ""

	queue_redraw()


func _resolve_texture(config: ProjectileConfig, direction: Vector2) -> Texture2D:
	if not config.sprite_frames:
		return null
	var anim_name: String
	if config.use_directional_anims:
		anim_name = _direction_to_anim(direction)
	elif config.animation != "":
		anim_name = config.animation
	else:
		return null
	if not config.sprite_frames.has_animation(anim_name):
		return null
	if config.sprite_frames.get_frame_count(anim_name) == 0:
		return null
	return config.sprite_frames.get_frame_texture(anim_name, 0)


# --- Processing ---

func _advance_animation(i: int, delta: float) -> void:
	var config: ProjectileConfig = _configs[i]
	if not config:
		return
	var sf: SpriteFrames = config.sprite_frames
	if not sf:
		return
	var anim: String = config.animation
	if anim == "" or not sf.has_animation(anim):
		return
	var frame_count: int = sf.get_frame_count(anim)
	if frame_count <= 1:
		return
	var fps: float = sf.get_animation_speed(anim)
	if fps <= 0.0:
		return
	_anim_frame_timer[i] += delta
	var spf: float = 1.0 / fps
	while _anim_frame_timer[i] >= spf:
		_anim_frame_timer[i] -= spf
		_anim_frame_idx[i] = (_anim_frame_idx[i] + 1) % frame_count
		_textures[i] = sf.get_frame_texture(anim, _anim_frame_idx[i])


func _process(delta: float) -> void:
	var any_active := false
	for i in _count:
		if not _alive[i]:
			continue
		any_active = true
		_advance_animation(i, delta)
		if _arc_heights[i] > 0.0:
			_process_arc(i, delta)
		else:
			_process_linear(i, delta)
	if any_active:
		queue_redraw()


func _process_linear(i: int, delta: float) -> void:
	if _motion_types[i] == MOTION_HOMING:
		var config: ProjectileConfig = _configs[i]
		## Bloodhound (Gravity + DOT): re-evaluate target each frame, prefer bleeding enemies
		if config and config.homing_prefers_bleeding and spatial_grid:
			var best: Node2D = null
			var best_score: float = INF
			for candidate in spatial_grid.get_nearby(_positions[i], _target_factions[i]):
				if not is_instance_valid(candidate) or not candidate.is_alive:
					continue
				var d: float = _positions[i].distance_to(candidate.global_position)
				## Bleeding targets get a 50% distance bonus (appear "closer" in scoring)
				var score: float = d * (0.5 if candidate.status_effect_component.has_status("bleed") else 1.0)
				if score < best_score:
					best_score = score
					best = candidate
			if best:
				_targets[i] = best
		var tgt = _targets[i]
		if is_instance_valid(tgt) and tgt.is_alive:
			var dir: Vector2 = (tgt.global_position - _positions[i]).normalized()
			_velocities[i] = dir * _speeds[i]
			if config and config.use_directional_anims:
				_textures[i] = _resolve_texture(config, dir)

	_positions[i] += _velocities[i] * delta
	_distances[i] += _speeds[i] * delta

	if _max_ranges[i] > 0.0 and _distances[i] >= _max_ranges[i]:
		_fire_on_expire(i)
		_release_slot(i)
		return

	var pos := _positions[i]
	if pos.x < BOUNDS_MIN_X or pos.x > BOUNDS_MAX_X or pos.y < BOUNDS_MIN_Y or pos.y > BOUNDS_MAX_Y:
		# Ricochet: reflect off arena walls instead of expiring
		if _bounce_counts[i] > 0:
			var vel := _velocities[i]
			if pos.x < BOUNDS_MIN_X or pos.x > BOUNDS_MAX_X:
				vel.x = -vel.x
				_positions[i].x = clampf(pos.x, BOUNDS_MIN_X, BOUNDS_MAX_X)
			if pos.y < BOUNDS_MIN_Y or pos.y > BOUNDS_MAX_Y:
				vel.y = -vel.y
				_positions[i].y = clampf(pos.y, BOUNDS_MIN_Y, BOUNDS_MAX_Y)
			_velocities[i] = vel
			_rotations[i] = vel.angle()
			_bounce_counts[i] -= 1
			_on_bounce(i)
		else:
			_fire_on_expire(i)
			_release_slot(i)
		return

	_check_hits(i)


func _process_arc(i: int, delta: float) -> void:
	_arc_times[i] += delta
	if _arc_durations[i] <= 0.0:
		_release_slot(i)
		return

	var tgt = _targets[i]
	if is_instance_valid(tgt) and tgt.is_alive:
		_arc_ends[i] = tgt.global_position

	var t := clampf(_arc_times[i] / _arc_durations[i], 0.0, 1.0)
	var start := _arc_starts[i]
	var end := _arc_ends[i]
	var arc_h := _arc_heights[i]

	var base_pos := start.lerp(end, t)
	var arc_offset := 4.0 * arc_h * t * (1.0 - t)
	_positions[i] = Vector2(base_pos.x, base_pos.y - arc_offset)

	var dx := end.x - start.x
	var dy := (end.y - start.y) - 4.0 * arc_h * (1.0 - 2.0 * t)
	_rotations[i] = atan2(dy, dx)

	if t >= 1.0:
		_check_hits(i)
		_spawn_impact_vfx(i)
		_release_slot(i)
		return

	var pos := _positions[i]
	if pos.x < BOUNDS_MIN_X or pos.x > BOUNDS_MAX_X or pos.y < BOUNDS_MIN_Y or pos.y > BOUNDS_MAX_Y:
		_release_slot(i)
		return

	_check_hits(i)


func _check_hits(i: int) -> void:
	if not spatial_grid:
		return
	var nearby: Array = spatial_grid.get_nearby(_positions[i], _target_factions[i])
	var hit_radius_sq: float = _hit_radius_sqs[i]
	var pos: Vector2 = _positions[i]
	var hits: Array = _hit_lists[i]
	for tgt in nearby:
		if tgt in hits:
			continue
		if not is_instance_valid(tgt):
			continue
		if pos.distance_squared_to(tgt.global_position) <= hit_radius_sq:
			## Reflecting elite: reverse projectile back toward player faction
			if _factions[i] == 0:
				var se_comp = tgt.get("status_effect_component")
				if se_comp != null and se_comp.has_status("elite_reflecting"):
					_velocities[i] = -_velocities[i].normalized() * _speeds[i]
					_rotations[i] = _velocities[i].angle()
					_target_factions[i] = 0
					_factions[i] = 1
					_sources[i] = tgt
					_hit_lists[i].clear()
					return
			_on_hit(i, tgt)
			if not _alive[i]:
				return


func _on_hit(i: int, target_entity: Node2D) -> void:
	_hit_lists[i].append(target_entity)
	_execute_effects(i, target_entity)
	_execute_impact_aoe(i, target_entity)
	_spawn_impact_vfx(i)
	## Ice Ball (Ricochet + Cryo): apply extra status on hits made after a bounce
	var config: ProjectileConfig = _configs[i]
	if config and _has_bounced[i] and config.bounced_hit_extra_apply != null:
		var source: Node2D = _sources[i]
		if is_instance_valid(source):
			EffectDispatcher.execute_effect(
					config.bounced_hit_extra_apply, source, target_entity,
					_abilities[i], combat_manager)
	var pierce: int = _pierce_counts[i]
	if pierce >= 0 and _hit_lists[i].size() > pierce:
		_fire_on_expire(i)
		_release_slot(i)


func _execute_effects(i: int, target_entity: Node2D) -> void:
	var config: ProjectileConfig = _configs[i]
	if not config:
		return
	var ability = _abilities[i]
	var raw_source = _sources[i]
	if not is_instance_valid(raw_source):
		return
	var source: Node2D = raw_source
	for effect in config.on_hit_effects:
		EffectDispatcher.execute_effect(effect, source, target_entity, ability, combat_manager)


func _execute_impact_aoe(i: int, primary_target: Node2D) -> void:
	var config: ProjectileConfig = _configs[i]
	if not config or config.impact_aoe_radius <= 0.0 or config.impact_aoe_effects.is_empty():
		return
	if not spatial_grid:
		return
	var ability = _abilities[i]
	var raw_source = _sources[i]
	if not is_instance_valid(raw_source):
		return
	var source: Node2D = raw_source
	var pos: Vector2 = _positions[i]
	var radius_sq: float = config.impact_aoe_radius * config.impact_aoe_radius
	var splash_targets: Array = spatial_grid.get_nearby_in_range(pos, _target_factions[i], radius_sq)
	for target in splash_targets:
		if target == primary_target:
			continue
		for effect in config.impact_aoe_effects:
			EffectDispatcher.execute_effect(effect, source, target, ability, combat_manager)


func _fire_on_expire(i: int) -> void:
	var config: ProjectileConfig = _configs[i]
	if not config or config.on_expire_effects.is_empty():
		return
	var source: Node2D = _sources[i]
	if not is_instance_valid(source):
		return
	var ability = _abilities[i]
	var expire_pos: Vector2 = _positions[i]
	# Calculate offset from source so sub-projectiles spawn at the expiry location
	var spawn_offset: Vector2 = expire_pos - source.global_position
	for effect in config.on_expire_effects:
		if effect is SpawnProjectilesEffect:
			var orig_offset: Vector2 = effect.spawn_offset
			effect.spawn_offset = spawn_offset
			spawn_projectiles(source, ability, effect, [])
			effect.spawn_offset = orig_offset
		else:
			EffectDispatcher.execute_effect(effect, source, null, ability, combat_manager)


func _on_bounce(i: int) -> void:
	## Called immediately after a wall bounce is processed.
	## Handles all mod combo effects that trigger on bounce.
	var config: ProjectileConfig = _configs[i]
	if not config:
		return
	var source: Node2D = _sources[i]
	var ability = _abilities[i]
	var bounce_pos: Vector2 = _positions[i]

	## Phase Bolt (Pierce + Ricochet): reset pierce counter to full on each bounce
	if config.pierce_resets_on_bounce:
		_pierce_counts[i] = _initial_pierce_counts[i]
		_hit_lists[i].clear()

	## Bouncing Grenade / Storm Breaker: fire impact AoE at the bounce position
	if config.explodes_on_bounce and config.impact_aoe_radius > 0.0 \
			and not config.impact_aoe_effects.is_empty() \
			and is_instance_valid(source) and spatial_grid:
		var r_sq := config.impact_aoe_radius * config.impact_aoe_radius
		var bounce_targets := spatial_grid.get_nearby_in_range(bounce_pos, _target_factions[i], r_sq)
		for bt in bounce_targets:
			if is_instance_valid(bt) and bt.is_alive:
				for eff in config.impact_aoe_effects:
					EffectDispatcher.execute_effect(eff, source, bt, ability, combat_manager)

	## Generic on-bounce AoE: apply effects to nearby enemies at bounce point
	## (Wildfire fire zones, Thunderball shock, Ricochet Razor bleed refresh, etc.)
	if config.on_bounce_aoe_radius > 0.0 and not config.on_bounce_aoe_effects.is_empty() \
			and is_instance_valid(source) and spatial_grid:
		var r_sq := config.on_bounce_aoe_radius * config.on_bounce_aoe_radius
		var nearby := spatial_grid.get_nearby_in_range(bounce_pos, _target_factions[i], r_sq)
		for nb in nearby:
			if is_instance_valid(nb) and nb.is_alive:
				for eff in config.on_bounce_aoe_effects:
					EffectDispatcher.execute_effect(eff, source, nb, ability, combat_manager)

	## Spiral Orbit (Gravity + Ricochet): re-acquire nearest enemy as homing target
	if config.re_home_after_bounce and spatial_grid:
		var best_tgt: Node2D = null
		var best_dist_sq: float = INF
		for candidate in spatial_grid.get_nearby(bounce_pos, _target_factions[i]):
			if is_instance_valid(candidate) and candidate.is_alive:
				var d_sq: float = bounce_pos.distance_squared_to(candidate.global_position)
				if d_sq < best_dist_sq:
					best_dist_sq = d_sq
					best_tgt = candidate
		_targets[i] = best_tgt

	_has_bounced[i] = 1


func _spawn_impact_vfx(i: int) -> void:
	var impact_sf: SpriteFrames = _impact_sprite_frames[i]
	if not impact_sf:
		return
	if not is_instance_valid(combat_manager):
		return
	var fx := VfxEffect.create(impact_sf, _impact_animations[i], false)
	fx.position = _positions[i]
	combat_manager.add_child(fx)


# --- Rendering ---

func _draw() -> void:
	for i in _count:
		if not _alive[i]:
			continue
		var tex: Texture2D = _textures[i]
		var pos := _positions[i]
		if not tex:
			# Procedural circle fallback for projectiles without textures
			var scl := _visual_scales[i]
			var r: float = 5.0 * scl.x
			var config: ProjectileConfig = _configs[i]
			var col: Color = config.fallback_color if config else Color(1.0, 0.5, 0.1, 0.9)
			draw_circle(pos, r * 1.6, Color(col.r, col.g, col.b, 0.22))
			draw_circle(pos, r, col)
			draw_circle(pos, r * 0.4, Color(1.0, 0.95, 0.75, 1.0))
			continue
		var rot := _rotations[i]
		var scl := _visual_scales[i]
		var size := tex.get_size()
		var half := size * 0.5
		if rot == 0.0 and scl == Vector2.ONE:
			draw_texture(tex, pos - half)
		else:
			draw_set_transform(pos, rot, scl)
			draw_texture(tex, -half)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Utility ---

static func _direction_to_anim(dir: Vector2) -> String:
	var angle := dir.angle()
	if angle < 0.0:
		angle += TAU
	var index := int(round(angle / (TAU / 8.0))) % 8
	return DIR_NAMES[index]


func spawn_projectiles(source: Node2D, ability,
		effect: Resource, targets: Array) -> void:
	match effect.spawn_pattern:
		"radial":
			_spawn_radial(source, ability, effect)
		"aimed_single":
			_spawn_aimed_single(source, ability, effect)
		"spread":
			_spawn_spread(source, ability, effect)
		"at_targets":
			_spawn_at_targets(source, ability, effect, targets)


func _spawn_radial(source: Node2D, ability, effect: Resource) -> void:
	for i in effect.count:
		var angle := float(i) * TAU / float(effect.count)
		var dir := Vector2.from_angle(angle)
		spawn(source, ability, effect.projectile, dir, null, effect.spawn_offset)


func _spawn_spread(source: Node2D, ability, effect: Resource) -> void:
	## Spawn N projectiles in a cone aimed at the source's attack_target.
	var aim_target: Node2D = source.get("attack_target")
	if not is_instance_valid(aim_target) or not aim_target.is_alive:
		return
	var base_dir = (aim_target.global_position - (source.global_position + effect.spawn_offset)).normalized()
	var proj_count: int = effect.count
	var spread_rad: float = deg_to_rad(effect.spread_angle)
	var needs_target: bool = effect.projectile.motion_type == "homing" or effect.projectile.arc_height > 0.0
	for i in proj_count:
		var offset_angle: float = 0.0
		if proj_count > 1:
			offset_angle = -spread_rad * 0.5 + spread_rad * float(i) / float(proj_count - 1)
		var dir: Vector2 = base_dir.rotated(offset_angle)
		var proj_target: Node2D = aim_target if needs_target else null
		spawn(source, ability, effect.projectile, dir, proj_target, effect.spawn_offset)


func _spawn_aimed_single(source: Node2D, ability, effect: Resource) -> void:
	var aim_target: Node2D = source.get("attack_target")
	if not is_instance_valid(aim_target) or not aim_target.is_alive:
		return
	var dir = (aim_target.global_position - (source.global_position + effect.spawn_offset)).normalized()
	var needs_target: bool = effect.projectile.motion_type == "homing" or effect.projectile.arc_height > 0.0
	var proj_target: Node2D = aim_target if needs_target else null
	spawn(source, ability, effect.projectile, dir, proj_target, effect.spawn_offset)


func _spawn_at_targets(source: Node2D, ability, effect: Resource,
		targets: Array) -> void:
	for t in targets:
		if not is_instance_valid(t) or not t.is_alive:
			continue
		var dir = (t.global_position - (source.global_position + effect.spawn_offset)).normalized()
		var homing_target: Node2D = t if effect.projectile.motion_type == "homing" else null
		spawn(source, ability, effect.projectile, dir, homing_target, effect.spawn_offset)


# --- Queries ---

func clear_tracking_target(entity: Node2D) -> void:
	for i in _count:
		if _alive[i] and _targets[i] == entity:
			_targets[i] = null


func get_active_count() -> int:
	var count := 0
	for i in _count:
		if _alive[i]:
			count += 1
	return count


func clear_all() -> void:
	for i in _count:
		if _alive[i]:
			_release_slot(i)
	_count = 0
	_free_list.clear()
