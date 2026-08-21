class_name ChoreographyRunner
extends Node
## Host-agnostic executor for ChoreographyDefinition sequences (combo graphs, boss attacks).
## Ported from the original enemy.gd executor; the owning entity ("host") supplies sprite, target
## resolution, effect firing, condition evaluation, and start/end hooks via the duck-typed Host
## interface below. See docs/combat_chain_architecture.md §5.
##
## Wired to BOTH the player (melee combo graphs) and enemy.gd (boss/elite attack sequences) as of
## 2026-07-21 — enemy.gd's in-place duplicate was retired in favour of this runner.
##
## WARNING: choreography carries heavy live content. Four bosses (Goblin King, Heart of the Deep,
## Warped Colossus, Ancient Troll) plus every one of the 12 player kits' light/heavy/channel graphs
## and Q/E skills run through here. Changes are NOT low-risk; regress the bosses and at least one
## melee kit in the Training Room before calling a change done.
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
##   choreo_on_finisher_hit() -> void  (optional; called when an is_finisher phase's hit lands)
##   choreo_on_phase_hit(phase, phase_index, ability) -> void
##       (optional; called whenever a phase's hit fires — the exact moment the cancel window
##        opens, since tick() gates branch-advance on _hit_fired. Combo cadence feedback hangs
##        here; see docs/combo_feedback_spec.md.)
##   choreo_on_chain_timeout(phase) -> void
##       (optional; called when a "wait" phase's window lapses with default_next < 0 — the chain
##        ended by the player letting it drop, as opposed to interrupt() or a finisher completing.)
##   choreo_displacement_active() -> bool
##       (optional; only consulted by "displacement_complete" phases — true while the host is still
##        being carried by the displacement. Hosts that omit it fall back to the watchdog timer.)
##   choreo_on_phase_recovery(phase) -> void
##       (optional; called ONCE per phase entry when a combo node's body anim has finished drawing
##        but its cancel window is still open — see tick(). The host should hand the sprite back to
##        its own locomotion anims; the window, flags and branches all stay live.)

var _host = null                      ## untyped for duck-typed host dispatch
var _sprite: AnimatedSprite2D = null

var _choreo: ChoreographyDefinition = null
var _ability: AbilityDefinition = null
var _phase_index: int = -1
var _timer: float = 0.0
var _phase_time: float = 0.0          ## seconds since this phase was entered (spam cap)
var _targets: Array = []
var _current_anim: String = ""
var _hit_fired: bool = false
var _running: bool = false
## Staged-channel playback: "" = unstaged, else "intro" | "loop" | "outro".
var _stage: String = ""
## Effective hit frame for the phase currently playing. Normally phase.hit_frame, but the host
## may override it per FACING (Animation Lab per-direction edits), so it's resolved on entry.
var _hit_frame: int = -1
## True once choreo_on_phase_recovery() has fired for the current phase entry (once per entry).
var _recovered: bool = false


func setup(host) -> void:
	_host = host


func is_running() -> bool:
	return _running


func get_ability() -> AbilityDefinition:
	return _ability


## True while the CURRENT phase is a sustained held-channel beat — the player is holding an
## input and the graph is parked on a node that repeats until they let go (Immolate, Bramble
## Barrage, Bone Barrage, Taunt, the Reckoning dome, the Ninja's blade storm, and the Whirlwind
## / Dictum nodes embedded inside the Fighter's and Paladin's LIGHT chains).
##
## Deliberately a per-phase question, not a per-ability one. Two kits reach a channel from
## inside their light chain, so "is this ability a channel" would start a channel bed on an
## ordinary opening swing. Callers poll this; it flips true on entry to the held node and false
## the moment the graph moves on.
##
## Both clauses are load-bearing, verified against all 12 kits:
##   • parked-on-self (default_next == self, or hold_anim_on_reentry) — the common shape, and
##     the only one that catches the Ninja's storm, whose release branch goes to an OUTRO
##     phase rather than ending the graph;
##   • held-branch-exits (a ConditionInputHeld branch with next_phase < 0) — catches the Blood
##     Mage's Vampirize, which alternates between TWO phases so neither points at itself.
## Requiring a held branch in both cases is what excludes the light-chain nodes whose held
## branch is a GATE INTO the channel (next_phase = the hold node) rather than the hold itself.
func current_phase_is_held_channel() -> bool:
	if not _running or _choreo == null:
		return false
	if _phase_index < 0 or _phase_index >= _choreo.phases.size():
		return false
	var phase: ChoreographyPhase = _choreo.phases[_phase_index]
	var parked: bool = phase.hold_anim_on_reentry or phase.default_next == _phase_index
	for branch in phase.branches:
		if not (branch.condition is ConditionInputHeld):
			continue
		if parked or branch.next_phase < 0:
			return true
	return false


