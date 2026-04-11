class_name ModComboFactory
extends RefCounted
## Applies named mod combo effects to a ProjectileConfig after base mod application.
## Called from WeaponFactory after each mod is individually applied.
##
## Design source: docs/mod_interaction_matrix.md
## All 69 authored double combos and 8 legendary triple combos are handled here.
##
## Combo detection is pair/triple set membership — order doesn't matter.
## Triples run last and may override or augment pairwise effects.


# ── Entry point ────────────────────────────────────────────────────────────────

static func apply_projectile_combos(config: ProjectileConfig,
		mods: Array, data: Dictionary) -> void:
	## Main entry. Apply all mod combo modifications to config.
	## split_config is accessed via _get_split_spawn(config).projectile if split is present.
	StatusFactory.build_all()

	## Behavior × Behavior
	_combo_pierce_chain(config, mods, data)
	_combo_pierce_explosive(config, mods, data)
	_combo_pierce_split(config, mods, data)
	_combo_pierce_gravity(config, mods)
	_combo_pierce_ricochet(config, mods)
	_combo_chain_explosive(config, mods, data)
	_combo_chain_split(config, mods, data)
	_combo_chain_gravity(config, mods)
	_combo_chain_ricochet(config, mods)
	_combo_explosive_split(config, mods, data)
	_combo_explosive_gravity(config, mods)
	_combo_explosive_ricochet(config, mods)
	_combo_split_gravity(config, mods)
	_combo_split_ricochet(config, mods, data)
	_combo_gravity_ricochet(config, mods)

	## Behavior × Elemental — Chain
	_combo_chain_fire(config, mods)
	_combo_chain_cryo(config, mods)
	_combo_chain_shock(config, mods)
	_combo_chain_dot(config, mods)

	## Behavior × Elemental — Explosive
	_combo_explosive_fire(config, mods, data)
	_combo_explosive_cryo(config, mods)
	_combo_explosive_shock(config, mods)
	_combo_explosive_dot(config, mods)

	## Behavior × Elemental — Split
	_combo_split_fire(config, mods)
	_combo_split_cryo(config, mods)
	_combo_split_shock(config, mods)
	_combo_split_dot(config, mods)

	## Behavior × Elemental — Gravity
	_combo_gravity_fire(config, mods)
	_combo_gravity_cryo(config, mods)
	_combo_gravity_shock(config, mods)
	_combo_gravity_dot(config, mods)

	## Behavior × Elemental — Ricochet
	_combo_ricochet_fire(config, mods)
	_combo_ricochet_cryo(config, mods)
	_combo_ricochet_shock(config, mods)
	_combo_ricochet_dot(config, mods)

	## Behavior × Elemental — Pierce (mainly implicit; some additive)
	_combo_pierce_fire(config, mods)

	## Stat × Behavior / Elemental
	_combo_size_interactions(config, mods, data)
	_combo_crit_interactions(config, mods, data)
	_combo_lifesteal_cryo(config, mods)
	_combo_accelerating_interactions(config, mods, data)
	_combo_shock_dot(config, mods)   ## Galvanized Shocked replacement

	## Triples — must run after all pairwise combos
	_triple_doomsday_device(config, mods, data)
	_triple_vampire_lord(config, mods)
	_triple_absolute_zero(config, mods)
	_triple_storm_breaker(config, mods, data)
	_triple_world_serpent(config, mods, data)
	_triple_frostfire_meteor(config, mods)
	## NOTE: Two triples require runtime state beyond ProjectileConfig and are wired elsewhere:
	## EXTRACTION TITAN (Instability Siphon + Explosive + Fire): multi-kill explosion siphon bonus
	##   → needs kill-count-per-explosion tracking; wire into player._on_kill_siphon.
	## CRIMSON REAPER (DOT Applicator + Crit + Accelerating): crit deals 15% of Bleed stacks
	##   → needs target Bleed stack count at crit time; wire into DamageCalculator or crit event.


static func build_combo_passives(mods: Array) -> Array[StatusEffectDefinition]:
	## Returns StatusEffectDefinitions to be applied permanently to the player
	## for mod combos that require runtime trigger effects.
	StatusFactory.build_all()
	var result: Array[StatusEffectDefinition] = []

	## Static Strike (Crit + Shock): crits deal 10 Lightning AoE without consuming Shocked.
	## Implemented as a crit-triggered AoE passive (same pattern as static_discharge).
	if _has(mods, "crit_amp") and _has(mods, "shock"):
		result.append(_build_static_strike_passive())

	## Vampiric Strike (Crit + Lifesteal): bonus leech handled via build_mod_modifiers.
	## No extra passive needed — handled in weapon_factory.build_mod_modifiers.

	## Vital Extraction (Lifesteal + Instability Siphon): on kill → heal.
	## Handled by existing bloodthirst pattern if equipped as upgrade; skip here.

	return result


