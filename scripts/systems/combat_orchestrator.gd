class_name CombatOrchestrator
extends Node2D
## Central orchestrator owning all engine subsystems. Scene-owned (not autoload).
## Added as a child of the arena scene. Manages tick order, entity lifecycle,
## and subsystem wiring.
##
## Owns: SpatialGrid, ProjectileManager, VfxManager, DisplacementSystem,
##       CombatFeedbackManager, ground zones, corpses.
##
## Tick order per frame:
##   1. Rebuild SpatialGrid
##   2. StatusEffectComponent.tick() for all entities
##   3. AbilityComponent.tick_cooldowns() for all entities
##   4. BehaviorComponent.tick() for all entities
##   5. ProjectileManager._process() (automatic via Node)
##   6. Ground zone ticks

var spatial_grid: SpatialGrid = SpatialGrid.new()
var projectile_manager: ProjectileManager = null
var vfx_manager: VfxManager = null
var telegraph_manager: TelegraphManager = null
var displacement_system: DisplacementSystem = null
var combat_feedback: Node2D = null  ## CombatFeedbackManager
var combo_effect_resolver: ComboEffectResolver = null
var debug_draw: DebugDraw = null

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var run_time: float = 0.0
var is_headless: bool = false  ## True for replay/test — suppresses VFX

## Entity tracking
var _players: Array = []   ## All player-faction entities (player + summons)
var _enemies: Array = []   ## All enemy-faction entities
var corpses: Array = []    ## Dead entities persisting as corpses

## Ground zones
var _ground_zones: Array = []  ## Active ground zone instances


func _ready() -> void:
	# Create subsystems as children
	projectile_manager = ProjectileManager.new()
	projectile_manager.name = "ProjectileManager"
	projectile_manager.spatial_grid = spatial_grid
	projectile_manager.combat_manager = self
	add_child(projectile_manager)

	vfx_manager = VfxManager.new()
	vfx_manager.name = "VfxManager"
	add_child(vfx_manager)

	telegraph_manager = TelegraphManager.new()
	telegraph_manager.name = "TelegraphManager"
	add_child(telegraph_manager)

	displacement_system = DisplacementSystem.new()
	displacement_system.name = "DisplacementSystem"
	add_child(displacement_system)

	# CombatFeedbackManager (the engine's pooled version)
	var CombatFeedbackScript = load("res://scripts/systems/combat_feedback_manager.gd")
	if CombatFeedbackScript:
		combat_feedback = CombatFeedbackScript.new()
		combat_feedback.name = "CombatFeedback"
		add_child(combat_feedback)

	# ComboEffectResolver — tracks combo triggers and emits discovery signals
	combo_effect_resolver = ComboEffectResolver.new()
	combo_effect_resolver.name = "ComboEffectResolver"
	combo_effect_resolver.combat_manager = self
	add_child(combo_effect_resolver)

	# DebugDraw — targeting/hitbox visualization (disabled by default)
	debug_draw = DebugDraw.new()
	debug_draw.name = "DebugDraw"
	add_child(debug_draw)


func register_player(entity: Node2D) -> void:
	## Register a player-faction entity (player character, summons).
	if entity not in _players:
		_players.append(entity)
	_inject_references(entity)


func register_enemy(entity: Node2D) -> void:
	## Register an enemy-faction entity.
	if entity not in _enemies:
		_enemies.append(entity)
	_inject_references(entity)


func unregister_entity(entity: Node2D) -> void:
	_players.erase(entity)
	_enemies.erase(entity)


func _inject_references(entity: Node2D) -> void:
	## Inject engine back-references into an entity.
	## All engine entities declare these properties — set directly.
	entity.combat_manager = self
	entity.spatial_grid = spatial_grid
	if entity.status_effect_component:
		entity.status_effect_component.combat_manager = self
	if entity.trigger_component:
		entity.trigger_component.combat_manager = self


