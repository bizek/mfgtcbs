class_name StatusFactory
extends RefCounted
## Builds all StatusEffectDefinitions for the game. Called once at startup.
## These are the engine-pattern equivalents of the old inline status effects.


## Attach the looping elemental aura overlay that plays while this status is on an entity.
## VfxManager spawns/despawns it off on_status_applied / on_status_expired / on_cleanse — no
## per-status wiring beyond this call. Silently no-ops when the sheet is unavailable, so a
## missing asset degrades to "no overlay", never to a broken status.
##
## Pilot scope (2026-07-21 doc audit): burning / chilled / frozen only. Statuses previously had
## no visual at all. Extend to the other elements once Ben has eyeballed these three.
static func _attach_aura(def: StatusEffectDefinition, element: String,
		scale: Vector2 = Vector2.ONE, tint: Color = Color.WHITE) -> void:
	var layer: VfxLayerConfig = StatusVfxFactory.build_aura_layer(
			element, 1, Vector2.ZERO, scale, tint)
	if layer != null:
		def.vfx_layers = [layer]


## Cached definitions — built once, reused everywhere
static var burning: StatusEffectDefinition
static var bleed: StatusEffectDefinition
static var chilled: StatusEffectDefinition
static var frozen: StatusEffectDefinition
static var shocked: StatusEffectDefinition
static var void_touched: StatusEffectDefinition
static var abyssal_slow: StatusEffectDefinition  ## The Deep's Pull: void wake slow
static var stunned: StatusEffectDefinition       ## plain hard CC — the Ravager's Pile Driver

## Trigger-based upgrade effects (passive statuses on player)
static var bloodthirst: StatusEffectDefinition
static var static_discharge: StatusEffectDefinition
static var serrated_strikes: StatusEffectDefinition
static var adrenaline_rush: StatusEffectDefinition
static var thorns_passive: StatusEffectDefinition
static var second_wind: StatusEffectDefinition

## Crowd-answer upgrades (2026-08-03). The level-up pool had sixteen stat sticks and no answer to
## the thing that actually kills you: enemies spawn on a 340px ring around the player
## (EnemySpawnManager) against a 320px screen half-width, so they arrive just off-screen and
## converge from every side. +20% damage does nothing about a ring. These four do — each one is
## worth more the more enemies are on you, and near-worthless against a single target.
static var cinder_skin: StatusEffectDefinition
static var glacial_guard: StatusEffectDefinition
static var volatile_remains: StatusEffectDefinition
static var last_stand: StatusEffectDefinition

## Combo-reactive class passives (2026-08-24). The first content to use the three combo events
## (on_finisher_hit / on_combo_step / on_combo_dropped) that TriggerComponent learned to hear.
## These are the Fighter pilot for the level-up-layer seam: a class mod is picked in the hub and
## says what the kit IS, so it owns the numbers; these are picked mid-run and react to how the
## chain is actually being played, which no loadout screen can express.
static var fighter_thunderclap: StatusEffectDefinition
static var fighter_battle_rhythm: StatusEffectDefinition
static var fighter_last_word: StatusEffectDefinition
static var fighter_spite: StatusEffectDefinition

## Evolution combined statuses
static var vampiric_blade: StatusEffectDefinition
static var overdrive: StatusEffectDefinition
static var lightning_reflexes: StatusEffectDefinition
static var pyre: StatusEffectDefinition
static var bulwark: StatusEffectDefinition

## Mod interaction combo statuses
## Hellfire (Burning + Shocked): 15 hybrid AoE, consumes both
## Superconductor (Chilled + Shocked): 18 cold AoE, consumes Chilled
## Searing Wound (Burning + Bleed): double bleed tick rate amplifier
## Hemorrhage (Frozen expiry + Bleed): burst damage on Frozen expiry
## Galvanized Shocked (Shocked + DOT Applicator): Conductor also spreads Bleed
static var searing_wound: StatusEffectDefinition
static var galvanized_shocked: StatusEffectDefinition
static var burning_extended: StatusEffectDefinition  ## Comet: 4.5s Burning for Gravity + Fire

## Elite enemy modifier statuses
static var elite_hasting: StatusEffectDefinition
static var elite_exploding: StatusEffectDefinition
static var elite_shielded: StatusEffectDefinition
static var elite_reflecting: StatusEffectDefinition
static var elite_regenerating: StatusEffectDefinition
static var elite_armored: StatusEffectDefinition
static var elite_vampiric: StatusEffectDefinition

