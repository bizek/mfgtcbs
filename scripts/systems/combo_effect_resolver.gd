class_name ComboEffectResolver
extends Node
## Runtime combo effect orchestrator.
##
## Responsibilities:
##   1. STATUS_LISTENER combos — detected via EventBus, wired to CodexManager.
##      The actual game effects fire through StatusFactory's TriggerListeners on status
##      definitions; this resolver tracks discovery and mastery counts.
##   2. Projectile lifecycle hooks — notify_projectile_* methods called by ProjectileManager
##      to record triggers for behavior combos whose effects are baked into ProjectileConfig
##      by ModComboFactory at weapon-build time.
##   3. Discovery signal — combo_first_triggered emitted the first time a combo fires in a
##      run so the HUD can show a "FROSTFIRE DISCOVERED!" flash.
##
## ── INTEGRATION POINTS ──────────────────────────────────────────────────────────────
##
## A. CombatOrchestrator — add ComboEffectResolver as a child node:
##      @onready var combo_effect_resolver: ComboEffectResolver = $ComboEffectResolver
##      # In _ready():
##      combo_effect_resolver.combat_manager = self
##
## B. Player entity — add combo tracking (player.gd):
##      var active_combo_ids: Array[StringName] = []   # set at loadout change
##
##    At loadout change (hub armory / run start):
##      var detector := ComboDetector.new()
##      active_combo_ids = detector.get_active_combo_ids(weapon.get_equipped_mod_ids())
##      CodexManager.discover_combo(id) for id in active_combo_ids
##
## C. ProjectileManager — add parallel array and call hooks:
##      # In variable declarations:
##      var _proj_combo_ids: Array = []                # Array of Array[StringName]
##
##      # In _init_pool():
##      _proj_combo_ids.resize(POOL_SIZE)
##      for i in POOL_SIZE: _proj_combo_ids[i] = []
##
##      # In spawn():
##      _proj_combo_ids[i] = source.get("active_combo_ids") if source else []
##
##      # In _release_slot():
##      _proj_combo_ids[i] = []
##
##      # In _on_hit(), after existing effects:
##      var resolver = combat_manager.get("combo_effect_resolver") as ComboEffectResolver
##      if resolver:
##          resolver.notify_projectile_hit(_sources[i], target_entity, _proj_combo_ids[i])
##
##      # In _on_bounce(), at end:
##      var resolver = combat_manager.get("combo_effect_resolver") as ComboEffectResolver
##      if resolver:
##          resolver.notify_projectile_bounce(_sources[i], _positions[i], _proj_combo_ids[i])
##
##      # In _fire_on_expire(), after existing effects:
##      var resolver = combat_manager.get("combo_effect_resolver") as ComboEffectResolver
##      if resolver:
##          resolver.notify_projectile_expire(_sources[i], _positions[i], _proj_combo_ids[i])
##
## D. GameManager — on run end / scene cleanup, clear CodexManager revealed flags if
##    "revealed" should only be per-run (current design keeps revealed permanently).
## ────────────────────────────────────────────────────────────────────────────────────

## Emitted the first time a combo fires in a run (CodexEntry.revealed transitions false→true).
## HUD listens to show a discovery flash banner.
## combo_type matches ModCombo.ComboType enum value so HUD can style triples differently.
signal combo_first_triggered(combo_id: StringName, combo_name: String, combo_type: int)

## Emitted when a triple legendary combo fires for the first time.
## Separate signal so HUD can trigger a more dramatic effect.
signal triple_combo_first_triggered(combo_id: StringName, combo_name: String)

var combat_manager: Node2D = null


func _ready() -> void:
	## Connect to EventBus for STATUS_LISTENER (elemental reaction) detection.
	## This node connects at scene start, before enemy TriggerComponents register their
	## listeners — so our handlers run first and can read pre-consume status state.
	EventBus.on_status_applied.connect(_on_status_applied)
	EventBus.on_status_expired.connect(_on_status_expired)
	EventBus.on_hit_received.connect(_on_hit_received)


## ── Projectile lifecycle hooks ─────────────────────────────────────────────────────
## Each notify_* method records triggers for behavior combos whose actual game effects
## are already executed by ProjectileManager (via flags set in ProjectileConfig by
## ModComboFactory). Calling these methods is the ONLY thing needed to wire mastery
## tracking and discovery for those combos.

