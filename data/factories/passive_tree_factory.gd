class_name PassiveTreeFactory
extends RefCounted
## Builds StatusEffectDefinitions for passive tree behavior nodes.
## Called by player.gd._apply_passive_tree() for each allocated behavior node.
## Pattern mirrors StatusFactory: static cached definitions, built once on first access.
##
## Keystones (slipstream, berserkers_cadence) do NOT return a status — player.gd
## sets a flag and applies the buff directly in the dash / finisher-hit path.

## Trigger-based passive statuses (permanent hidden statuses on the player)
static var bloodletter: StatusEffectDefinition
static var second_wind_passive: StatusEffectDefinition
static var opportunist: StatusEffectDefinition
static var ignition: StatusEffectDefinition
static var volatile_souls: StatusEffectDefinition

## Keystone buff statuses (applied on demand by player.gd, not as hidden passives)
static var slipstream_status: StatusEffectDefinition
static var frenzy_status: StatusEffectDefinition

static var _built: bool = false


static func build_all() -> void:
	if _built:
		return
	_built = true
	StatusFactory.build_all()

	bloodletter = _build_bloodletter()
	second_wind_passive = _build_second_wind_passive()
	opportunist = _build_opportunist()
	ignition = _build_ignition()
	volatile_souls = _build_volatile_souls()
	slipstream_status = _build_slipstream_status()
	frenzy_status = _build_frenzy_status()


## Returns the hidden permanent StatusEffectDefinition for a given behavior id,
## or null for keystone ids (handled via flags in player.gd).
static func build(behavior_id: String) -> StatusEffectDefinition:
	build_all()
	match behavior_id:
		"bloodletter":
			return bloodletter
		"second_wind":
			return second_wind_passive
		"opportunist":
			return opportunist
		"ignition":
			return ignition
		"volatile_souls":
			return volatile_souls
		"slipstream", "berserkers_cadence":
			return null  ## flag-gated; player.gd handles these directly
	return null


# ── Behavior node passives ─────────────────────────────────────────────────