func tick(delta: float) -> void:
	## Main tick — call once per frame from the arena scene's _process.
	run_time += delta

	# 1. Rebuild spatial grid
	spatial_grid.rebuild(_players, _enemies)

	# 2-4. Tick all entities' components in defined order
	var all_entities: Array = _players + _enemies
	for entity in all_entities:
		if not is_instance_valid(entity) or not entity.is_alive:
			continue
		# Status effects tick first (DoTs, duration countdown, modifier decay)
		if entity.get("status_effect_component"):
			entity.status_effect_component.tick(delta)
		# Cooldowns tick second
		if entity.get("ability_component"):
			entity.ability_component.tick_cooldowns(delta)
		# Behavior tick last (ability decisions, auto-attacks)
		# Skip player — player ticks own behavior in _physics_process (input-driven)
		if int(entity.faction) != 0 and entity.get("behavior_component"):
			entity.behavior_component.tick(delta, entity)

	# 5. Ground zone ticks
	_tick_ground_zones(delta)

	# 6. Clean up dead entity references
	_cleanup_dead()


func spawn_ground_zone(effect: GroundZoneEffect, source: Node2D,
		zone_pos: Vector2) -> void:
	## Create a persistent ground zone that ticks effects on nearby entities.
	var zone := {
		effect = effect,
		source = source,
		position = zone_pos,
		time_remaining = effect.duration,
		tick_timer = effect.tick_interval,
	}
	_ground_zones.append(zone)


func _tick_ground_zones(delta: float) -> void:
	var expired: Array = []
	for zone in _ground_zones:
		zone.time_remaining -= delta
		zone.tick_timer -= delta
		if zone.tick_timer <= 0.0:
			zone.tick_timer += zone.effect.tick_interval
			_apply_ground_zone_tick(zone)
		if zone.time_remaining <= 0.0:
			expired.append(zone)
	for zone in expired:
		_ground_zones.erase(zone)


func _apply_ground_zone_tick(zone: Dictionary) -> void:
	var effect: GroundZoneEffect = zone.effect
	var source: Node2D = zone.source if is_instance_valid(zone.source) else null
	var target_faction: int
	match effect.target_faction:
		"enemy":
			target_faction = 1 if source != null and int(source.faction) == 0 else 0
		"ally":
			target_faction = int(source.faction) if source != null else 0
		_:
			return
	var range_sq: float = effect.radius * effect.radius
	var targets: Array = spatial_grid.get_nearby_in_range(zone.position, target_faction, range_sq)
	for target in targets:
		if not target.is_alive:
			continue
		for tick_effect in effect.tick_effects:
			EffectDispatcher.execute_effect(tick_effect, source, target, null, self, source)


func spawn_summon(source: Node2D, ability, effect: SummonEffect) -> void:
	## Summon spawning hook. Override or connect to implement summon entity creation.
	## The base pattern: check max_active, create entity, register, emit signal.
	push_warning("CombatOrchestrator.spawn_summon() — not yet wired to entity factory")


func revive_entity(corpse: Node2D, hp_percent: float, source: Node2D) -> void:
	## Resurrection hook. Override or connect to implement corpse revival.
	push_warning("CombatOrchestrator.revive_entity() — not yet wired")


func get_nearest_corpse(pos: Vector2, faction: int) -> Node2D:
	var best: Node2D = null
	var best_dist_sq := INF
	for corpse in corpses:
		if not is_instance_valid(corpse):
			continue
		if int(corpse.faction) != faction:
			continue
		var d_sq := pos.distance_squared_to(corpse.global_position)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best = corpse
	return best


func _cleanup_dead() -> void:
	_players = _players.filter(func(e): return is_instance_valid(e))
	_enemies = _enemies.filter(func(e): return is_instance_valid(e))


func cleanup() -> void:
	## Call on run end — release all pooled resources.
	if projectile_manager:
		projectile_manager.clear_all()
	_ground_zones.clear()
	corpses.clear()
	_players.clear()
	_enemies.clear()