func notify_projectile_hit(
		_source: Node2D, _target: Node2D, combo_ids: Array[StringName]) -> void:
	## Call from ProjectileManager._on_hit() after existing effect execution.
	## Records one trigger per active ON_HIT combo per projectile-hit event.
	for combo_id: StringName in combo_ids:
		match combo_id:
			## ── BEHAVIOR × BEHAVIOR ────────────────────────────────────────────
			## Shrapnel Storm (Pierce + Chain): pierce fires chain AoE on each hit
			&"shrapnel_storm":
				_fire_combo(combo_id)
			## Bouncing Bomb (Chain + Explosive): chain destination explodes on hit
			&"bouncing_bomb":
				_fire_combo(combo_id)
			## Hydra (Chain + Split): chain arrival spawns sub-projectiles
			&"hydra":
				_fire_combo(combo_id)
			## Seeker Chain (Chain + Gravity): chain range extended, guided bounce
			&"seeker_chain":
				_fire_combo(combo_id)
			## Billiard (Chain + Ricochet): bounce momentum extends chain range
			&"billiard":
				_fire_combo(combo_id)
			## Cluster Bomb (Explosive + Split): explosion spawns spread sub-projectiles
			&"cluster_bomb":
				_fire_combo(combo_id)
			## Seeking Missile (Explosive + Gravity): homing with +50% explosion radius
			&"seeking_missile":
				_fire_combo(combo_id)
			## Star Formation (Split + Gravity): homing sub-projectiles
			&"star_formation":
				_fire_combo(combo_id)
			## Scatter Shot (Split + Ricochet): sub-projectiles each bounce once
			&"scatter_shot":
				_fire_combo(combo_id)
			## ── BEHAVIOR × ELEMENTAL ───────────────────────────────────────────
			## Ice Spear (Pierce + Cryo): all pierced targets chilled simultaneously
			&"ice_spear":
				_fire_combo(combo_id)
			## Arc Chain (Pierce + Shock): each additional pierce triggers Conductor on prior
			&"arc_chain":
				_fire_combo(combo_id)
			## Bloodletter (Pierce + DOT): each pierced enemy gets independent Bleed
			&"bloodletter":
				_fire_combo(combo_id)
			## Firebrand (Chain + Fire): chain destination is Ignited on arrival
			&"firebrand":
				_fire_combo(combo_id)
			## Freeze Relay (Chain + Cryo): chain destination Chilled; Frozen if already Chilled
			&"freeze_relay":
				_fire_combo(combo_id)
			## Arc Flash (Chain + Shock): chain arc triggers Conductor on secondary target
			&"arc_flash":
				_fire_combo(combo_id)
			## Bleeding Edge (Chain + DOT): chain arrival applies Bleed to secondary target
			&"bleeding_edge":
				_fire_combo(combo_id)
			## Flash Freeze (Explosive + Cryo): AoE chills all targets, 2 stacks = Frozen
			&"flash_freeze":
				_fire_combo(combo_id)
			## Static Pulse (Explosive + Shock): AoE applies Shocked to every hit enemy
			&"static_pulse":
				_fire_combo(combo_id)
			## Frag Round (Explosive + DOT): each explosion hit also applies Bleed
			&"frag_round":
				_fire_combo(combo_id)
			## Fire Flower (Split + Fire): each sub-projectile independently applies Burning
			&"fire_flower":
				_fire_combo(combo_id)
			## Ice Fan (Split + Cryo): each sub-projectile independently applies Chilled
			&"ice_fan":
				_fire_combo(combo_id)
			## Fork Lightning (Split + Shock): each sub-projectile independently applies Shocked
			&"fork_lightning":
				_fire_combo(combo_id)
			## Razor Fan (Split + DOT): each sub-projectile independently applies Bleed
			&"razor_fan":
				_fire_combo(combo_id)
			## Comet (Gravity + Fire): homing firebolt, Burning +50% duration (4.5s)
			&"comet":
				_fire_combo(combo_id)
			## Frost Seeker (Gravity + Cryo): guaranteed Chilled on impact
			&"frost_seeker":
				_fire_combo(combo_id)
			## Lightning Rod (Gravity + Shock): homing, applies Shocked + triggers Conductor
			&"lightning_rod":
				_fire_combo(combo_id)
			## Bloodhound (Gravity + DOT): homing prefers bleeding enemies; refreshes Bleed
			&"bloodhound":
				_fire_combo(combo_id)
			## Ice Ball (Ricochet + Cryo): bounced hits gain extra Chilled stack
			&"ice_ball":
				_fire_combo(combo_id)
			## Thunderball (Ricochet + Shock): Shocked applied on every impact including bounces
			&"thunderball":
				_fire_combo(combo_id)
			## ── STAT INTERACTIONS ──────────────────────────────────────────────
			## Static Strike (Crit + Shock): crits trigger Conductor without consuming Shocked
			&"static_strike":
				_fire_combo(combo_id)
			## Vampiric Strike (Crit + Lifesteal): crits leech at 3× rate
			&"vampiric_strike":
				_fire_combo(combo_id)
			## ── TRIPLES ────────────────────────────────────────────────────────
			## Doomsday Device (Explosive + Split + Size): explode then spawn large sub-shots
			&"doomsday_device":
				_fire_combo(combo_id)
			## Vampire Lord (Pierce + Lifesteal + DOT): bleed every pierce; all bleed leeches
			&"vampire_lord":
				_fire_combo(combo_id)
			## Absolute Zero (Cryo + Size + Crit): crits apply 2 Chilled stacks immediately
			&"absolute_zero":
				_fire_combo(combo_id)
			## Storm Breaker (Ricochet + Shock + Explosive): shocks + explodes on every bounce
			&"storm_breaker":
				_fire_combo(combo_id)
			## World Serpent (Gravity + Chain + Split): chain spawns homing sub-projectiles
			&"world_serpent":
				_fire_combo(combo_id)
			## Crimson Reaper (DOT + Crit + Accelerating): crits refresh DoT; ramp buffs bleed
			&"crimson_reaper":
				_fire_combo(combo_id)
			## Frostfire Meteor (Gravity + Fire + Cryo): guaranteed hit applies both Burning+Chilled
			&"frostfire_meteor":
				_fire_combo(combo_id)


