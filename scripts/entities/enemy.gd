extends CharacterBody2D

## Enemy — Data-driven base enemy script. All enemy types use this script.
## Behavior is driven by EnemyDefinition fields (behavior_type, preferred_range, etc.)
## Uses engine component system for stats, damage pipeline, and status effects.

signal died(enemy: Node2D)

const XP_GEM_SCENE_PATH: String = "res://scenes/pickups/xp_gem.tscn"
const HEALTH_ORB_SCENE_PATH: String = "res://scenes/pickups/health_orb.tscn"

## Base stats (set by setup_from_enemy_def or @export for legacy scenes)
@export var max_hp: float = 30.0
@export var base_move_speed: float = 42.0
@export var contact_damage: float = 10.0
@export var base_armor: float = 0.0
@export var xp_value: float = 1.0

## Engine entity interface
var faction: int = 1  ## 0 = player/allies, 1 = enemies
var is_alive: bool = true
var is_attacking: bool = false
var is_channeling: bool = false
var is_invulnerable: bool = false
var is_untargetable: bool = false
var attack_target: Node2D = null
var last_hit_by: Node2D = null
var last_hit_time: float = -1e18
var _last_hit_time_by_tag: Dictionary = {}
var talent_picks: Array[String] = []
var combat_manager: Node2D = null
var spatial_grid: SpatialGrid = null
var combat_role: String = "MELEE"

## Elite system
var is_elite: bool = false
enum EliteModifier { NONE, HASTING, EXPLODING, SHIELDED }
var elite_modifier: int = EliteModifier.NONE

var player_ref: Node2D = null
var knockback_velocity: Vector2 = Vector2.ZERO
var _hit_tween: Tween = null
var _base_modulate: Color = Color.WHITE

var xp_pickup_scene: PackedScene
var health_orb_scene: PackedScene
@export var health_drop_chance: float = 0.05

var _contact_damage_timer: float = 0.0
const CONTACT_DAMAGE_INTERVAL: float = 0.8

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hurtbox: Area2D = $Hurtbox

## Engine components (created at runtime)
var health: HealthComponent = null
var modifier_component: ModifierComponent = null
var ability_component: AbilityComponent = null
var behavior_component: BehaviorComponent = null
var status_effect_component: StatusEffectComponent = null
var trigger_component: TriggerComponent = null

## Data-driven behavior fields (set by setup_from_enemy_def)
var _enemy_def: EnemyDefinition = null
var _behavior_type: String = "chase"        ## "chase", "ranged", "flee"
var _preferred_range: float = 0.0
var _knockback_multiplier: float = 1.0
var _flee_despawn_at_bounds: bool = false

## Ability pipeline active flag (true when auto_attack registered with AbilityComponent)
var _abilities_wired: bool = false

## Stalker stealth state
var _stealth_active: bool = false
var _stealth_reveal_distance: float = 0.0
var _stealth_revealed: bool = false
var _stealth_hidden_alpha: float = 0.07

## Herald aura visual
var _has_aura_visual: bool = false
var _aura_radius: float = 0.0
var _aura_color: Color = Color(0.85, 0.2, 1.0, 0.18)
var _aura_pulse: float = 0.0

## Carrier loot
var _loot_drop_scene: PackedScene = null
var _loot_value: float = 45.0

## Choreography state (multi-phase boss abilities)
var _choreography: ChoreographyDefinition = null
var _choreography_ability: AbilityDefinition = null
var _choreography_phase_index: int = -1
var _choreography_timer: float = 0.0
var _choreography_targets: Array = []
var _ability_anim_active: bool = false
var _current_attack_anim: String = "attack"
var _current_hit_frame: int = 3
var _hit_frame_fired: bool = false
var _pending_ability: AbilityDefinition = null
var _pending_targets: Array = []