## True if the current phase has a branch listening for `action` (buffered or held). Lets the
## host tell "this press will be consumed by the graph" apart from "this press dead-ends here"
## (e.g. RMB on a light opener before the heavy-finisher gate opens).
func current_phase_handles(action: String) -> bool:
	if not _running or _choreo == null:
		return false
	if _phase_index < 0 or _phase_index >= _choreo.phases.size():
		return false
	for branch in _choreo.phases[_phase_index].branches:
		var c: Resource = branch.condition
		if c != null and "action" in c and c.action == action:
			return true
	return false


## How much of the current node's CANCEL WINDOW is still open, 0.0-1.0 (0.0 when the graph is
## not parked on one). A "wait" phase carrying branches IS the cancel window — the span in which
## a press chains to the next node.
##
## Added for the HUD chain meter, because nothing else could answer the question. EventBus's
## on_combo_step fires at the instant a node's hit lands and says nothing about the window that
## follows it, so a listener can know a chain got deeper but never how long it has to continue —
## which is the half a player actually acts on.
##
## Held channel beats are excluded on purpose. They are also "wait" phases with branches, but
## they re-enter themselves every beat, so their timer sawtooths; reported as a window it would
## read as a chain window slamming shut and reopening several times a second.
func get_cancel_window_ratio() -> float:
	if not _running or _choreo == null:
		return 0.0
	if _phase_index < 0 or _phase_index >= _choreo.phases.size():
		return 0.0
	var phase: ChoreographyPhase = _choreo.phases[_phase_index]
	if phase.exit_type != "wait" or phase.branches.is_empty() or phase.wait_duration <= 0.0:
		return 0.0
	if current_phase_is_held_channel():
		return 0.0
	return clampf(_timer / phase.wait_duration, 0.0, 1.0)


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
	_stage = ""
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
	var prev_index: int = _phase_index
	_phase_index = index
	_phase_time = 0.0
	_recovered = false
	var phase: ChoreographyPhase = _choreo.phases[index]

	_host.choreo_set_flags(phase.set_untargetable, phase.set_invulnerable)

	if phase.retarget:
		var t: Array = _host.choreo_resolve_targets(phase.retarget)
		if not t.is_empty():
			_targets = t

	if phase.displacement:
		_host.choreo_execute_displacement(phase.displacement, _targets)

	## Staged channel: Ben authored intro/loop/outro segments for this body in the Animation
	## Lab, so the wind-up plays once and only the LOOP segment repeats while held (see
	## CharacterSpriteFactory.STAGE_NAMES). Purely additive — a body with no authored stages
	## keeps the freeze-on-last-frame behavior in the animation block below.
	var staged: bool = phase.animation != "" and phase.hold_anim_on_reentry \
			and _has_stage(phase.animation, "loop")

	## Resolve the hit frame for THIS entry — the host may pin a different one per facing.
	_hit_frame = phase.hit_frame
	if _host.has_method("choreo_hit_frame"):
		_hit_frame = _host.choreo_hit_frame(phase)

	## Fire immediately when no hit_frame is specified (hit_frame < 0), or on every entry of a
	## staged channel body — a looping segment's frame indices don't line up with the phase's
	## authored hit_frame, so the wait cadence IS the damage tick.
	if not phase.effects.is_empty() and (_hit_frame < 0 or staged):
		_fire(phase)

	if _sprite:
		_sprite.speed_scale = 1.0

	if phase.animation != "":
		## Hosts may resolve the phase's canonical anim to a variant (e.g. the player's
		## cursor-facing "<anim>_<dir>" row). hit_frame indices are identical across rows.
		var anim_name: String = phase.animation
		if _host.has_method("choreo_anim_name"):
			anim_name = _host.choreo_anim_name(phase.animation)
		if phase.hold_anim_on_reentry and index == prev_index:
			## Channel self-loop: leave the body alone — a staged body keeps looping its loop
			## segment, an unstaged one stays frozen on its last frame (Guard's raised sword).
			## An unstaged frozen body never reaches its hit_frame again, so tick it here.
			## (hit_frame < 0 and staged bodies already fired at the top — don't double.)
			if _host.has_method("choreo_on_phase_anim"):
				_host.choreo_on_phase_anim(phase, _stage)
			if not staged and _hit_fired and _hit_frame >= 0 and not phase.effects.is_empty():
				_fire(phase)
		elif staged:
			_hit_fired = false
			_begin_stage("intro" if _has_stage(phase.animation, "intro") else "loop", phase)
		else:
			_current_anim = anim_name
			_hit_fired = false
			if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(anim_name):
				_sprite.play(anim_name)
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
		"displacement_complete":
			## Watchdog — a displacement that never ran (dead/invalid target, or a
			## Displacement-negated entity) would otherwise never report completion and the phase
			## would hard-lock the host in whatever flags it set (invulnerable frozen boss).
			var disp_duration: float = phase.displacement.duration if phase.displacement else 0.0
			_timer = disp_duration + 1.5
		"anim_finished":
			if phase.animation == "":
				_on_phase_exit()


