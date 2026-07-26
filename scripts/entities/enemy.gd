extends CharacterBody2D

## Enemy — Data-driven base enemy script. All enemy types use this script.
## Behavior is driven by EnemyDefinition fields (behavior_type, preferred_range, etc.)
## Uses engine component system for stats, damage pipeline, and status effects.

signal died(enemy: Node2D)

const XP_GEM_SCENE_PATH: String = "res://scenes/pickups/xp_gem.tscn"
const HEALTH_ORB_SCENE_PATH: String = "res://scenes/pickups/health_orb.tscn"

## Deliberate-pacing rebalance (2026-06-23, pass 2 2026-07-07) — global slowdown
## applied to every enemy's per-type design speed at setup. Tuning this one number
## rescales ALL enemy movement while preserving the relative spread authored in the
## data factories. See docs/pacing_rebalance.md.
const MOVE_SPEED_SCALE: float = 0.5   ## was 0.6

## Kill pop — white flash + scale punch on the death frame (game-feel pass).
const KILL_POP_ENABLED: bool = true
const KILL_POP_SCALE: float = 1.35
const KILL_POP_DURATION: float = 0.12

## Base stats (set by setup_from_enemy_def or @export for legacy scenes)
@export var max_hp: float = 30.0
@export var base_move_speed: float = 25.0  ## legacy-scene default; data enemies override via setup_from_enemy_def
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
var enemy_id: String = "fodder"

## Elite system
var is_elite: bool = false
enum EliteModifier { NONE, HASTING, EXPLODING, SHIELDED, REFLECTING, REGENERATING, ARMORED, VAMPIRIC }
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

## Choreography (multi-phase boss abilities) — executed by the SHARED ChoreographyRunner,
## the same executor the player's combo graphs use. Migrated off enemy.gd's private copy
## 2026-07-21; the host contract is the `choreo_*` methods further down this file.
var _choreo_runner: ChoreographyRunner = null
var _choreo_ability: AbilityDefinition = null   ## ability driving the active sequence (for effects)
var _ability_anim_active: bool = false
var _current_attack_anim: String = "attack"
var _current_hit_frame: int = 3
var _hit_frame_fired: bool = false
var _pending_ability: AbilityDefinition = null
var _pending_targets: Array = []
var _is_damage_anim_active: bool = false


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
	base_move_speed = def.move_speed * MOVE_SPEED_SCALE  ## deliberate-pacing global slowdown
	contact_damage = def.contact_damage
	base_armor = def.base_armor
	xp_value = def.xp_value
	health_drop_chance = def.health_drop_chance
	combat_role = def.combat_role
	enemy_id = def.enemy_id

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

	# Boss health bar wiring — bosses push state to the HUD on spawn + damage + death.
	if def.is_boss:
		var boss_id: String = def.enemy_id
		var boss_name: String = def.enemy_name if def.enemy_name != "" else def.enemy_id.to_upper()
		var boss_color: Color = def.boss_bar_color
		health.health_changed.connect(
				func(hp: float, max_hp_: float):
					GameManager.boss_state_changed.emit(
							boss_id, hp, max_hp_, true, boss_name, boss_color))
		health.died.connect(
				func(_entity: Node2D):
					GameManager.boss_state_changed.emit(
							boss_id, 0.0, max_hp, false, boss_name, boss_color))
		## Push initial state so the bar appears immediately on spawn.
		GameManager.boss_state_changed.emit(
				boss_id, health.current_hp, health.max_hp, true, boss_name, boss_color)


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
	## Per-frame monitoring during choreography phases only. The runner self-guards when idle;
	## _choreo_on_start/_end toggle set_process so we don't tick every enemy every frame.
	if not is_alive:
		set_process(false)
		return
	if _choreo_runner == null or not _choreo_runner.is_running():
		set_process(false)
		return
	_choreo_runner.tick(delta)