func notify_projectile_expire(
		_source: Node2D, _expire_pos: Vector2, combo_ids: Array[StringName]) -> void:
	## Call from ProjectileManager._fire_on_expire() after existing expire effects.
	for combo_id: StringName in combo_ids:
		match combo_id:
			## Tunnel Bomb (Pierce + Explosive): delayed explosion fires backward along pierce path
			&"tunnel_bomb":
				_fire_combo(combo_id)
			## Flechette (Pierce + Split): sub-projectiles inherit pierce = 1 each
			&"flechette":
				_fire_combo(combo_id)
			## Needle Vortex (Pierce + Gravity): homing pierce; continues straight post-contact
			## (ON_FIRE conceptually, but expiry = first hit for this combo)
			&"needle_vortex":
				_fire_combo(combo_id)


func notify_projectile_bounce(
		_source: Node2D, _bounce_pos: Vector2, combo_ids: Array[StringName]) -> void:
	## Call from ProjectileManager._on_bounce() after existing bounce logic.
	for combo_id: StringName in combo_ids:
		match combo_id:
			## Phase Bolt (Pierce + Ricochet): pierce counter resets to full on each wall bounce
			&"phase_bolt":
				_fire_combo(combo_id)
			## Bouncing Grenade / Storm Breaker: AoE explosion fires at each bounce point
			&"bouncing_grenade", &"storm_breaker":
				_fire_combo(combo_id)
			## Wildfire (Ricochet + Fire): bounce point becomes a 0.8s fire zone
			&"wildfire":
				_fire_combo(combo_id)
			## Ricochet Razor (Ricochet + DOT): bouncing refreshes Bleed near the bounce point
			&"ricochet_razor":
				_fire_combo(combo_id)
			## Spiral Orbit (Gravity + Ricochet): re-acquires nearest enemy as new homing target
			&"spiral_orbit":
				_fire_combo(combo_id)
			## Billiard (Chain + Ricochet): each bounce increments chain range (tracked in config)
			&"billiard":
				_fire_combo(combo_id)


## ── STATUS_LISTENER combos ────────────────────────────────────────────────────────
## EventBus.on_status_applied fires BEFORE the target's existing TriggerComponents
## process the same event. This guarantees we can read pre-consume status state.
## Each check mirrors the condition that StatusFactory's TriggerListeners verify,
## so this resolver fires in sync with the actual game effect.