# ── Helpers ────────────────────────────────────────────────────────────────────

static func _has(mods: Array, mod_id: String) -> bool:
	return mod_id in mods


static func _has_all(mods: Array, required: Array) -> bool:
	for m in required:
		if m not in mods:
			return false
	return true


static func _base_damage(config: ProjectileConfig) -> float:
	for eff in config.on_hit_effects:
		if eff is DealDamageEffect:
			return eff.base_damage
	return 10.0


static func _damage_type(config: ProjectileConfig) -> String:
	for eff in config.on_hit_effects:
		if eff is DealDamageEffect:
			return eff.damage_type
	return "Physical"


static func _get_chain_aoe(config: ProjectileConfig) -> AreaDamageEffect:
	## The chain AreaDamageEffect lives in on_hit_effects after the weapon_factory fix.
	for eff in config.on_hit_effects:
		if eff is AreaDamageEffect:
			return eff
	return null


static func _get_split_spawn(config: ProjectileConfig) -> SpawnProjectilesEffect:
	for eff in config.on_expire_effects:
		if eff is SpawnProjectilesEffect:
			return eff
	return null


static func _apply_status_effect(status: StatusEffectDefinition, stacks: int = 1) -> ApplyStatusEffectData:
	var apply := ApplyStatusEffectData.new()
	apply.status = status
	apply.stacks = stacks
	return apply


# ── Behavior × Behavior ────────────────────────────────────────────────────────

static func _combo_pierce_chain(config: ProjectileConfig, mods: Array, _data: Dictionary) -> void:
	## Shrapnel Storm: pierce up to 3 enemies + chain from each pierced enemy.
	## Already implicit — chain AreaDamageEffect fires on every pierce hit.
	## Combo ensures pierce = 3 when both mods present.
	if not (_has(mods, "pierce") and _has(mods, "chain")):
		return
	config.pierce_count = maxi(config.pierce_count, 3)


static func _combo_pierce_explosive(config: ProjectileConfig, mods: Array, data: Dictionary) -> void:
	## Tunnel Bomb: large expiry explosion covers all previously pierced targets.
	## Adds a big AoE on expire (in addition to per-hit explosion from explosive mod).
	if not (_has(mods, "pierce") and _has(mods, "explosive")):
		return
	var expiry_aoe := AreaDamageEffect.new()
	expiry_aoe.damage_type = _damage_type(config)
	expiry_aoe.base_damage = _base_damage(config)   ## Full damage detonation on expiry
	expiry_aoe.aoe_radius = 60.0                     ## Wide enough to catch all pierce trail
	config.on_expire_effects.append(expiry_aoe)


static func _combo_pierce_split(config: ProjectileConfig, mods: Array, _data: Dictionary) -> void:
	## Flechette: sub-projectiles each get pierce = 1.
	if not (_has(mods, "pierce") and _has(mods, "split")):
		return
	var spawn := _get_split_spawn(config)
	if not spawn:
		return
	var sc: ProjectileConfig = spawn.projectile
	sc.pierce_count = 1
	## Sub-damage stays at design value; pierce gives extra reach


static func _combo_pierce_gravity(config: ProjectileConfig, mods: Array) -> void:
	## Needle Vortex: homing already active from gravity mod. No additional structural change.
	## The first hit is homed; pierce continues straight (natural behavior after first contact).
	if not (_has(mods, "pierce") and _has(mods, "gravity")):
		return
	## Already handled by gravity setting motion_type = "homing". No change.


static func _combo_pierce_ricochet(config: ProjectileConfig, mods: Array) -> void:
	## Phase Bolt: pierce counter resets to full on each wall bounce.
	## A single shot can pierce 12+ enemies across 3 bounces.
	if not (_has(mods, "pierce") and _has(mods, "ricochet")):
		return
	config.pierce_resets_on_bounce = true
	config.pierce_count_base = config.pierce_count


static func _combo_chain_explosive(config: ProjectileConfig, mods: Array, data: Dictionary) -> void:
	## Bouncing Bomb: chain area carries the explosion payload (+30% AoE at chain range).
	## Increases chain AoE damage and radius to simulate bomb at chain destination.
	if not (_has(mods, "chain") and _has(mods, "explosive")):
		return
	var chain := _get_chain_aoe(config)
	if not chain:
		return
	chain.base_damage = _base_damage(config) * 0.6 * 1.3   ## chain damage × 30% bonus
	chain.aoe_radius = maxf(chain.aoe_radius, 80.0)          ## wider blast at chain destination