## True when the sprite carries an authored "<anim>_<stage>" segment (Animation Lab).
func _has_stage(anim: String, stage: String) -> bool:
	return _sprite != null and _sprite.sprite_frames != null \
			and _sprite.sprite_frames.has_animation(StringName("%s_%s" % [anim, stage]))


## Play one segment of a staged body, resolved through the host's facing variants.
func _begin_stage(stage: String, phase: ChoreographyPhase) -> void:
	_stage = stage
	var base: String = "%s_%s" % [phase.animation, stage]
	var resolved: String = base
	if _host.has_method("choreo_anim_name"):
		resolved = _host.choreo_anim_name(base)
	_current_anim = resolved
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(resolved):
		_sprite.play(resolved)
		if phase.telegraph_speed_scale != 1.0:
			_sprite.speed_scale = phase.telegraph_speed_scale
	## Pass the stage so the host can pick this segment's own fx overlay.
	if _host.has_method("choreo_on_phase_anim"):
		_host.choreo_on_phase_anim(phase, stage)


## Channel released on a staged body: play the outro and let IT end the sequence.
## Returns false when there's nothing authored to play (caller ends normally).
func _begin_outro(phase: ChoreographyPhase) -> bool:
	if _stage == "" or _stage == "outro":
		return false
	if not _has_stage(phase.animation, "outro"):
		return false
	_begin_stage("outro", phase)
	return true


## Host calls this each physics frame; only does work during a "wait" phase.
func tick(delta: float) -> void:
	if not _running or _choreo == null:
		return
	if _phase_index < 0 or _phase_index >= _choreo.phases.size():
		return
	## The outro owns the rest of the sequence — nothing but interrupt() cuts it short.
	if _stage == "outro":
		return
	var phase: ChoreographyPhase = _choreo.phases[_phase_index]
	_phase_time += delta

	## Charge/leap phases: hold until the displacement reports done, or the watchdog fires.
	if phase.exit_type == "displacement_complete":
		_timer -= delta
		var still_moving: bool = false
		if _host.has_method("choreo_displacement_active"):
			still_moving = _host.choreo_displacement_active()
		if not still_moving or _timer <= 0.0:
			_on_phase_exit()
		return

	if phase.exit_type != "wait":
		return
	## Combo feel — "buffer during the swing, cancel at impact" (standard action-game input
	## queuing): presses buffer at any time, but a branch may only cancel this phase once its
	## hit has fired (or the anim ended / it has no hit_frame). Without the gate, a fast tap
	## advances on frame 0 — the swing is cut before its hit_frame (no damage) and the chain
	## visually restarts; with it, mashing advances exactly at each node's impact frame.
	## (A staged body's loop segment plays forever, so its "anim still running" is not a
	## wind-up — input must stay live or the release branch could never fire.)
	var anim_playing: bool = _sprite != null and _sprite.is_playing() \
			and String(_sprite.animation) == _current_anim

	## Recovery release. A combo node's cancel window runs 2-4x its swing length ON PURPOSE
	## (CANCEL_WIN 0.75s over a 0.2s True Heroes body — a forgiving buffer, widened after a feel
	## test). But a one-shot body FREEZES on its last frame when it finishes, so without this the
	## player holds an end-of-swing pose for the rest of the window — and keeps walking around in
	## it, since combos are mobile. Hand the ANIMATION back to the host the frame the body finishes;
	## the window, the phase flags and every branch stay live, so chaining is unchanged.
	## (Audited 2026-07-29: 25 nodes across all 12 kits were freezing 0.15-0.60s each.)
	if not _recovered and not anim_playing and phase.animation != "" and _stage == "" \
			and (_hit_fired or _hit_frame < 0) and not _is_channel_beat(phase):
		_recovered = true
		if _host.has_method("choreo_on_phase_recovery"):
			_host.choreo_on_phase_recovery(phase)

	if _stage != "" or _hit_fired or _hit_frame < 0 or not anim_playing:
		## Spam cap: tap-advance (buffered) branches also wait out the host's minimum
		## cadence — presses stay buffered, so queued input still advances the instant the
		## gate opens. Held/release branches (channel exits) are never delayed.
		var min_tap: float = 0.0
		if _host.has_method("choreo_min_advance_time"):
			min_tap = _host.choreo_min_advance_time(phase)
		## Evaluate branches; first passing branch wins.
		for branch in phase.branches:
			if branch.condition is ConditionInputBuffered and _phase_time < min_tap:
				continue
			if _evaluate_branch(branch, phase):
				## Channel released on a staged body → play the authored outro first.
				if branch.next_phase < 0 and _begin_outro(phase):
					return
				_enter_phase(branch.next_phase)
				return
	_timer -= delta
	if _timer <= 0.0:
		## Window lapsed with nowhere to go = the player dropped the chain (a timeout into a
		## loop index is a continuation, not a drop — hence the default_next gate).
		if phase.default_next < 0 and _host.has_method("choreo_on_chain_timeout"):
			_host.choreo_on_chain_timeout(phase)
		_on_phase_exit()


