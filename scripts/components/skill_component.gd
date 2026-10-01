class_name SkillComponent
extends Node
## Maps trigger slots → skill AbilityDefinition, tracks per-skill cooldowns, and runs the skill
## through the host's shared ChoreographyRunner (so skills reuse the same anim/hit_frame/effect
## pipeline as combos). See docs/combat_chain_architecture.md §7 and docs/fighter_kit_spec.md §4.
##
## Cooldowns are a simple per-slot timer keyed off each ability's cooldown_base (data-driven). This
## is intentionally lighter than reusing AbilityComponent's auto-attack cooldown (which is bound to
## the single weapon auto-attack) — revisit if skills ever need the full ability cooldown pipeline.

var _host = null
var _runner: ChoreographyRunner = null
var _skills: Dictionary = {}        ## slot:String -> AbilityDefinition
var _cooldowns: Dictionary = {}     ## slot:String -> seconds remaining
var _durations: Dictionary = {}     ## slot:String -> full length of the cooldown now running


func setup(host, runner: ChoreographyRunner) -> void:
	_host = host
	_runner = runner


func set_skill(slot: String, ability: AbilityDefinition) -> void:
	_skills[slot] = ability
	if not _cooldowns.has(slot):
		_cooldowns[slot] = 0.0


func clear() -> void:
	_skills.clear()
	_cooldowns.clear()
	_durations.clear()


func has_skill(slot: String) -> bool:
	return _skills.has(slot)


func is_ready(slot: String) -> bool:
	return _skills.has(slot) and float(_cooldowns.get(slot, 0.0)) <= 0.0


func cooldown_remaining(slot: String) -> float:
	return maxf(0.0, float(_cooldowns.get(slot, 0.0)))


## How much of the running cooldown is left, 1.0 → 0.0 (the HUD's veil). Measured against the
## duration this cast actually got, not cooldown_base, so cooldown reduction doesn't start the veil
## part-way down.
func cooldown_fraction(slot: String) -> float:
	var full: float = float(_durations.get(slot, 0.0))
	if full <= 0.0:
		return 0.0
	return clampf(cooldown_remaining(slot) / full, 0.0, 1.0)


func get_skill(slot: String) -> AbilityDefinition:
	return _skills.get(slot)


## Every bound slot, for callers that need to walk the whole set (ComboTimingAudit, debug UI).
func get_slots() -> Array:
	return _skills.keys()


func tick(delta: float) -> void:
	for slot in _cooldowns:
		if _cooldowns[slot] > 0.0:
			_cooldowns[slot] -= delta


## Fire the skill in `slot` if it's ready and the runner is idle. Returns true if it fired.
func trigger(slot: String) -> bool:
	if not is_ready(slot):
		return false
	if _runner == null or _runner.is_running():
		return false
	var ability: AbilityDefinition = _skills[slot]
	var full: float = ability.cooldown_base * (1.0 - _cooldown_reduction())
	_cooldowns[slot] = full
	_durations[slot] = full
	_runner.start(ability, [_host])
	## Reuses the same signal weapon fire rides (EventBus.on_ability_used) so AudioManager has one
	## seam for "an ability just went off" rather than a second bespoke path. AudioManager reads
	## the "Skill" tag to route to the category stinger instead of the weapon-fire sounds.
	EventBus.on_ability_used.emit(_host, ability)
	return true


## The host's cooldown reduction: the ("All", "cooldown_reduce") pair with the 50% cap, read exactly
## as AbilityComponent.start_cooldown reads it. Q/E ignored it until 2026-10-01, so on the player
## (whose combo graphs carry no cooldown) every source of it was dead: the class mods MANABURN,
## DARK HASTE and RELENTLESS VOW, the evolution ABSOLUTE ZERO, and the Shade's Tome of the Restless
## and Soulcage Scepter (balance sim, Spark pass).
func _cooldown_reduction() -> float:
	if _host == null or _host.get("modifier_component") == null:
		return 0.0
	return clampf(_host.modifier_component.sum_modifiers("All", "cooldown_reduce"), 0.0, 0.50)