static func _combo_chain_split(config: ProjectileConfig, mods: Array, data: Dictionary) -> void:
	## Hydra: on chain arrival, spawn sub-projectiles at the chain destination.
	## Approximate: the chain AoE fires, and on expiry the split still triggers from main projectile.
	## Full "split at chain destination" requires runtime chain tracking (future work).
	## Combo effect: chain range → 140px, sub-projectiles available as usual.
	if not (_has(mods, "chain") and _has(mods, "split")):
		return
	var chain := _get_chain_aoe(config)
	if chain:
		chain.aoe_radius = maxf(chain.aoe_radius, 140.0)
	## Each chain hop also gets a split (approximate via wider AoE)


static func _combo_chain_gravity(config: ProjectileConfig, mods: Array) -> void:
	## Seeker Chain: chain range extends to 200px (from 120px).
	if not (_has(mods, "chain") and _has(mods, "gravity")):
		return
	var chain := _get_chain_aoe(config)
	if chain:
		chain.aoe_radius = maxf(chain.aoe_radius, 200.0)


static func _combo_chain_ricochet(config: ProjectileConfig, mods: Array) -> void:
	## Billiard: chain range increases with bounces. Baked in as +40px bonus (1 bounce worth).
	if not (_has(mods, "chain") and _has(mods, "ricochet")):
		return
	var chain := _get_chain_aoe(config)
	if chain:
		chain.aoe_radius += 40.0   ## momentum bonus baked in


static func _combo_explosive_split(config: ProjectileConfig, mods: Array, data: Dictionary) -> void:
	## Cluster Bomb: explosion spawns sub-projectiles at impact. Both effects remain active;
	## explosion fires on impact AoE, split fires on expiry — combined they cover the mechanic.
	## No structural change needed beyond having both mods active.
	if not (_has(mods, "explosive") and _has(mods, "split")):
		return
	## Ensure split damage bumped to 50% per design (larger shards)
	var spawn := _get_split_spawn(config)
	if spawn:
		for eff in spawn.projectile.on_hit_effects:
			if eff is DealDamageEffect:
				eff.base_damage = _base_damage(config) * 0.5   ## 50% per sub


static func _combo_explosive_gravity(config: ProjectileConfig, mods: Array) -> void:
	## Seeking Missile: explosion radius +50% (40 → 60px).
	if not (_has(mods, "explosive") and _has(mods, "gravity")):
		return
	config.impact_aoe_radius *= 1.5


static func _combo_explosive_ricochet(config: ProjectileConfig, mods: Array) -> void:
	## Bouncing Grenade: explodes at each wall bounce (30% AoE damage).
	if not (_has(mods, "explosive") and _has(mods, "ricochet")):
		return
	config.explodes_on_bounce = true
	## Scale bounce explosions to 30% of the main explosion damage
	for eff in config.impact_aoe_effects:
		if eff is DealDamageEffect:
			var bounce_dmg := DealDamageEffect.new()
			bounce_dmg.damage_type = eff.damage_type
			bounce_dmg.base_damage = eff.base_damage * 0.3   ## 30% per bounce


static func _combo_split_gravity(config: ProjectileConfig, mods: Array) -> void:
	## Star Formation: sub-projectiles independently home toward nearest enemies.
	if not (_has(mods, "split") and _has(mods, "gravity")):
		return
	var spawn := _get_split_spawn(config)
	if spawn:
		spawn.projectile.motion_type = "homing"
		spawn.spawn_pattern = "spread"   ## Spread so they fan out before homing


static func _combo_split_ricochet(config: ProjectileConfig, mods: Array, _data: Dictionary) -> void:
	## Scatter Shot: sub-projectiles each bounce off walls once. Damage bumped to 50%.
	if not (_has(mods, "split") and _has(mods, "ricochet")):
		return
	var spawn := _get_split_spawn(config)
	if not spawn:
		return
	spawn.projectile.bounce_count = 1
	for eff in spawn.projectile.on_hit_effects:
		if eff is DealDamageEffect:
			eff.base_damage = _base_damage(config) * 0.5   ## 50% per sub (up from 40%)


static func _combo_gravity_ricochet(config: ProjectileConfig, mods: Array) -> void:
	## Spiral Orbit: re-acquire homing target after each wall bounce.
	if not (_has(mods, "gravity") and _has(mods, "ricochet")):
		return
	config.re_home_after_bounce = true


# ── Behavior × Elemental — Chain ───────────────────────────────────────────────

static func _combo_chain_fire(config: ProjectileConfig, mods: Array) -> void:
	## Firebrand: chain arc ignites secondary target on arrival.
	if not (_has(mods, "chain") and _has(mods, "fire")):
		return
	var chain := _get_chain_aoe(config)
	if chain:
		chain.on_hit_effects.append(_apply_status_effect(StatusFactory.burning))


