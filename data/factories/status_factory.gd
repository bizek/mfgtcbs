class_name StatusFactory
extends RefCounted
## Builds all StatusEffectDefinitions for the game. Called once at startup.
## These are the engine-pattern equivalents of the old inline status effects.

## Cached definitions — built once, reused everywhere
static var burning: StatusEffectDefinition
static var bleed: StatusEffectDefinition
static var chilled: StatusEffectDefinition
static var frozen: StatusEffectDefinition
static var shocked: StatusEffectDefinition
static var void_touched: StatusEffectDefinition
static var shade_invisible: StatusEffectDefinition

## Trigger-based upgrade effects (passive statuses on player)
static var bloodthirst: StatusEffectDefinition
static var static_discharge: StatusEffectDefinition
static var serrated_strikes: StatusEffectDefinition
static var adrenaline_rush: StatusEffectDefinition
static var thorns_passive: StatusEffectDefinition
static var second_wind: StatusEffectDefinition

## Evolution combined statuses
static var vampiric_blade: StatusEffectDefinition
static var overdrive: StatusEffectDefinition
static var lightning_reflexes: StatusEffectDefinition

## Elite enemy modifier statuses
static var elite_hasting: StatusEffectDefinition
static var elite_exploding: StatusEffectDefinition
static var elite_shielded: StatusEffectDefinition

static var _built: bool = false


static func build_all() -> void:
	if _built:
		return
	_built = true

	burning = _build_burning()
	bleed = _build_bleed()
	chilled = _build_chilled()
	frozen = _build_frozen()
	shocked = _build_shocked()
	void_touched = _build_void_touched()
	shade_invisible = _build_shade_invisible()

	bloodthirst = _build_bloodthirst()
	static_discharge = _build_static_discharge()
	serrated_strikes = _build_serrated_strikes()
	adrenaline_rush = _build_adrenaline_rush()
	thorns_passive = _build_thorns_passive()
	second_wind = _build_second_wind()

	vampiric_blade = _build_vampiric_blade()
	overdrive = _build_overdrive()
	lightning_reflexes = _build_lightning_reflexes()

	elite_hasting = _build_elite_hasting()
	elite_exploding = _build_elite_exploding()
	elite_shielded = _build_elite_shielded()


static func get_by_id(status_id: String) -> StatusEffectDefinition:
	build_all()
	match status_id:
		"burning", "fire":
			return burning
		"bleed":
			return bleed
		"chilled", "cryo":
			return chilled
		"frozen":
			return frozen
		"shocked", "shock":
			return shocked
		"void_touched":
			return void_touched
		"shade_invisible":
			return shade_invisible
		"bloodthirst":
			return bloodthirst
		"static_discharge":
			return static_discharge
		"serrated_strikes":
			return serrated_strikes
		"adrenaline_rush":
			return adrenaline_rush
		"thorns_passive":
			return thorns_passive
		"second_wind":
			return second_wind
		"vampiric_blade":
			return vampiric_blade
		"overdrive":
			return overdrive
		"lightning_reflexes":
			return lightning_reflexes
		"elite_hasting":
			return elite_hasting
		"elite_exploding":
			return elite_exploding
		"elite_shielded":
			return elite_shielded
	return null


static func _build_burning() -> StatusEffectDefinition:
	## 3 damage/sec for 3 seconds. Refreshes duration on reapply.
	var def := StatusEffectDefinition.new()
	def.status_id = "burning"
	def.tags = ["Fire", "DoT"]
	def.is_positive = false
	def.max_stacks = 1
	def.base_duration = 3.0
	def.duration_refresh_mode = "overwrite"
	def.tick_interval = 1.0

	var tick_dmg := DealDamageEffect.new()
	tick_dmg.damage_type = "Fire"
	tick_dmg.base_damage = 3.0
	def.tick_effects = [tick_dmg]

	return def


