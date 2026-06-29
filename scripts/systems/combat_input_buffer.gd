class_name CombatInputBuffer
extends RefCounted
## Tracks recent presses (for buffered-tap queries) and continuous hold durations for a set of
## combat actions. Polled each physics frame by the player (tick()); read by the input-condition
## evaluators (ConditionInputBuffered / ConditionInputHeld). Pure input state — no FSM, no anim,
## no damage. See docs/combat_chain_architecture.md §6.

var _actions: Array[String] = []
var _last_press_ms: Dictionary = {}     ## action -> Time.get_ticks_msec() of last just_pressed
var _held_since_ms: Dictionary = {}     ## action -> msec when current hold began, or -1 if up
var _consumed_ms: Dictionary = {}       ## action -> press timestamp already consumed by a branch


func setup(actions: Array[String]) -> void:
	_actions = actions.duplicate()
	for a in _actions:
		_last_press_ms[a] = -1.0
		_held_since_ms[a] = -1.0
		_consumed_ms[a] = -1.0


## Poll input for this frame. Must be called every physics frame so just_pressed is never missed.
func tick() -> void:
	var now: float = float(Time.get_ticks_msec())
	for a in _actions:
		if not InputMap.has_action(a):
			continue
		if Input.is_action_just_pressed(a):
			_last_press_ms[a] = now
			_held_since_ms[a] = now
		if not Input.is_action_pressed(a):
			_held_since_ms[a] = -1.0


## True if `action` was pressed within the last `within` seconds and not yet consumed.
func was_buffered(action: String, within: float) -> bool:
	var t: float = _last_press_ms.get(action, -1.0)
	if t < 0.0:
		return false
	if t <= float(_consumed_ms.get(action, -1.0)):
		return false   ## this press was already consumed by an earlier branch
	var now: float = float(Time.get_ticks_msec())
	return (now - t) <= maxf(0.0, within) * 1000.0


## Seconds `action` has been held continuously; 0.0 if currently up.
func held_for(action: String) -> float:
	var since: float = _held_since_ms.get(action, -1.0)
	if since < 0.0:
		return 0.0
	return (float(Time.get_ticks_msec()) - since) / 1000.0


## Mark the latest press of `action` consumed so a single tap can't satisfy two branches.
func consume(action: String) -> void:
	_consumed_ms[action] = _last_press_ms.get(action, -1.0)
