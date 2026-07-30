class_name CombatInputBuffer
extends RefCounted
## Tracks recent presses (for buffered-tap queries) and continuous hold durations for a set of
## combat actions. Polled each physics frame by the player (tick()); read by the input-condition
## evaluators (ConditionInputBuffered / ConditionInputHeld). Pure input state — no FSM, no anim,
## no damage. See docs/combat_chain_architecture.md §6.
##
## CLOCK: this runs on GAME time — an internal accumulator of the scaled physics delta — NOT on
## Time.get_ticks_msec(). That matters because every window it gets compared against is game time:
## ConditionInputBuffered checks a press's age against ChoreographyPhase.wait_duration, which the
## runner decrements by delta. Wherever the two clocks disagree, presses are silently discarded
## while the cancel window is still wide open.
##
## They disagreed constantly. Hitstop sets Engine.time_scale = 0 for 6 frames on every combo
## finisher — physics keeps ticking (Godot 4.6 does NOT stop physics iterations at time_scale 0;
## verified in-engine 2026-07-29) but with delta ~0, so phase windows freeze while real time runs
## on. Measured on the old real-time clock: across a freeze the phase's window sat at a full
## untouched 0.75s while a just-made press aged out and was_buffered() flipped false — the chain
## dropped with the window open, exactly when the player was mashing hardest. The Training Room's
## 0.25x slow-mo had the same bug 4x worse: windows ran at quarter speed, the buffer at full speed.

var _actions: Array[String] = []
var _now: float = 0.0                   ## seconds of GAME time since setup (sum of scaled deltas)
var _last_press: Dictionary = {}        ## action -> _now at last just_pressed, or -1
var _held_since: Dictionary = {}        ## action -> _now when the current hold began, or -1 if up
var _consumed: Dictionary = {}          ## action -> press stamp already consumed by a branch


func setup(actions: Array[String]) -> void:
	_actions = actions.duplicate()
	_now = 0.0
	for a in _actions:
		_last_press[a] = -1.0
		_held_since[a] = -1.0
		_consumed[a] = -1.0


## Poll input for this frame. Must be called every physics frame so just_pressed is never missed.
## `delta` is the scaled physics delta: it advances this buffer's clock, so the buffer stops when
## the game stops (hitstop) and crawls when the game crawls (slow-mo), exactly like phase windows.
func tick(delta: float) -> void:
	_now += delta
	for a in _actions:
		if not InputMap.has_action(a):
			continue
		if Input.is_action_just_pressed(a):
			_last_press[a] = _now
			_held_since[a] = _now
		if not Input.is_action_pressed(a):
			_held_since[a] = -1.0


## True if `action` was pressed within the last `within` seconds of GAME time and not yet consumed.
func was_buffered(action: String, within: float) -> bool:
	var t: float = _last_press.get(action, -1.0)
	if t < 0.0:
		return false
	if t <= float(_consumed.get(action, -1.0)):
		return false   ## this press was already consumed by an earlier branch
	return (_now - t) <= maxf(0.0, within)


## Seconds of GAME time `action` has been held continuously; 0.0 if currently up.
func held_for(action: String) -> float:
	var since: float = _held_since.get(action, -1.0)
	if since < 0.0:
		return 0.0
	return _now - since


## Mark the latest press of `action` consumed so a single tap can't satisfy two branches.
func consume(action: String) -> void:
	_consumed[action] = _last_press.get(action, -1.0)