func _init() -> void:
	# Components must exist before _ready() because EnemySpawnManager calls
	# apply_difficulty_scaling() and apply_elite_modifier() before add_child().
	_setup_components()
	set_process(false)  # _process only enabled during choreography phases


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("enemies")
	xp_pickup_scene = load(XP_GEM_SCENE_PATH) if ResourceLoader.exists(XP_GEM_SCENE_PATH) else null
	health_orb_scene = load(HEALTH_ORB_SCENE_PATH) if ResourceLoader.exists(HEALTH_ORB_SCENE_PATH) else null
	player_ref = get_tree().get_first_node_in_group("player")
	if hurtbox:
		hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	if sprite:
		sprite.frame_changed.connect(_on_frame_changed)
		sprite.animation_finished.connect(_on_animation_finished)

	# Apply definition if set before add_child
	if _enemy_def:
		_apply_def_visuals()
		_apply_def_spawn_statuses()


func setup_from_enemy_def(def: EnemyDefinition) -> void:
	## Configure this enemy from a data definition. Call BEFORE add_child().
	_enemy_def = def

	# Core stats
	max_hp = def.base_stats.get("max_hp", 30.0)
	base_move_speed = def.move_speed
	contact_damage = def.contact_damage
	base_armor = def.base_armor
	xp_value = def.xp_value
	health_drop_chance = def.health_drop_chance
	combat_role = def.combat_role

	# Re-setup health with correct max_hp
	health.setup(max_hp)

	# Re-apply armor if needed
	if base_armor > 0.0:
		var armor_mod := ModifierDefinition.new()
		armor_mod.target_tag = "Physical"
		armor_mod.operation = "resist"
		armor_mod.value = base_armor
		armor_mod.source_name = "base_armor"
		modifier_component.add_modifier(armor_mod)

	# Behavior
	_behavior_type = def.behavior_type
	_preferred_range = def.preferred_range
	_knockback_multiplier = def.knockback_multiplier
	_flee_despawn_at_bounds = def.flee_despawn_at_bounds
	_base_modulate = def.base_modulate

	# Groups
	for group_name in def.groups:
		add_to_group(group_name)

	# Wire abilities through engine pipeline (BehaviorComponent → AbilityComponent → EffectDispatcher)
	if def.auto_attack:
		var aa_interval: float = def.auto_attack.cooldown_base if def.auto_attack.cooldown_base > 0.0 else 2.0
		if def.aa_interval_override > 0.0:
			aa_interval = def.aa_interval_override
		ability_component.setup_abilities(def.auto_attack, def.skills, 99)
		behavior_component.setup(modifier_component, aa_interval)
		behavior_component.ability_requested.connect(_on_ability_requested)
		behavior_component.auto_attack_requested.connect(_on_auto_attack_requested)
		_abilities_wired = true
		_check_heal_reactive_targeting(def.auto_attack, def.skills)

	# Carrier loot
	if "carriers" in def.groups:
		if ResourceLoader.exists("res://scenes/pickups/loot_drop.tscn"):
			_loot_drop_scene = load("res://scenes/pickups/loot_drop.tscn")

	# Stalker stealth (tag-driven: "Stealth" in tags)
	if "Stealth" in def.tags:
		_stealth_active = true
		_stealth_reveal_distance = def.aggro_range if def.aggro_range > 0.0 else 60.0

	# Herald aura visual (detected from on_spawn_statuses having aura_radius > 0)
	for status_def in def.on_spawn_statuses:
		if status_def.aura_radius > 0.0:
			_has_aura_visual = true
			_aura_radius = status_def.aura_radius
			break


func _apply_def_visuals() -> void:
	## Apply definition's visual settings to the scene's sprite. Called in _ready().
	if not _enemy_def:
		return
	if sprite and _enemy_def.sprite_scale != Vector2(1.0, 1.0):
		sprite.scale = _enemy_def.sprite_scale
	if sprite and _base_modulate != Color.WHITE:
		sprite.modulate = _base_modulate
	if _stealth_active and not _stealth_revealed:
		_base_modulate = Color(0.85, 0.9, 1.0, _stealth_hidden_alpha)
		if sprite:
			sprite.modulate = _base_modulate
	# Carrier trail particles
	if _flee_despawn_at_bounds:
		_spawn_trail_particles()


func _apply_def_spawn_statuses() -> void:
	## Apply on_spawn_statuses from the definition. Called in _ready() after tree is available.
	if not _enemy_def:
		return
	for status_def in _enemy_def.on_spawn_statuses:
		status_effect_component.apply_status(status_def, self, 1, status_def.base_duration)