static func _build_bleed() -> StatusEffectDefinition:
	## 2 damage/sec for 4 seconds. Refreshes duration on reapply.
	var def := StatusEffectDefinition.new()
	def.status_id = "bleed"
	def.tags = ["Physical", "DoT"]
	def.is_positive = false
	def.max_stacks = 1
	def.base_duration = 4.0
	def.duration_refresh_mode = "overwrite"
	def.tick_interval = 1.0

	var tick_dmg := DealDamageEffect.new()
	tick_dmg.damage_type = "Physical"
	tick_dmg.base_damage = 2.0
	def.tick_effects = [tick_dmg]

	return def


static func _build_chilled() -> StatusEffectDefinition:
	## -30% move speed for 3 seconds. Stacks toward Frozen at 3 stacks.
	## COMBO: If Burning is applied while Chilled → Frostfire (consume both + Fire AoE)
	var def := StatusEffectDefinition.new()
	def.status_id = "chilled"
	def.tags = ["Ice", "CC"]
	def.is_positive = false
	def.max_stacks = 3
	def.base_duration = 3.0
	def.duration_refresh_mode = "overwrite"

	var slow_mod := ModifierDefinition.new()
	slow_mod.target_tag = "move_speed"
	slow_mod.operation = "bonus"
	slow_mod.value = -0.30
	slow_mod.source_name = "chilled"
	def.modifiers = [slow_mod]

	## Frostfire combo: Burning applied to Chilled target → consume chilled + 12 Fire AoE
	var frostfire_dmg := AreaDamageEffect.new()
	frostfire_dmg.damage_type = "Fire"
	frostfire_dmg.base_damage = 12.0
	frostfire_dmg.aoe_radius = 45.0

	var frostfire_consume := ConsumeStacksEffect.new()
	frostfire_consume.status_id = "chilled"
	frostfire_consume.stacks_to_consume = -1

	var fire_condition := TriggerConditionStatusId.new()
	fire_condition.status_id = "burning"

	var target_is_self := TriggerConditionTargetIsSelf.new()

	var frostfire_listener := TriggerListenerDefinition.new()
	frostfire_listener.event = "on_status_applied"
	frostfire_listener.target_self = true
	frostfire_listener.conditions = [fire_condition, target_is_self]
	frostfire_listener.effects = [frostfire_dmg, frostfire_consume]
	def.trigger_listeners = [frostfire_listener]

	return def


static func _build_frozen() -> StatusEffectDefinition:
	## Stun for 1.5 seconds. Cannot move or act.
	## COMBO: If Burning is applied while Frozen → Shatter (consume Frozen + Ice AoE)
	var def := StatusEffectDefinition.new()
	def.status_id = "frozen"
	def.tags = ["Ice", "CC", "Stun"]
	def.is_positive = false
	def.max_stacks = 1
	def.base_duration = 1.5
	def.disables_actions = true
	def.disables_movement = true

	## Shatter combo: Fire applied to Frozen target → consume Frozen + 20 Ice AoE
	var shatter_dmg := AreaDamageEffect.new()
	shatter_dmg.damage_type = "Ice"
	shatter_dmg.base_damage = 20.0
	shatter_dmg.aoe_radius = 50.0

	var shatter_consume := ConsumeStacksEffect.new()
	shatter_consume.status_id = "frozen"
	shatter_consume.stacks_to_consume = -1  ## Consume all stacks

	var fire_condition := TriggerConditionStatusId.new()
	fire_condition.status_id = "burning"

	var target_is_self := TriggerConditionTargetIsSelf.new()

	var shatter_listener := TriggerListenerDefinition.new()
	shatter_listener.event = "on_status_applied"
	shatter_listener.target_self = true  ## AoE centered on self (the frozen entity)
	shatter_listener.conditions = [fire_condition, target_is_self]
	shatter_listener.effects = [shatter_dmg, shatter_consume]
	def.trigger_listeners = [shatter_listener]

	return def


