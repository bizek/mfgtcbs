class_name ChainFactory
extends RefCounted
## Builds melee combo-graph AbilityDefinitions (choreography of attack nodes with input-conditioned
## branches) for the ChoreographyRunner. See docs/combat_chain_architecture.md §1 and
## docs/fighter_kit_spec.md. Numbers here are PROVISIONAL — tune after playtest.
##
## A character's "melee_kit" yields three entry abilities (build_kit), each started at its own
## phase 0 by a different input:
##   light   — LMB:        Attack → Swirl → Tempest (loops); held-LMB Whirlwind; RMB → Cataclysm.
##   heavy   — RMB tap:     Uppercut → Cataclysm (1-2 heavy combo).
##   channel — RMB hold:    Taunt (loops + ticks a shockwave while held; player slow applied by host).
## Cataclysm appears as a node in BOTH light and heavy graphs so it's reachable either way.
##
## Player combo hits are AreaDamageEffects centered on the player (host fires them on [self], so
## EffectDispatcher resolves the AoE around the player and excludes the player). DisplacementEffect
## (Uppercut fling) is dispatched per-enemy by player.choreo_fire_effects.
##
## Radii below are BASE (unmodded) hit zones. They scale with the player's melee_range stat, which
## the player caps at MELEE_RANGE_MAX (2.0) — so a fully Reach-modded Fighter reaches ~2× these,
## the intended "end of the road" size. The swing-effect visual tracks the live radius automatically.

## Shared tuning (provisional)
const CANCEL_WIN: float = 0.55      ## light-chain cancel/buffer window (forgiving)
const HEAVY_WIN: float = 0.55       ## Uppercut → Cataclysm follow-up window
const WHIRL_TICK: float = 0.22      ## one Swirl rotation ≈ Whirlwind tick
const TAUNT_TICK: float = 0.56      ## Taunt anim length (9f @ 16fps) ≈ shockwave tick
const HOLD_ENTER: float = 0.18      ## hold LMB this long → enter Whirlwind
const HOLD_KEEP: float = 0.01       ## still-held check for a channel self-loop


## Dispatcher: { "light", "heavy", "channel" } abilities for a character's melee_kit.
static func build_kit(kit_id: String, weapon_data: Dictionary) -> Dictionary:
	match kit_id:
		"fighter":
			return {
				"light": build_fighter_light(weapon_data),
				"heavy": build_fighter_heavy(weapon_data),
				"channel": build_fighter_taunt(weapon_data),
			}
	return {}


## Back-compat: the light combo alone (some callers/tests use this).
static func build_combo(kit_id: String, weapon_data: Dictionary) -> AbilityDefinition:
	return build_kit(kit_id, weapon_data).get("light")