func _setup_components() -> void:
	modifier_component = ModifierComponent.new()
	modifier_component.name = "ModifierComponent"
	add_child(modifier_component)

	health = HealthComponent.new()
	health.name = "HealthComponent"
	add_child(health)
	health.setup(max_hp)
	health.died.connect(_on_health_died)

	status_effect_component = StatusEffectComponent.new()
	status_effect_component.name = "StatusEffectComponent"
	add_child(status_effect_component)
	status_effect_component.setup(modifier_component)

	trigger_component = TriggerComponent.new()
	trigger_component.name = "TriggerComponent"
	add_child(trigger_component)

	ability_component = AbilityComponent.new()
	ability_component.name = "AbilityComponent"
	add_child(ability_component)

	behavior_component = BehaviorComponent.new()
	behavior_component.name = "BehaviorComponent"
	add_child(behavior_component)
	behavior_component.setup(modifier_component)

	# Base armor as a resistance modifier (for legacy @export scenes)
	if base_armor > 0.0 and _enemy_def == null:
		var armor_mod := ModifierDefinition.new()
		armor_mod.target_tag = "Physical"
		armor_mod.operation = "resist"
		armor_mod.value = base_armor
		armor_mod.source_name = "base_armor"
		modifier_component.add_modifier(armor_mod)


func _process(delta: float) -> void:
	## Per-frame monitoring during choreography phases only.
	if not is_alive or _choreography == null:
		_choreography = null
		_choreography_phase_index = -1
		set_process(false)
		return

	if _choreography_phase_index < 0 or _choreography_phase_index >= _choreography.phases.size():
		_end_choreography()
		return

	var phase: ChoreographyPhase = _choreography.phases[_choreography_phase_index]

	if phase.exit_type == "wait":
		_choreography_timer -= delta
		# Evaluate branches each frame
		for branch in phase.branches:
			if _evaluate_choreography_branch(branch):
				_enter_choreography_phase(branch.next_phase)
				return
		# Timeout → default_next
		if _choreography_timer <= 0.0:
			_on_choreography_phase_exit()

	elif phase.exit_type == "displacement_complete":
		if not is_channeling:
			_on_choreography_phase_exit()


func _physics_process(delta: float) -> void:
	if not is_alive or player_ref == null or not is_instance_valid(player_ref):
		return

	_contact_damage_timer = maxf(_contact_damage_timer - delta, 0.0)

	# Choreography active: movement suppressed (boss is executing an attack sequence)
	if _choreography != null:
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		return

	# Stunned/frozen: cannot move or act. Interrupts choreography.
	if status_effect_component.is_disabled():
		if _choreography != null:
			_end_choreography()
		elif _ability_anim_active:
			_end_animated_ability()
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		return

	# Shade passive: don't chase invisible player
	if player_ref.has_method("is_invisible") and player_ref.is_invisible():
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		return

	# Stalker reveal check
	if _stealth_active and not _stealth_revealed:
		var dist_to_player: float = global_position.distance_to(player_ref.global_position)
		if dist_to_player <= _stealth_reveal_distance:
			_stalker_reveal()

	# Movement speed from modifiers (slow = negative bonus)
	var speed_mult: float = 1.0 + modifier_component.sum_modifiers("move_speed", "bonus")
	if status_effect_component.is_movement_disabled():
		speed_mult = 0.0

	# Movement direction based on behavior type
	var dist: float = global_position.distance_to(player_ref.global_position)
	match _behavior_type:
		"flee":
			var dir: Vector2 = (global_position - player_ref.global_position).normalized()
			velocity = dir * base_move_speed * maxf(speed_mult, 0.0) + knockback_velocity
		"ranged":
			if dist > _preferred_range:
				var dir: Vector2 = (player_ref.global_position - global_position).normalized()
				velocity = dir * base_move_speed * maxf(speed_mult, 0.0) + knockback_velocity
			else:
				velocity = knockback_velocity
		_:  # "chase" (default)
			var dir: Vector2 = (player_ref.global_position - global_position).normalized()
			velocity = dir * base_move_speed * maxf(speed_mult, 0.0) + knockback_velocity

	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)

	# Flee bounds despawn (carrier)
	if _flee_despawn_at_bounds:
		if not EnemySpawnManager.arena_bounds.has_point(global_position):
			_despawn_escaped()
			return

	# Sustained contact damage
	if contact_damage > 0.0 and _contact_damage_timer <= 0.0 and hurtbox != null:
		for body in hurtbox.get_overlapping_bodies():
			if body.is_in_group("player") and body.has_method("take_damage"):
				var hit := DamageCalculator.calculate_raw_hit(
					self, body, contact_damage, "Physical", null,
					combat_manager.rng if combat_manager else null)
				if not hit.is_dodged:
					body.take_damage(hit)
					_apply_contact_knockback(body)
				_contact_damage_timer = CONTACT_DAMAGE_INTERVAL
				break

	# Set attack_target for BehaviorComponent targeting (player is always the target in arena)
	if is_instance_valid(player_ref) and player_ref.is_alive:
		attack_target = player_ref

	# Animation
	if sprite:
		if _behavior_type == "ranged" and velocity.length() < 5.0:
			if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")
			else:
				sprite.play("walk")
		else:
			sprite.play("walk")

	# Herald aura visual
	if _has_aura_visual:
		_aura_pulse += delta * 2.8
		queue_redraw()