static func _build_shocked() -> StatusEffectDefinition:
	## COMBO: When a Shocked entity is hit → consume shocked + chain 10 Lightning AoE.
	var def := StatusEffectDefinition.new()
	def.status_id = "shocked"
	def.tags = ["Lightning"]
	def.is_positive = false
	def.max_stacks = 1
	def.base_duration = 5.0

	## Conductor combo: hit received while Shocked → consume + Lightning AoE chain
	var chain_dmg := AreaDamageEffect.new()
	chain_dmg.damage_type = "Lightning"
	chain_dmg.base_damage = 10.0
	chain_dmg.aoe_radius = 80.0

	var chain_consume := ConsumeStacksEffect.new()
	chain_consume.status_id = "shocked"
	chain_consume.stacks_to_consume = -1

	var target_is_self := TriggerConditionTargetIsSelf.new()

	var conductor_listener := TriggerListenerDefinition.new()
	conductor_listener.event = "on_hit_received"
	conductor_listener.target_self = true  ## AoE centered on shocked entity
	conductor_listener.conditions = [target_is_self]
	conductor_listener.effects = [chain_dmg, chain_consume]
	def.trigger_listeners = [conductor_listener]

	return def


static func _build_void_touched() -> StatusEffectDefinition:
	## Permanent debuff. On death: AOE explosion damaging nearby enemies + instability bleed.
	## Death explosion is handled by the entity's death callback since it needs
	## game-specific logic (instability system). This status marks the entity.
	var def := StatusEffectDefinition.new()
	def.status_id = "void_touched"
	def.tags = ["Void"]
	def.is_positive = false
	def.max_stacks = 1
	def.base_duration = -1.0  ## Permanent

	return def