func _physics_process(delta: float) -> void:
	if not is_alive or player_ref == null or not is_instance_valid(player_ref):
		return

	_contact_damage_timer = maxf(_contact_damage_timer - delta, 0.0)

	# Stunned/frozen: cannot move or act. Interrupts choreography.
	# NOTE (2026-07-21): this check MUST precede the choreography block below. Previously the
	# choreography early-return came first, so this block's interrupt branch was unreachable
	# and a stunned boss kept executing its attack sequence — contradicting both this comment and
	# docs/engine_reference.md. Ordering fixed during the ChoreographyRunner migration.
	if status_effect_component.is_disabled():
		if _choreo_runner != null and _choreo_runner.is_running():
			_choreo_runner.interrupt()
		elif _ability_anim_active:
			_end_animated_ability()
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		return

	# Choreography active: movement suppressed (boss is executing an attack sequence)
	if _choreo_runner != null and _choreo_runner.is_running():
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		return

	# Charmed: fight for the player — chase and strike other enemies.
	if _charm_tinted and not status_effect_component.has_status("charmed"):
		## Charm wore off — drop the love-struck tint.
		_charm_tinted = false
		_base_modulate = _charm_prev_modulate
		if sprite:
			sprite.modulate = _base_modulate
	if status_effect_component.has_status("charmed"):
		_process_charmed(delta)
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
	var eff_speed: float = base_move_speed * maxf(speed_mult, 0.0)
	match _behavior_type:
		"flee":
			velocity = _ff_flee_dir() * eff_speed + knockback_velocity
		"ranged":
			if dist > _preferred_range:
				velocity = _ff_chase_dir() * eff_speed + knockback_velocity
			else:
				velocity = knockback_velocity
		_:  # "chase" (default)
			velocity = _ff_chase_dir() * eff_speed + knockback_velocity
	velocity += _separation_push(speed_mult)

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
					if elite_modifier == EliteModifier.VAMPIRIC:
						health.apply_healing(contact_damage * 0.4)
				_contact_damage_timer = CONTACT_DAMAGE_INTERVAL
				break

	# Set attack_target for BehaviorComponent targeting (player is always the target in arena)
	if is_instance_valid(player_ref) and player_ref.is_alive:
		attack_target = player_ref

	# Animation — never stomp an active attack/damage animation with walk/idle.
	# play("walk") cancels the non-looping anim, animation_finished never fires,
	# and _ability_anim_active/is_attacking wedge permanently (one attack per life).
	if sprite and not _ability_anim_active and not _is_damage_anim_active:
		# Face the player horizontally (sprites authored facing right; flip when target is left)
		if is_instance_valid(player_ref):
			var dx: float = player_ref.global_position.x - global_position.x
			if absf(dx) > 1.0:
				sprite.flip_h = dx < 0.0
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

	# Generic attack animation fallback (before instant fire)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
		_start_animated_ability(ability, targets)
		return

	# Instant ability: fire effects immediately
	EffectDispatcher.execute_effects(ability.effects, self, targets, ability, combat_manager)
	EventBus.on_ability_used.emit(self, ability)


func _on_auto_attack_requested(ability: AbilityDefinition, targets: Array) -> void:
	## Engine auto-attack pipeline: BehaviorComponent timer expired, fire AA.
	if _ability_anim_active and ability.choreography == null:
		return  # Auto-attacks don't interrupt ability animations (but are ignored during choreography)

	# Choreographed auto-attack (boss stance machines, telegraphed slams) — must run
	# its phases. The animated path below would play a bare attack anim and fire the
	# ability's top-level effects list, which is empty for choreographed abilities.
	if ability.choreography != null:
		if not _is_choreographing() and not _ability_anim_active:
			_start_choreography(ability, targets)
		return

	# Animated auto-attack
	if ability.anim_override != "" or ability.hit_frame_override >= 0:
		_start_animated_ability(ability, targets)
		return

	# Generic attack animation fallback
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
		_start_animated_ability(ability, targets)
		return

	# Instant auto-attack (no animation)
	EffectDispatcher.execute_effects(ability.effects, self, targets, ability, combat_manager)
	EventBus.on_ability_used.emit(self, ability)


# --- Animated Ability Execution (non-choreography) ---

func _start_animated_ability(ability: AbilityDefinition, targets: Array) -> void:
	## Play attack animation and fire effects on the hit frame.
	_pending_ability = ability
	_pending_targets = targets
	_ability_anim_active = true
	_is_damage_anim_active = false  # attack supersedes damage anim; clear stuck flag
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

	# Choreography phase: the runner owns hit-frame matching and firing.
	if _is_choreographing():
		_choreo_runner.notify_frame_changed()
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
	if _is_choreographing():
		_choreo_runner.notify_animation_finished()
		return

	# Damage reaction: resume walk after damage anim
	if _is_damage_anim_active:
		_is_damage_anim_active = false
		if sprite and sprite.sprite_frames:
			sprite.play("walk")
		return

	# Standard animated ability: done
	if _ability_anim_active and _pending_ability != null:
		# If hit frame was never reached (short anim), fire effects now
		if not _hit_frame_fired:
			_execute_pending_effects()
		_end_animated_ability()