func _draw() -> void:
	if not _has_aura_visual or not is_alive:
		return
	var alpha: float = 0.12 + sin(_aura_pulse) * 0.07
	draw_circle(Vector2.ZERO, _aura_radius, Color(_aura_color.r, _aura_color.g, _aura_color.b, alpha * 0.5))
	draw_circle(Vector2.ZERO, _aura_radius * 0.6, Color(_aura_color.r, _aura_color.g, _aura_color.b, alpha))


func _check_heal_reactive_targeting(auto_attack: AbilityDefinition,
		skills: Array) -> void:
	## Enable heal-reactive targeting if any ability uses the "most_recently_healed_enemy" type.
	if auto_attack and auto_attack.targeting and auto_attack.targeting.type == "most_recently_healed_enemy":
		behavior_component.enable_heal_reactive_targeting()
		return
	for skill in skills:
		if skill.ability and skill.ability.targeting and skill.ability.targeting.type == "most_recently_healed_enemy":
			behavior_component.enable_heal_reactive_targeting()
			return


func _on_ability_requested(ability: AbilityDefinition, targets: Array) -> void:
	## Engine ability pipeline: BehaviorComponent resolved targets and wants to fire.
	if _ability_anim_active:
		return

	# Choreography: multi-phase ability sequence (boss attacks, etc.)
	if ability.choreography != null:
		_start_choreography(ability, targets)
		return

	# Standard animated ability: play attack animation, fire on hit frame
	if ability.anim_override != "" or ability.hit_frame_override >= 0:
		_start_animated_ability(ability, targets)
		return

	# Instant ability: fire effects immediately
	EffectDispatcher.execute_effects(ability.effects, self, targets, ability, combat_manager)
	EventBus.on_ability_used.emit(self, ability)


func _on_auto_attack_requested(ability: AbilityDefinition, targets: Array) -> void:
	## Engine auto-attack pipeline: BehaviorComponent timer expired, fire AA.
	if _ability_anim_active and ability.choreography == null:
		return  # Auto-attacks don't interrupt ability animations (but are ignored during choreography)

	# Animated auto-attack
	if ability.anim_override != "" or ability.hit_frame_override >= 0:
		_start_animated_ability(ability, targets)
		return

	# Instant auto-attack
	EffectDispatcher.execute_effects(ability.effects, self, targets, ability, combat_manager)
	EventBus.on_ability_used.emit(self, ability)


# --- Animated Ability Execution (non-choreography) ---

func _start_animated_ability(ability: AbilityDefinition, targets: Array) -> void:
	## Play attack animation and fire effects on the hit frame.
	_pending_ability = ability
	_pending_targets = targets
	_ability_anim_active = true
	_current_attack_anim = ability.anim_override if ability.anim_override != "" else "attack"
	_current_hit_frame = ability.hit_frame_override if ability.hit_frame_override >= 0 else 3
	_hit_frame_fired = false
	is_attacking = true

	if ability.grants_invulnerability:
		is_invulnerable = true

	EventBus.on_ability_used.emit(self, ability)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(_current_attack_anim):
		sprite.play(_current_attack_anim)
	else:
		# No animation available — fire immediately
		_execute_pending_effects()
		_end_animated_ability()