## True when this phase is one BEAT of a HELD channel rather than a node the player taps: it holds
## its pose across re-entries, falls through to itself, or re-enters itself while an input is HELD.
## Such a phase's recovery IS its next beat — releasing the body to idle between beats would break
## the Whirlwind spin and the Guard's raised shield.
##
## A self-pointing *buffered* branch does NOT count: that's a re-tappable node (Holy Hammer's
## "RMB again → another hammer"), where the player is tapping, not holding, and returning to a
## neutral stance between presses is exactly right.
func _is_channel_beat(phase: ChoreographyPhase) -> bool:
	if phase.hold_anim_on_reentry or phase.default_next == _phase_index:
		return true
	for branch in phase.branches:
		if branch.next_phase == _phase_index and branch.condition is ConditionInputHeld:
			return true
	return false


## Host forwards AnimatedSprite2D.frame_changed here.
func notify_frame_changed() -> void:
	if not _running or _choreo == null or _sprite == null:
		return
	if _phase_index < 0 or _phase_index >= _choreo.phases.size():
		return
	## Staged bodies tick on the wait cadence (_enter_phase), not on frame matches — segment
	## frame indices don't line up with the phase's authored hit_frame.
	if _stage != "":
		return
	var phase: ChoreographyPhase = _choreo.phases[_phase_index]
	if _hit_frame >= 0 and _sprite.animation == _current_anim \
			and _sprite.frame == _hit_frame and not _hit_fired:
		_hit_fired = true
		_fire(phase)


## Host forwards AnimatedSprite2D.animation_finished here.
func notify_animation_finished() -> void:
	if not _running or _choreo == null:
		return
	if _phase_index < 0 or _phase_index >= _choreo.phases.size():
		return
	var phase: ChoreographyPhase = _choreo.phases[_phase_index]
	## Staged channel handoffs: the wind-up rolls into the loop; the outro ends the sequence.
	if _stage == "intro":
		_begin_stage("loop", phase)
		return
	if _stage == "outro":
		_end()
		return
	if phase.exit_type == "anim_finished":
		_on_phase_exit()


func _on_phase_exit() -> void:
	if _choreo == null:
		return
	var phase: ChoreographyPhase = _choreo.phases[_phase_index]
	## A staged body ending for good (not looping back) still gets its outro.
	if phase.default_next < 0 and _begin_outro(phase):
		return
	_enter_phase(phase.default_next)


func _fire(phase: ChoreographyPhase) -> void:
	if phase.is_finisher and _host.has_method("choreo_on_finisher_hit"):
		_host.choreo_on_finisher_hit()
	if _host.has_method("choreo_on_phase_hit"):
		_host.choreo_on_phase_hit(phase, _phase_index, _ability)
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
	_stage = ""
	_hit_frame = -1
	_recovered = false
	if _sprite:
		_sprite.speed_scale = 1.0
	if _host:
		_host.choreo_on_end()