func _on_status_applied(
		_source: Node2D, target: Node2D, status_id: String, _stacks: int) -> void:
	if not is_instance_valid(target):
		return
	var sec: StatusEffectComponent = target.get("status_effect_component")
	if not sec:
		return

	match status_id:
		"burning":
			## Frostfire: Burning applied to Chilled → consume Chilled + 12 Fire AoE (45px)
			## Effect: chilled.trigger_listeners (status_factory._build_chilled)
			## VFX hint: fire_ice_burst
			if sec.has_status("chilled"):
				_fire_combo(&"frostfire")

			## Shatter: Burning applied to Frozen → consume Frozen + 20 Ice AoE (50px)
			## Effect: frozen.trigger_listeners (status_factory._build_frozen)
			## VFX hint: ice_break
			if sec.has_status("frozen"):
				_fire_combo(&"shatter")

			## Hellfire: Burning applied to Shocked → consume both + 15 Hellfire AoE (55px)
			## Effect: shocked.trigger_listeners (_wire_hellfire_combo, burning-onto-shocked path)
			## VFX hint: hellfire_burst
			if sec.has_status("shocked"):
				_fire_combo(&"hellfire")

			## Searing Wound: Burning co-present with Bleed → double Bleed tick rate
			## Effect: burning.trigger_listeners (_wire_searing_wound_combo, bleed-present path)
			## VFX hint: dual_dot
			if sec.has_status("bleed"):
				_fire_combo(&"searing_wound")

		"shocked":
			## Superconductor: Shocked applied to Chilled → consume Chilled + 18 Cold AoE (60px)
			## Effect: chilled.trigger_listeners (_wire_superconductor_combo)
			## VFX hint: cold_shock
			if sec.has_status("chilled"):
				_fire_combo(&"superconductor")

			## Hellfire (reverse direction): Shocked applied to Burning → consume both + Hellfire AoE
			## Effect: burning.trigger_listeners (_wire_hellfire_combo, shocked-onto-burning path)
			if sec.has_status("burning"):
				_fire_combo(&"hellfire")

		"bleed":
			## Searing Wound (reverse direction): Bleed applied to Burning target
			## Effect: bleed.trigger_listeners (_wire_searing_wound_combo, burning-present path)
			if sec.has_status("burning"):
				_fire_combo(&"searing_wound")

			## Galvanized: Bleed applied while Galvanized Shocked active
			## Effect: galvanized_shocked trigger fires on next hit; this marks the combo active
			## NOTE: Galvanized's trigger fires on_hit_received, so we also detect in _on_hit_received.
			## This path records discovery the moment the STATUS COMBINATION first forms.
			if sec.has_status("galvanized_shocked"):
				_fire_combo(&"galvanized")

		"galvanized_shocked":
			## Galvanized Shocked + Bleed: the Galvanized combo is now live
			if sec.has_status("bleed"):
				_fire_combo(&"galvanized")


func _on_status_expired(entity: Node2D, status_id: String) -> void:
	## Hemorrhage: Frozen expires while target has Bleed → burst physical damage
	## Effect: frozen.on_expire_effects fires DealDamageEffect unconditionally;
	## we record it as Hemorrhage only when Bleed is co-present, per design intent.
	## VFX hint: freeze_execute
	if status_id != "frozen":
		return
	if not is_instance_valid(entity):
		return
	var sec: StatusEffectComponent = entity.get("status_effect_component")
	if sec and sec.has_status("bleed"):
		_fire_combo(&"hemorrhage")


func _on_hit_received(source: Node2D, target: Node2D, _hit_data) -> void:
	## Conductor: any hit received while Shocked → consume Shocked + 10 Lightning AoE (80px)
	## Effect: shocked.trigger_listeners (status_factory._build_shocked)
	## VFX hint: chain_lightning
	##
	## Galvanized: same trigger, but Galvanized Shocked also spreads Bleed stacks
	## Effect: galvanized_shocked.trigger_listeners (_build_galvanized_shocked)
	## VFX hint: shock_bleed_spread
	if not is_instance_valid(target):
		return
	var sec: StatusEffectComponent = target.get("status_effect_component")
	if not sec:
		return

	if sec.has_status("galvanized_shocked"):
		## Galvanized Shocked subsumes regular Conductor for this target
		_fire_combo(&"galvanized")
	elif sec.has_status("shocked"):
		_fire_combo(&"conductor")


## ── Core record + signal ──────────────────────────────────────────────────────────

func _fire_combo(combo_id: StringName) -> void:
	## Central dispatch: record trigger in CodexManager, emit discovery signals.
	## Safe to call frequently — CodexManager.record_trigger is O(1).
	if not CodexManager:
		return
	if not CodexManager.entries.has(combo_id):
		push_warning("ComboEffectResolver: unknown combo_id '%s'" % combo_id)
		return

	var entry: CodexEntry = CodexManager.entries[combo_id]
	var first_reveal: bool = not entry.revealed

	if first_reveal:
		CodexManager.reveal_combo(combo_id)
		combo_first_triggered.emit(combo_id, entry.combo.combo_name, entry.combo.combo_type)
		if entry.combo.combo_type == ModCombo.ComboType.TRIPLE_LEGENDARY:
			triple_combo_first_triggered.emit(combo_id, entry.combo.combo_name)

	CodexManager.record_trigger(combo_id)