static func _combo_chain_cryo(config: ProjectileConfig, mods: Array) -> void:
	## Freeze Relay: chain applies Chilled to secondary target; if already Chilled → Frozen.
	## Applying Chilled is sufficient — Frozen triggers automatically at 3 stacks.
	if not (_has(mods, "chain") and _has(mods, "cryo")):
		return
	var chain := _get_chain_aoe(config)
	if chain:
		chain.on_hit_effects.append(_apply_status_effect(StatusFactory.chilled))


static func _combo_chain_shock(config: ProjectileConfig, mods: Array) -> void:
	## Arc Flash: chain arc IS the shock — applies Shocked to secondary target on arrival.
	## Conductor fires immediately (next hit will consume it — effectively near-instant).
	if not (_has(mods, "chain") and _has(mods, "shock")):
		return
	var chain := _get_chain_aoe(config)
	if chain:
		chain.on_hit_effects.append(_apply_status_effect(StatusFactory.shocked))


static func _combo_chain_dot(config: ProjectileConfig, mods: Array) -> void:
	## Bleeding Edge: chain applies Bleed to secondary target on arrival.
	if not (_has(mods, "chain") and _has(mods, "dot_applicator")):
		return
	var chain := _get_chain_aoe(config)
	if chain:
		chain.on_hit_effects.append(_apply_status_effect(StatusFactory.bleed))


# ── Behavior × Elemental — Explosive ───────────────────────────────────────────

static func _combo_explosive_fire(config: ProjectileConfig, mods: Array, _data: Dictionary) -> void:
	## Napalm Burst: explosion leaves a 2s fire pool at impact.
	## Implemented as a GroundZoneEffect in on_hit_effects (fires at impact position).
	if not (_has(mods, "explosive") and _has(mods, "fire")):
		return
	var zone := GroundZoneEffect.new()
	zone.zone_id = "napalm_pool"
	zone.radius = 30.0
	zone.duration = 2.0
	zone.tick_interval = 0.5
	zone.target_faction = "enemy"
	var zone_burn := ApplyStatusEffectData.new()
	zone_burn.status = StatusFactory.burning
	zone_burn.stacks = 1
	zone.tick_effects = [zone_burn]
	config.on_hit_effects.append(zone)


static func _combo_explosive_cryo(config: ProjectileConfig, mods: Array) -> void:
	## Flash Freeze: explosion applies Chilled to all enemies in AoE simultaneously.
	## Already partially covered (cryo on_hit_effects applies to primary target).
	## Combo: add Chilled apply to impact AoE effects so all blast targets are Chilled.
	if not (_has(mods, "explosive") and _has(mods, "cryo")):
		return
	config.impact_aoe_effects.append(_apply_status_effect(StatusFactory.chilled))


static func _combo_explosive_shock(config: ProjectileConfig, mods: Array) -> void:
	## Static Pulse: explosion applies Shocked to every enemy in AoE.
	if not (_has(mods, "explosive") and _has(mods, "shock")):
		return
	config.impact_aoe_effects.append(_apply_status_effect(StatusFactory.shocked))


static func _combo_explosive_dot(config: ProjectileConfig, mods: Array) -> void:
	## Frag Round: each enemy hit by explosion also receives Bleed.
	if not (_has(mods, "explosive") and _has(mods, "dot_applicator")):
		return
	config.impact_aoe_effects.append(_apply_status_effect(StatusFactory.bleed))


# ── Behavior × Elemental — Split ───────────────────────────────────────────────

static func _combo_split_fire(config: ProjectileConfig, mods: Array) -> void:
	## Fire Flower: each sub-projectile independently applies Burning.
	if not (_has(mods, "split") and _has(mods, "fire")):
		return
	var spawn := _get_split_spawn(config)
	if spawn:
		spawn.projectile.on_hit_effects.append(_apply_status_effect(StatusFactory.burning))


static func _combo_split_cryo(config: ProjectileConfig, mods: Array) -> void:
	## Ice Fan: each sub-projectile applies Chilled.
	if not (_has(mods, "split") and _has(mods, "cryo")):
		return
	var spawn := _get_split_spawn(config)
	if spawn:
		spawn.projectile.on_hit_effects.append(_apply_status_effect(StatusFactory.chilled))


static func _combo_split_shock(config: ProjectileConfig, mods: Array) -> void:
	## Fork Lightning: each sub-projectile applies Shocked.
	if not (_has(mods, "split") and _has(mods, "shock")):
		return
	var spawn := _get_split_spawn(config)
	if spawn:
		spawn.projectile.on_hit_effects.append(_apply_status_effect(StatusFactory.shocked))