func _execute_pending_effects() -> void:
	if _pending_ability == null:
		return
	var targets: Array = _pending_targets
	if targets.is_empty() and is_instance_valid(player_ref) and player_ref.is_alive:
		targets = [player_ref]
	EffectDispatcher.execute_effects(
		_pending_ability.effects, self, targets, _pending_ability, combat_manager)


func _end_animated_ability() -> void:
	_ability_anim_active = false
	is_attacking = false
	is_invulnerable = false
	_pending_ability = null
	_pending_targets = []

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")


# --- Frame Changed / Animation Finished ---

func _on_frame_changed() -> void:
	if not is_attacking or not is_alive:
		return

	# Choreography phase: fire effects on the phase's hit frame
	if _choreography != null:
		if _choreography_phase_index < 0 or _choreography_phase_index >= _choreography.phases.size():
			return
		var phase: ChoreographyPhase = _choreography.phases[_choreography_phase_index]
		if phase.hit_frame >= 0 and sprite.animation == _current_attack_anim \
				and sprite.frame == phase.hit_frame and not _hit_frame_fired:
			_hit_frame_fired = true
			_execute_choreography_phase_effects(phase)
		return

	# Standard animated ability: fire on hit frame
	if _pending_ability != null and not _hit_frame_fired:
		if sprite.frame == _current_hit_frame:
			_hit_frame_fired = true
			_execute_pending_effects()


func _on_animation_finished() -> void:
	if not is_alive:
		return

	# Choreography: animation finished for current phase
	if _choreography != null:
		_on_choreography_animation_finished()
		return

	# Standard animated ability: done
	if _ability_anim_active and _pending_ability != null:
		# If hit frame was never reached (short anim), fire effects now
		if not _hit_frame_fired:
			_execute_pending_effects()
		_end_animated_ability()


# --- Choreography System (multi-phase boss abilities) ---

func _start_choreography(ability: AbilityDefinition, targets: Array) -> void:
	## Begin a choreography sequence. Sets up state and enters phase 0.
	_choreography = ability.choreography
	_choreography_ability = ability
	_choreography_targets = targets.duplicate()
	_choreography_phase_index = -1
	_choreography_timer = 0.0

	is_channeling = true
	is_attacking = true
	_ability_anim_active = true
	_pending_ability = null
	_pending_targets = []

	EventBus.on_ability_used.emit(self, ability)
	_enter_choreography_phase(0)


func _enter_choreography_phase(index: int) -> void:
	## Enter a specific phase. index = -1 or out of bounds ends the choreography.
	if _choreography == null or index < 0 or index >= _choreography.phases.size():
		_end_choreography()
		return

	_choreography_phase_index = index
	var phase: ChoreographyPhase = _choreography.phases[index]

	# Entity state flags
	is_untargetable = phase.set_untargetable
	is_invulnerable = phase.set_invulnerable

	# Retarget if specified
	if phase.retarget and spatial_grid:
		var targets: Array = behavior_component.resolve_targets_with_rule(phase.retarget, self)
		if not targets.is_empty():
			_choreography_targets = targets

	# Execute displacement if specified
	if phase.displacement and combat_manager and combat_manager.get("displacement_system"):
		var disp_source: Node2D = _choreography_targets[0] if not _choreography_targets.is_empty() else self
		combat_manager.displacement_system.execute(
			disp_source, _choreography_ability, phase.displacement, [self])

	# Fire effects immediately if no hit_frame specified
	if phase.hit_frame < 0 and not phase.effects.is_empty():
		_execute_choreography_phase_effects(phase)

	# Play animation or set up exit monitoring
	if phase.animation != "":
		_current_attack_anim = phase.animation
		_hit_frame_fired = false
		is_attacking = true

		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(phase.animation):
			sprite.play(phase.animation)
		elif phase.exit_type == "anim_finished":
			# No animation available — skip to next
			_on_choreography_phase_exit()
			return

	# Set up phase exit monitoring
	match phase.exit_type:
		"wait":
			_choreography_timer = phase.wait_duration
			set_process(true)
		"displacement_complete":
			set_process(true)
		"anim_finished":
			if phase.animation == "":
				_on_choreography_phase_exit()