# --- Fighter: light combo (LMB) ---
## Phase indices: 0 Attack · 1 Swirl · 2 Tempest · 3 Whirlwind · 4 Cataclysm.
static func build_fighter_light(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	# 0 — Attack (crisp opener). No heavy branch here (Cataclysm gate = depth ≥ Swirl).
	var attack := ChoreographyPhase.new()
	attack.animation = "attack"
	attack.hit_frame = 1
	attack.effects = [_aoe(dtype, dmg * 0.9, 28.0)]
	attack.exit_type = "wait"
	attack.wait_duration = CANCEL_WIN
	attack.default_next = -1
	attack.branches = [
		_branch_held("light_attack", HOLD_ENTER, 3),       # hold → Whirlwind
		_branch_buffered("light_attack", 1),               # tap  → Swirl
	]

	# 1 — Swirl (gate now met → heavy branch available).
	var swirl := ChoreographyPhase.new()
	swirl.animation = "swirl"
	swirl.hit_frame = 1
	swirl.effects = [_aoe(dtype, dmg * 0.7, 30.0)]
	swirl.exit_type = "wait"
	swirl.wait_duration = CANCEL_WIN
	swirl.default_next = -1
	swirl.branches = [
		_branch_held("light_attack", HOLD_ENTER, 3),       # hold → Whirlwind
		_branch_buffered("light_attack", 2),               # tap  → Tempest
		_branch_buffered("heavy_attack", 4),               # RMB  → Cataclysm
	]

	# 2 — Tempest (light finisher; loops back to Attack on a fresh tap).
	var tempest := ChoreographyPhase.new()
	tempest.animation = "tempest"
	tempest.hit_frame = 3
	tempest.effects = [_aoe(dtype, dmg * 1.05, 40.0)]
	tempest.exit_type = "wait"
	tempest.wait_duration = CANCEL_WIN
	tempest.default_next = -1
	tempest.branches = [
		_branch_buffered("heavy_attack", 4),               # RMB → Cataclysm
		_branch_buffered("light_attack", 0),               # tap → loop to Attack
	]

	# 3 — Whirlwind (held channel; loops via default_next while held, exits on release).
	var whirl := ChoreographyPhase.new()
	whirl.animation = "swirl"
	whirl.hit_frame = 1
	whirl.effects = [_aoe(dtype, dmg * 0.30, 30.0)]
	whirl.exit_type = "wait"
	whirl.wait_duration = WHIRL_TICK
	whirl.default_next = 3
	whirl.branches = [
		_branch_held("light_attack", HOLD_KEEP, -1, true), # released → end
	]

	# 4 — Cataclysm (heavy finisher; terminal).
	var cataclysm := _cataclysm_phase(dtype, dmg)

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [attack, swirl, tempest, whirl, cataclysm]
	return _ability("fighter_light", "Fighter Combo", choreo)


# --- Fighter: heavy combo (RMB tap) ---
## Uppercut → Cataclysm. Phase indices: 0 Uppercut · 1 Cataclysm.
static func build_fighter_heavy(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	# 0 — Uppercut: AoE + arc knockback that flings nearby enemies. RMB again → Cataclysm.
	var up := ChoreographyPhase.new()
	up.animation = "uppercut"
	up.hit_frame = 1
	up.effects = [_aoe(dtype, dmg * 0.6, 35.0), _fling()]
	up.exit_type = "wait"
	up.wait_duration = HEAVY_WIN
	up.default_next = -1
	up.branches = [
		_branch_buffered("heavy_attack", 1),               # RMB → Cataclysm
	]

	# 1 — Cataclysm (shared finisher).
	var cataclysm := _cataclysm_phase(dtype, dmg)

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [up, cataclysm]
	return _ability("fighter_heavy", "Fighter Heavy", choreo)


# --- Fighter: Taunt channel (RMB hold) ---
## Loops the shield-hammer, ticking a shockwave AoE while held. Player slow + ring VFX are applied
## host-side (player.gd) while this ability runs. Single looping node.
static func build_fighter_taunt(weapon_data: Dictionary) -> AbilityDefinition:
	var dmg: float = weapon_data.get("damage", 42.0)
	var dtype: String = _damage_type(weapon_data)

	var taunt := ChoreographyPhase.new()
	taunt.animation = "taunt"
	taunt.hit_frame = 5                                     # the shield smack
	taunt.effects = [_aoe(dtype, dmg * 0.5, 46.0)]         # per-tick shockwave (lower; repeats)
	taunt.exit_type = "wait"
	taunt.wait_duration = TAUNT_TICK
	taunt.default_next = 0                                  # tick elapsed & still held → hammer again
	taunt.branches = [
		_branch_held("heavy_attack", HOLD_KEEP, -1, true), # released → end
	]

	var choreo := ChoreographyDefinition.new()
	choreo.phases = [taunt]
	return _ability("fighter_taunt", "Taunt", choreo)


# --- helpers ---

static func _cataclysm_phase(dtype: String, dmg: float) -> ChoreographyPhase:
	var c := ChoreographyPhase.new()
	c.animation = "cataclysm"
	c.hit_frame = 7
	c.effects = [_aoe(dtype, dmg * 1.8, 55.0)]
	c.exit_type = "anim_finished"
	c.default_next = -1
	return c


static func _fling() -> DisplacementEffect:
	var d := DisplacementEffect.new()
	d.displaced = "target"
	d.destination = "away_from_source"   ## knockback away from the player
	d.motion = "arc"                     ## parabolic launch reads as an uppercut
	d.duration = 0.32
	d.arc_height = 34.0
	d.distance = 88.0
	return d


static func _aoe(damage_type: String, base_damage: float, radius: float) -> AreaDamageEffect:
	var e := AreaDamageEffect.new()
	e.damage_type = damage_type
	e.base_damage = base_damage
	e.aoe_radius = radius
	return e


static func _ability(id: String, name: String, choreo: ChoreographyDefinition) -> AbilityDefinition:
	var a := AbilityDefinition.new()
	a.ability_id = id
	a.ability_name = name
	a.tags = ["Weapon", "Melee", "Combo"]
	a.mode = "Manual"
	a.choreography = choreo
	return a


static func _branch_buffered(action: String, next_phase: int) -> ChoreographyBranch:
	var c := ConditionInputBuffered.new()
	c.action = action
	c.within_window = 0.0                                   # 0 = use the phase's cancel window
	var b := ChoreographyBranch.new()
	b.condition = c
	b.next_phase = next_phase
	return b


static func _branch_held(action: String, min_duration: float, next_phase: int,
		negate: bool = false) -> ChoreographyBranch:
	var c := ConditionInputHeld.new()
	c.action = action
	c.min_duration = min_duration
	c.negate = negate
	var b := ChoreographyBranch.new()
	b.condition = c
	b.next_phase = next_phase
	return b


static func _damage_type(data: Dictionary) -> String:
	match data.get("damage_type", "physical"):
		"physical": return "Physical"
		"fire": return "Fire"
		"cryo": return "Ice"
		"shock": return "Lightning"
		"void": return "Void"
	return "Physical"