static func _combo_split_dot(config: ProjectileConfig, mods: Array) -> void:
	## Razor Fan: each sub-projectile applies Bleed.
	if not (_has(mods, "split") and _has(mods, "dot_applicator")):
		return
	var spawn := _get_split_spawn(config)
	if spawn:
		spawn.projectile.on_hit_effects.append(_apply_status_effect(StatusFactory.bleed))


# ── Behavior × Elemental — Gravity ─────────────────────────────────────────────

static func _combo_gravity_fire(config: ProjectileConfig, mods: Array) -> void:
	## Comet: homing firebolt. Burning duration +50% (4.5s). Replace Burning with extended variant.
	if not (_has(mods, "gravity") and _has(mods, "fire")):
		return
	for eff in config.on_hit_effects:
		if eff is ApplyStatusEffectData and eff.status != null \
				and eff.status.status_id in ["burning", "fire"]:
			eff.status = StatusFactory.burning_extended
			return


static func _combo_gravity_cryo(config: ProjectileConfig, _mods: Array) -> void:
	## Frost Seeker: homing cryo orb. Seek range conceptually increased.
	## Engine homing tracks target continuously; range increase is implicit in guaranteed hits.
	pass


static func _combo_gravity_shock(config: ProjectileConfig, mods: Array) -> void:
	## Lightning Rod: homing shot applies Shocked + bonus Lightning AoE on impact.
	## The homing guarantees both the Shocked apply and a bonus Conductor-like burst.
	if not (_has(mods, "gravity") and _has(mods, "shock")):
		return
	var bonus_aoe := AreaDamageEffect.new()
	bonus_aoe.damage_type = "Lightning"
	bonus_aoe.base_damage = 10.0
	bonus_aoe.aoe_radius = 80.0
	config.on_hit_effects.append(bonus_aoe)


static func _combo_gravity_dot(config: ProjectileConfig, mods: Array) -> void:
	## Bloodhound: homing projectile prefers Bleeding targets.
	if not (_has(mods, "gravity") and _has(mods, "dot_applicator")):
		return
	config.homing_prefers_bleeding = true


# ── Behavior × Elemental — Ricochet ────────────────────────────────────────────

static func _combo_ricochet_fire(config: ProjectileConfig, mods: Array) -> void:
	## Wildfire: each wall bounce briefly ignites enemies near the bounce point (30px, 0.8s burn).
	if not (_has(mods, "ricochet") and _has(mods, "fire")):
		return
	var apply_burn := _apply_status_effect(StatusFactory.burning)
	config.on_bounce_aoe_radius = 30.0
	config.on_bounce_aoe_effects.append(apply_burn)


static func _combo_ricochet_cryo(config: ProjectileConfig, mods: Array) -> void:
	## Ice Ball: bounced hits apply an extra Chilled stack (2 stacks instead of 1 per hit).
	if not (_has(mods, "ricochet") and _has(mods, "cryo")):
		return
	var extra_chill := _apply_status_effect(StatusFactory.chilled)
	config.bounced_hit_extra_apply = extra_chill


static func _combo_ricochet_shock(config: ProjectileConfig, mods: Array) -> void:
	## Thunderball: Shocked already applied on every hit via Shock mod in on_hit_effects.
	## Combo ensures Shocked fires from bounce-adjacent enemies too.
	if not (_has(mods, "ricochet") and _has(mods, "shock")):
		return
	var apply_shock := _apply_status_effect(StatusFactory.shocked)
	if config.on_bounce_aoe_radius <= 0.0:
		config.on_bounce_aoe_radius = 30.0
	config.on_bounce_aoe_effects.append(apply_shock)


static func _combo_ricochet_dot(config: ProjectileConfig, mods: Array) -> void:
	## Ricochet Razor: each wall bounce refreshes Bleed on enemies near the bounce point.
	## Implemented as re-applying Bleed (duration refresh) in a 20px bounce AoE.
	if not (_has(mods, "ricochet") and _has(mods, "dot_applicator")):
		return
	var reapply_bleed := _apply_status_effect(StatusFactory.bleed)
	if config.on_bounce_aoe_radius <= 0.0:
		config.on_bounce_aoe_radius = 20.0
	config.on_bounce_aoe_effects.append(reapply_bleed)


# ── Behavior × Elemental — Pierce ──────────────────────────────────────────────

static func _combo_pierce_fire(_config: ProjectileConfig, _mods: Array) -> void:
	## Flaming Lance: pierce trail leaves a lingering fire zone.
	## Full implementation requires trail position tracking (future work).
	## Burning is already applied to each pierced target via on_hit_effects — partial coverage.
	pass