# --- Choreography System (multi-phase boss abilities) ---
#
# The sequencing itself lives in the SHARED ChoreographyRunner (scripts/components/
# choreography_runner.gd) — the same executor the player's combo graphs run on. Everything below
# is this entity's implementation of the runner's duck-typed host contract.
#
# Migrated 2026-07-21 off enemy.gd's private copy of the executor. Behavior is preserved except
# for one deliberate fix: stun now actually interrupts choreography (see _physics_process).

func _is_choreographing() -> bool:
	return _choreo_runner != null and _choreo_runner.is_running()


func _start_choreography(ability: AbilityDefinition, targets: Array) -> void:
	## Begin a choreography sequence via the shared runner.
	if _choreo_runner == null:
		_choreo_runner = ChoreographyRunner.new()
		_choreo_runner.name = "ChoreographyRunner"
		add_child(_choreo_runner)
		_choreo_runner.setup(self)
	_choreo_ability = ability
	_choreo_runner.start(ability, targets)


# --- ChoreographyRunner host contract ---

func choreo_sprite() -> AnimatedSprite2D:
	return sprite


func choreo_resolve_targets(rule: TargetingRule) -> Array:
	if not spatial_grid or behavior_component == null:
		return []
	return behavior_component.resolve_targets_with_rule(rule, self)


func choreo_fire_effects(effects: Array, targets: Array, ability: AbilityDefinition) -> void:
	## Fire one phase's effects. Falls back to the nearest hostile when the phase has no targets
	## (a telegraphed slam that outlived its original target still needs somewhere to land).
	if effects.is_empty():
		return

	var resolved: Array = targets.duplicate()
	if resolved.is_empty() and spatial_grid:
		var enemy_faction: int = 1 if int(faction) == 0 else 0
		var nearest: Node2D = spatial_grid.find_nearest(global_position, enemy_faction)
		if nearest:
			resolved = [nearest]

	# Set attack_target for projectile aim direction
	if not resolved.is_empty():
		attack_target = resolved[0]

	EffectDispatcher.execute_effects(effects, self, resolved, ability, combat_manager)

	# Dispatch ability modifications (talent/item augments)
	if ability and ability_component:
		var mod_effects: Array = ability_component.get_ability_modifications(ability.ability_id)
		if not mod_effects.is_empty():
			EffectDispatcher.execute_effects(
				mod_effects, self, resolved, ability, combat_manager)


func choreo_execute_displacement(disp, targets: Array) -> void:
	## This entity is the effect's "self"; choreography targets provide the destination
	## (displaced="self" resolves the source arg, so passing the target there displaced the
	## PLAYER and left our is_channeling flag permanently set — invulnerable frozen boss).
	if disp == null or combat_manager == null or not combat_manager.get("displacement_system"):
		return
	combat_manager.displacement_system.execute(self, _choreo_ability, disp, targets)


func choreo_evaluate_condition(condition: Resource, _phase: ChoreographyPhase) -> bool:
	## Enemies branch on world state only — no input conditions (that's the player's vocabulary).
	if condition == null:
		return true
	if condition is ConditionEntityCount:
		return ability_component._check_entity_count(condition, self)
	if condition is ConditionHpThreshold:
		return ability_component._check_hp_threshold(condition, self)
	return false


func choreo_set_flags(untargetable: bool, invulnerable: bool) -> void:
	is_untargetable = untargetable
	is_invulnerable = invulnerable


func choreo_displacement_active() -> bool:
	## "displacement_complete" phases hold until the DisplacementSystem clears is_channeling.
	return is_channeling


func choreo_on_start(ability: AbilityDefinition) -> void:
	is_channeling = true
	is_attacking = true
	_ability_anim_active = true
	_is_damage_anim_active = false  # choreography supersedes damage anim
	_pending_ability = null
	_pending_targets = []
	set_process(true)
	EventBus.on_ability_used.emit(self, ability)


func choreo_on_phase_anim(_phase: ChoreographyPhase, _stage: String = "") -> void:
	## A phase started playing its body — keep the attack gate open so frame_changed forwards.
	is_attacking = true


func choreo_on_end() -> void:
	## Clean up all choreography state and return to normal behavior.
	if sprite:
		sprite.speed_scale = 1.0
	if combat_manager and combat_manager.get("telegraph_manager"):
		combat_manager.telegraph_manager.cleanup_entity(self)
	_choreo_ability = null
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