## Ranger quiver stance markers (the Scavenger's E, 2026-07-31). Permanent — base_duration 0 means
## time_remaining stays 0, which StatusEffectComponent already treats as indefinite, so the chip
## sits in the buff bar for exactly as long as the head is loaded and never drains. They carry NO
## modifiers: the stance's whole effect is the head injected into arrows (player._apply_quiver);
## these exist so the state is legible — a buff chip plus the pack's own fire/ice aura on the body.
static var quiver_fire: StatusEffectDefinition
static var quiver_frost: StatusEffectDefinition

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
	abyssal_slow = _build_abyssal_slow()
	stunned = _build_stunned()

	bloodthirst = _build_bloodthirst()
	static_discharge = _build_static_discharge()
	serrated_strikes = _build_serrated_strikes()
	adrenaline_rush = _build_adrenaline_rush()
	thorns_passive = _build_thorns_passive()
	second_wind = _build_second_wind()

	## Must follow chilled — glacial_guard embeds it as the nova's on-hit payload.
	cinder_skin = _build_cinder_skin()
	glacial_guard = _build_glacial_guard()
	volatile_remains = _build_volatile_remains()
	last_stand = _build_last_stand()

	fighter_thunderclap = _build_fighter_thunderclap()
	fighter_battle_rhythm = _build_fighter_battle_rhythm()
	fighter_last_word = _build_fighter_last_word()
	fighter_spite = _build_fighter_spite()

	vampiric_blade = _build_vampiric_blade()
	overdrive = _build_overdrive()
	lightning_reflexes = _build_lightning_reflexes()
	pyre = _build_pyre()
	bulwark = _build_bulwark()

	searing_wound = _build_searing_wound()
	galvanized_shocked = _build_galvanized_shocked()
	burning_extended = _build_burning_extended()

	quiver_fire = _build_quiver_stance("quiver_fire", "fire", Color(1.0, 0.75, 0.5, 0.85))
	quiver_frost = _build_quiver_stance("quiver_frost", "ice", Color(0.75, 0.95, 1.0, 0.85))

	## Wire new elemental combos onto existing statuses (must run after all statuses built)
	_wire_hellfire_combo()
	_wire_superconductor_combo()
	_wire_searing_wound_combo()

	elite_hasting = _build_elite_hasting()
	elite_exploding = _build_elite_exploding()
	elite_shielded = _build_elite_shielded()
	elite_reflecting = _build_elite_reflecting()
	elite_regenerating = _build_elite_regenerating()
	elite_armored = _build_elite_armored()
	elite_vampiric = _build_elite_vampiric()