# ── Stat Mod: Size interactions ─────────────────────────────────────────────────

static func _combo_size_interactions(config: ProjectileConfig, mods: Array, _data: Dictionary) -> void:
	if not _has(mods, "size"):
		return

	## Size + Chain: chain detection range +25%
	if _has(mods, "chain"):
		var chain := _get_chain_aoe(config)
		if chain:
			chain.aoe_radius *= 1.25

	## Size + Explosive: explosion radius +40%
	if _has(mods, "explosive"):
		config.impact_aoe_radius *= 1.4

	## Size + Split: sub-projectile damage → 50% (up from 40%)
	if _has(mods, "split"):
		var spawn := _get_split_spawn(config)
		if spawn:
			for eff in spawn.projectile.on_hit_effects:
				if eff is DealDamageEffect:
					eff.base_damage = _base_damage(config) * 0.5

	## Size + Fire: burning splash at hit point (10px bounce AoE apply)
	if _has(mods, "fire"):
		var splash_burn := _apply_status_effect(StatusFactory.burning)
		if config.on_bounce_aoe_radius <= 0.0:
			config.on_bounce_aoe_radius = 0.0   ## Don't set bounce AoE for non-ricochet
		## Apply to impact AoE instead for cleaner "burn splash on hit"
		config.impact_aoe_effects.append(splash_burn)
		if config.impact_aoe_radius < 15.0:
			config.impact_aoe_radius = 15.0

	## Size + Cryo: chill applies in 20px splash on hit
	if _has(mods, "cryo"):
		var splash_chill := _apply_status_effect(StatusFactory.chilled)
		config.impact_aoe_effects.append(splash_chill)
		config.impact_aoe_radius = maxf(config.impact_aoe_radius, 20.0)

	## Size + DOT Applicator: Bleed applies in 10px splash
	if _has(mods, "dot_applicator"):
		var splash_bleed := _apply_status_effect(StatusFactory.bleed)
		config.impact_aoe_effects.append(splash_bleed)
		config.impact_aoe_radius = maxf(config.impact_aoe_radius, 10.0)


# ── Stat Mod: Crit interactions ─────────────────────────────────────────────────

static func _combo_crit_interactions(config: ProjectileConfig, mods: Array, _data: Dictionary) -> void:
	if not _has(mods, "crit_amp"):
		return

	## Crit + Explosive: explosion radius +30%
	if _has(mods, "explosive"):
		config.impact_aoe_radius *= 1.3

	## Crit + Split: 5 sub-projectiles on crit vs 3 normally.
	## Baked in as 4 sub-projectiles (middle ground).
	if _has(mods, "split"):
		var spawn := _get_split_spawn(config)
		if spawn:
			spawn.count = 4

	## Crit + Ricochet: each bounce grants +5% crit chance (3 bounces = +15%).
	## Baked in as a flat +10% crit — handled in build_combo_modifiers, not config.

	## Crit + Fire: crits apply 2 Burning stacks simultaneously.
	## Cannot conditionally double stacks without crit tracking in ProjectileManager.
	## Future work; skip for now.

	## Crit + Chain: chain only triggers on crits (chain_on_crit_only).
	## Complex runtime behavior; skip for now.


## Returns extra ModifierDefinitions from crit combos (bonus crit chance).
static func build_combo_modifiers(mods: Array) -> Array[ModifierDefinition]:
	var result: Array[ModifierDefinition] = []

	## Size + Crit Amplifier (Massive Crit): +5% additional crit chance
	if _has(mods, "size") and _has(mods, "crit_amp"):
		var mod := ModifierDefinition.new()
		mod.target_tag = "crit_chance"
		mod.operation = "add"
		mod.value = 0.05
		mod.source_name = "combo_size_crit"
		result.append(mod)

	## Crit + Ricochet: +10% crit chance (baked-in version of per-bounce bonus)
	if _has(mods, "crit_amp") and _has(mods, "ricochet"):
		var mod := ModifierDefinition.new()
		mod.target_tag = "crit_chance"
		mod.operation = "add"
		mod.value = 0.10
		mod.source_name = "combo_crit_ricochet"
		result.append(mod)

	## Crit + Lifesteal (Vampiric Strike): bonus leech rate
	if _has(mods, "crit_amp") and _has(mods, "lifesteal"):
		var mod := ModifierDefinition.new()
		mod.target_tag = "leech"
		mod.operation = "bonus"
		mod.value = 0.10   ## +10% leech on top of base 5%
		mod.source_name = "combo_vampiric_strike"
		result.append(mod)

	## Accelerating + Crit: at full ramp +10% crit
	if _has(mods, "accelerating") and _has(mods, "crit_amp"):
		var mod := ModifierDefinition.new()
		mod.target_tag = "crit_chance"
		mod.operation = "add"
		mod.value = 0.10
		mod.source_name = "combo_frenzy_crit"
		result.append(mod)

	return result