static func _build_bloodletter() -> StatusEffectDefinition:
	## m_bloodletter: on kill, 10% chance, heal 2 HP flat.
	var def := StatusEffectDefinition.new()
	def.status_id = "passive_bloodletter"
	def.tags = ["Passive", "Heal"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0

	var heal := HealEffect.new()
	heal.base_healing = 2.0

	var listener := TriggerListenerDefinition.new()
	listener.event = "on_kill"
	listener.target_self = true
	listener.chance = 0.1
	listener.conditions = [TriggerConditionSourceIsSelf.new()]
	listener.effects = [heal]
	def.trigger_listeners = [listener]

	return def


static func _build_second_wind_passive() -> StatusEffectDefinition:
	## m_second_wind: on hit received while below 30% HP, apply +25% move_speed for 2s.
	## Internal cooldown 8s prevents spam (stored on the listener itself).
	var def := StatusEffectDefinition.new()
	def.status_id = "passive_second_wind"
	def.tags = ["Passive", "Speed"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0

	## The temporary buff status applied on trigger
	var burst := StatusEffectDefinition.new()
	burst.status_id = "tree_second_wind_burst"
	burst.is_positive = true
	burst.max_stacks = 1
	burst.base_duration = 2.0
	burst.duration_refresh_mode = "overwrite"
	var spd := ModifierDefinition.new()
	spd.target_tag = "move_speed"
	spd.operation = "bonus"
	spd.value = 0.25
	spd.source_name = "tree_second_wind_burst"
	burst.modifiers = [spd]

	var apply_burst := ApplyStatusEffectData.new()
	apply_burst.status = burst
	apply_burst.stacks = 1

	var below_30 := TriggerConditionHpThreshold.new()
	below_30.threshold = 0.30
	below_30.direction = "below"

	var is_target := TriggerConditionTargetIsSelf.new()

	var listener := TriggerListenerDefinition.new()
	listener.event = "on_hit_received"
	listener.target_self = true
	listener.internal_cooldown = 8.0
	listener.conditions = [is_target, below_30]
	listener.effects = [apply_burst]
	def.trigger_listeners = [listener]

	return def


static func _build_opportunist() -> StatusEffectDefinition:
	## f_opportunist: on dodge, apply +20% damage for 2s.
	var def := StatusEffectDefinition.new()
	def.status_id = "passive_opportunist"
	def.tags = ["Passive", "Damage"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0

	var burst := StatusEffectDefinition.new()
	burst.status_id = "opportunist_burst"
	burst.is_positive = true
	burst.max_stacks = 1
	burst.base_duration = 2.0
	burst.duration_refresh_mode = "overwrite"
	var dmg := ModifierDefinition.new()
	dmg.target_tag = "All"
	dmg.operation = "bonus"
	dmg.value = 0.20
	dmg.source_name = "opportunist_burst"
	burst.modifiers = [dmg]

	var apply_burst := ApplyStatusEffectData.new()
	apply_burst.status = burst
	apply_burst.stacks = 1

	var is_target := TriggerConditionTargetIsSelf.new()

	var listener := TriggerListenerDefinition.new()
	listener.event = "on_dodge"
	listener.target_self = true
	listener.conditions = [is_target]
	listener.effects = [apply_burst]
	def.trigger_listeners = [listener]

	return def


static func _build_ignition() -> StatusEffectDefinition:
	## a_ignition: on crit, apply Burning to the target. Reuses StatusFactory.burning.
	var def := StatusEffectDefinition.new()
	def.status_id = "passive_ignition"
	def.tags = ["Passive", "Fire"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0

	var apply_burn := ApplyStatusEffectData.new()
	apply_burn.status = StatusFactory.burning
	apply_burn.stacks = 1

	var listener := TriggerListenerDefinition.new()
	listener.event = "on_crit"
	listener.target_self = false  ## apply burn to the crit victim
	listener.conditions = [TriggerConditionSourceIsSelf.new()]
	listener.effects = [apply_burn]
	def.trigger_listeners = [listener]

	return def


static func _build_volatile_souls() -> StatusEffectDefinition:
	## a_keystone Volatile Souls: on kill, victim had any status, 25% chance, AoE explosion
	## (~40% weapon damage approximated as base 8 Physical, scaled by player's damage mods).
	var def := StatusEffectDefinition.new()
	def.status_id = "passive_volatile_souls"
	def.tags = ["Passive", "Physical"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0

	var aoe := AreaDamageEffect.new()
	aoe.damage_type = "Physical"
	aoe.base_damage = 8.0   ## ~40% of a typical ~20 base weapon damage
	aoe.aoe_radius = 60.0

	var has_any_status := TriggerConditionTargetHasAnyStatus.new()

	var listener := TriggerListenerDefinition.new()
	listener.event = "on_kill"
	listener.target_self = false  ## target = victim; AoE centers on their position
	listener.chance = 0.25
	listener.conditions = [TriggerConditionSourceIsSelf.new(), has_any_status]
	listener.effects = [aoe]
	def.trigger_listeners = [listener]

	return def


# ── Keystone buff statuses (applied on demand) ─────────────────────────────

static func _build_slipstream_status() -> StatusEffectDefinition:
	## f_keystone Slipstream buff: +30% attack_speed, +15% damage for 2.5s.
	## Applied by player.gd._try_dash() when the keystone is allocated.
	var def := StatusEffectDefinition.new()
	def.status_id = "slipstream"
	def.tags = ["Buff", "Speed"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = 2.5
	def.duration_refresh_mode = "overwrite"

	var as_mod := ModifierDefinition.new()
	as_mod.target_tag = "attack_speed"
	as_mod.operation = "bonus"
	as_mod.value = 0.30
	as_mod.source_name = "slipstream"

	var dmg_mod := ModifierDefinition.new()
	dmg_mod.target_tag = "All"
	dmg_mod.operation = "bonus"
	dmg_mod.value = 0.15
	dmg_mod.source_name = "slipstream"

	def.modifiers = [as_mod, dmg_mod]
	return def


static func _build_frenzy_status() -> StatusEffectDefinition:
	## m_keystone Berserker's Cadence Frenzy buff: +25% attack_speed, +15% move_speed for 3s.
	## Applied by player.gd.choreo_on_finisher_hit() when the keystone is allocated.
	var def := StatusEffectDefinition.new()
	def.status_id = "frenzy"
	def.tags = ["Buff", "Speed"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = 3.0
	def.duration_refresh_mode = "overwrite"

	var as_mod := ModifierDefinition.new()
	as_mod.target_tag = "attack_speed"
	as_mod.operation = "bonus"
	as_mod.value = 0.25
	as_mod.source_name = "frenzy"

	var ms_mod := ModifierDefinition.new()
	ms_mod.target_tag = "move_speed"
	ms_mod.operation = "bonus"
	ms_mod.value = 0.15
	ms_mod.source_name = "frenzy"

	def.modifiers = [as_mod, ms_mod]
	return def