func _execute_choreography_phase_effects(phase: ChoreographyPhase) -> void:
	## Fire effects for the current choreography phase.
	if phase.effects.is_empty():
		return

	var targets: Array = _choreography_targets.duplicate()
	if targets.is_empty() and spatial_grid:
		var enemy_faction: int = 1 if int(faction) == 0 else 0
		var nearest: Node2D = spatial_grid.find_nearest(global_position, enemy_faction)
		if nearest:
			targets = [nearest]

	# Set attack_target for projectile aim direction
	if not targets.is_empty():
		attack_target = targets[0]

	EffectDispatcher.execute_effects(
		phase.effects, self, targets, _choreography_ability, combat_manager)

	# Dispatch ability modifications (talent/item augments)
	if _choreography_ability and ability_component:
		var mod_effects: Array = ability_component.get_ability_modifications(
			_choreography_ability.ability_id)
		if not mod_effects.is_empty():
			EffectDispatcher.execute_effects(
				mod_effects, self, targets, _choreography_ability, combat_manager)


func _on_choreography_animation_finished() -> void:
	## Animation finished during a choreography phase.
	if _choreography_phase_index < 0 or _choreography_phase_index >= _choreography.phases.size():
		return
	var phase: ChoreographyPhase = _choreography.phases[_choreography_phase_index]
	if phase.exit_type == "anim_finished":
		_on_choreography_phase_exit()


func _on_choreography_phase_exit() -> void:
	## Current phase complete. Transition to default_next.
	set_process(false)
	if _choreography == null:
		return
	var phase: ChoreographyPhase = _choreography.phases[_choreography_phase_index]
	_enter_choreography_phase(phase.default_next)


func _evaluate_choreography_branch(branch: ChoreographyBranch) -> bool:
	## Evaluate a choreography branch condition.
	if not branch.condition:
		return true
	var condition: Resource = branch.condition
	if condition is ConditionEntityCount:
		return ability_component._check_entity_count(condition, self)
	return false


func _end_choreography() -> void:
	## Clean up all choreography state and return to normal behavior.
	_choreography = null
	_choreography_ability = null
	_choreography_phase_index = -1
	_choreography_timer = 0.0
	_choreography_targets = []
	is_untargetable = false
	is_invulnerable = false
	is_channeling = false
	is_attacking = false
	_ability_anim_active = false
	attack_target = null
	_pending_ability = null
	_pending_targets = []
	set_process(false)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")


func _stalker_reveal() -> void:
	_stealth_revealed = true
	var revealed_color := Color(0.65, 0.82, 1.0, 1.0)
	_base_modulate = revealed_color
	if sprite:
		sprite.modulate = Color(8.0, 8.0, 8.0, 1.0)
		var t := create_tween()
		t.tween_property(sprite, "modulate", revealed_color, 0.20)


func _despawn_escaped() -> void:
	is_alive = false
	EnemySpawnManager.on_enemy_despawned()
	queue_free()


func _spawn_trail_particles() -> void:
	var p := CPUParticles2D.new()
	p.amount = 8
	p.lifetime = 0.7
	p.one_shot = false
	p.explosiveness = 0.0
	p.direction = Vector2(0.0, -1.0)
	p.spread = 180.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 20.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(1.0, 0.85, 0.2, 0.9)
	add_child(p)
	p.emitting = true


func get_armor() -> float:
	return modifier_component.sum_modifiers("Physical", "resist")


func is_dead() -> bool:
	return not is_alive


