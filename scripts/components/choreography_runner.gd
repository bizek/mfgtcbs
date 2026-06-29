class_name ChoreographyRunner
extends Node
## Host-agnostic executor for ChoreographyDefinition sequences (combo graphs, boss attacks).
## Ported from the original enemy.gd executor; the owning entity ("host") supplies sprite, target
## resolution, effect firing, condition evaluation, and start/end hooks via the duck-typed Host
## interface below. See docs/combat_chain_architecture.md §5.
##
## Currently wired to the player (melee combo graphs). enemy.gd keeps its own copy until a later
## migration task moves it onto this runner (deferred — choreography has no shipped content yet, so
## there's no live behavior to regress, but no reason to destabilize it mid-feature either).
##
## Host interface (the owner Node must implement):
##   choreo_sprite() -> AnimatedSprite2D
##   choreo_resolve_targets(rule: TargetingRule) -> Array
##   choreo_fire_effects(effects: Array, targets: Array, ability: AbilityDefinition) -> void
##   choreo_execute_displacement(disp, targets: Array) -> void
##   choreo_evaluate_condition(condition: Resource, phase: ChoreographyPhase) -> bool
##   choreo_set_flags(untargetable: bool, invulnerable: bool) -> void
##   choreo_on_start(ability: AbilityDefinition) -> void
##   choreo_on_end() -> void

var _host = null                      ## untyped for duck-typed host dispatch
var _sprite: AnimatedSprite2D = null

var _choreo: ChoreographyDefinition = null
var _ability: AbilityDefinition = null
var _phase_index: int = -1
var _timer: float = 0.0
var _targets: Array = []
var _current_anim: String = ""
var _hit_fired: bool = false
var _running: bool = false


func setup(host) -> void:
	_host = host


func is_running() -> bool:
	return _running


## Begin a choreography sequence. `targets` is the initial target set (host may ignore it).
func start(ability: AbilityDefinition, targets: Array) -> void:
	if ability == null or ability.choreography == null:
		return
	if _running:
		_end()
	_choreo = ability.choreography
	_ability = ability
	_targets = targets.duplicate()
	_phase_index = -1
	_timer = 0.0
	_current_anim = ""
	_hit_fired = false
	_running = true
	_sprite = _host.choreo_sprite()
	_host.choreo_on_start(ability)
	_enter_phase(0)


## Cancel an in-progress sequence (hurt/dash/stun/death).
func interrupt() -> void:
	if _running:
		_end()


func _enter_phase(index: int) -> void:
	if _choreo == null or index < 0 or index >= _choreo.phases.size():
		_end()
		return
	_phase_index = index
	var phase: ChoreographyPhase = _choreo.phases[index]

	_host.choreo_set_flags(phase.set_untargetable, phase.set_invulnerable)

	if phase.retarget:
		var t: Array = _host.choreo_resolve_targets(phase.retarget)
		if not t.is_empty():
			_targets = t

	if phase.displacement:
		_host.choreo_execute_displacement(phase.displacement, _targets)

	## Fire immediately when no hit_frame is specified (hit_frame < 0).
	if phase.hit_frame < 0 and not phase.effects.is_empty():
		_fire(phase)

	if _sprite:
		_sprite.speed_scale = 1.0

	if phase.animation != "":
		_current_anim = phase.animation
		_hit_fired = false
		if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(phase.animation):
			_sprite.play(phase.animation)
			if phase.telegraph_speed_scale != 1.0:
				_sprite.speed_scale = phase.telegraph_speed_scale
			if _host.has_method("choreo_on_phase_anim"):
				_host.choreo_on_phase_anim(phase)
		elif phase.exit_type == "anim_finished":
			## No animation to wait on — advance immediately.
			_on_phase_exit()
			return

	match phase.exit_type:
		"wait":
			_timer = phase.wait_duration
		"anim_finished":
			if phase.animation == "":
				_on_phase_exit()


## Host calls this each physics frame; only does work during a "wait" phase.
func tick(delta: float) -> void:
	if not _running or _choreo == null:
		return
	if _phase_index < 0 or _phase_index >= _choreo.phases.size():
		return
	var phase: ChoreographyPhase = _choreo.phases[_phase_index]
	if phase.exit_type != "wait":
		return
	## Evaluate branches every frame; first passing branch wins.
	for branch in phase.branches:
		if _evaluate_branch(branch, phase):
			_enter_phase(branch.next_phase)
			return
	_timer -= delta
	if _timer <= 0.0:
		_on_phase_exit()


## Host forwards AnimatedSprite2D.frame_changed here.
func notify_frame_changed() -> void:
	if not _running or _choreo == null or _sprite == null:
		return
	if _phase_index < 0 or _phase_index >= _choreo.phases.size():
		return
	var phase: ChoreographyPhase = _choreo.phases[_phase_index]
	if phase.hit_frame >= 0 and _sprite.animation == _current_anim \
			and _sprite.frame == phase.hit_frame and not _hit_fired:
		_hit_fired = true
		_fire(phase)


## Host forwards AnimatedSprite2D.animation_finished here.
func notify_animation_finished() -> void:
	if not _running or _choreo == null:
		return
	if _phase_index < 0 or _phase_index >= _choreo.phases.size():
		return
	var phase: ChoreographyPhase = _choreo.phases[_phase_index]
	if phase.exit_type == "anim_finished":
		_on_phase_exit()


func _on_phase_exit() -> void:
	if _choreo == null:
		return
	var phase: ChoreographyPhase = _choreo.phases[_phase_index]
	_enter_phase(phase.default_next)


func _fire(phase: ChoreographyPhase) -> void:
	if phase.effects.is_empty():
		return
	_host.choreo_fire_effects(phase.effects, _targets, _ability)


func _evaluate_branch(branch: ChoreographyBranch, phase: ChoreographyPhase) -> bool:
	if branch.condition == null:
		return true
	return _host.choreo_evaluate_condition(branch.condition, phase)


func _end() -> void:
	_running = false
	_choreo = null
	_ability = null
	_phase_index = -1
	_timer = 0.0
	_targets = []
	_current_anim = ""
	_hit_fired = false
	if _sprite:
		_sprite.speed_scale = 1.0
	if _host:
		_host.choreo_on_end()