# --- Charm ---
## While "charmed" runs, this enemy turns on its own: chases the nearest other enemy and
## strikes it with boosted contact damage. It deals no contact damage to the player and its
## normal attack pipeline is suspended (this branch returns before both).
##
## NOTE: no shipped kit applies "charmed" since the Bard was replaced by the Demonologist
## (2026-07-26). The mechanic is generic and kept intact for future content — it is dormant,
## not dead. Apply StatusEffectDefinition "charmed" from anywhere to switch it back on.
var _charm_target: Node2D = null
var _charm_rescan: float = 0.0
var _charm_strike_cd: float = 0.0
var _charm_tinted: bool = false          ## love-struck pink while charmed (restored on expiry)
var _charm_prev_modulate: Color = Color.WHITE
const CHARM_STRIKE_RANGE: float = 22.0
const CHARM_STRIKE_COOLDOWN: float = 0.9
const SEP_RADIUS: float = 22.0       ## Separation push radius (px)
const SEP_RADIUS_SQ: float = SEP_RADIUS * SEP_RADIUS
const SEP_WEIGHT: float = 0.28       ## Separation as fraction of base move speed


func _process_charmed(delta: float) -> void:
	if not _charm_tinted:
		## Love-struck pink for the charm's whole run — hit flashes tween back to it.
		_charm_tinted = true
		_charm_prev_modulate = _base_modulate
		_base_modulate = Color(1.0, 0.55, 0.75, 1.0)
		if sprite:
			sprite.modulate = _base_modulate
	_charm_strike_cd = maxf(_charm_strike_cd - delta, 0.0)
	_charm_rescan -= delta
	if _charm_rescan <= 0.0:
		_charm_rescan = 0.4
		_charm_target = _nearest_other_enemy()
	var target: Node2D = _charm_target
	if target != null and (not is_instance_valid(target) or not target.get("is_alive")):
		target = null
		_charm_target = null

	var speed_mult: float = 1.0 + modifier_component.sum_modifiers("move_speed", "bonus")
	if status_effect_component.is_movement_disabled():
		speed_mult = 0.0
	if target:
		var to_t: Vector2 = target.global_position - global_position
		if to_t.length() <= CHARM_STRIKE_RANGE:
			velocity = knockback_velocity
			if _charm_strike_cd <= 0.0:
				_charm_strike_cd = CHARM_STRIKE_COOLDOWN
				var hit := DamageCalculator.calculate_raw_hit(
					self, target, contact_damage * 1.5, "Physical", null,
					combat_manager.rng if combat_manager else null)
				if not hit.is_dodged:
					target.take_damage(hit)
		else:
			## Straight-line chase: the flow field flows toward the PLAYER, so steering by it
			## here made charmed enemies orbit the player instead of hunting their victim
			## (targets are within the 160px charm scan — walls rarely matter at that range).
			velocity = to_t.normalized() * base_move_speed * maxf(speed_mult, 0.0) + knockback_velocity
	else:
		velocity = knockback_velocity   ## love-struck and no one to fight — stand swooning
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)
	if sprite and not _is_damage_anim_active and absf(velocity.x) > 0.01:
		sprite.flip_h = velocity.x < 0


func _nearest_other_enemy() -> Node2D:
	## Nearest live enemy that isn't this one, within a modest search radius. Gated by the
	## 0.4s rescan — never per-frame (300x lens).
	var best: Node2D = null
	var best_d: float = 160.0 * 160.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not is_instance_valid(e) or not e.get("is_alive"):
			continue
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _ff_chase_dir() -> Vector2:
	## Flow-field direction toward the player. Falls back to straight-line when field is
	## inactive (open arena) or this cell is disconnected from the player.
	## Look-ahead: sample 8px ahead of current velocity so the enemy starts turning
	## before physically reaching a corner, preventing wall-clip hang-ups.
	var ff = combat_manager.get("flow_field") if combat_manager else null
	if ff:
		var sample_pos: Vector2 = global_position
		if velocity.length_squared() > 25.0:
			sample_pos += velocity.normalized() * 8.0
		var dir: Vector2 = ff.get_flow_direction(sample_pos)
		if dir != Vector2.ZERO:
			return dir
	return (player_ref.global_position - global_position).normalized()


func _ff_flee_dir() -> Vector2:
	## Direction away from the player through the field: steers toward the neighbor cell
	## with the highest BFS distance. Falls back to straight-away when the field is absent
	## or the current cell is disconnected.
	var ff = combat_manager.get("flow_field") if combat_manager else null
	if ff and ff.is_active():
		var cur_d: int = ff.get_distance_cells(global_position)
		if cur_d >= 0:
			var best_d: int = cur_d
			var best_dir: Vector2 = Vector2.ZERO
			for offset: Vector2 in [Vector2(16.0, 0.0), Vector2(-16.0, 0.0),
					Vector2(0.0, 16.0), Vector2(0.0, -16.0)]:
				var d: int = ff.get_distance_cells(global_position + offset)
				if d > best_d:
					best_d = d
					best_dir = offset
			if best_dir != Vector2.ZERO:
				return best_dir.normalized()
	return (global_position - player_ref.global_position).normalized()