static func _build_shade_invisible() -> StatusEffectDefinition:
	## Brief invisibility on dodge. 0.5 seconds.
	var def := StatusEffectDefinition.new()
	def.status_id = "shade_invisible"
	def.tags = ["Stealth"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = 0.5

	return def


# ── Trigger-based upgrade effects ──────────────────────────────────────────

static func _build_bloodthirst() -> StatusEffectDefinition:
	## On kill: heal 5% max HP. Passive status applied permanently to player.
	var def := StatusEffectDefinition.new()
	def.status_id = "bloodthirst"
	def.tags = ["Passive", "Heal"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0  ## Permanent

	var heal := HealEffect.new()
	heal.percent_max_hp = 0.05

	var listener := TriggerListenerDefinition.new()
	listener.event = "on_kill"
	listener.target_self = true
	listener.conditions = [TriggerConditionSourceIsSelf.new()]
	listener.effects = [heal]
	def.trigger_listeners = [listener]

	return def


static func _build_static_discharge() -> StatusEffectDefinition:
	## On crit: deal 15 Lightning AOE damage around the target.
	var def := StatusEffectDefinition.new()
	def.status_id = "static_discharge"
	def.tags = ["Passive", "Lightning"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0  ## Permanent

	var aoe := AreaDamageEffect.new()
	aoe.damage_type = "Lightning"
	aoe.base_damage = 15.0
	aoe.aoe_radius = 60.0

	var listener := TriggerListenerDefinition.new()
	listener.event = "on_crit"
	listener.target_self = false  ## Targets the crit victim (AOE centered on them)
	listener.conditions = [TriggerConditionSourceIsSelf.new()]
	listener.effects = [aoe]
	def.trigger_listeners = [listener]

	return def


static func _build_serrated_strikes() -> StatusEffectDefinition:
	## On hit dealt: 20% chance to apply Bleed. Implemented as permanent passive.
	## (No probabilistic condition exists yet, so this applies bleed on every hit.
	##  Balanced by bleed's duration-refresh behavior — effectively a sustained DoT.)
	var def := StatusEffectDefinition.new()
	def.status_id = "serrated_strikes"
	def.tags = ["Passive", "Physical"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0  ## Permanent

	var apply_bleed := ApplyStatusEffectData.new()
	apply_bleed.status = _build_bleed()
	apply_bleed.stacks = 1

	var listener := TriggerListenerDefinition.new()
	listener.event = "on_hit_dealt"
	listener.target_self = false  ## Apply bleed to the target we hit
	listener.conditions = [TriggerConditionSourceIsSelf.new()]
	listener.effects = [apply_bleed]
	def.trigger_listeners = [listener]

	return def


static func _build_adrenaline_rush() -> StatusEffectDefinition:
	## On kill: gain +25% move speed for 3 seconds. Permanent passive.
	var def := StatusEffectDefinition.new()
	def.status_id = "adrenaline_rush"
	def.tags = ["Passive", "Speed"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0  ## Permanent

	## The buff that gets applied on kill
	var speed_buff := StatusEffectDefinition.new()
	speed_buff.status_id = "adrenaline_burst"
	speed_buff.is_positive = true
	speed_buff.max_stacks = 1
	speed_buff.base_duration = 3.0
	speed_buff.duration_refresh_mode = "overwrite"
	var spd_mod := ModifierDefinition.new()
	spd_mod.target_tag = "move_speed"
	spd_mod.operation = "bonus"
	spd_mod.value = 0.25
	spd_mod.source_name = "adrenaline_burst"
	speed_buff.modifiers = [spd_mod]

	var apply_buff := ApplyStatusEffectData.new()
	apply_buff.status = speed_buff
	apply_buff.stacks = 1
	apply_buff.apply_to_self = true

	var listener := TriggerListenerDefinition.new()
	listener.event = "on_kill"
	listener.target_self = true
	listener.conditions = [TriggerConditionSourceIsSelf.new()]
	listener.effects = [apply_buff]
	def.trigger_listeners = [listener]

	return def


static func _build_thorns_passive() -> StatusEffectDefinition:
	## On hit received: deal 8 Physical damage back to attacker. Permanent passive.
	var def := StatusEffectDefinition.new()
	def.status_id = "thorns_passive"
	def.tags = ["Passive", "Physical"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0  ## Permanent

	var reflect_dmg := DealDamageEffect.new()
	reflect_dmg.damage_type = "Physical"
	reflect_dmg.base_damage = 8.0

	var listener := TriggerListenerDefinition.new()
	listener.event = "on_hit_received"
	listener.target_event_source = true  ## Deal damage back to the attacker
	listener.conditions = [TriggerConditionTargetIsSelf.new()]  ## Only when I'm the one hit
	listener.effects = [reflect_dmg]
	def.trigger_listeners = [listener]

	return def


static func _build_second_wind() -> StatusEffectDefinition:
	## On dodge: heal 3% max HP. Permanent passive.
	var def := StatusEffectDefinition.new()
	def.status_id = "second_wind"
	def.tags = ["Passive", "Heal"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0  ## Permanent

	var heal := HealEffect.new()
	heal.percent_max_hp = 0.03

	var listener := TriggerListenerDefinition.new()
	listener.event = "on_dodge"
	listener.target_self = true  ## Heal myself
	listener.conditions = [TriggerConditionTargetIsSelf.new()]  ## Only when I dodged
	listener.effects = [heal]
	def.trigger_listeners = [listener]

	return def


# ── Evolution combined statuses ────────────────────────────────────────────

static func _build_vampiric_blade() -> StatusEffectDefinition:
	## Combines Bloodthirst + Serrated Strikes: on-hit bleed + on-kill heal 8% max HP.
	var def := StatusEffectDefinition.new()
	def.status_id = "vampiric_blade"
	def.tags = ["Passive", "Physical", "Heal"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0

	var apply_bleed := ApplyStatusEffectData.new()
	apply_bleed.status = _build_bleed()
	apply_bleed.stacks = 1
	var bleed_listener := TriggerListenerDefinition.new()
	bleed_listener.event = "on_hit_dealt"
	bleed_listener.target_self = false
	bleed_listener.conditions = [TriggerConditionSourceIsSelf.new()]
	bleed_listener.effects = [apply_bleed]

	var heal := HealEffect.new()
	heal.percent_max_hp = 0.08  ## Upgraded from 5%
	var heal_listener := TriggerListenerDefinition.new()
	heal_listener.event = "on_kill"
	heal_listener.target_self = true
	heal_listener.conditions = [TriggerConditionSourceIsSelf.new()]
	heal_listener.effects = [heal]

	def.trigger_listeners = [bleed_listener, heal_listener]
	return def


static func _build_overdrive() -> StatusEffectDefinition:
	## Combines Adrenaline Rush + move speed: on-kill +40% speed for 4s (upgraded).
	var def := StatusEffectDefinition.new()
	def.status_id = "overdrive"
	def.tags = ["Passive", "Speed"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0

	var speed_buff := StatusEffectDefinition.new()
	speed_buff.status_id = "overdrive_burst"
	speed_buff.is_positive = true
	speed_buff.max_stacks = 1
	speed_buff.base_duration = 4.0  ## Upgraded from 3s
	speed_buff.duration_refresh_mode = "overwrite"
	var spd_mod := ModifierDefinition.new()
	spd_mod.target_tag = "move_speed"
	spd_mod.operation = "bonus"
	spd_mod.value = 0.40  ## Upgraded from 25%
	spd_mod.source_name = "overdrive_burst"
	speed_buff.modifiers = [spd_mod]

	var apply_buff := ApplyStatusEffectData.new()
	apply_buff.status = speed_buff
	apply_buff.stacks = 1
	apply_buff.apply_to_self = true
	var listener := TriggerListenerDefinition.new()
	listener.event = "on_kill"
	listener.target_self = true
	listener.conditions = [TriggerConditionSourceIsSelf.new()]
	listener.effects = [apply_buff]

	def.trigger_listeners = [listener]
	return def


static func _build_lightning_reflexes() -> StatusEffectDefinition:
	## Combines Static Discharge + Second Wind: on-crit 20 Lightning AoE + on-dodge heal 5%.
	var def := StatusEffectDefinition.new()
	def.status_id = "lightning_reflexes"
	def.tags = ["Passive", "Lightning", "Heal"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0

	var aoe := AreaDamageEffect.new()
	aoe.damage_type = "Lightning"
	aoe.base_damage = 20.0  ## Upgraded from 15
	aoe.aoe_radius = 70.0  ## Upgraded from 60
	var crit_listener := TriggerListenerDefinition.new()
	crit_listener.event = "on_crit"
	crit_listener.target_self = false
	crit_listener.conditions = [TriggerConditionSourceIsSelf.new()]
	crit_listener.effects = [aoe]

	var heal := HealEffect.new()
	heal.percent_max_hp = 0.05  ## Upgraded from 3%
	var dodge_listener := TriggerListenerDefinition.new()
	dodge_listener.event = "on_dodge"
	dodge_listener.target_self = true
	dodge_listener.conditions = [TriggerConditionTargetIsSelf.new()]
	dodge_listener.effects = [heal]

	def.trigger_listeners = [crit_listener, dodge_listener]
	return def


# ── Elite modifier statuses ───────────────────────────────────────────────

static func _build_elite_hasting() -> StatusEffectDefinition:
	## Elite: +100% move speed. Applied permanently while elite is alive.
	var def := StatusEffectDefinition.new()
	def.status_id = "elite_hasting"
	def.tags = ["Elite"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0

	var spd_mod := ModifierDefinition.new()
	spd_mod.target_tag = "move_speed"
	spd_mod.operation = "bonus"
	spd_mod.value = 1.0
	spd_mod.source_name = "elite_hasting"
	def.modifiers = [spd_mod]

	return def


static func _build_elite_exploding() -> StatusEffectDefinition:
	## Elite: on death, 60px AoE 15 Fire damage. Marker status — death logic
	## checks has_status("elite_exploding") since triggers clean up before death.
	var def := StatusEffectDefinition.new()
	def.status_id = "elite_exploding"
	def.tags = ["Elite", "Fire"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0

	return def


static func _build_elite_shielded() -> StatusEffectDefinition:
	## Elite: marker status. Shield is applied manually in enemy.gd because
	## ApplyShieldEffect scales from modifier sums, not raw max_hp.
	var def := StatusEffectDefinition.new()
	def.status_id = "elite_shielded"
	def.tags = ["Elite"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0

	return def