func apply_status(effect: String, params: Dictionary = {}) -> void:
	## Compatibility bridge: translates old string-based status calls from weapon_controller
	## and projectile.gd into engine StatusEffectComponent calls.
	if not is_alive or not status_effect_component:
		return
	StatusFactory.build_all()
	var status_def: StatusEffectDefinition = StatusFactory.get_by_id(effect)
	if not status_def:
		return

	# Cryo special case: stacking toward Frozen
	if effect == "cryo":
		var stacks: int = status_effect_component.get_stacks("chilled") + 1
		var freeze_threshold: int = params.get("freeze_stacks", 3)
		if stacks >= freeze_threshold:
			# Clear chilled, apply frozen
			status_effect_component.force_remove_status("chilled")
			var frozen_def: StatusEffectDefinition = StatusFactory.frozen
			var freeze_dur: float = params.get("freeze_duration", 1.5)
			status_effect_component.apply_status(frozen_def, self, 1, freeze_dur)
		else:
			var chill_dur: float = params.get("duration", 3.0)
			status_effect_component.apply_status(status_def, self, 1, chill_dur)
		return

	# Override duration/damage from params if provided
	var duration: float = -1.0
	if params.has("dot_duration"):
		duration = params["dot_duration"]
	elif params.has("duration"):
		duration = params["duration"]

	status_effect_component.apply_status(status_def, self, 1, duration)


func take_damage(hit_data) -> void:
	if not is_alive:
		return
	if is_invulnerable:
		return

	CombatUtils.process_incoming_damage(self, hit_data)

	# Enemy-specific: hit flash
	if is_alive and sprite:
		if _hit_tween and _hit_tween.is_valid():
			_hit_tween.kill()
		sprite.modulate = Color(5.0, 5.0, 5.0, 1.0)
		_hit_tween = create_tween()
		_hit_tween.tween_property(sprite, "modulate", _base_modulate, 0.08)


func apply_knockback(force: Vector2) -> void:
	knockback_velocity += force * _knockback_multiplier


static func apply_knockback_from_hit(attacker: Node2D, defender: Node2D, force: float = 160.0) -> void:
	if not is_instance_valid(defender) or not defender.has_method("apply_knockback"):
		return
	var dir: Vector2 = (defender.global_position - attacker.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	defender.apply_knockback(dir * force)


func _apply_contact_knockback(target: Node2D) -> void:
	apply_knockback_from_hit(self, target, 160.0)


func apply_difficulty_scaling(difficulty: float) -> void:
	max_hp *= (1.0 + (difficulty - 1.0) * 0.5)
	health.setup(max_hp)
	contact_damage *= (1.0 + (difficulty - 1.0) * 0.3)
	base_move_speed *= (1.0 + (difficulty - 1.0) * 0.1)


func apply_elite_modifier() -> void:
	max_hp *= 2.0
	health.setup(max_hp)
	contact_damage *= 1.5
	xp_value *= 2.5
	is_elite = true

	# Elite armor via modifier
	var elite_armor := ModifierDefinition.new()
	elite_armor.target_tag = "Physical"
	elite_armor.operation = "resist"
	elite_armor.value = 3.0
	elite_armor.source_name = "elite"
	modifier_component.add_modifier(elite_armor)

	var modifiers: Array = [EliteModifier.HASTING, EliteModifier.EXPLODING, EliteModifier.SHIELDED]
	elite_modifier = modifiers[randi() % modifiers.size()]

	match elite_modifier:
		EliteModifier.HASTING:
			if status_effect_component:
				status_effect_component.apply_status(StatusFactory.get_by_id("elite_hasting"), self)
			_base_modulate = Color(0.2, 1.0, 0.3, 1.0)
		EliteModifier.EXPLODING:
			if status_effect_component:
				status_effect_component.apply_status(StatusFactory.get_by_id("elite_exploding"), self)
			_base_modulate = Color(1.0, 0.25, 0.1, 1.0)
		EliteModifier.SHIELDED:
			if status_effect_component:
				status_effect_component.apply_status(StatusFactory.get_by_id("elite_shielded"), self)
			health.add_shield(max_hp * 0.4, "elite_shield")
			_base_modulate = Color(0.3, 0.5, 1.0, 1.0)

	if sprite:
		sprite.modulate = _base_modulate
		var glow_tween := create_tween().set_loops()
		glow_tween.tween_property(sprite, "modulate", _base_modulate * 1.6, 0.45)
		glow_tween.tween_property(sprite, "modulate", _base_modulate * 0.7, 0.45)


# --- Death ---

func _on_health_died(_entity: Node2D) -> void:
	if not is_alive:
		return
	is_alive = false
	if trigger_component:
		trigger_component.cleanup()

	EventBus.on_death.emit(self)
	var killer: Node2D = last_hit_by if is_instance_valid(last_hit_by) else null
	if killer:
		EventBus.on_kill.emit(killer, self)
		if health.last_overkill > 0.0:
			EventBus.on_overkill.emit(killer, self, health.last_overkill)

	died.emit(self)

	if status_effect_component and status_effect_component.has_status("elite_exploding"):
		_exploding_death()

	# Void-Touched death explosion
	if status_effect_component and status_effect_component.has_status("void_touched"):
		_void_explosion()

	# Carrier loot
	if _loot_drop_scene:
		_drop_carrier_loot()

	_spawn_death_effect()
	_drop_xp()
	_drop_health()
	queue_free()


func _drop_carrier_loot() -> void:
	var count: int = randi_range(2, 3)
	for i in range(count):
		var drop: Area2D = _loot_drop_scene.instantiate()
		var offset := Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))
		drop.global_position = global_position + offset
		drop.value = _loot_value / float(count)
		get_tree().current_scene.add_child(drop)