## A Ranger quiver stance marker. Zero modifiers, zero duration — a legibility layer over a
## player-side stance var. `aura_element` is a StatusVfxFactory key ("fire" / "ice"); the aura is
## scaled down because this rides the PLAYER permanently and a full-size elemental cloud would
## bury a 32px sprite for the whole run.
static func _build_quiver_stance(id: String, aura_element: String,
		tint: Color) -> StatusEffectDefinition:
	var def := StatusEffectDefinition.new()
	def.status_id = id
	def.tags = ["Stance"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = 0.0            ## indefinite — cleared by the next E press, not by a timer
	def.duration_refresh_mode = "overwrite"
	_attach_aura(def, aura_element, Vector2(0.6, 0.6), tint)
	return def


static func get_by_id(status_id: String) -> StatusEffectDefinition:
	build_all()
	match status_id:
		"quiver_fire":
			return quiver_fire
		"quiver_frost":
			return quiver_frost
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
		"abyssal_slow":
			return abyssal_slow
		"stunned", "stun":
			return stunned
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
		"cinder_skin":
			return cinder_skin
		"glacial_guard":
			return glacial_guard
		"volatile_remains":
			return volatile_remains
		"last_stand":
			return last_stand
		"fighter_thunderclap":
			return fighter_thunderclap
		"fighter_battle_rhythm":
			return fighter_battle_rhythm
		"fighter_last_word":
			return fighter_last_word
		"fighter_spite":
			return fighter_spite
		"vampiric_blade":
			return vampiric_blade
		"overdrive":
			return overdrive
		"lightning_reflexes":
			return lightning_reflexes
		"pyre":
			return pyre
		"bulwark":
			return bulwark
		"elite_hasting":
			return elite_hasting
		"elite_exploding":
			return elite_exploding
		"elite_shielded":
			return elite_shielded
		"elite_reflecting":
			return elite_reflecting
		"elite_regenerating":
			return elite_regenerating
		"elite_armored":
			return elite_armored
		"elite_vampiric":
			return elite_vampiric
		"searing_wound":
			return searing_wound
		"galvanized_shocked":
			return galvanized_shocked
		"burning_extended":
			return burning_extended
	return null


static func _build_burning() -> StatusEffectDefinition:
	## 4 damage/sec for 6 seconds = 24 total. Refreshes duration on reapply.
	var def := StatusEffectDefinition.new()
	def.status_id = "burning"
	def.tags = ["Fire", "DoT"]
	def.is_positive = false
	def.max_stacks = 1
	def.base_duration = 6.0
	def.duration_refresh_mode = "overwrite"
	def.tick_interval = 1.0

	var tick_dmg := DealDamageEffect.new()
	tick_dmg.damage_type = "Fire"
	tick_dmg.base_damage = 4.0
	def.tick_effects = [tick_dmg]

	_attach_aura(def, "fire")
	return def


static func _build_bleed() -> StatusEffectDefinition:
	## 4 damage/sec for 6 seconds = 24 total. Refreshes duration on reapply.
	var def := StatusEffectDefinition.new()
	def.status_id = "bleed"
	def.tags = ["Physical", "DoT"]
	def.is_positive = false
	def.max_stacks = 1
	def.base_duration = 6.0
	def.duration_refresh_mode = "overwrite"
	def.tick_interval = 1.0

	var tick_dmg := DealDamageEffect.new()
	tick_dmg.damage_type = "Physical"
	tick_dmg.base_damage = 4.0
	def.tick_effects = [tick_dmg]

	## No pack ships a blood aura, but the Poison sheet's creeping motes recolour to arterial red
	## and read correctly as bleeding. Small — a bleed is a wound, not a cloud.
	_attach_aura(def, "poison", Vector2(0.7, 0.7), Color(1.0, 0.25, 0.28))

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

	## Chilled is the lighter of the two ice states — same sheet, smaller read than Frozen.
	_attach_aura(def, "ice", Vector2(0.8, 0.8))
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

	## Hemorrhage (Frozen + Bleed): burst damage when Frozen expires.
	## Full design calls for Bleed-stack-scaled damage; implemented as flat burst
	## since stack-conditional effects require TriggerConditionHasStatus (future work).
	var hemorrhage_dmg := DealDamageEffect.new()
	hemorrhage_dmg.damage_type = "Physical"
	hemorrhage_dmg.base_damage = 20.0
	def.on_expire_effects = [hemorrhage_dmg]

	_attach_aura(def, "ice")
	return def


static func _build_stunned() -> StatusEffectDefinition:
	## Hard CC with no element and no combo rider. Until now `frozen` was the game's ONLY status
	## setting disables_actions, so anything that wanted to stun had to borrow it — and frozen is
	## Ice-tagged and carries the Shatter trigger, which would have made the Ravager's physical
	## body-slam prime a fire combo it has no business priming. Duration is the default; callers
	## pass their own (Pile Driver overrides per landing).
	var def := StatusEffectDefinition.new()
	def.status_id = "stunned"
	def.tags = ["CC", "Stun"]
	def.is_positive = false
	def.max_stacks = 1
	def.base_duration = 1.2
	def.duration_refresh_mode = "overwrite"
	def.disables_actions = true
	def.disables_movement = true
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

	## Shocked is a live trap — hitting the target chains Lightning to everything nearby. It has
	## to be visible for that to be a decision rather than a surprise.
	_attach_aura(def, "electric")

	return def


static func _build_abyssal_slow() -> StatusEffectDefinition:
	## The Deep's Pull void wake: -30% move speed for 1.5s. Single stack, refreshes.
	## Distinct from Chilled (no Frozen escalation, Void-tagged).
	var def := StatusEffectDefinition.new()
	def.status_id = "abyssal_slow"
	def.tags = ["Void", "CC"]
	def.is_positive = false
	def.max_stacks = 1
	def.base_duration = 1.5
	def.duration_refresh_mode = "overwrite"

	var slow_mod := ModifierDefinition.new()
	slow_mod.target_tag = "move_speed"
	slow_mod.operation = "bonus"
	slow_mod.value = -0.30
	slow_mod.source_name = "abyssal_slow"
	def.modifiers = [slow_mod]

	## Pack II's Shadow aura — the void motes mark who the Deep has hold of.
	_attach_aura(def, "shadow", Vector2(0.8, 0.8), Color(0.72, 0.45, 1.0))

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

	## Permanent and it explodes on death — the player needs to know which bodies are primed.
	_attach_aura(def, "shadow", Vector2.ONE, Color(0.62, 0.30, 0.95))

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


# ── Crowd answers ─────────────────────────────────────────────────────────
#
# Every one of these scales with how many enemies are on you and does almost nothing to a lone
# target — the opposite of the stat sticks that made up the rest of the pool. The shapes are
# factored into helpers so each evolution is demonstrably the SAME mechanic with bigger numbers
# and cannot drift from the upgrade it replaces.


## A standing ring of harm centred on the bearer. Uses the aura path StatusEffectComponent
## already runs for the Shade's bone swirl (ChainFactory._bone_swirl_orbit) — proven on the
## player, not a new code path. Needs tick_interval > 0 or the aura never fires.
static func _sear_aura_onto(def: StatusEffectDefinition, radius: float,
		tick: float, dmg: float) -> void:
	def.tick_interval = tick
	def.aura_radius = radius
	def.aura_target_faction = "enemy"
	var sear := DealDamageEffect.new()
	sear.damage_type = "Fire"
	sear.base_damage = dmg
	def.aura_tick_effects = [sear]


## Kill something and the pack it came from eats the corpse. Centred on the VICTIM
## (target_self = false), which is safe because enemy._on_health_died emits on_kill long before
## the death animation ends and the node frees.
##
## The internal cooldown is load-bearing, not balance garnish: on_kill is emitted synchronously
## from inside take_damage, so a burst that kills is a NESTED dispatch. Without an ICD a dense
## pack could chain-detonate to arbitrary call depth. The ICD bounds the cascade at one.
static func _corpse_burst_listener(dmg: float, radius: float,
		icd: float) -> TriggerListenerDefinition:
	var burst := AreaDamageEffect.new()
	burst.damage_type = "Fire"
	burst.base_damage = dmg
	burst.aoe_radius = radius

	var listener := TriggerListenerDefinition.new()
	listener.event = "on_kill"
	listener.target_self = false
	listener.conditions = [TriggerConditionSourceIsSelf.new()]
	listener.internal_cooldown = icd
	listener.effects = [burst]
	return listener


## Getting hit buys you room: a chill nova centred on the bearer. Space-making WITHOUT knockback —
## player knockback was cut from every kit on 2026-07-31 and is not coming back, so distance has
## to come from slowing them instead of shoving them. Feeds Frostfire / Superconductor too.
static func _frost_nova_listener(dmg: float, radius: float,
		icd: float) -> TriggerListenerDefinition:
	var nova := AreaDamageEffect.new()
	nova.damage_type = "Ice"
	nova.base_damage = dmg
	nova.aoe_radius = radius

	var chill := ApplyStatusEffectData.new()
	chill.status = chilled
	chill.stacks = 1
	nova.on_hit_effects = [chill]

	var listener := TriggerListenerDefinition.new()
	listener.event = "on_hit_received"
	listener.target_self = true                  ## nova centred on me, not on whoever hit me
	listener.conditions = [TriggerConditionTargetIsSelf.new()]
	listener.internal_cooldown = icd
	listener.effects = [nova]
	return listener


## Turns on only when you are actually being swarmed. First use of
## StatusEffectDefinition.targeting_count_threshold, which counts enemies whose attack_target is
## the bearer — so it reads real aggro, not proximity. Checked from _execute_tick_effects, hence
## the tick_interval; the surge outlives one check interval so it holds steady while surrounded
## and lapses about a second after you break out.
static func _last_stand_onto(def: StatusEffectDefinition, threshold: int,
		damage_reduction: float, speed_bonus: float) -> void:
	var surge := StatusEffectDefinition.new()
	surge.status_id = "%s_surge" % def.status_id
	surge.tags = ["Passive"]
	surge.is_positive = true
	surge.max_stacks = 1
	surge.base_duration = 1.0
	surge.duration_refresh_mode = "overwrite"

	## ("All", "damage_taken") — damage_taken is an OPERATION, never a tag (ModifierComponent
	## NEVER_A_TAG). DamageCalculator does raw *= 1.0 + sum, so the value is negative to reduce.
	var dr := ModifierDefinition.new()
	dr.target_tag = "All"
	dr.operation = "damage_taken"
	dr.value = -damage_reduction
	dr.source_name = surge.status_id

	var spd := ModifierDefinition.new()
	spd.target_tag = "move_speed"
	spd.operation = "bonus"
	spd.value = speed_bonus
	spd.source_name = surge.status_id

	surge.modifiers = [dr, spd]

	def.tick_interval = maxf(def.tick_interval, 0.5)
	def.targeting_count_threshold = threshold
	def.targeting_count_status = surge


## Tags are set by each caller (not passed in) so every assignment stays a literal going straight
## into the Array[String] property, matching every other builder in this file.
static func _passive_shell(id: String) -> StatusEffectDefinition:
	var def := StatusEffectDefinition.new()
	def.status_id = id
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0  ## Permanent
	return def


static func _build_cinder_skin() -> StatusEffectDefinition:
	## 5 Fire every 0.5s to everything inside 70px — 10 dps per enemy in contact. Trivial against
	## one target, brutal against the ring that is actually killing you.
	var def := _passive_shell("cinder_skin")
	def.tags = ["Passive", "Fire"]
	_sear_aura_onto(def, 70.0, 0.5, 5.0)
	## The overlay is the radius tell — an invisible damage ring would be a guessing game.
	_attach_aura(def, "fire", Vector2(1.1, 1.1), Color(1.0, 0.72, 0.42))
	return def


static func _build_glacial_guard() -> StatusEffectDefinition:
	var def := _passive_shell("glacial_guard")
	def.tags = ["Passive", "Ice"]
	def.trigger_listeners = [_frost_nova_listener(8.0, 100.0, 2.0)]
	return def


static func _build_volatile_remains() -> StatusEffectDefinition:
	var def := _passive_shell("volatile_remains")
	def.tags = ["Passive", "Fire"]
	def.trigger_listeners = [_corpse_burst_listener(22.0, 65.0, 0.25)]
	return def


static func _build_last_stand() -> StatusEffectDefinition:
	var def := _passive_shell("last_stand")
	def.tags = ["Passive"]
	_last_stand_onto(def, 5, 0.20, 0.20)
	return def


# ── Combo-reactive class passives (Fighter pilot, 2026-08-24) ──────────────
##
## All four are permanent shells applied straight to the player by the "self_status" ability-upgrade
## op, exactly like the generic pool's procs. What is new is the EVENT they listen on: the three
## combo signals player.gd has emitted since the cadence pass, which until now only AudioManager
## and the HUD could hear.
##
## A note on why none of these carry an internal_cooldown, since every other listener in this file
## that fires off a kill or a hit does: the combo events are already rate-limited by the animation
## graph. A finisher takes most of a second to reach its hit frame and a combo step cannot fire
## faster than a phase can play, so there is no dense-pack cascade to bound — the recursion risk
## _corpse_burst_listener guards against does not exist here. AreaDamageEffect cannot re-enter a
## combo event either: nothing it does advances a choreography.


## Finishers detonate the ground you are standing on. Centred on the bearer, so it answers the
## ring rather than the one enemy the finisher happened to land on.
static func _build_fighter_thunderclap() -> StatusEffectDefinition:
	var def := _passive_shell("fighter_thunderclap")
	def.tags = ["Passive"]

	var clap := AreaDamageEffect.new()
	clap.damage_type = "Physical"
	clap.base_damage = 30.0
	clap.aoe_radius = 90.0

	var listener := TriggerListenerDefinition.new()
	listener.event = "on_finisher_hit"
	listener.target_self = true
	listener.effects = [clap]
	def.trigger_listeners = [listener]
	return def


## Every third link sharpens the next. multiple_of rather than min_depth, so it rewards keeping a
## chain alive through its whole length instead of paying out once and staying on.
static func _build_fighter_battle_rhythm() -> StatusEffectDefinition:
	var def := _passive_shell("fighter_battle_rhythm")
	def.tags = ["Passive"]

	var surge := StatusEffectDefinition.new()
	surge.status_id = "fighter_battle_rhythm_surge"
	surge.tags = ["Passive"]
	surge.is_positive = true
	surge.max_stacks = 1
	surge.base_duration = 3.0
	surge.duration_refresh_mode = "overwrite"
	var haste := ModifierDefinition.new()
	haste.target_tag = "attack_speed"
	haste.operation = "bonus"
	haste.value = 0.15
	haste.source_name = surge.status_id
	surge.modifiers = [haste]

	var apply := ApplyStatusEffectData.new()
	apply.status = surge
	apply.stacks = 1
	apply.apply_to_self = true

	var depth := TriggerConditionComboDepth.new()
	depth.multiple_of = 3

	var listener := TriggerListenerDefinition.new()
	listener.event = "on_combo_step"
	listener.target_self = true
	listener.conditions = [depth]
	listener.effects = [apply]
	def.trigger_listeners = [listener]
	return def


## Deep in the chain, less lands on you. The buff outlives one combo step (2s against a 0.75s
## cancel window) so it holds steady while the chain continues and lapses shortly after it ends —
## the same shape last_stand's surge uses, for the same reason.
##
## ("All", "damage_taken") — damage_taken is an OPERATION, never a tag (ModifierComponent
## NEVER_A_TAG). DamageCalculator does raw *= 1.0 + sum, so the value is negative to reduce.
static func _build_fighter_last_word() -> StatusEffectDefinition:
	var def := _passive_shell("fighter_last_word")
	def.tags = ["Passive"]

	var surge := StatusEffectDefinition.new()
	surge.status_id = "fighter_last_word_surge"
	surge.tags = ["Passive"]
	surge.is_positive = true
	surge.max_stacks = 1
	surge.base_duration = 2.0
	surge.duration_refresh_mode = "overwrite"
	var dr := ModifierDefinition.new()
	dr.target_tag = "All"
	dr.operation = "damage_taken"
	dr.value = -0.25
	dr.source_name = surge.status_id
	surge.modifiers = [dr]

	var apply := ApplyStatusEffectData.new()
	apply.status = surge
	apply.stacks = 1
	apply.apply_to_self = true

	var depth := TriggerConditionComboDepth.new()
	depth.min_depth = 4

	var listener := TriggerListenerDefinition.new()
	listener.event = "on_combo_step"
	listener.target_self = true
	listener.conditions = [depth]
	listener.effects = [apply]
	def.trigger_listeners = [listener]
	return def


## Dropping a chain is the one moment in this kit that used to be pure loss. min_depth 2 because
## on_combo_dropped only fires from depth >= 2 anyway (player.gd) — stating it makes the intent
## explicit and survives that rule changing.
static func _build_fighter_spite() -> StatusEffectDefinition:
	var def := _passive_shell("fighter_spite")
	def.tags = ["Passive"]

	var burst := AreaDamageEffect.new()
	burst.damage_type = "Physical"
	burst.base_damage = 40.0
	burst.aoe_radius = 110.0

	var depth := TriggerConditionComboDepth.new()
	depth.min_depth = 2

	var listener := TriggerListenerDefinition.new()
	listener.event = "on_combo_dropped"
	listener.target_self = true
	listener.conditions = [depth]
	listener.effects = [burst]
	def.trigger_listeners = [listener]
	return def


# ── Evolution combined statuses ────────────────────────────────────────────

static func _build_pyre() -> StatusEffectDefinition:
	## Cinder Skin + Volatile Remains: a wider, hotter ring whose kills feed the next detonation.
	var def := _passive_shell("pyre")
	def.tags = ["Passive", "Fire"]
	_sear_aura_onto(def, 90.0, 0.4, 7.0)
	def.trigger_listeners = [_corpse_burst_listener(32.0, 80.0, 0.2)]
	_attach_aura(def, "fire", Vector2(1.35, 1.35), Color(1.0, 0.6, 0.3))
	return def


static func _build_bulwark() -> StatusEffectDefinition:
	## Glacial Guard + Last Stand: the swarm that closes on you is the swarm that freezes.
	var def := _passive_shell("bulwark")
	def.tags = ["Passive", "Ice"]
	def.trigger_listeners = [_frost_nova_listener(12.0, 120.0, 1.5)]
	_last_stand_onto(def, 4, 0.30, 0.25)
	return def


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


# ── Mod combo elemental statuses ─────────────────────────────────────

static func _build_searing_wound() -> StatusEffectDefinition:
	## Searing Wound amplifier: applied to a target that has BOTH Burning and Bleed active.
	## Deals +3 Fire damage/sec for 4s, stacking on top of existing Bleed tick.
	## Applied by trigger listeners wired in _wire_searing_wound_combo().
	var def := StatusEffectDefinition.new()
	def.status_id = "searing_wound"
	def.tags = ["Fire", "Physical", "DoT"]
	def.is_positive = false
	def.max_stacks = 1
	def.base_duration = 4.0
	def.duration_refresh_mode = "overwrite"
	def.tick_interval = 1.0

	var tick_dmg := DealDamageEffect.new()
	tick_dmg.damage_type = "Fire"
	tick_dmg.base_damage = 3.0
	def.tick_effects = [tick_dmg]

	return def


static func _build_burning_extended() -> StatusEffectDefinition:
	## Comet variant: Burning with 4.5s duration (Gravity + Fire combo).
	var def := StatusEffectDefinition.new()
	def.status_id = "burning_extended"
	def.tags = ["Fire", "DoT"]
	def.is_positive = false
	def.max_stacks = 1
	def.base_duration = 4.5
	def.duration_refresh_mode = "overwrite"
	def.tick_interval = 1.0

	var tick_dmg := DealDamageEffect.new()
	tick_dmg.damage_type = "Fire"
	tick_dmg.base_damage = 3.0
	def.tick_effects = [tick_dmg]

	return def


static func _build_galvanized_shocked() -> StatusEffectDefinition:
	## Galvanized Shocked (Shock + DOT Applicator combo variant of Shocked).
	## Conductor AoE also spreads one Bleed stack to each enemy hit.
	var def := StatusEffectDefinition.new()
	def.status_id = "galvanized_shocked"
	def.tags = ["Lightning"]
	def.is_positive = false
	def.max_stacks = 1
	def.base_duration = 5.0

	## Conductor AoE with Bleed spread via on_hit_effects
	var chain_dmg := AreaDamageEffect.new()
	chain_dmg.damage_type = "Lightning"
	chain_dmg.base_damage = 10.0
	chain_dmg.aoe_radius = 80.0

	var spread_bleed := ApplyStatusEffectData.new()
	spread_bleed.status = bleed
	spread_bleed.stacks = 1
	chain_dmg.on_hit_effects = [spread_bleed]

	var chain_consume := ConsumeStacksEffect.new()
	chain_consume.status_id = "galvanized_shocked"
	chain_consume.stacks_to_consume = -1

	var target_is_self := TriggerConditionTargetIsSelf.new()
	var conductor_listener := TriggerListenerDefinition.new()
	conductor_listener.event = "on_hit_received"
	conductor_listener.target_self = true
	conductor_listener.conditions = [target_is_self]
	conductor_listener.effects = [chain_dmg, chain_consume]
	def.trigger_listeners = [conductor_listener]

	return def


static func _wire_hellfire_combo() -> void:
	## Hellfire (Burning + Shocked): either order of application triggers the combo.
	## When Burning is applied to a Shocked target → on Shocked's listener.
	## When Shocked is applied to a Burning target → on Burning's listener.

	var hellfire_aoe := AreaDamageEffect.new()
	hellfire_aoe.damage_type = "Fire"   ## Hybrid: use Fire tag, deal split damage
	hellfire_aoe.base_damage = 15.0
	hellfire_aoe.aoe_radius = 55.0

	## Shocked listener: fires when burning is applied to Shocked entity
	var consume_shocked := ConsumeStacksEffect.new()
	consume_shocked.status_id = "shocked"
	consume_shocked.stacks_to_consume = -1

	var consume_burning_a := ConsumeStacksEffect.new()
	consume_burning_a.status_id = "burning"
	consume_burning_a.stacks_to_consume = -1

	var burning_cond_a := TriggerConditionStatusId.new()
	burning_cond_a.status_id = "burning"
	var self_cond_a := TriggerConditionTargetIsSelf.new()

	var hellfire_on_shocked := TriggerListenerDefinition.new()
	hellfire_on_shocked.event = "on_status_applied"
	hellfire_on_shocked.target_self = true
	hellfire_on_shocked.conditions = [burning_cond_a, self_cond_a]
	hellfire_on_shocked.effects = [hellfire_aoe, consume_shocked, consume_burning_a]
	shocked.trigger_listeners.append(hellfire_on_shocked)

	## Burning listener: fires when shocked is applied to Burning entity
	var hellfire_aoe_b := AreaDamageEffect.new()
	hellfire_aoe_b.damage_type = "Fire"
	hellfire_aoe_b.base_damage = 15.0
	hellfire_aoe_b.aoe_radius = 55.0

	var consume_burning_b := ConsumeStacksEffect.new()
	consume_burning_b.status_id = "burning"
	consume_burning_b.stacks_to_consume = -1

	var consume_shocked_b := ConsumeStacksEffect.new()
	consume_shocked_b.status_id = "shocked"
	consume_shocked_b.stacks_to_consume = -1

	var shocked_cond_b := TriggerConditionStatusId.new()
	shocked_cond_b.status_id = "shocked"
	var self_cond_b := TriggerConditionTargetIsSelf.new()

	var hellfire_on_burning := TriggerListenerDefinition.new()
	hellfire_on_burning.event = "on_status_applied"
	hellfire_on_burning.target_self = true
	hellfire_on_burning.conditions = [shocked_cond_b, self_cond_b]
	hellfire_on_burning.effects = [hellfire_aoe_b, consume_burning_b, consume_shocked_b]
	burning.trigger_listeners.append(hellfire_on_burning)


static func _wire_superconductor_combo() -> void:
	## Superconductor (Chilled + Shocked): Shocked applied to Chilled target
	## → consume Chilled, deal 18 Cold Lightning AoE (60px).
	var super_aoe := AreaDamageEffect.new()
	super_aoe.damage_type = "Ice"
	super_aoe.base_damage = 18.0
	super_aoe.aoe_radius = 60.0

	var consume_chilled := ConsumeStacksEffect.new()
	consume_chilled.status_id = "chilled"
	consume_chilled.stacks_to_consume = -1

	var shocked_cond := TriggerConditionStatusId.new()
	shocked_cond.status_id = "shocked"
	var self_cond := TriggerConditionTargetIsSelf.new()

	var superconductor_listener := TriggerListenerDefinition.new()
	superconductor_listener.event = "on_status_applied"
	superconductor_listener.target_self = true
	superconductor_listener.conditions = [shocked_cond, self_cond]
	superconductor_listener.effects = [super_aoe, consume_chilled]
	chilled.trigger_listeners.append(superconductor_listener)


static func _wire_searing_wound_combo() -> void:
	## Searing Wound (Burning + Bleed co-presence):
	## Burning applied to Bleeding target → apply searing_wound.
	## Bleed applied to Burning target → apply searing_wound.

	var apply_sw_a := ApplyStatusEffectData.new()
	apply_sw_a.status = searing_wound
	apply_sw_a.stacks = 1

	var bleed_cond := TriggerConditionStatusId.new()
	bleed_cond.status_id = "bleed"
	var self_cond_a := TriggerConditionTargetIsSelf.new()

	var sw_on_burning := TriggerListenerDefinition.new()
	sw_on_burning.event = "on_status_applied"
	sw_on_burning.target_self = true
	sw_on_burning.conditions = [bleed_cond, self_cond_a]
	sw_on_burning.effects = [apply_sw_a]
	burning.trigger_listeners.append(sw_on_burning)

	var apply_sw_b := ApplyStatusEffectData.new()
	apply_sw_b.status = searing_wound
	apply_sw_b.stacks = 1

	var burning_cond := TriggerConditionStatusId.new()
	burning_cond.status_id = "burning"
	var self_cond_b := TriggerConditionTargetIsSelf.new()

	var sw_on_bleed := TriggerListenerDefinition.new()
	sw_on_bleed.event = "on_status_applied"
	sw_on_bleed.target_self = true
	sw_on_bleed.conditions = [burning_cond, self_cond_b]
	sw_on_bleed.effects = [apply_sw_b]
	bleed.trigger_listeners.append(sw_on_bleed)


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


static func _build_elite_reflecting() -> StatusEffectDefinition:
	## Elite: marker status. Projectile reflection is handled in ProjectileManager._check_hits().
	## When a player projectile hits this enemy, velocity is reversed and faction targeting flipped.
	var def := StatusEffectDefinition.new()
	def.status_id = "elite_reflecting"
	def.tags = ["Elite"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0

	return def


static func _build_elite_regenerating() -> StatusEffectDefinition:
	## Elite: heals 3% max HP every second permanently.
	var def := StatusEffectDefinition.new()
	def.status_id = "elite_regenerating"
	def.tags = ["Elite"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0
	def.tick_interval = 1.0

	var heal := HealEffect.new()
	heal.percent_max_hp = 0.03
	def.tick_effects = [heal]

	return def


static func _build_elite_armored() -> StatusEffectDefinition:
	## Elite: +30 Physical resist, +12 resist to Fire/Cryo/Shock/Void while alive.
	var def := StatusEffectDefinition.new()
	def.status_id = "elite_armored"
	def.tags = ["Elite"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0

	var mods: Array[Resource] = []
	for dmg_type in ["Physical", "Fire", "Cryo", "Shock", "Void"]:
		var m := ModifierDefinition.new()
		m.target_tag = dmg_type
		m.operation = "resist"
		m.value = 30.0 if dmg_type == "Physical" else 12.0
		m.source_name = "elite_armored"
		mods.append(m)
	def.modifiers = mods

	return def


static func _build_elite_vampiric() -> StatusEffectDefinition:
	## Elite: marker status. Self-heal on contact hit is handled directly in enemy.gd.
	## Heals 40% of contact_damage dealt when a hit connects.
	var def := StatusEffectDefinition.new()
	def.status_id = "elite_vampiric"
	def.tags = ["Elite"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0

	return def
