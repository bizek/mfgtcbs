class_name BalanceChain
extends RefCounted

## BalanceChain — the ONE walker over a kit's combo graphs.
##
## ── Why this is its own class ─────────────────────────────────────────────────
##
## Two things need to agree about what a phase is called: the registry, which emits a
## BalanceField per tunable number, and the applier, which stamps the tuned value back onto
## the built kit. If those two computed the address separately they would drift the moment
## a graph gained a repeated animation name, and the failure would be silent — the editor
## would show a spinbox, you would move it, save it, and nothing would change in the game.
##
## That failure mode has bitten this project repeatedly (see the `scale_aoe` inert-param
## note and ClassModFactory.validate_anim_targets). So both callers walk through here, and
## the address is computed exactly once.
##
## ── Addressing ────────────────────────────────────────────────────────────────
##
## A phase is `<graph>/<animation>`, matching the convention ClassModData and
## AbilityUpgradeData already use, so a renamed phase orphans its override VISIBLY
## (BalanceRegistry.orphaned_paths reports it) instead of silently landing on a neighbour —
## which is what addressing by phase index would do. An animation repeated inside one graph
## gets a `#2`, `#3` suffix in walk order.
##
## Effects inside a phase are addressed by type ordinal — `aoe0`, `proj1`, `zone0` — which
## is stable as long as the phase's effect composition is.


## Call `fn(graph: String, addr: String, phase: ChoreographyPhase)` for every phase in
## `abilities` ({ graph_name: AbilityDefinition }), in deterministic order.
static func walk(abilities: Dictionary, fn: Callable) -> void:
	if not fn.is_valid():
		return
	for graph: String in abilities.keys():
		var ability: AbilityDefinition = abilities[graph]
		if ability == null or ability.choreography == null:
			continue
		var seen: Dictionary = {}
		for phase: ChoreographyPhase in ability.choreography.phases:
			var anim: String = phase.animation
			if anim == "":
				anim = "(no anim)"
			var n: int = int(seen.get(anim, 0)) + 1
			seen[anim] = n
			fn.call(graph, (anim if n == 1 else "%s#%d" % [anim, n]), phase)


## Stamp every authored override for `kit_id` onto an already-built kit, in place.
##
## Runs AFTER class mods and run upgrades in player._load_combo, so a tuned base value is
## what those layers multiply — the editor sets what the phase IS, and the mod layer keeps
## meaning "+35% of whatever it is". Every rebuild starts from a pristine ChainFactory
## build, so nothing accumulates across rebuilds.
static func apply(kit_id: String, abilities: Dictionary) -> void:
	walk(abilities, func(graph: String, addr: String, phase: ChoreographyPhase) -> void:
		_apply_phase(kit_id, graph, addr, phase))


static func _apply_phase(kit_id: String, graph: String, addr: String,
		phase: ChoreographyPhase) -> void:
	if phase.exit_type == "wait":
		phase.wait_duration = BalanceOverrides.get_float(
				BalanceOverrides.chain_path(kit_id, graph, addr, "window"), phase.wait_duration)
	phase.telegraph_speed_scale = BalanceOverrides.get_float(
			BalanceOverrides.chain_path(kit_id, graph, addr, "telegraph"), phase.telegraph_speed_scale)
	phase.hit_frame = BalanceOverrides.get_int(
			BalanceOverrides.chain_path(kit_id, graph, addr, "hit_frame"), phase.hit_frame)
	_apply_effects(kit_id, graph, addr, phase.effects)


## Mirror of BalanceRegistry._effect_fields — same ordinals, same field names. Any tunable
## added there needs its line here, and the editor's own self-check (the footer's "inert"
## count, via BalanceRegistry.orphaned_paths) is what catches a miss.
static func _apply_effects(kit_id: String, graph: String, addr: String, effects: Array) -> void:
	var aoe_i: int = 0
	var proj_i: int = 0
	var zone_i: int = 0
	var heal_i: int = 0
	var dmg_i: int = 0
	var shield_i: int = 0

	for e in effects:
		if e is AreaDamageEffect:
			var ad: AreaDamageEffect = e
			ad.base_damage = _f(kit_id, graph, addr, "aoe%d_damage" % aoe_i, ad.base_damage)
			ad.aoe_radius = _f(kit_id, graph, addr, "aoe%d_radius" % aoe_i, ad.aoe_radius)
			ad.aoe_forward_offset = _f(kit_id, graph, addr, "aoe%d_offset" % aoe_i, ad.aoe_forward_offset)
			aoe_i += 1
		elif e is SpawnProjectilesEffect:
			var sp: SpawnProjectilesEffect = e
			sp.count = _i(kit_id, graph, addr, "proj%d_count" % proj_i, sp.count)
			sp.spread_angle = _f(kit_id, graph, addr, "proj%d_spread" % proj_i, sp.spread_angle)
			if sp.projectile != null:
				var pc: ProjectileConfig = sp.projectile
				pc.speed = _f(kit_id, graph, addr, "proj%d_speed" % proj_i, pc.speed)
				pc.hit_radius = _f(kit_id, graph, addr, "proj%d_hit_radius" % proj_i, pc.hit_radius)
				pc.pierce_count = _i(kit_id, graph, addr, "proj%d_pierce" % proj_i, pc.pierce_count)
				pc.max_range = _f(kit_id, graph, addr, "proj%d_range" % proj_i, pc.max_range)
			proj_i += 1
		elif e is GroundZoneEffect:
			var gz: GroundZoneEffect = e
			gz.radius = _f(kit_id, graph, addr, "zone%d_radius" % zone_i, gz.radius)
			gz.duration = _f(kit_id, graph, addr, "zone%d_duration" % zone_i, gz.duration)
			gz.tick_interval = _f(kit_id, graph, addr, "zone%d_tick" % zone_i, gz.tick_interval)
			zone_i += 1
		elif e is HealEffect:
			var he: HealEffect = e
			he.base_healing = _f(kit_id, graph, addr, "heal%d_amount" % heal_i, he.base_healing)
			he.percent_max_hp = _f(kit_id, graph, addr, "heal%d_pct" % heal_i, he.percent_max_hp)
			heal_i += 1
		elif e is DealDamageEffect:
			var dd: DealDamageEffect = e
			dd.base_damage = _f(kit_id, graph, addr, "dmg%d_damage" % dmg_i, dd.base_damage)
			dmg_i += 1
		elif e is ApplyShieldEffect:
			var sh: ApplyShieldEffect = e
			sh.base_shield = _f(kit_id, graph, addr, "shield%d_amount" % shield_i, sh.base_shield)
			shield_i += 1


static func _f(kit_id: String, graph: String, addr: String, field: String, fallback: float) -> float:
	return BalanceOverrides.get_float(BalanceOverrides.chain_path(kit_id, graph, addr, field), fallback)


static func _i(kit_id: String, graph: String, addr: String, field: String, fallback: int) -> int:
	return BalanceOverrides.get_int(BalanceOverrides.chain_path(kit_id, graph, addr, field), fallback)