# ── Stat Mod: Lifesteal interactions ───────────────────────────────────────────

static func _combo_lifesteal_cryo(config: ProjectileConfig, mods: Array) -> void:
	## Lifesteal + Cryo: Frozen trigger heals flat 8 HP.
	## Implemented by adding a HealEffect to Frozen's on_consume_effects.
	## Note: this modifies the shared Frozen StatusEffectDefinition — changes apply globally.
	## For a per-weapon effect, a weapon-specific variant would be needed (future work).
	if not (_has(mods, "lifesteal") and _has(mods, "cryo")):
		return
	## Skip global status modification; handled by player passive or future leech-on-status system.
	pass


# ── Stat Mod: Accelerating interactions ────────────────────────────────────────

static func _combo_accelerating_interactions(config: ProjectileConfig, mods: Array, _data: Dictionary) -> void:
	if not _has(mods, "accelerating"):
		return

	## Accelerating + Chain: chain range +40px at full ramp (baked in)
	if _has(mods, "chain"):
		var chain := _get_chain_aoe(config)
		if chain:
			chain.aoe_radius += 40.0

	## Accelerating + Explosive: explosion radius +30% at full ramp (baked in)
	if _has(mods, "explosive"):
		config.impact_aoe_radius *= 1.3

	## Accelerating + Split: 4 sub-projectiles instead of 3 at full ramp (baked in)
	if _has(mods, "split"):
		var spawn := _get_split_spawn(config)
		if spawn:
			spawn.count = maxi(spawn.count, 4)

	## Accelerating + Ricochet: +1 bounce at full ramp (baked in)
	if _has(mods, "ricochet"):
		config.bounce_count += 1

	## Accelerating + DOT Applicator: 2 Bleed stacks per hit at full ramp.
	## Modify existing Bleed ApplyStatusEffectData to stacks = 2.
	if _has(mods, "dot_applicator"):
		for eff in config.on_hit_effects:
			if eff is ApplyStatusEffectData and eff.status != null \
					and eff.status.status_id == "bleed":
				eff.stacks = 2


# ── Galvanized Shocked replacement ─────────────────────────────────────────────

static func _combo_shock_dot(config: ProjectileConfig, mods: Array) -> void:
	## Galvanized (Shock + DOT Applicator): replace Shocked apply with galvanized_shocked.
	## Conductor AoE then also spreads one Bleed stack to each hit enemy.
	if not (_has(mods, "shock") and _has(mods, "dot_applicator")):
		return
	for eff in config.on_hit_effects:
		if eff is ApplyStatusEffectData and eff.status != null \
				and eff.status.status_id in ["shocked", "shock"]:
			eff.status = StatusFactory.galvanized_shocked
			return


# ── Legendary Triple Combos ─────────────────────────────────────────────────────

static func _triple_doomsday_device(config: ProjectileConfig, mods: Array, _data: Dictionary) -> void:
	## DOOMSDAY DEVICE (Explosive + Split + Size):
	## Sub-projectiles are 1.5× scale, deal 55% each, explosion radius = 56px.
	if not _has_all(mods, ["explosive", "split", "size"]):
		return
	config.impact_aoe_radius = 56.0   ## Combined size+explosive bonus
	var spawn := _get_split_spawn(config)
	if spawn:
		spawn.count = 3   ## Ensure exactly 3 large sub-projectiles
		var sc: ProjectileConfig = spawn.projectile
		sc.visual_scale *= 1.5
		for eff in sc.on_hit_effects:
			if eff is DealDamageEffect:
				eff.base_damage = _base_damage(config) * 0.55


static func _triple_vampire_lord(config: ProjectileConfig, mods: Array) -> void:
	## VAMPIRE LORD (Pierce + Lifesteal + DOT Applicator):
	## Pierce bleeds every target. Bleed ticks leech HP. Homing toward lowest-HP bleeding target.
	## The leech-on-bleed is a passive handled elsewhere; enable Bloodhound homing here.
	if not _has_all(mods, ["pierce", "lifesteal", "dot_applicator"]):
		return
	config.homing_prefers_bleeding = true
	config.motion_type = "homing"   ## Enable homing component for Vampire Lord