func _exploding_death() -> void:
	const EXPLODE_RADIUS: float = 60.0
	const EXPLODE_DAMAGE: float = 15.0
	var player := get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) <= EXPLODE_RADIUS:
		if player.has_method("take_damage"):
			var hit := DamageCalculator.calculate_raw_hit(self, player, EXPLODE_DAMAGE, "Fire")
			if not hit.is_dodged:
				player.take_damage(hit)
	VFXHelpers.spawn_expanding_ring(
		get_tree().current_scene, global_position,
		Color(1.0, 0.2, 0.05, 0.6), EXPLODE_RADIUS, 1.2, 0.3)
	VFXHelpers.spawn_burst(
		get_tree().current_scene, global_position,
		Color(1.0, 0.35, 0.0, 0.9), 12, 0.4, 40.0, 120.0, 2.5, 5.0,
		Vector2.ZERO)


func _void_explosion() -> void:
	const VOID_RADIUS: float = 80.0
	var dmg: float = contact_damage * 2.0
	for other in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(other) or other == self:
			continue
		if global_position.distance_to(other.global_position) <= VOID_RADIUS:
			if other.has_method("take_damage"):
				var hit := DamageCalculator.calculate_raw_hit(self, other, dmg, "Void")
				if not hit.is_dodged:
					other.take_damage(hit)
	GameManager.modify_instability(2)
	VFXHelpers.spawn_expanding_ring(
		get_tree().current_scene, global_position,
		Color(0.40, 0.08, 0.65, 0.55), VOID_RADIUS, 1.4, 0.25)
	VFXHelpers.spawn_burst(
		get_tree().current_scene, global_position,
		Color(0.55, 0.10, 0.90, 0.90), 14, 0.55, 60.0, 160.0, 2.0, 5.0,
		Vector2.ZERO)


func _spawn_death_effect() -> void:
	VFXHelpers.spawn_burst(
		get_tree().current_scene, global_position,
		Color(1.0, 0.5, 0.1, 1.0), 8, 0.45, 50.0, 130.0, 2.0, 4.0,
		Vector2(0.0, 120.0))


func _drop_xp() -> void:
	if xp_pickup_scene == null:
		return
	var pickup: Node2D = xp_pickup_scene.instantiate()
	pickup.global_position = global_position
	pickup.xp_value = xp_value
	get_tree().current_scene.add_child(pickup)


func _drop_health() -> void:
	if health_orb_scene == null:
		return
	if randf() > health_drop_chance:
		return
	var orb: Node2D = health_orb_scene.instantiate()
	orb.global_position = global_position
	get_tree().current_scene.add_child(orb)


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if not is_alive:
		return
	if body.is_in_group("player") and body.has_method("take_damage") and _contact_damage_timer <= 0.0:
		var hit := DamageCalculator.calculate_raw_hit(
			self, body, contact_damage, "Physical", null,
			combat_manager.rng if combat_manager else null)
		if not hit.is_dodged:
			body.take_damage(hit)
			_apply_contact_knockback(body)
		_contact_damage_timer = CONTACT_DAMAGE_INTERVAL
