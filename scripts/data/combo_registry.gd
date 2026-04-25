## ComboRegistry — static data factory for all mod combos
## Built from mod_interaction_matrix.md (2026-04-10)
## 69 authored doubles + 8 triples = 77 total combos

class_name ComboRegistry

static func build_registry() -> Array[ModCombo]:
	var combos: Array[ModCombo] = []

	# ============================================================================
	# SECTION 1: BEHAVIOR × BEHAVIOR (15 combos)
	# ============================================================================

	combos.append(_create_combo(
		"shrapnel_storm", "Shrapnel Storm",
		["pierce", "chain"],
		"Projectile pierces up to 3 enemies; each pierced enemy chains to the nearest un-pierced enemy within 120px at 60% damage.",
		ModCombo.ComboType.BEHAVIOR_BEHAVIOR,
		"chain_arc",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.12, "+12% chain radius")
	))

	combos.append(_create_combo(
		"tunnel_bomb", "Tunnel Bomb",
		["pierce", "explosive"],
		"Projectile pierces silently through all targets. On pierce-expiry, a delayed explosion fires backward along the travel path.",
		ModCombo.ComboType.BEHAVIOR_BEHAVIOR,
		"delayed_explosion",
		_make_bonus(MasteryBonus.BonusType.DAMAGE_INCREASE, 0.12, "+12% explosion damage")
	))

	combos.append(_create_combo(
		"flechette", "Flechette",
		["pierce", "split"],
		"On expiry, the 3 sub-projectiles each inherit pierce (1 each). Sub-projectile damage is 40% of base.",
		ModCombo.ComboType.BEHAVIOR_BEHAVIOR,
		"piercing_spread",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.10, "+10% spread radius")
	))

	combos.append(_create_combo(
		"needle_vortex", "Needle Vortex",
		["pierce", "gravity"],
		"Projectile homes toward the nearest enemy. On contact, it pierces through them and continues in a straight line.",
		ModCombo.ComboType.BEHAVIOR_BEHAVIOR,
		"homing_pierce",
		_make_bonus(MasteryBonus.BonusType.DAMAGE_INCREASE, 0.10, "+10% pierce damage")
	))

	combos.append(_create_combo(
		"phase_bolt", "Phase Bolt",
		["pierce", "ricochet"],
		"Projectile pierces enemies AND bounces off walls. Each wall bounce resets the pierce counter to full (3).",
		ModCombo.ComboType.BEHAVIOR_BEHAVIOR,
		"bouncing_pierce",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.10, "+10% bounce radius")
	))

	combos.append(_create_combo(
		"bouncing_bomb", "Bouncing Bomb",
		["chain", "explosive"],
		"On chain arrival at the secondary target, an explosion fires at the chain destination (not the origin).",
		ModCombo.ComboType.BEHAVIOR_BEHAVIOR,
		"chained_explosion",
		_make_bonus(MasteryBonus.BonusType.DAMAGE_INCREASE, 0.12, "+12% explosion damage")
	))

	combos.append(_create_combo(
		"hydra", "Hydra",
		["chain", "split"],
		"On chain arrival, the chained projectile splits into 3 sub-projectiles at the chain destination. Each can chain once more.",
		ModCombo.ComboType.BEHAVIOR_BEHAVIOR,
		"chained_split",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.12, "+12% split spread radius")
	))

	combos.append(_create_combo(
		"seeker_chain", "Seeker Chain",
		["chain", "gravity"],
		"The chain bounce is guided: bounces to the nearest enemy to the chain target, extending chain range to 200px.",
		ModCombo.ComboType.BEHAVIOR_BEHAVIOR,
		"guided_chain",
		_make_bonus(MasteryBonus.BonusType.DAMAGE_INCREASE, 0.10, "+10% chain damage")
	))

	combos.append(_create_combo(
		"billiard", "Billiard",
		["chain", "ricochet"],
		"Each wall bounce increases chain range by 40px (base 120px → 200px at 2 bounces). Bounce momentum extends chains.",
		ModCombo.ComboType.BEHAVIOR_BEHAVIOR,
		"bouncing_chain",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.12, "+12% chain radius")
	))

	combos.append(_create_combo(
		"cluster_bomb", "Cluster Bomb",
		["explosive", "split"],
		"The explosion spawns the 3 sub-projectiles outward at the impact point (evenly spread, 120° apart).",
		ModCombo.ComboType.BEHAVIOR_BEHAVIOR,
		"explosive_split",
		_make_bonus(MasteryBonus.BonusType.DAMAGE_INCREASE, 0.12, "+12% explosion damage")
	))

	combos.append(_create_combo(
		"seeking_missile", "Seeking Missile",
		["explosive", "gravity"],
		"Homing projectile. Explosion radius increased by 50% (40px → 60px). The missile locks on and delivers a bigger payload.",
		ModCombo.ComboType.BEHAVIOR_BEHAVIOR,
		"homing_explosive",
		_make_bonus(MasteryBonus.BonusType.DAMAGE_INCREASE, 0.15, "+15% explosion damage")
	))

	combos.append(_create_combo(
		"bouncing_grenade", "Bouncing Grenade",
		["explosive", "ricochet"],
		"Projectile explodes on every wall bounce (up to 3 explosions). Each explosion deals 30% AoE damage independently.",
		ModCombo.ComboType.BEHAVIOR_BEHAVIOR,
		"bouncing_explosive",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.12, "+12% explosion radius")
	))

	combos.append(_create_combo(
		"star_formation", "Star Formation",
		["split", "gravity"],
		"The 3 sub-projectiles all independently home toward the nearest enemies. They acquire separate targets if available.",
		ModCombo.ComboType.BEHAVIOR_BEHAVIOR,
		"homing_spread",
		_make_bonus(MasteryBonus.BonusType.DAMAGE_INCREASE, 0.12, "+12% spread damage")
	))

	combos.append(_create_combo(
		"scatter_shot", "Scatter Shot",
		["split", "ricochet"],
		"Sub-projectiles each bounce off walls once. Sub-projectile damage increases to 50% to compensate for unpredictable angles.",
		ModCombo.ComboType.BEHAVIOR_BEHAVIOR,
		"bouncing_spread",
		_make_bonus(MasteryBonus.BonusType.DAMAGE_INCREASE, 0.10, "+10% spread damage")
	))

	combos.append(_create_combo(
		"spiral_orbit", "Spiral Orbit",
		["gravity", "ricochet"],
		"After each wall bounce, the projectile re-acquires the nearest enemy as a new homing target.",
		ModCombo.ComboType.BEHAVIOR_BEHAVIOR,
		"bouncing_homing",
		_make_bonus(MasteryBonus.BonusType.DAMAGE_INCREASE, 0.10, "+10% damage")
	))

	# ============================================================================
	# SECTION 2: BEHAVIOR × ELEMENTAL (24 combos)
	# ============================================================================

	# Pierce × Elemental (4)
	combos.append(_create_combo(
		"flaming_lance", "Flaming Lance",
		["pierce", "fire"],
		"The pierce trail leaves a lingering fire zone for 1.5s. Enemies that walk through the path take Burning.",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"fire_trail",
		_make_bonus(MasteryBonus.BonusType.DURATION_INCREASE, 1.0, "+1s fire zone duration")
	))

	combos.append(_create_combo(
		"ice_spear", "Ice Spear",
		["pierce", "cryo"],
		"All pierced targets receive Chilled simultaneously in a single pass. If 3+ targets are pierced, the first already-Chilled one is instantly pushed to Frozen.",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"freeze_pierce",
		_make_bonus(MasteryBonus.BonusType.DURATION_INCREASE, 1.0, "+1s Chilled duration")
	))

	combos.append(_create_combo(
		"arc_chain", "Arc Chain",
		["pierce", "shock"],
		"Each additional enemy pierced after the first triggers Conductor on the previous pierced enemy.",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"shock_cascade",
		_make_bonus(MasteryBonus.BonusType.EXTRA_PROC, 0.15, "+15% Conductor proc chance")
	))

	combos.append(_create_combo(
		"bloodletter", "Bloodletter",
		["pierce", "dot_applicator"],
		"Each enemy pierced receives a separate Bleed application with full 4s duration. All bleed timers run independently.",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"bleed_pierce",
		_make_bonus(MasteryBonus.BonusType.DURATION_INCREASE, 1.0, "+1s Bleed duration")
	))

	# Chain × Elemental (4)
	combos.append(_create_combo(
		"firebrand", "Firebrand",
		["chain", "fire"],
		"The chain arc carries fire. The chain destination target is also Ignited on arrival (Burning applied).",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"fire_chain",
		_make_bonus(MasteryBonus.BonusType.DURATION_INCREASE, 1.0, "+1s Burning duration")
	))

	combos.append(_create_combo(
		"freeze_relay", "Freeze Relay",
		["chain", "cryo"],
		"Chain applies Chilled to the secondary target on arrival. If already Chilled, Frozen triggers immediately.",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"freeze_chain",
		_make_bonus(MasteryBonus.BonusType.DURATION_INCREASE, 1.0, "+1s Chilled duration")
	))

	combos.append(_create_combo(
		"arc_flash", "Arc Flash",
		["chain", "shock"],
		"The chain arc itself is treated as a Shocked trigger on the secondary target — Conductor fires immediately.",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"shock_chain",
		_make_bonus(MasteryBonus.BonusType.EXTRA_PROC, 0.15, "+15% Conductor proc chance")
	))

	combos.append(_create_combo(
		"bleeding_edge", "Bleeding Edge",
		["chain", "dot_applicator"],
		"Chain arc applies Bleed to the secondary target on arrival (separate stack from primary).",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"bleed_chain",
		_make_bonus(MasteryBonus.BonusType.DURATION_INCREASE, 1.0, "+1s Bleed duration")
	))

	# Explosive × Elemental (4)
	combos.append(_create_combo(
		"napalm_burst", "Napalm Burst",
		["explosive", "fire"],
		"The explosion leaves a persistent fire pool at the impact point for 2s. Enemies that enter or stand in the pool receive Burning.",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"fire_pool",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.10, "+10% fire pool radius")
	))

	combos.append(_create_combo(
		"flash_freeze", "Flash Freeze",
		["explosive", "cryo"],
		"The explosion applies Chilled to all enemies in the AoE radius simultaneously. Enemies with 2 Chilled stacks are instantly Frozen.",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"freeze_aoe",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.12, "+12% explosion radius")
	))

	combos.append(_create_combo(
		"static_pulse", "Static Pulse",
		["explosive", "shock"],
		"Explosion applies Shocked to every enemy in the AoE. Multiple Shocked enemies in proximity will trigger Conductor on next hit.",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"shock_aoe",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.12, "+12% explosion radius")
	))

	combos.append(_create_combo(
		"frag_round", "Frag Round",
		["explosive", "dot_applicator"],
		"Each enemy hit by the explosion also receives a Bleed (counted as a hit).",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"bleed_aoe",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.10, "+10% explosion radius")
	))

	# Split × Elemental (4)
	combos.append(_create_combo(
		"fire_flower", "Fire Flower",
		["split", "fire"],
		"Each of the 3 sub-projectiles independently applies Burning. Spread shot becomes a three-point igniter.",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"fire_split",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.12, "+12% spread radius")
	))

	combos.append(_create_combo(
		"ice_fan", "Ice Fan",
		["split", "cryo"],
		"Each sub-projectile independently applies Chilled. Wide-spread chill coverage from a single shot.",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"freeze_split",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.12, "+12% spread radius")
	))

	combos.append(_create_combo(
		"fork_lightning", "Fork Lightning",
		["split", "shock"],
		"Each sub-projectile independently applies Shocked. A single shot can apply Shocked to 3 separate targets simultaneously.",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"shock_split",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.12, "+12% spread radius")
	))

	combos.append(_create_combo(
		"razor_fan", "Razor Fan",
		["split", "dot_applicator"],
		"Each sub-projectile independently applies Bleed. Three bleeds in three directions.",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"bleed_split",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.10, "+10% spread radius")
	))

	# Gravity × Elemental (4)
	combos.append(_create_combo(
		"comet", "Comet",
		["gravity", "fire"],
		"Homing firebolt. On impact, Burning is applied with +50% duration (4.5s instead of 3s).",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"homing_fire",
		_make_bonus(MasteryBonus.BonusType.DURATION_INCREASE, 1.0, "+1s Burning duration")
	))

	combos.append(_create_combo(
		"frost_seeker", "Frost Seeker",
		["gravity", "cryo"],
		"Homing cryo orb. Guaranteed hit means guaranteed Chilled. Seek range increases to 200px.",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"homing_freeze",
		_make_bonus(MasteryBonus.BonusType.DURATION_INCREASE, 1.0, "+1s Chilled duration")
	))

	combos.append(_create_combo(
		"lightning_rod", "Lightning Rod",
		["gravity", "shock"],
		"Homing shot that, on impact, applies Shocked and immediately triggers Conductor.",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"homing_shock",
		_make_bonus(MasteryBonus.BonusType.EXTRA_PROC, 0.15, "+15% Conductor proc chance")
	))

	combos.append(_create_combo(
		"bloodhound", "Bloodhound",
		["gravity", "dot_applicator"],
		"Homing projectile preferentially targets bleeding enemies. On hit, Bleed duration refreshes to full.",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"homing_bleed",
		_make_bonus(MasteryBonus.BonusType.DURATION_INCREASE, 1.0, "+1s Bleed duration")
	))

	# Ricochet × Elemental (4)
	combos.append(_create_combo(
		"wildfire", "Wildfire",
		["ricochet", "fire"],
		"Each wall bounce briefly ignites the bounce-point, leaving a 0.8s fire zone. Enemies approaching walls take Burning.",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"bouncing_fire",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.12, "+12% fire zone radius")
	))

	combos.append(_create_combo(
		"ice_ball", "Ice Ball",
		["ricochet", "cryo"],
		"Each enemy hit by a bounced projectile receives an additional Chilled stack. Bouncing builds freeze faster.",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"bouncing_freeze",
		_make_bonus(MasteryBonus.BonusType.DURATION_INCREASE, 1.0, "+1s Chilled duration")
	))

	combos.append(_create_combo(
		"thunderball", "Thunderball",
		["ricochet", "shock"],
		"Projectile applies Shocked on every enemy impact (both first hit and bounced hits).",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"bouncing_shock",
		_make_bonus(MasteryBonus.BonusType.EXTRA_PROC, 0.15, "+15% Conductor proc chance")
	))

	combos.append(_create_combo(
		"ricochet_razor", "Ricochet Razor",
		["ricochet", "dot_applicator"],
		"Each wall bounce refreshes the Bleed duration on currently-bleeding targets near the bounce point (20px radius).",
		ModCombo.ComboType.BEHAVIOR_ELEMENTAL,
		"bouncing_bleed",
		_make_bonus(MasteryBonus.BonusType.DURATION_INCREASE, 1.0, "+1s Bleed duration")
	))

	# ============================================================================
	# SECTION 3: ELEMENTAL × ELEMENTAL (8 combos)
	# ============================================================================

	combos.append(_create_combo(
		"frostfire", "Frostfire",
		["burning", "chilled"],
		"Burning applied to a Chilled target. Consume Chilled → 12 Fire AoE (45px).",
		ModCombo.ComboType.ELEMENTAL_ELEMENTAL,
		"fire_ice_burst",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.15, "+15% AoE radius")
	))

	combos.append(_create_combo(
		"shatter", "Shatter",
		["burning", "frozen"],
		"Burning applied to a Frozen target. Consume Frozen → 20 Ice AoE (50px).",
		ModCombo.ComboType.ELEMENTAL_ELEMENTAL,
		"ice_break",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.15, "+15% AoE radius")
	))

	combos.append(_create_combo(
		"conductor", "Conductor",
		["shocked", "any_hit"],
		"Any hit received while Shocked. Consume Shocked → 10 Lightning AoE (80px).",
		ModCombo.ComboType.ELEMENTAL_ELEMENTAL,
		"chain_lightning",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.15, "+15% AoE radius")
	))

	combos.append(_create_combo(
		"hellfire", "Hellfire",
		["burning", "shocked"],
		"Burning applied to a Shocked target. Consume both → 15 Hellfire AoE (55px). Hybrid Fire+Lightning damage.",
		ModCombo.ComboType.ELEMENTAL_ELEMENTAL,
		"hellfire_burst",
		_make_bonus(MasteryBonus.BonusType.DAMAGE_INCREASE, 0.15, "+15% damage")
	))

	combos.append(_create_combo(
		"superconductor", "Superconductor",
		["chilled", "shocked"],
		"Shocked applied to a Chilled target. Consume Chilled → 18 Cold Lightning AoE (60px).",
		ModCombo.ComboType.ELEMENTAL_ELEMENTAL,
		"cold_shock",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.15, "+15% AoE radius")
	))

	combos.append(_create_combo(
		"searing_wound", "Searing Wound",
		["burning", "bleeding"],
		"Burning active on a target that is also Bleeding. Bleed tick rate doubles. Neither consumed.",
		ModCombo.ComboType.ELEMENTAL_ELEMENTAL,
		"dual_dot",
		_make_bonus(MasteryBonus.BonusType.DURATION_INCREASE, 1.0, "+1s status duration")
	))

	combos.append(_create_combo(
		"hemorrhage", "Hemorrhage",
		["frozen", "bleeding"],
		"Target is both Frozen and Bleeding when Frozen stun expires. Deal bonus damage equal to (Bleed stacks × 5).",
		ModCombo.ComboType.ELEMENTAL_ELEMENTAL,
		"freeze_execute",
		_make_bonus(MasteryBonus.BonusType.DAMAGE_INCREASE, 0.15, "+15% damage")
	))

	combos.append(_create_combo(
		"galvanized", "Galvanized",
		["shocked", "bleeding"],
		"Target is both Shocked and Bleeding; Conductor triggers. Conductor AoE spreads one Bleed stack to each hit enemy.",
		ModCombo.ComboType.ELEMENTAL_ELEMENTAL,
		"shock_bleed_spread",
		_make_bonus(MasteryBonus.BonusType.EXTRA_PROC, 0.15, "+15% Conductor proc chance")
	))

	# ============================================================================
	# SECTION 4: STAT INTERACTIONS (5 distinctively named combos)
	# ============================================================================

	combos.append(_create_combo(
		"massive_crit", "Massive Crit",
		["size", "crit_amplifier"],
		"Larger projectile has +5% additional crit chance (easier to land crits with a bigger hitbox).",
		ModCombo.ComboType.STAT_INTERACTION,
		"crit_indicator",
		_make_bonus(MasteryBonus.BonusType.DAMAGE_INCREASE, 0.15, "+15% crit damage")
	))

	combos.append(_create_combo(
		"static_strike", "Static Strike",
		["crit_amplifier", "shock"],
		"Crits instantly trigger Conductor without consuming Shocked. Shocked status remains; Conductor fires as a bonus.",
		ModCombo.ComboType.STAT_INTERACTION,
		"crit_shock",
		_make_bonus(MasteryBonus.BonusType.EXTRA_PROC, 0.20, "+20% Conductor proc chance")
	))

	combos.append(_create_combo(
		"vampiric_strike", "Vampiric Strike",
		["crit_amplifier", "lifesteal"],
		"Crits leech at 3× rate (15% of crit damage instead of 5%). Burst heal on crits.",
		ModCombo.ComboType.STAT_INTERACTION,
		"lifesteal_crit",
		_make_bonus(MasteryBonus.BonusType.DAMAGE_INCREASE, 0.15, "+15% crit damage")
	))

	combos.append(_create_combo(
		"vital_extraction", "Vital Extraction",
		["lifesteal", "instability_siphon"],
		"Each kill heals (via Lifesteal) AND reduces Instability. Full combat loop — fight well, stay healthy, stay calm.",
		ModCombo.ComboType.STAT_INTERACTION,
		"extraction_heal",
		_make_bonus(MasteryBonus.BonusType.COOLDOWN_REDUCTION, 0.20, "+20% cooldown reduction")
	))

	combos.append(_create_combo(
		"frenzy_extraction", "Frenzy Extraction",
		["instability_siphon", "accelerating"],
		"At full ramp (3s in), all kills reduce Instability by 2 instead of 1. Ramp up → go fast → defuse the timer.",
		ModCombo.ComboType.STAT_INTERACTION,
		"ramp_extraction",
		_make_bonus(MasteryBonus.BonusType.COOLDOWN_REDUCTION, 0.25, "+25% cooldown reduction")
	))

	# ============================================================================
	# SECTION 5: LEGENDARY TRIPLES (8 combos)
	# ============================================================================

	combos.append(_create_combo(
		"doomsday_device", "DOOMSDAY DEVICE",
		["explosive", "split", "size"],
		"Main shot explodes on contact. Explosion spawns 3 large sub-projectiles (1.5× scale, 55% damage each). Triple scaling synergy.",
		ModCombo.ComboType.TRIPLE_LEGENDARY,
		"triple_explosion",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.20, "+20% explosion radius")
	))

	combos.append(_create_combo(
		"vampire_lord", "VAMPIRE LORD",
		["pierce", "lifesteal", "dot_applicator"],
		"Pierce bleeds every target in path. All Bleed ticks leech HP. Triple: projectile homes to most-wounded bleeding target.",
		ModCombo.ComboType.TRIPLE_LEGENDARY,
		"triple_bleed_drain",
		_make_bonus(MasteryBonus.BonusType.DURATION_INCREASE, 2.0, "+2s Bleed duration")
	))

	combos.append(_create_combo(
		"absolute_zero", "ABSOLUTE ZERO",
		["cryo", "size", "crit_amplifier"],
		"Crits apply 2 stacks immediately. Triple: any enemy Frozen while both active emits 50px cryo pulse — secondary AoE freeze wave.",
		ModCombo.ComboType.TRIPLE_LEGENDARY,
		"triple_freeze",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.25, "+25% cryo pulse radius")
	))

	combos.append(_create_combo(
		"storm_breaker", "STORM BREAKER",
		["ricochet", "shock", "explosive"],
		"Shocks on every contact. Each bounce explodes. Triple: each bounce-explosion triggers Conductor on Shocked enemies within 80px.",
		ModCombo.ComboType.TRIPLE_LEGENDARY,
		"triple_shock_explosion",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.20, "+20% explosion radius")
	))

	combos.append(_create_combo(
		"extraction_titan", "EXTRACTION TITAN",
		["instability_siphon", "explosive", "fire"],
		"Explosions leave fire pools. Kills while Burning reduce Instability by 2. Triple: multi-kill explosions reduce by flat 5 additional.",
		ModCombo.ComboType.TRIPLE_LEGENDARY,
		"triple_extraction",
		_make_bonus(MasteryBonus.BonusType.COOLDOWN_REDUCTION, 0.25, "+25% cooldown reduction")
	))

	combos.append(_create_combo(
		"world_serpent", "WORLD SERPENT",
		["gravity", "chain", "split"],
		"Chains on impact. Chain spawns 3 homing sub-projectiles. Triple: each sub also homes to different targets independently.",
		ModCombo.ComboType.TRIPLE_LEGENDARY,
		"triple_homing",
		_make_bonus(MasteryBonus.BonusType.DAMAGE_INCREASE, 0.25, "+25% damage")
	))

	combos.append(_create_combo(
		"crimson_reaper", "CRIMSON REAPER",
		["dot_applicator", "crit_amplifier", "accelerating"],
		"Crits refresh all DoT. At full ramp, each hit applies 2 Bleed. Triple: at full ramp, crits deal bonus dmg = 15% of target's Bleed stacks.",
		ModCombo.ComboType.TRIPLE_LEGENDARY,
		"triple_bleed_crit",
		_make_bonus(MasteryBonus.BonusType.DAMAGE_INCREASE, 0.25, "+25% damage")
	))

	combos.append(_create_combo(
		"frostfire_meteor", "FROSTFIRE METEOR",
		["gravity", "fire", "cryo"],
		"Guaranteed hit applies both Burning and Chilled — triggers Frostfire on every shot. Triple: Frostfire AoE increases to 55px.",
		ModCombo.ComboType.TRIPLE_LEGENDARY,
		"triple_frostfire",
		_make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.25, "+25% AoE radius")
	))

	return combos


static func _create_combo(
	combo_id: StringName,
	name: String,
	mods: Array[StringName],
	description: String,
	combo_type: ModCombo.ComboType,
	vfx_hint: String,
	mastery_bonus: MasteryBonus = null
) -> ModCombo:
	var combo = ModCombo.new()
	combo.combo_id = combo_id
	combo.combo_name = name
	combo.required_mods = mods
	combo.description = description
	combo.combo_type = combo_type
	combo.vfx_hint = vfx_hint
	combo.mastery_bonus = mastery_bonus
	combo.is_authored = true
	return combo


static func _make_bonus(bonus_type: MasteryBonus.BonusType, value: float, description: String) -> MasteryBonus:
	var bonus = MasteryBonus.new()
	bonus.bonus_type = bonus_type
	bonus.bonus_value = value
	bonus.description = description
	return bonus