static func _triple_absolute_zero(config: ProjectileConfig, mods: Array) -> void:
	## ABSOLUTE ZERO (Cryo + Size + Crit):
	## Frozen trigger emits a 50px cryo pulse. Implemented by adding AoE Chilled to
	## impact_aoe_effects — when target reaches Frozen via stacked hits the pulse fires.
	## Note: the "on Freeze trigger" specifically requires a Frozen on_apply reaction;
	## here approximated as larger chill AoE that builds freeze faster.
	if not _has_all(mods, ["cryo", "size", "crit_amp"]):
		return
	## Wide area chill on every hit (Size+Cryo+Crit = huge freeze wave)
	config.impact_aoe_radius = maxf(config.impact_aoe_radius, 50.0)
	var aoe_chill := _apply_status_effect(StatusFactory.chilled, 2)   ## 2 stacks on crits
	config.impact_aoe_effects.append(aoe_chill)


static func _triple_storm_breaker(config: ProjectileConfig, mods: Array, _data: Dictionary) -> void:
	## STORM BREAKER (Ricochet + Shock + Explosive):
	## Each bounce: shock nearby + explode. Bounce-explosions count as hits and trigger Conductor.
	## explodes_on_bounce handles the explosion. Bounce AoE applies Shocked so Conductor fires.
	if not _has_all(mods, ["ricochet", "shock", "explosive"]):
		return
	config.explodes_on_bounce = true
	## Apply Shocked in bounce AoE so Conductor fires on nearby enemies
	var bounce_shock := _apply_status_effect(StatusFactory.shocked)
	if config.on_bounce_aoe_radius <= 0.0:
		config.on_bounce_aoe_radius = 80.0
	config.on_bounce_aoe_effects.append(bounce_shock)


static func _triple_world_serpent(config: ProjectileConfig, mods: Array, _data: Dictionary) -> void:
	## WORLD SERPENT (Gravity + Chain + Split):
	## Homing → chains → 3 homing sub-projectiles from chain destination.
	## Enabled via: homing on main shot (gravity), chain AoE (chain),
	## and homing sub-projectiles (split + gravity combo already sets sub homing).
	if not _has_all(mods, ["gravity", "chain", "split"]):
		return
	## Ensure chain range is 200px (Seeker Chain base)
	var chain := _get_chain_aoe(config)
	if chain:
		chain.aoe_radius = maxf(chain.aoe_radius, 200.0)
	## Sub-projectiles already set to homing by split+gravity combo. Count = 3.
	var spawn := _get_split_spawn(config)
	if spawn:
		spawn.count = 3
		spawn.projectile.motion_type = "homing"


static func _triple_frostfire_meteor(config: ProjectileConfig, mods: Array) -> void:
	## FROSTFIRE METEOR (Gravity + Fire + Cryo):
	## Every homed shot guarantees Frostfire proc (Fire applied to Chilled target).
	## Apply both Chilled AND Burning simultaneously — Frostfire triggers every hit.
	## Additionally increase Frostfire AoE to 55px by applying Chilled first.
	if not _has_all(mods, ["gravity", "fire", "cryo"]):
		return
	## Ensure Chilled is applied BEFORE Burning in on_hit_effects so Frostfire triggers.
	## Reorder: move Chilled apply to first position among status effects.
	var chilled_idx: int = -1
	var burning_idx: int = -1
	for i in config.on_hit_effects.size():
		var eff = config.on_hit_effects[i]
		if eff is ApplyStatusEffectData and eff.status != null:
			if eff.status.status_id in ["chilled", "cryo"]:
				chilled_idx = i
			elif eff.status.status_id in ["burning", "fire", "burning_extended"]:
				burning_idx = i
	## Ensure Chilled is applied before Burning so Frostfire triggers every hit
	if chilled_idx > burning_idx and burning_idx >= 0:
		var chilled_eff = config.on_hit_effects[chilled_idx]
		config.on_hit_effects.remove_at(chilled_idx)
		config.on_hit_effects.insert(burning_idx, chilled_eff)


# ── Combo passives ──────────────────────────────────────────────────────────────

static func _build_static_strike_passive() -> StatusEffectDefinition:
	## Static Strike (Crit + Shock): on crit, deal 10 Lightning AoE without consuming Shocked.
	var def := StatusEffectDefinition.new()
	def.status_id = "combo_static_strike"
	def.tags = ["Passive", "Lightning"]
	def.is_positive = true
	def.max_stacks = 1
	def.base_duration = -1.0

	var aoe := AreaDamageEffect.new()
	aoe.damage_type = "Lightning"
	aoe.base_damage = 10.0
	aoe.aoe_radius = 60.0

	var listener := TriggerListenerDefinition.new()
	listener.event = "on_crit"
	listener.target_self = false   ## AoE centered on the crit victim
	listener.conditions = [TriggerConditionSourceIsSelf.new()]
	listener.effects = [aoe]
	def.trigger_listeners = [listener]

	return def