func _separation_push(speed_mult: float) -> Vector2:
	## Gentle repulsion from the 2-3 nearest enemies; capped at SEP_WEIGHT of move speed
	## so it never overpowers the flow direction. Uses SpatialGrid faction 1 (enemies).
	if spatial_grid == null:
		return Vector2.ZERO
	var push: Vector2 = Vector2.ZERO
	var count: int = 0
	for e in spatial_grid.get_nearby_in_range(global_position, 1, SEP_RADIUS_SQ):
		if e == self or not is_instance_valid(e):
			continue
		var diff: Vector2 = global_position - e.global_position
		var dsq: float = diff.length_squared()
		if dsq < 0.001:
			continue
		push += diff / dsq   ## 1/r weighting: closer neighbors push harder
		count += 1
		if count >= 3:
			break
	if push == Vector2.ZERO:
		return Vector2.ZERO
	return push.normalized() * base_move_speed * maxf(speed_mult, 0.0) * SEP_WEIGHT


func take_damage(hit_data) -> void:
	if not is_alive:
		return
	if is_invulnerable:
		return

	CombatUtils.process_incoming_damage(self, hit_data)

	# Enemy-specific: hit flash + damage reaction
	if is_alive and sprite:
		if _hit_tween and _hit_tween.is_valid():
			_hit_tween.kill()
		sprite.modulate = Color(5.0, 5.0, 5.0, 1.0)
		_hit_tween = create_tween()
		_hit_tween.tween_property(sprite, "modulate", _base_modulate, 0.08)
		# Damage animation (skip if mid-attack or already playing damage)
		if not _ability_anim_active and not _is_damage_anim_active:
			if sprite.sprite_frames and sprite.sprite_frames.has_animation("damage"):
				_is_damage_anim_active = true
				sprite.play("damage")


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

	var modifiers: Array = [
		EliteModifier.HASTING, EliteModifier.EXPLODING, EliteModifier.SHIELDED,
		EliteModifier.REFLECTING, EliteModifier.REGENERATING, EliteModifier.ARMORED,
		EliteModifier.VAMPIRIC,
	]
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
		EliteModifier.REFLECTING:
			if status_effect_component:
				status_effect_component.apply_status(StatusFactory.get_by_id("elite_reflecting"), self)
			_base_modulate = Color(0.0, 0.9, 0.9, 1.0)
		EliteModifier.REGENERATING:
			if status_effect_component:
				status_effect_component.apply_status(StatusFactory.get_by_id("elite_regenerating"), self)
			_base_modulate = Color(0.3, 1.0, 0.5, 1.0)
		EliteModifier.ARMORED:
			if status_effect_component:
				status_effect_component.apply_status(StatusFactory.get_by_id("elite_armored"), self)
			_base_modulate = Color(0.7, 0.7, 0.75, 1.0)
		EliteModifier.VAMPIRIC:
			if status_effect_component:
				status_effect_component.apply_status(StatusFactory.get_by_id("elite_vampiric"), self)
			_base_modulate = Color(0.7, 0.05, 0.3, 1.0)

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
	set_physics_process(false)
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

	_drop_xp()
	_drop_health()

	_kill_pop()

	# Death animation (plays before despawn; collision/contact already inert via is_alive=false)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
	else:
		_spawn_death_effect()
		if sprite:
			## No death anim to wait on — hold the frame briefly so the pop is visible
			## before the node frees.
			await get_tree().create_timer(KILL_POP_DURATION).timeout

	queue_free()


func _kill_pop() -> void:
	if not KILL_POP_ENABLED or not sprite:
		return
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	var base_scale: Vector2 = sprite.scale
	sprite.modulate = Color(4.0, 4.0, 4.0, 1.0)
	sprite.scale = base_scale * KILL_POP_SCALE
	var t := create_tween()
	t.tween_property(sprite, "modulate", _base_modulate, KILL_POP_DURATION)
	t.parallel().tween_property(sprite, "scale", base_scale, KILL_POP_DURATION)


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
			if elite_modifier == EliteModifier.VAMPIRIC:
				health.apply_healing(contact_damage * 0.4)
		_contact_damage_timer = CONTACT_DAMAGE_INTERVAL
