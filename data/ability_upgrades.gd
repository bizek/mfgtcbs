class_name AbilityUpgradeData

## AbilityUpgradeData — run-scoped class ability upgrades for the level-up pool (task 33).
##
## One slot per level-up is reserved for these; they reset on UpgradeManager.reset() and never
## persist to ProgressionManager. The vocabulary mirrors ClassModData/ClassModFactory so the
## same _apply_op_to_phase code path handles both:
##
##   op = "scale_aoe"            → multiplies radius/damage of matching phases
##   op = "add_status"           → appends a status effect to matching phases
##   op = "add_projectile_status"→ injects a status into projectile on_hit_effects
##   op = "add_projectiles"      → increments SpawnProjectilesEffect.count
##   op = "modifier"             → adds a player ModifierDefinition (source "ability_upgrade")
##
## modifier entries carry stat/type/value (same shape as generic upgrades) rather than
## target/params, and are applied immediately via player.apply_ability_upgrade — no kit rebuild.
## All other ops require a _load_combo rebuild (ClassModFactory.apply_upgrade_dicts_to_kit).
##
## ── Ranks ─────────────────────────────────────────────────────────────────────
## Every level-up reserves one slot for these, so with one pick per entry a kit ran out of things
## to say about itself at level 4 and the rest of the run was stat sticks. Entries are now
## repeatable up to a per-op cap, which multiplies the offer without inventing filler.
##
## The cap is keyed on the op rather than written onto each entry, because whether an upgrade can
## meaningfully repeat is a property of what the op DOES, not of the individual upgrade:
##
##   scale_aoe / add_projectiles / modifier — repeat cleanly. Two copies multiply or sum, because
##       every rebuild applies each stored dict to a pristine kit.
##   add_status / add_projectile_status     — must NOT repeat. Appending the same status twice
##       leaves the phase applying it twice per hit, which the stacking rules collapse back to one:
##       the second rank would be a pick that visibly does nothing. This is the same silent-no-op
##       class of bug validate_anim_targets exists to catch.
##
## An individual entry can override with an explicit "max_rank" when its numbers do not want to
## triple. Nothing does yet, and the compounding is worth knowing before that changes: ranks
## multiply, so the largest entries in the table (damage_mult 1.50, radius_mult 1.40) reach 3.4x
## damage and 2.7x radius at rank 3. That is intended — three of a run's scarce picks should buy
## something that reshapes the kit — but it is the first dial to reach for if a kit runs away.
const MAX_RANK_BY_OP: Dictionary = {
	"scale_aoe": 3,
	"add_projectiles": 3,
	"modifier": 3,
	"add_status": 1,
	"add_projectile_status": 1,
	## Level-up-layer ops (2026-08-24). extend_window multiplies, so it compounds cleanly, but
	## it is capped at 2 rather than 3: a window is a timing budget, and 3.4x turns a combo into
	## a menu you can walk away from. The other two are one-shot for the same reason add_status
	## is — a second rank would set an already-true boolean, or re-apply a permanent status the
	## player already carries. Both would be picks that visibly do nothing.
	"extend_window": 2,
	"add_iframes": 1,
	"self_status": 1,
	## One-shot. A second rank would append a SECOND echo effect rather than widening the first,
	## so two copies would become four in one step — and the op clones the phase's AoEs at pick
	## time, so the ranks would not even compound evenly. If it should scale, raise `copies`.
	"echo_aoe": 1,
	## Both append a NEW effect rather than scaling one, so a second rank would stack a second
	## ring / a second zone rather than making the first bigger. One-shot until that is the
	## intent; raise the radius or damage_mult instead.
	"add_shockwave": 1,
	"add_ground_zone": 1,
}

## How many times this upgrade may be taken in one run. Explicit "max_rank" wins; otherwise the
## op's default; otherwise 1, so an op added later is one-shot until someone decides it stacks.
static func max_rank_of(entry: Dictionary) -> int:
	if entry.has("max_rank"):
		return maxi(1, int(entry["max_rank"]))
	return int(MAX_RANK_BY_OP.get(entry.get("op", ""), 1))

const ALL: Dictionary = {

	## ── Fighter (The Sellsword) — level-up-layer pilot, 2026-08-24 ────────────
	##
	## All six entries were replaced. The old set (Extended Whirlwind, Cataclysm Aftershock,
	## Tempest Rush, Rushing Tempest, Skullcrusher, Shoulder Charge) was five phase-scalers and a
	## dash-distance stat stick; two of them duplicated a class mod outright (SUSTAINED WHIRLWIND,
	## SHATTERING UPPERCUT) and Tempest Rush duplicated the generic pool's Momentum line.
	##
	## The seam this pilot establishes: a class MOD is equipped in the hub before the run and says
	## what the kit IS, so it owns the numbers — scale_aoe, add_status, add_projectiles all stay
	## there. A LEVEL-UP is picked mid-descent in reaction to how the run is going, so it owns how
	## the kit BEHAVES: what the combo rewards, how long its windows stay open, what it costs to
	## commit. Nothing below can be expressed by any mod op, which is what makes the collision
	## structurally impossible rather than an authoring hazard.
	##
	## Four of the six are the first content anywhere to use the combo events
	## (TriggerComponent learned to hear them the same day). Between them they cover all three:
	## on_finisher_hit, on_combo_step with both condition modes, and on_combo_dropped.
	"fighter_thunderclap": {
		"id": "fighter_thunderclap",
		"name": "Thunderclap",
		"description": "Finishers detonate the ground around you",
		"kit": "fighter",
		"is_ability_upgrade": true,
		"op": "self_status",
		"status_id": "fighter_thunderclap",
	},
	"fighter_spite": {
		"id": "fighter_spite",
		"name": "Spite",
		"description": "A dropped chain detonates instead of fizzling",
		"kit": "fighter",
		"is_ability_upgrade": true,
		"op": "self_status",
		"status_id": "fighter_spite",
	},
	## Targets the heavy opener specifically, not the light graph. Two reasons: uppercut carries
	## the tightest window in the kit (HEAVY_WIN 0.55 against CANCEL_WIN 0.75) and it is the
	## confirm into Cataclysm, the kit's payoff. And a graph-wide target would also have caught
	## the Whirlwind hold phase, whose 0.22s "wait" is a TICK INTERVAL rather than a cancel
	## window — widening that would have slowed the whirlwind while reading as a buff.
	"fighter_patient_blade": {
		"id": "fighter_patient_blade",
		"name": "Patient Blade",
		"description": "Uppercut holds its window into Cataclysm 50% longer",
		"kit": "fighter",
		"is_ability_upgrade": true,
		"op": "extend_window",
		"target": { "graph": "heavy", "anim": "uppercut" },
		"params": { "window_mult": 1.50 },
	},
	## Ben's ask, 2026-09-05: Path of Exile's Ancestral Call. Cataclysm is a single AoE (dmg x1.8,
	## r55) centred on the Sellsword; this repeats it on two other enemies at 60% damage, so a
	## finisher into a pack lands three slams across the fight instead of one under his feet.
	##
	## Graph-less for the same reason as UNBROKEN below — Cataclysm is reachable from the light
	## chain and the heavy, and the pick should mean the same thing however you got there.
	"fighter_ancestral_call": {
		"id": "fighter_ancestral_call",
		"name": "Ancestral Call",
		"description": "Cataclysm slams twice more on nearby enemies",
		"kit": "fighter",
		"is_ability_upgrade": true,
		"op": "echo_aoe",
		"target": { "anim": "cataclysm" },
		"params": { "copies": 2, "damage_mult": 0.60, "radius": 170.0, "separation": 40.0 },
	},
	## No graph key on purpose — Cataclysm is reachable from BOTH the light chain (phase 4) and
	## the heavy (phase 1), and the pick should mean the same thing however you got there.
	## Ben, 2026-09-05, filling the rest of the roster. All three are legible from their own
	## effect — a ring, a burning crater, and a speed you can feel — which is the bar the two cut
	## picks failed.
	##
	## Aftershock and Tempest Break deliberately land on DIFFERENT buttons. Thunderclap, Unbroken
	## and Ancestral Call all fire on Cataclysm, so the light chain had no payoff of its own;
	## Tempest is the light finisher and now ends in something.
	"fighter_aftershock": {
		"id": "fighter_aftershock",
		"name": "Aftershock",
		"description": "Cataclysm leaves the crater burning",
		"kit": "fighter",
		"is_ability_upgrade": true,
		"op": "add_ground_zone",
		"target": { "anim": "cataclysm" },
		"params": { "zone_id": "fighter_aftershock", "radius": 62.0, "duration": 4.0,
					"tick": 0.5, "damage_mult": 0.16, "element": "fire", "damage_type": "Fire" },
	},
	"fighter_tempest_break": {
		"id": "fighter_tempest_break",
		"name": "Tempest Break",
		"description": "Tempest throws out a wide shockwave",
		"kit": "fighter",
		"is_ability_upgrade": true,
		"op": "add_shockwave",
		"target": { "graph": "light", "anim": "tempest" },
		"params": { "radius": 115.0, "damage_mult": 0.55 },
	},
	## A "modifier" op, so it applies instantly with no kit rebuild. FLAT because whirl_speed's
	## base is 0.0 and get_stat is add*(1+bonus) — a percent modifier on a zero base is zero.
	"fighter_whirling_dervish": {
		"id": "fighter_whirling_dervish",
		"name": "Whirling Dervish",
		"description": "+35% Move Speed while whirlwinding",
		"kit": "fighter",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "whirl_speed",
		"type": "flat",
		"value": 0.35,
		## Capped at 2 rather than the modifier default of 3. Three ranks is +105% move speed
		## while spinning, which stops being a whirlwind and starts being a dash you can hold.
		"max_rank": 2,
	},
	## Ben, 2026-09-05, second pass at Rolling Thunder. The first shape — a shockwave per Whirlwind
	## tick — was dropped as a 4.5/sec strobe. A chance-gated bolt on a random nearby enemy keeps
	## the fantasy, costs one sprite when it fires, and borrows the Spark's Electric aura since the
	## Sellsword's pack ships no lightning of its own.
	##
	## A "modifier" op, so it applies with no kit rebuild. FLAT for the same reason as Whirling
	## Dervish: whirl_bolt_chance has a 0.0 base and get_stat is add*(1+bonus).
	"fighter_rolling_thunder": {
		"id": "fighter_rolling_thunder",
		"name": "Rolling Thunder",
		"description": "Whirlwind calls lightning down on nearby enemies",
		"kit": "fighter",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "whirl_bolt_chance",
		"type": "flat",
		"value": 0.20,
		## 2 ranks = 40% per tick, about two bolts a second. Three would be a permanent storm and
		## would start costing frames for the sprites alone.
		"max_rank": 2,
	},
	## Rolling Thunder's capstones (Ben, 2026-09-05: "the lightning bolts look so cool"). Two tiers
	## that each raise the proc chance, gated behind the base pick at full rank so they read as a
	## build rather than three copies of one card.
	##
	## 40 (Rolling Thunder x2) + 30 + 30 lands exactly on 100%, so the last one means "every turn
	## of the spin calls a bolt" — a real end state rather than another increment.
	##
	## is_capstone is a DISPLAY flag only: the level-up card renders gold like an evolution, but
	## apply_upgrade still routes on is_ability_upgrade, so nothing goes near _apply_evolution and
	## nothing gets consumed.
	"fighter_thunderhead": {
		"id": "fighter_thunderhead",
		"name": "Thunderhead",
		"description": "Whirlwind's lightning strikes far more often",
		"kit": "fighter",
		"is_ability_upgrade": true,
		"is_capstone": true,
		"requires": ["fighter_rolling_thunder", "fighter_rolling_thunder"],
		"op": "modifier",
		"stat": "whirl_bolt_chance",
		"type": "flat",
		"value": 0.30,
		"max_rank": 1,
	},
	"fighter_skyfall": {
		"id": "fighter_skyfall",
		"name": "Skyfall",
		"description": "Every turn of the spin calls a bolt",
		"kit": "fighter",
		"is_ability_upgrade": true,
		"is_capstone": true,
		"requires": ["fighter_thunderhead"],
		"op": "modifier",
		"stat": "whirl_bolt_chance",
		"type": "flat",
		"value": 0.30,
		"max_rank": 1,
	},
	"fighter_unbroken": {
		"id": "fighter_unbroken",
		"name": "Unbroken",
		"description": "Nothing can touch you during Cataclysm",
		"kit": "fighter",
		"is_ability_upgrade": true,
		"op": "add_iframes",
		"target": { "anim": "cataclysm" },
	},

	## ── Paladin (The Warden) — level-up-layer pass, 2026-09-06 ────────────────
	##
	## Same pass the Fighter got, and it found one thing the Fighter's did not: HAMMER STORM was
	## scaling the wrong object. "Holy Hammer hits +40% damage" was a scale_aoe on the hammer
	## PHASE, whose only effect is a dmg*0.8 r30 slam under the Warden's feet. The blessed hammers
	## are HolyHammer *entities* spawned host-side (player._spawn_holy_hammers) with their own
	## damage_mult, and no phase op can reach an entity — so the kit's flagship pick barely touched
	## the thing the pick is named after. It is a modifier now, on a real hammer stat.
	##
	## Cut: IRON FAITH (+4 armor — a generic stat stick the generic pool already sells three ways)
	## and SEARING HAMMER (burning on `hammer`, the same pick as CONSECRATED BASH one anim over).
	## CONSECRATED BASH went too: RETRIBUTION DOME (epic class mod) already owns "the Warden sets
	## things alight", and this layer is for things mods cannot express.
	##
	## What the old set never touched at all: the hammerdin spiral, Reckoning's absorb pool, and
	## Aegis Shield — i.e. all three of the Warden's signature systems, because all three are
	## host-side and the pool only spoke phase-op. Six of the eleven below reach them.
	"paladin_hammer_storm": {
		"id": "paladin_hammer_storm",
		"name": "Hammer Storm",
		"description": "Blessed hammers strike +35% harder",
		"kit": "paladin",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "hammer_damage",
		## FLAT, like every host-side kit stat: the base is 0.0 and get_stat is add*(1+bonus),
		## so a percent modifier on it would resolve to zero.
		"type": "flat",
		"value": 0.35,
	},
	## The hammerdin line, and the kit's capstone chain. Chosen for it over Reckoning because the
	## spiral is the Warden's spectacle the way the bolts are the Sellsword's — and `count` scales
	## the spectacle directly, with no new art and no new motion: the golden-angle cycle in
	## _spawn_holy_hammers already fans successive hammers apart, so a throw of five arranges
	## itself.
	"paladin_hammerdin": {
		"id": "paladin_hammerdin",
		"name": "Hammerdin",
		"description": "Holy Hammer throws an extra blessed hammer",
		"kit": "paladin",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "hammer_count",
		"type": "flat",
		"value": 1.0,
		## 2 ranks = 3 hammers a throw. Each lives ~4.1s, so a mashed RMB already keeps a dozen
		## in the air; 3 ranks plus the capstones below would be a node-count problem before it
		## was a balance one.
		"max_rank": 2,
	},
	"paladin_blessed_storm": {
		"id": "paladin_blessed_storm",
		"name": "Blessed Storm",
		"description": "Two more hammers join every throw",
		"kit": "paladin",
		"is_ability_upgrade": true,
		"is_capstone": true,
		"requires": ["paladin_hammerdin", "paladin_hammerdin"],
		"op": "modifier",
		"stat": "hammer_count",
		"type": "flat",
		"value": 2.0,
		"max_rank": 1,
	},
	## The end state, and deliberately not another number: the spiral itself becomes the delivery.
	## Every hammer detonates where it runs out, so a throw blooms a ring of judgement around the
	## Warden a beat later — see holy_hammer.burst_on_expire for why the END of the spiral is the
	## trigger rather than a timer or the cast point.
	"paladin_wrath_of_heaven": {
		"id": "paladin_wrath_of_heaven",
		"name": "Wrath of Heaven",
		"description": "Every hammer detonates where its spiral ends",
		"kit": "paladin",
		"is_ability_upgrade": true,
		"is_capstone": true,
		"requires": ["paladin_blessed_storm"],
		"op": "modifier",
		"stat": "hammer_burst",
		"type": "flat",
		## Fraction of the damage stat per detonation. At the full chain that is 5 blasts a throw,
		## which is why it is well under the 0.9 a hammer already deals on contact.
		"value": 0.55,
		"max_rank": 1,
	},
	## Reckoning (RMB-hold) had no pick at all despite being the kit's most distinctive button.
	## Adds to DOME_REFLECT_MULT rather than scaling it, so the card is a stated number.
	"paladin_judgement": {
		"id": "paladin_judgement",
		"name": "Judgement",
		"description": "Reckoning detonates for far more of what it drank",
		"kit": "paladin",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "reckoning_reflect",
		"type": "flat",
		"value": 0.75,
		## x1.5 base -> x2.25 -> x3.0. A third rank would out-scale the 30%-max-HP absorb cap
		## that feeds it, so the pick would stop meaning anything.
		"max_rank": 2,
	},
	## Aegis Shield (Q) likewise. 25% of max HP -> 40% -> 55%.
	"paladin_unbreakable_oath": {
		"id": "paladin_unbreakable_oath",
		"name": "Unbreakable Oath",
		"description": "Aegis Shield absorbs far more before it breaks",
		"kit": "paladin",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "aegis_bonus",
		"type": "flat",
		"value": 0.15,
		"max_rank": 2,
	},


	## Level-up-layer pass, 2026-09-21. Four of six duplicated a class mod, one by LITERAL NAME:
	##   DIVINE WRATH         divine_fire d1.30 vs PURIFYING FIRE (rare) d1.35
	##   GREATER WORD OF PAIN pray_pain r1.40   vs WORDS OF AGONY (rare) r1.50
	##   GUARDIAN'S WRATH     pray_guardian     vs GUARDIAN'S WRATH (mod) - the same name
	##   KINDLED FIRE         divine_fire burn  vs CENSER EMBERS - same status, same anim
	## SANCTIFIED SMITE and LITANY survive: RADIANT SMITE scales `attack` rather than statusing
	## it, and attack_2 is the one anim no Devout mod touches.
	##
	## The Spirit Guardian - a SpiritGuardian entity with its own DAMAGE_MULT - had nothing in
	## either layer that reached it. The cut GUARDIAN'S WRATH was scaling the summoning prayer.
	"cleric_warden_spirit": {
		"id": "cleric_warden_spirit",
		"name": "Warden Spirit",
		"description": "The guardian smites +25% harder",
		"kit": "cleric",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "guardian_damage",
		## FLAT: base 0.0, get_stat is add*(1+bonus). Added to SpiritGuardian.DAMAGE_MULT, so the
		## chain reads x0.50 -> x0.75 -> x1.00 -> x1.25 of the Devout's damage per smite.
		"type": "flat",
		"value": 0.25,
		"max_rank": 3,
	},
	"cleric_long_vigil": {
		"id": "cleric_long_vigil",
		"name": "Long Vigil",
		"description": "The guardian keeps its watch +8s longer",
		"kit": "cleric",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "guardian_life",
		"type": "flat",
		"value": 8.0,
		## 15s -> 23 -> 31.
		"max_rank": 2,
	},
	## The end state: the prayer is answered twice. A second guardian breaks the single-elite rule
	## on purpose, which is why it costs the whole damage line.
	"cleric_choir_of_spears": {
		"id": "cleric_choir_of_spears",
		"name": "Choir of Spears",
		"description": "A second guardian answers the prayer",
		"kit": "cleric",
		"is_ability_upgrade": true,
		"is_capstone": true,
		"requires": ["cleric_warden_spirit", "cleric_warden_spirit"],
		"op": "modifier",
		"stat": "guardian_count",
		"type": "flat",
		"value": 1.0,
		"max_rank": 1,
	},
	## Phase-op picks on ops no Devout mod uses. Devout mods occupy divine_fire (scale +
	## add_projectile_status x2), pray_pain (scale), attack (scale) and pray_guardian (scale).
	"cleric_censer_sweep": {
		"id": "cleric_censer_sweep", "name": "Censer Sweep",
		"description": "The guardian lands in a ring of holy fire",
		"kit": "cleric", "is_ability_upgrade": true, "op": "add_shockwave",
		"target": { "graph": "skill_e", "anim": "pray_guardian" },
		"params": { "radius": 96.0, "damage_mult": 0.55, "color": Color(1.0, 0.92, 0.55, 0.9) },
	},
	"cleric_consecration": {
		"id": "cleric_consecration", "name": "Consecration",
		"description": "Your smite leaves the ground burning",
		"kit": "cleric", "is_ability_upgrade": true, "op": "add_ground_zone",
		"target": { "graph": "light", "anim": "attack" },
		"params": { "zone_id": "cleric_consecration", "radius": 50.0, "duration": 4.0,
					"tick": 0.5, "damage_mult": 0.12, "element": "fire", "damage_type": "Fire" },
	},
	## The Q is a mend the Devout spends standing still in whatever made her need it.
	"cleric_steadfast": {
		"id": "cleric_steadfast", "name": "Steadfast",
		"description": "Nothing can touch you while you pray",
		"kit": "cleric", "is_ability_upgrade": true, "op": "add_iframes",
		"target": { "graph": "skill_q", "anim": "pray_heal" },
	},
	"cleric_cadence_of_faith": {
		"id": "cleric_cadence_of_faith", "name": "Cadence of Faith",
		"description": "The second strike holds its window 50% longer",
		"kit": "cleric", "is_ability_upgrade": true, "op": "extend_window",
		"target": { "graph": "light", "anim": "attack_2" }, "params": { "window_mult": 1.50 },
	},
	"cleric_judgement_echo": {
		"id": "cleric_judgement_echo", "name": "Echo of Judgement",
		"description": "The guardian's arrival repeats on two more of them",
		"kit": "cleric", "is_ability_upgrade": true, "op": "echo_aoe",
		"target": { "graph": "skill_e", "anim": "pray_guardian" },
		"params": { "copies": 2, "damage_mult": 0.60, "radius": 170.0, "separation": 40.0 },
	},
	"cleric_radiant_volley": {
		"id": "cleric_radiant_volley", "name": "Radiant Volley",
		"description": "Divine Fire looses two more motes",
		"kit": "cleric", "is_ability_upgrade": true, "op": "add_projectiles",
		"target": { "anim": "divine_fire" }, "params": { "count": 2 },
	},
	"cleric_sanctified_smite": {
		"id": "cleric_sanctified_smite",
		"name": "Sanctified Smite",
		"description": "Smite ignites each enemy struck",
		"kit": "cleric",
		"is_ability_upgrade": true,
		"op": "add_status",
		"target": { "anim": "attack" },
		"params": { "status": "burning", "stacks": 1 },
	},


	## The bone-count dial. Bone Swirl's orbiting bones ARE its outgoing volley, so one op grows
	## both: an extra bone rides the ring (player.gd draws the count) and an extra bolt flies out.
	## ── Shade — level-up-layer pass, 2026-09-21 ─────────────────────────────
	##
	## The Shade is the roster's SWARM SUMMONER and not one of the old seven picks reached a
	## skeleton. RISEN HORROR ("Rise Corpse hits +40%") and LEGION SWELL both scaled the dmg*0.3
	## cast pulse that exists only to make choreo_fire_effects run the spawn hook - the same bug as
	## the Warden's HAMMER STORM, twice in one kit. Soul Harvest, the kit's own resource, had
	## nothing in either layer.
	##
	## Cut as class-mod duplicates: GREATER SWIRL (vs SPLINTERING SWIRL, rare, strictly wider),
	## BONE BARRAGE (+1 bone on bone_cast vs ENDLESS BONES and THE OSSUARY, both +2), MARROW ROT
	## (vs MARROW SHARDS - the same status on the same anim), GRAVE VIGOR (+12% max HP vs GRAVE
	## BOND's identical +12%).
	##
	## BONE CHOIR survives: it is the only pick in either layer that reaches the SWIRL's outgoing
	## volley rather than its nova.
	"necro_risen_horror": {
		"id": "necro_risen_horror",
		"name": "Risen Horror",
		"description": "Risen champions cleave +30% harder",
		"kit": "necromancer",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "champion_damage",
		## FLAT: base 0.0, get_stat is add*(1+bonus). Added to SkeletalChampion.BASE_DAMAGE_MULT,
		## so the chain reads x0.60 -> x0.90 -> x1.20 -> x1.50 of the Shade's damage per cleave.
		"type": "flat",
		"value": 0.30,
		"max_rank": 3,
	},
	"necro_mass_grave": {
		"id": "necro_mass_grave",
		"name": "Mass Grave",
		"description": "Rise Corpse raises another champion",
		"kit": "necromancer",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "squad_size",
		"type": "flat",
		"value": 1.0,
		## 4 base -> 6. They fan across ~120 degrees at ~34px, so a squad of six still reads as a
		## rank of risen dead rather than a pile.
		"max_rank": 2,
	},
	## The Bone Legion line, and the kit's capstone chain. Chosen for it over the persistent squad
	## because the legion is the Shade's spectacle - five volatile skeletons sprinting into a pack
	## and going off - and because `count` and `blast` both scale that directly.
	"necro_legion_swell": {
		"id": "necro_legion_swell",
		"name": "Legion Swell",
		"description": "Two more volatile dead rise with the legion",
		"kit": "necromancer",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "legion_size",
		"type": "flat",
		"value": 2.0,
		## 5 base -> 9. They are raised in a ring and scatter outward, so the count is the read.
		"max_rank": 2,
	},
	"necro_volatile_marrow": {
		"id": "necro_volatile_marrow",
		"name": "Volatile Marrow",
		"description": "The dead go off far harder",
		"kit": "necromancer",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "legion_blast",
		"type": "flat",
		"value": 0.40,
		## x0.80 of the Shade's damage per blast -> x1.20 -> x1.60. The blast IS the legion's whole
		## payload (damage_mult is pinned to 0 for volatiles), so this is the line's damage dial.
		"max_rank": 2,
	},
	## The end state, and not another number: the legion stops being a thing you spend. Every blast
	## claws one more skeleton out of its own crater.
	##
	## FINITE BY CONSTRUCTION - SkeletalChampion.chain_raises decrements as it passes down, so one
	## rank is exactly one extra generation. An unbounded chain here is a hang, not a build.
	"necro_chain_of_the_dead": {
		"id": "necro_chain_of_the_dead",
		"name": "Chain of the Dead",
		"description": "Every blast raises one more of them",
		"kit": "necromancer",
		"is_ability_upgrade": true,
		"is_capstone": true,
		"requires": ["necro_legion_swell", "necro_legion_swell"],
		"op": "modifier",
		"stat": "legion_chain",
		"type": "flat",
		"value": 1.0,
		"max_rank": 1,
	},
	## Soul Harvest (the kit passive) banks every kill into a heal and, every third soul, an
	## empowered summon. Neither half had a pick in either layer.
	"necro_reapers_due": {
		"id": "necro_reapers_due",
		"name": "Reaper's Due",
		"description": "Every soul reaped mends far more",
		"kit": "necromancer",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "soul_heal",
		"type": "flat",
		"value": 2.0,
		## 2 HP a kill -> 4 -> 6. Against a horde that is the difference between a trickle and a
		## reason to stand in it.
		"max_rank": 2,
	},
	"necro_grave_hunger": {
		"id": "necro_grave_hunger",
		"name": "Grave Hunger",
		"description": "Souls empower the next raising sooner",
		"kit": "necromancer",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "soul_threshold",
		"type": "flat",
		"value": -1.0,
		## 3 souls -> 2. One-shot: _on_kill_soul_harvest clamps the bar at 1, and a threshold of 1
		## would empower every single summon, which is a different design.
		"max_rank": 1,
	},
	"necro_bone_choir": {
		"id": "necro_bone_choir",
		"name": "Bone Choir",
		"description": "Bone Swirl carries +1 bone - it orbits, then it flies",
		"kit": "necromancer",
		"is_ability_upgrade": true,
		"op": "add_projectiles",
		"target": { "anim": "bone_swirl" },
		"params": { "count": 1 },
	},

	## ── Ranger (The Scavenger) ────────────────────────────────────────────────
	## ── Verdant — level-up-layer pass, 2026-09-21 ────────────────────────
	##
	## A full replacement: all six duplicated a class mod, two of them by LITERAL NAME.
	##   STRANGLING ROOTS  root_cast r1.40   vs STRANGLING ROOTS (rare) r1.50 - same name
	##   THORNED SEEDS     attack bleed      vs THORNED SEEDS (mod) - same name, same status
	##   SEEDSTORM         attack +1 proj    vs BRISTLING VOLLEY / BRAMBLE TIDE (+1 / +2)
	##   WILD BARRAGE      channel d1.30     vs ENDLESS BRAMBLE d1.20
	##   GREATER BEAR      summon_bear scale vs URSINE FURY
	##   PACK LEADER       summon_hounds     vs PACK HUNTER and WILD HUNT
	##
	## The last two are the Warden's HAMMER STORM bug again: a bear and a hound are
	## ForestCompanion ENTITIES with their own per-species damage_mult, and both picks were
	## scaling the summon CAST instead. The animals are the kit - nothing in either layer had
	## ever touched one.
	"druid_ursine_might": {
		"id": "druid_ursine_might",
		"name": "Ursine Might",
		"description": "The bear mauls +30% harder",
		"kit": "druid",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "bear_damage",
		## FLAT: base 0.0, get_stat is add*(1+bonus). Added to the bear's species damage_mult,
		## so the chain reads x0.75 -> x1.05 -> x1.35 -> x1.65 of the Verdant's damage per swipe.
		"type": "flat",
		"value": 0.30,
		"max_rank": 3,
	},
	"druid_pack_fangs": {
		"id": "druid_pack_fangs",
		"name": "Pack Fangs",
		"description": "Hounds bite +20% harder",
		"kit": "druid",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "hound_damage",
		## A hound is deliberately slight (x0.28) and bites twice for every bear swipe, so its
		## dial is smaller: x0.28 -> x0.48 -> x0.68.
		"type": "flat",
		"value": 0.20,
		"max_rank": 2,
	},
	"druid_wild_hunt": {
		"id": "druid_wild_hunt",
		"name": "Wild Hunt",
		"description": "Another hound runs with the pack",
		"kit": "druid",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "hound_count",
		"type": "flat",
		"value": 1.0,
		## A pair -> four. They fan across ~70 degrees and take their own idle spots, so the pack
		## still reads as individual animals rather than one smear.
		"max_rank": 2,
	},
	"druid_deep_roots": {
		"id": "druid_deep_roots",
		"name": "Deep Roots",
		"description": "Your animals stay +10s longer",
		"kit": "druid",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "companion_life",
		"type": "flat",
		"value": 10.0,
		## Bear 20s -> 40, hounds 14s -> 34. One dial for both: they are summoned from the same
		## grove and the pick reads as "the grove holds them longer".
		"max_rank": 2,
	},
	## Level-up-layer pass, 2026-09-21. Four of six duplicated a class mod:
	##   KEEN BLADE  knife d1.50  vs IMPALING KNIFE (rare) d1.50 - the identical number
	##   VENOM TIPS  attack bleed vs BARBED ARROWS, bleed across the whole light graph
	##   RIPOSTE     melee d1.40  vs CLOSE QUARTERS (rare) r1.35 d1.30
	##   EAGLE EYE   a crit stat  vs HUNTER'S FOCUS (+10% crit)
	## TRIPLE VOLLEY and DOUBLE DOWN survive: EXPLOSIVE TIPS and PINNING SHOT status those anims
	## rather than scaling them.
	##
	## The Mirror Archer - a MirrorArcher entity drawing its own bow at damage_mult 0.5 - had no
	## pick in either layer.
	"ranger_mirror_focus": {
		"id": "ranger_mirror_focus",
		"name": "Mirror Focus",
		"description": "The reflection draws +25% harder",
		"kit": "ranger",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "archer_damage",
		## FLAT: base 0.0, get_stat is add*(1+bonus). Added to MirrorArcher.BASE_DAMAGE_MULT, so
		## the chain reads x0.50 -> x0.75 -> x1.00 -> x1.25 per arrow.
		"type": "flat",
		"value": 0.25,
		"max_rank": 3,
	},
	"ranger_lingering_reflection": {
		"id": "ranger_lingering_reflection",
		"name": "Lingering Reflection",
		"description": "The reflection holds +6s longer",
		"kit": "ranger",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "archer_life",
		"type": "flat",
		"value": 6.0,
		## 10s -> 16 -> 22.
		"max_rank": 2,
	},
	## The end state: one reflection becomes a firing line. The pair brackets her aim, one either
	## side, so it reads as being flanked by yourself rather than as a brighter single archer.
	"ranger_hall_of_mirrors": {
		"id": "ranger_hall_of_mirrors",
		"name": "Hall of Mirrors",
		"description": "A second reflection steps out on the other side",
		"kit": "ranger",
		"is_ability_upgrade": true,
		"is_capstone": true,
		"requires": ["ranger_mirror_focus", "ranger_mirror_focus"],
		"op": "modifier",
		"stat": "archer_count",
		"type": "flat",
		"value": 1.0,
		"max_rank": 1,
	},
	## Phase-op picks on ops no Scavenger mod uses. Her mods occupy the light graph
	## (add_projectile_status x3), knife (scale x2), double_shot / triple_shot (status) and
	## heavy/melee (scale).
	"ranger_knife_work": {
		"id": "ranger_knife_work", "name": "Knife Work",
		"description": "The second knife throws a shockwave out with it",
		"kit": "ranger", "is_ability_upgrade": true, "op": "add_shockwave",
		"target": { "graph": "heavy", "anim": "melee_2" },
		"params": { "radius": 84.0, "damage_mult": 0.55, "color": Color(0.80, 0.85, 0.95, 0.9) },
	},
	"ranger_caltrops": {
		"id": "ranger_caltrops", "name": "Caltrops",
		"description": "The close-quarters strike leaves the ground barbed",
		"kit": "ranger", "is_ability_upgrade": true, "op": "add_ground_zone",
		"target": { "graph": "heavy", "anim": "melee" },
		"params": { "zone_id": "ranger_caltrops", "radius": 46.0, "duration": 4.0,
					"tick": 0.5, "damage_mult": 0.13, "element": "poison" },
	},
	"ranger_quickstep": {
		"id": "ranger_quickstep", "name": "Quickstep",
		"description": "Nothing can touch you mid-knife",
		"kit": "ranger", "is_ability_upgrade": true, "op": "add_iframes",
		"target": { "graph": "light", "anim": "knife" },
	},
	"ranger_steady_draw": {
		"id": "ranger_steady_draw", "name": "Steady Draw",
		"description": "The double shot holds its window 50% longer",
		"kit": "ranger", "is_ability_upgrade": true, "op": "extend_window",
		"target": { "graph": "light", "anim": "double_shot" }, "params": { "window_mult": 1.50 },
	},
	## The CHANNEL's volley, not the light chain's - the mod layer only reaches light/triple_shot.
	"ranger_split_volley": {
		"id": "ranger_split_volley", "name": "Split Volley",
		"description": "The held volley looses two more arrows a beat",
		"kit": "ranger", "is_ability_upgrade": true, "op": "add_projectiles",
		"target": { "graph": "channel", "anim": "triple_shot" }, "params": { "count": 2 },
	},
	"ranger_triple_volley": {
		"id": "ranger_triple_volley",
		"name": "Triple Volley",
		"description": "Triple Shot arrows +40% damage",
		"kit": "ranger",
		"is_ability_upgrade": true,
		"op": "scale_aoe",
		"target": { "anim": "triple_shot" },
		"params": { "damage_mult": 1.40 },
	},

	## ── Wizard (The Spark) ────────────────────────────────────────────────────
	##
	## Third kit through the pass, and the worst roster found so far: 5 scale_aoe + 1 stat stick,
	## of which only TWO did what their card said.
	##
	##   FIREBALL EXPANSION ("+35% blast radius") did NOTHING AT ALL. _scale_effects' projectile
	##     branch scaled damage and never radius, so a radius_mult aimed at a Fireball could not
	##     reach impact_aoe_radius — the field the blast actually lives in. Fixed at the root in
	##     class_mod_factory (the branch now scales blast radii, and validate_anim_targets asks
	##     _scale_effects what a param reached so an inert one cannot ship again). The pick is
	##     kept verbatim: it finally means what it always claimed.
	##   TEMPEST CALL ("Storm (E) hits +40% damage") scaled the `storm_cast` phase, whose only
	##     effect is a dmg*0.2 r40 self-pulse that exists to make choreo_fire_effects run the host
	##     hook. Storm Call's real payload is STORM_CALL_DAMAGE_MULT 1.6 per enemy, arena-wide, in
	##     player._storm_strike. The pick moved about 2% of the ability it was named after. It also
	##     shared its id AND its name with the class mod TEMPEST CALL, so the player could be shown
	##     two different "Tempest Call"s in one run.
	##   FAMILIAR FURY ("the summon's burst hits +35%") scaled the dmg*0.4 r24 puff the cast makes.
	##     The familiar is a FireFamiliar entity dealing damage*0.5 of its own; no phase op reaches
	##     an entity. Same bug the Warden's HAMMER STORM had.
	##
	## Cut outright: BURST MASTERY (fireburst radius x1.40 — the uncommon class mod BURST SURGE is
	## the same pick at x1.5) and ARCANE SURGE (+15% damage, which the generic pool sells already).
	##
	## Four host-side seams the old set could not touch: Storm Call's strike, the familiar, the
	## Frost Burst shard aura (pure decoration until now) and the blink.
	"wizard_fireball_expansion": {
		"id": "wizard_fireball_expansion",
		"name": "Fireball Expansion",
		"description": "Fireball +35% blast radius",
		"kit": "wizard",
		"is_ability_upgrade": true,
		"op": "scale_aoe",
		"target": { "anim": "fireball_2" },
		"params": { "radius_mult": 1.35 },
	},
	## The Storm Call line, and the kit's capstone chain. Chosen for it because the sky-strike is
	## the Spark's signature and the best-looking effect in the game (Ben, 2026-09-05, on borrowing
	## it for the Sellsword: "the lightning bolts look so cool") — and because a 16s cooldown makes
	## a big capstone payoff read as earned rather than spammed.
	"wizard_rising_storm": {
		"id": "wizard_rising_storm",
		"name": "Rising Storm",
		"description": "Storm Call strikes +40% harder",
		"kit": "wizard",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "storm_damage",
		## FLAT, like every host-side kit stat: base 0.0, and get_stat is add*(1+bonus).
		## Added to STORM_CALL_DAMAGE_MULT, so the chain reads x1.6 -> x2.0 -> x2.4 -> x2.8.
		"type": "flat",
		"value": 0.40,
		"max_rank": 3,
	},
	"wizard_rolling_front": {
		"id": "wizard_rolling_front",
		"name": "Rolling Front",
		"description": "The storm sweeps back over the field again",
		"kit": "wizard",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "storm_waves",
		"type": "flat",
		"value": 1.0,
		## 2 ranks = 3 field-wide strikes, staggered STORM_WAVE_GAP apart so they read as a front
		## rolling through rather than one brighter flash.
		"max_rank": 2,
	},
	## The end state: the storm stops being an instant and becomes weather. After the last wave the
	## sky keeps picking single targets for 3s — deliberately single-target, because a field-wide
	## strike three times a second is just the whole ability again on a loop.
	"wizard_eye_of_the_storm": {
		"id": "wizard_eye_of_the_storm",
		"name": "Eye of the Storm",
		"description": "The storm refuses to leave - bolts keep falling",
		"kit": "wizard",
		"is_ability_upgrade": true,
		"is_capstone": true,
		"requires": ["wizard_rolling_front", "wizard_rolling_front"],
		"op": "modifier",
		"stat": "storm_linger",
		"type": "flat",
		"value": 3.0,
		"max_rank": 1,
	},
	## The familiar, finally reachable. Both are modifiers because a familiar is an ENTITY.
	"wizard_ember_brood": {
		"id": "wizard_ember_brood",
		"name": "Ember Brood",
		"description": "Summon an extra fire familiar",
		"kit": "wizard",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "familiar_count",
		"type": "flat",
		"value": 1.0,
		## 2 ranks = a brood of 3. They hunt independently inside a 150px leash, so a fourth stops
		## adding anything you can follow and starts adding nodes.
		"max_rank": 2,
	},
	"wizard_everflame": {
		"id": "wizard_everflame",
		"name": "Everflame",
		"description": "Familiars burn +10s longer",
		"kit": "wizard",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "familiar_life",
		"type": "flat",
		"value": 10.0,
		## 15s base -> 25 -> 35. A third rank would outlast the RMB cooldown entirely and turn a
		## summon into a permanent, which is a different design.
		"max_rank": 2,
	},

	## ── Blood Mage (The Cursed) ───────────────────────────────────────────────
	## Level-up-layer pass, 2026-09-12. The worst roster found in the game so far: THREE of the
	## six picks duplicated a class mod outright, and two more were named after things no phase
	## op can reach.
	##
	##   SPIKE FIELD (spikes radius x1.40) vs BLOODQUAKE (rare mod, x1.45 + damage)
	##   CRIMSON SLAM (slam radius x1.35)  vs RUPTURE    (rare mod, x1.40 + damage)
	##   BLOOD FRENZY (+20% damage)        vs DEEPER PACT (uncommon mod, +20% damage)
	##   All three cut. The mods are strictly better versions of the same sentence.
	##
	##   THRALL ("Blood summon (Q) hits +35% damage") scaled the summon CAST's dmg*0.4 r24
	##     ignition puff. The BloodElemental is an entity with its own DAMAGE_MULT and its own
	##     kill-feed growth; no phase op reaches it. Same bug as the Warden's HAMMER STORM and
	##     the Spark's FAMILIAR FURY.
	##   GLUTTONY ("Consume drains +40% harder") scaled the consume beat's dmg*0.15 burst. The
	##     DRAIN - the thing that makes Vampirize a drain - is VAMP_HEAL_FRAC, host-side, and the
	##     pick never touched it.
	##
	## Both keep their names below and finally mean them.
	##
	## Four host-side systems the old set never reached: the vessel, the blood pools' feed, the
	## Vampirize drink, and Extract Power's price.
	"blood_mage_hemorrhage_wave": {
		"id": "blood_mage_hemorrhage_wave",
		"name": "Hemorrhage Wave",
		"description": "Blood Shards +30% projectile damage",
		"kit": "blood_mage",
		"is_ability_upgrade": true,
		"op": "scale_aoe",
		"target": { "anim": "shards" },
		"params": { "damage_mult": 1.30 },
	},
	## The vessel line, and the kit's capstone chain. Chosen for it over the pools because the
	## BloodElemental already GROWS - FEED_SCALE swells the sprite 3.75% per kill - so every pick
	## on this line is visible on the creature itself rather than in a damage number.
	"blood_mage_thrall": {
		"id": "blood_mage_thrall",
		"name": "Thrall",
		"description": "The blood vessel strikes +30% harder",
		"kit": "blood_mage",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "thrall_damage",
		## FLAT: base 0.0, and get_stat is add*(1+bonus). Added to BloodElemental.DAMAGE_MULT,
		## so the chain reads x0.60 -> x0.90 -> x1.20 -> x1.50 of the Cursed's damage per pound.
		"type": "flat",
		"value": 0.30,
		"max_rank": 3,
	},
	"blood_mage_blood_gorged": {
		"id": "blood_mage_blood_gorged",
		"name": "Blood Gorged",
		"description": "The vessel keeps growing on 4 more kills",
		"kit": "blood_mage",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "thrall_feed_cap",
		"type": "flat",
		"value": 4.0,
		## FEED_MAX 8 -> 12 -> 16. At 16 the sprite is 1.60x and the feed has handed it +0.60
		## damage on top of THRALL, which is the point: a fed vessel should look frightening.
		"max_rank": 2,
	},
	"blood_mage_second_vessel": {
		"id": "blood_mage_second_vessel",
		"name": "Second Vessel",
		"description": "The blood stands up twice",
		"kit": "blood_mage",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "thrall_count",
		"type": "flat",
		"value": 1.0,
		## One-shot. Two vessels each feeding to their own cap is already the kit's whole screen;
		## a third would be a node-count decision, not a design one.
		"max_rank": 1,
	},
	## The end state, and not another number: the vessel stops being temporary. Re-summoning still
	## replaces it (16s cooldown), so this reads as "you never lose it" rather than a stack.
	"blood_mage_undying_vessel": {
		"id": "blood_mage_undying_vessel",
		"name": "Undying Vessel",
		"description": "The vessel does not die",
		"kit": "blood_mage",
		"is_ability_upgrade": true,
		"is_capstone": true,
		"requires": ["blood_mage_blood_gorged", "blood_mage_blood_gorged"],
		"op": "modifier",
		"stat": "thrall_immortal",
		"type": "flat",
		"value": 1.0,
		"max_rank": 1,
	},
	## Blood Eruption's pools are the E's whole identity and had no pick at all. The heal is
	## host-side (player._on_any_entity_death), so this could only ever be a stat.
	"blood_mage_bloodletting": {
		"id": "blood_mage_bloodletting",
		"name": "Bloodletting",
		"description": "Dying in your blood feeds you far more",
		"kit": "blood_mage",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "pool_heal",
		"type": "flat",
		"value": 0.03,
		## 3% -> 6% -> 9% of max HP per enemy that dies in a pool.
		"max_rank": 2,
	},
	"blood_mage_gluttony": {
		"id": "blood_mage_gluttony",
		"name": "Gluttony",
		"description": "Vampirize drinks far deeper",
		"kit": "blood_mage",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "vamp_heal",
		"type": "flat",
		"value": 0.02,
		## 2% -> 4% -> 6% of max HP per consume beat, which at VAMP_TICK cadence is the
		## difference between a trickle and actually out-healing a pack.
		"max_rank": 2,
	},
	## Extract Power is a pact you PAY for - 5% max HP on every cast. Nothing in either layer
	## had ever touched the price.
	"blood_mage_sanguine_pact": {
		"id": "blood_mage_sanguine_pact",
		"name": "Sanguine Pact",
		"description": "The pact takes half as much",
		"kit": "blood_mage",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "blood_cost",
		"type": "flat",
		"value": -0.025,
		## One-shot on purpose: a second rank would zero the price, and a pact that costs nothing
		## is just a buff button. _pay_blood_cost clamps at zero regardless.
		"max_rank": 1,
	},

	## ── Demonologist (The Demon) ──────────────────────────────────────────────
	## Level-up-layer pass, 2026-09-14. The first kit where NOTHING from the old set survives,
	## because the old set was the class-mod list in miniature - five of six picks duplicated a
	## mod on the same anim with the same op, four of them strictly worse:
	##
	##   CONFLAGRATION      hellfire_2   dmg x1.35 r x1.20  vs SEARING HELLFIRE  (rare)  r x1.35 dmg x1.20
	##   WIDER CIRCLE       brimstone    r x1.40 dmg x1.20  vs NINEFOLD CIRCLE   (rare)  r x1.40 dmg x1.25
	##   WIDER BREACH       hell_breach  r x1.35            vs BREACH WAKE       (rare)  r x1.40 dmg x1.20
	##   ARCHDEMON'S WRATH  archdemon    r/dmg x1.30        vs ARCHDEMON'S TOLL  (unc.)  r x1.45 dmg x1.25
	##   SUSTAINED HELLFIRE hellfire_ch  dmg x1.35          vs the kit's own EVOLUTION, r x1.30 dmg x1.25
	##   HELLFIRE HEART     +20% damage                     vs GREATER PACT      (unc.)  +15% damage
	##
	## CONFLAGRATION and SEARING HELLFIRE are the same op on the same phase with 1.35 and 1.20
	## assigned to opposite parameters, which is as close to an accident as this layer gets.
	##
	## What neither layer had ever touched: the bound demon (the kit's whole fantasy), the Hell
	## Breach fissure (drawn since it was authored, and dealing nothing), and Ashen Step's burning
	## trail. All three are host-side, which is why a phase-op roster could not see them.
	##
	## The capstone sits on SHARED AGONY because the pact's shared pain is the most distinctive
	## mechanic in the kit and, until now, purely a downside: AngryDemon._poll_pact_pain staggers
	## the bound demon every time the Demon is wounded. The capstone turns that over.
	"demon_bound_elite": {
		"id": "demon_bound_elite",
		"name": "Bound Elite",
		"description": "The bound demon strikes +35% harder",
		"kit": "demonologist",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "demon_damage",
		## FLAT: base 0.0, get_stat is add*(1+bonus). Added to AngryDemon.damage_mult, which starts
		## at a full x1.0 because it is an elite rather than a mook - so this reads x1.00 -> x2.05.
		"type": "flat",
		"value": 0.35,
		"max_rank": 3,
	},
	"demon_ninefold_pact": {
		"id": "demon_ninefold_pact",
		"name": "Ninefold Pact",
		"description": "A second pit opens beside the first",
		"kit": "demonologist",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "demon_count",
		"type": "flat",
		"value": 1.0,
		## One-shot. The Demon is deliberately the single-elite summoner (the Shade is the swarm);
		## two is the most that can be true while the fantasy still reads.
		"max_rank": 1,
	},
	"demon_binding_held": {
		"id": "demon_binding_held",
		"name": "Binding Held",
		"description": "The binding holds +12s longer",
		"kit": "demonologist",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "demon_life",
		"type": "flat",
		"value": 12.0,
		## 30s base -> 42 -> 54. The Q is on a 16s cooldown, so a third rank would make the demon
		## permanent by accident rather than by design.
		"max_rank": 2,
	},
	## The end state, and not another number: the pact stops costing the demon and starts feeding
	## it. Every wound the Demon takes drives his elite into a frenzy instead of a stagger.
	"demon_shared_agony": {
		"id": "demon_shared_agony",
		"name": "Shared Agony",
		"description": "Your wounds enrage the bound demon instead of staggering it",
		"kit": "demonologist",
		"is_ability_upgrade": true,
		"is_capstone": true,
		"requires": ["demon_bound_elite", "demon_bound_elite"],
		"op": "modifier",
		"stat": "demon_rage",
		"type": "flat",
		"value": 1.0,
		"max_rank": 1,
	},
	"demon_infernal_rebirth": {
		"id": "demon_infernal_rebirth",
		"name": "Infernal Rebirth",
		"description": "The binding ends in a detonation",
		"kit": "demonologist",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "demon_burst",
		"type": "flat",
		"value": 0.80,
		## Fires on banish, which is BOTH the lifetime running out and a resummon replacing it -
		## so recasting the Q is itself a detonation, which is the read we want.
		"max_rank": 1,
	},
	## The Hell Breach crack has been drawn since the day it was authored and has never dealt a
	## point of damage: the slam's AoE is centred on the landing, and the fissure races out past it
	## as pure art. This is the pick that makes the long thin part of the move mean something.
	"demon_sundered_earth": {
		"id": "demon_sundered_earth",
		"name": "Sundered Earth",
		"description": "The crack bites what the slam could not reach",
		"kit": "demonologist",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "fissure_damage",
		"type": "flat",
		"value": 0.50,
		"max_rank": 2,
	},
	## Ashen Step (the dash) already leaves burning ground; nothing had ever scaled it.
	"demon_cinder_trail": {
		"id": "demon_cinder_trail",
		"name": "Cinder Trail",
		"description": "The ground you leave burns far hotter",
		"kit": "demonologist",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "ashen_power",
		"type": "flat",
		"value": 0.50,
		## x0.18 of weapon damage a beat -> x0.68 -> x1.18. It is chip damage on a 3s zone you
		## place by retreating, so it can afford to climb.
		"max_rank": 2,
	},


	## ── Gunslinger (The Deadeye) ──────────────────────────────────────────────
	"gunslinger_hair_trigger": {
		"id": "gunslinger_hair_trigger",
		"name": "Hair Trigger",
		"description": "Fan the Hammer fires +2 bullets",
		"kit": "gunslinger",
		"is_ability_upgrade": true,
		"op": "add_projectiles",
		"target": { "anim": "fan" },
		"params": { "count": 2 },
	},
	"gunslinger_storm_surge": {
		"id": "gunslinger_storm_surge",
		"name": "Storm Surge",
		"description": "Desert Storm ticks +35% damage",
		"kit": "gunslinger",
		"is_ability_upgrade": true,
		"op": "scale_aoe",
		"target": { "anim": "storm" },
		"params": { "damage_mult": 1.35 },
	},
	"gunslinger_cold_steel": {
		"id": "gunslinger_cold_steel",
		"name": "Cold Steel",
		"description": "+8% Crit Chance this run",
		"kit": "gunslinger",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "crit_chance",
		"type": "flat",
		"value": 0.08,
	},

	## ══ Second wave (2026-08-07) — three more per kit ═════════════════════════
	##
	## Kept in one block rather than merged into the per-kit sections above so the original
	## three stay legible as the kit's core identity and these read as the depth pass.
	##
	## Every target below was chosen against a dump of the real phase graph (ChainFactory.build_kit
	## + SkillFactory.build_kit_skills), not from memory, and each op matches the effect type
	## actually on that phase — `add_projectiles` only where a SpawnProjectilesEffect exists,
	## `add_projectile_status` only on ranged phases, `scale_aoe` everywhere _scale_effects reaches.
	## `validate_anim_targets()` covers the rest.
	##
	## The bias is deliberate: **Q and E were almost untouched design space.** Of the original 37
	## entries exactly one (ninja_smoke_ambush) targeted a skill, so a kit's two most characterful
	## buttons never grew during a run. Most kits now get at least one upgrade that improves a skill.
	##
	## Two phases carry no effects at all and are NOT valid targets — paladin `dome`, ninja
	## `blades_start`, wizard `fireball`, barbarian `guard`. Neither is a heal-only phase like the
	## cleric's `pray_heal`: _scale_effects has no HealEffect branch, so scaling one does nothing.

	## ── Paladin ───────────────────────────────────────────────────────────────
	## The two survivors of the 2026-09-06 pass (SEARING HAMMER was cut as a duplicate of
	## CONSECRATED BASH), plus the two picks that give Shield Bash and Lay on Hands something.
	"paladin_ringing_dictum": {
		"id": "paladin_ringing_dictum", "name": "Ringing Dictum",
		"description": "Dictum rings out +35% wider",
		"kit": "paladin", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "dictum" }, "params": { "radius_mult": 1.35 },
	},
	"paladin_crusaders_cadence": {
		"id": "paladin_crusaders_cadence", "name": "Crusader's Cadence",
		"description": "Second chain strike hits +30% damage",
		"kit": "paladin", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "attack_2" }, "params": { "damage_mult": 1.30 },
	},
	## Shield Bash is the light chain's finisher and had one pick, which was a status. A zone the
	## shield leaves behind is legible from its own art (GroundZoneVfx draws every zone in the game
	## from vfx_element) and turns the bash into a piece of area denial you place.
	##
	## `fire` because there is no holy tileable in either Spell Effects pack — and consecrated
	## flame is already the Warden's idiom, per RETRIBUTION DOME.
	##
	## Ticks are 0.13 of the bash's own damage, NOT Aftershock's 0.16: the bash lands at dmg*0.9
	## against Cataclysm's dmg*1.8, so the same fraction would put a far larger share of the hit
	## into the floor. (Aftershock itself still wants a look — see its note.)
	"paladin_hallowed_ground": {
		"id": "paladin_hallowed_ground", "name": "Hallowed Ground",
		"description": "Shield Bash consecrates the ground it breaks",
		"kit": "paladin", "is_ability_upgrade": true, "op": "add_ground_zone",
		"target": { "anim": "bash" },
		"params": { "zone_id": "paladin_hallowed_ground", "radius": 58.0, "duration": 4.0,
					"tick": 0.5, "damage_mult": 0.13, "element": "fire", "damage_type": "Fire" },
	},
	## The hammerdin spiral is built by MASHING: every RMB press inside the Hammer node throws
	## another and re-enters the node. So the window is the build's real ceiling — how long the
	## Warden has to confirm the next press before the graph drops him out. This is the only pick
	## in the kit that makes the other four hammer picks easier to actually use.
	"paladin_zeal": {
		"id": "paladin_zeal", "name": "Zeal",
		"description": "Holy Hammer holds its window 50% longer",
		"kit": "paladin", "is_ability_upgrade": true, "op": "extend_window",
		"target": { "anim": "hammer" }, "params": { "window_mult": 1.50 },
	},
	## Lay on Hands (E) is a 20%-max-HP mend with an 11-frame wind-up, and the Warden spends it
	## standing in whatever made him need it. i-frames for the cast are the pick that makes the
	## heal usable at the moment you actually reach for it.
	"paladin_sanctuary": {
		"id": "paladin_sanctuary", "name": "Sanctuary",
		"description": "Nothing can touch you while you mend",
		"kit": "paladin", "is_ability_upgrade": true, "op": "add_iframes",
		"target": { "graph": "skill_e", "anim": "heal_word" },
	},

	## Level-up-layer pass, 2026-09-21. Four of six duplicated a class mod:
	##   BLADE STORM SURGE blades r1.40    vs ENDLESS STORM (rare) r1.50 on the same storm
	##   FINAL CUT         blades_end d1.45 vs FINISHING FLOURISH (rare) r1.35 d1.30
	##   SMOKE AMBUSH      smoke chilled    vs BLINDING SMOKE - the same status on the same anim
	##   KILLING EDGE      a crit stat      vs HONED EDGE, DEEP CUT and SHADOWKILL, all crit
	## TWIN FANGS and SHADOW STEP survive: attack_2 and the dash are untouched by the mod layer.
	##
	## The Whisper is the roster's crit assassin and holds a channel, and nothing joined those
	## two facts - her mods sell crit you carry everywhere. BLADE STORM FOCUS is crit that only
	## exists while the storm is up, which is a reason to hold it.
	"ninja_blade_storm_focus": {
		"id": "ninja_blade_storm_focus",
		"name": "Blade Storm Focus",
		"description": "+15% Crit while the storm is held",
		"kit": "ninja",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "storm_crit",
		## FLAT: base 0.0, get_stat is add*(1+bonus). Applied as a tagged modifier on the
		## channel's edges, so it is gone the moment she lets go.
		"type": "flat",
		"value": 0.15,
		"max_rank": 3,
	},
	## The end state: inside the storm there is no roll left to make.
	"ninja_perfect_silence": {
		"id": "ninja_perfect_silence",
		"name": "Perfect Silence",
		"description": "Every blade lands true while the storm is held",
		"kit": "ninja",
		"is_ability_upgrade": true,
		"is_capstone": true,
		"requires": ["ninja_blade_storm_focus", "ninja_blade_storm_focus"],
		"op": "modifier",
		"stat": "storm_crit",
		"type": "flat",
		## +100 on top of the line: whatever crit she carries, holding the storm guarantees it.
		"value": 1.00,
		"max_rank": 1,
	},
	## The storm's DURATION dial. ENDLESS STORM widens the ring; nothing lengthened the beat it
	## spends spinning, and extend_window on the channel's own looping phase is exactly that.
	"ninja_endless_edge": {
		"id": "ninja_endless_edge", "name": "Endless Edge",
		"description": "The storm holds each beat 50% longer",
		"kit": "ninja", "is_ability_upgrade": true, "op": "extend_window",
		"target": { "graph": "channel", "anim": "blades" }, "params": { "window_mult": 1.50 },
	},
	## Phase-op picks on ops no Whisper mod uses. Her mods occupy the light graph (add_status),
	## blades (scale + add_status), blades_end (scale), smoke and sharpen (add_status).
	"ninja_shadowburst": {
		"id": "ninja_shadowburst", "name": "Shadowburst",
		"description": "The storm ends in a ring of steel",
		"kit": "ninja", "is_ability_upgrade": true, "op": "add_shockwave",
		"target": { "anim": "blades_end" },
		"params": { "radius": 92.0, "damage_mult": 0.55, "color": Color(0.70, 0.75, 0.85, 0.9) },
	},
	"ninja_bloodgrass": {
		"id": "ninja_bloodgrass", "name": "Bloodgrass",
		"description": "Your opener leaves the ground slick",
		"kit": "ninja", "is_ability_upgrade": true, "op": "add_ground_zone",
		"target": { "graph": "light", "anim": "attack" },
		"params": { "zone_id": "ninja_bloodgrass", "radius": 46.0, "duration": 4.0,
					"tick": 0.5, "damage_mult": 0.13, "element": "poison" },
	},
	"ninja_mirror_cuts": {
		"id": "ninja_mirror_cuts", "name": "Mirror Cuts",
		"description": "The storm's last cut repeats on two more of them",
		"kit": "ninja", "is_ability_upgrade": true, "op": "echo_aoe",
		"target": { "anim": "blades_end" },
		"params": { "copies": 2, "damage_mult": 0.60, "radius": 170.0, "separation": 40.0 },
	},
	## The smoke bomb is her disengage and she is standing in the open while it goes off.
	"ninja_vanishing_act": {
		"id": "ninja_vanishing_act", "name": "Vanishing Act",
		"description": "Nothing can touch you in the smoke",
		"kit": "ninja", "is_ability_upgrade": true, "op": "add_iframes",
		"target": { "graph": "skill_e", "anim": "smoke" },
	},
	"ninja_killing_tempo": {
		"id": "ninja_killing_tempo", "name": "Killing Tempo",
		"description": "The second strike holds its window 50% longer",
		"kit": "ninja", "is_ability_upgrade": true, "op": "extend_window",
		"target": { "graph": "light", "anim": "attack_2" }, "params": { "window_mult": 1.50 },
	},
	"ninja_twin_fangs": {
		"id": "ninja_twin_fangs", "name": "Twin Fangs",
		"description": "Second chain strike hits +35% damage",
		"kit": "ninja", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "attack_2" }, "params": { "damage_mult": 1.35 },
	},
	"ninja_shadow_step": {
		"id": "ninja_shadow_step", "name": "Shadow Step",
		"description": "-20% Dash Cooldown this run",
		"kit": "ninja", "is_ability_upgrade": true, "op": "modifier",
		"stat": "dash_cooldown", "type": "percent", "value": -0.20,
	},

	"cleric_litany": {
		"id": "cleric_litany", "name": "Litany",
		"description": "Second chain strike hits +30% damage",
		"kit": "cleric", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "attack_2" }, "params": { "damage_mult": 1.30 },
	},



	## The three phase-op picks that survive the mod diff. Shade mods occupy bone_cast
	## (add_projectiles x2, add_projectile_status), bone_swirl (scale_aoe) and bone_legion
	## (scale_aoe), so these use ops no Shade mod touches.
	## Targeted at the LEGION's raising, not the swirl: bone_swirl carries only its orbiting aura
	## status and no AreaDamageEffect, so add_ground_zone had nothing to scale from there - caught
	## by validate_anim_targets rather than shipped inert.
	"necro_bone_field": {
		"id": "necro_bone_field", "name": "Bone Field",
		"description": "The raising leaves the ground splintered",
		"kit": "necromancer", "is_ability_upgrade": true, "op": "add_ground_zone",
		"target": { "graph": "skill_e", "anim": "bone_legion" },
		"params": { "zone_id": "necro_bone_field", "radius": 52.0, "duration": 4.0,
					"tick": 0.5, "damage_mult": 0.13, "element": "shadow" },
	},
	## Rise Corpse is a 9-frame ritual the Shade spends standing still in front of whatever he is
	## raising the dead to deal with.
	"necro_deathless": {
		"id": "necro_deathless", "name": "Deathless",
		"description": "Nothing can touch you while the dead climb out",
		"kit": "necromancer", "is_ability_upgrade": true, "op": "add_iframes",
		"target": { "graph": "skill_q", "anim": "rise_corpse" },
	},
	## The light chain is Cast -> Cast II -> Bone Missile with Swirl hanging off the second beat;
	## the window on Cast II is the only thing gating both branches.
	"necro_patient_dead": {
		"id": "necro_patient_dead", "name": "Patient Dead",
		"description": "The second cast holds its window 50% longer",
		"kit": "necromancer", "is_ability_upgrade": true, "op": "extend_window",
		"target": { "graph": "light", "anim": "attack_2" }, "params": { "window_mult": 1.50 },
	},

	## ── Ranger ────────────────────────────────────────────────────────────────
	## The phase-op picks that survive the mod diff. Verdant mods occupy attack / attack_2
	## (scale + add_projectiles), root_cast (scale), summon_bear and summon_hounds (scale), so
	## these use ops no Verdant mod touches.
	## The end state, and not another number: the Verdant stops being one bear and a pack. A second
	## bear is the single-elite rule broken on purpose, which is why it costs the whole hound line.
	"druid_second_grove": {
		"id": "druid_second_grove",
		"name": "Second Grove",
		"description": "A second bear answers the call",
		"kit": "druid",
		"is_ability_upgrade": true,
		"is_capstone": true,
		"requires": ["druid_wild_hunt", "druid_wild_hunt"],
		"op": "modifier",
		"stat": "bear_count",
		"type": "flat",
		"value": 1.0,
		"max_rank": 1,
	},
	"druid_verdant_surge": {
		"id": "druid_verdant_surge", "name": "Verdant Surge",
		"description": "The bear arrives hard enough to shake the ground",
		"kit": "druid", "is_ability_upgrade": true, "op": "add_shockwave",
		"target": { "graph": "skill_q", "anim": "summon_bear" },
		"params": { "radius": 98.0, "damage_mult": 0.55, "color": Color(0.45, 0.85, 0.35, 0.9) },
	},
	## The CHANNEL's volley, not the light chain's — BRISTLING VOLLEY and BRAMBLE TIDE both sit on
	## light/attack_2, and the barrage is a separate graph nothing in the mod layer touches.
	"druid_thorn_volley": {
		"id": "druid_thorn_volley", "name": "Thorn Volley",
		"description": "The barrage throws two more seeds a beat",
		"kit": "druid", "is_ability_upgrade": true, "op": "add_projectiles",
		"target": { "graph": "channel", "anim": "attack_2" }, "params": { "count": 2 },
	},
	"druid_bramble_bed": {
		"id": "druid_bramble_bed", "name": "Bramble Bed",
		"description": "The pack tears up the ground it rises from",
		"kit": "druid", "is_ability_upgrade": true, "op": "add_ground_zone",
		"target": { "graph": "skill_e", "anim": "summon_hounds" },
		"params": { "zone_id": "druid_bramble_bed", "radius": 58.0, "duration": 5.0,
					"tick": 0.5, "damage_mult": 0.12, "element": "poison" },
	},
	"druid_grove_guard": {
		"id": "druid_grove_guard", "name": "Grove Guard",
		"description": "Nothing can touch you while the grove answers",
		"kit": "druid", "is_ability_upgrade": true, "op": "add_iframes",
		"target": { "graph": "skill_q", "anim": "summon_bear" },
	},
	"druid_patient_growth": {
		"id": "druid_patient_growth", "name": "Patient Growth",
		"description": "The second volley holds its window 50% longer",
		"kit": "druid", "is_ability_upgrade": true, "op": "extend_window",
		"target": { "graph": "light", "anim": "attack_2" }, "params": { "window_mult": 1.50 },
	},
	"ranger_double_down": {
		"id": "ranger_double_down", "name": "Double Down",
		"description": "Double Shot fires +1 arrow",
		"kit": "ranger", "is_ability_upgrade": true, "op": "add_projectiles",
		"target": { "anim": "double_shot" }, "params": { "count": 1 },
	},

	## ── Wizard ────────────────────────────────────────────────────────────────
	## The one survivor of the 2026-09-12 pass, plus the four picks that give the Fire Burst
	## finisher, the Frost Burst aura and the blink something of their own.
	"wizard_glacial_cast": {
		"id": "wizard_glacial_cast", "name": "Glacial Cast",
		"description": "Ice (Q) freezes a +35% wider circle",
		"kit": "wizard", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "ice_cast" }, "params": { "radius_mult": 1.35 },
	},
	## The Fire Burst finisher already sprays 8 radial bolts; this makes the ring visibly denser.
	## Distinct from the class mod ARCANE MULTIPLICITY, which adds ONE bolt to the chain's OPENER.
	"wizard_cinder_ring": {
		"id": "wizard_cinder_ring", "name": "Cinder Ring",
		"description": "Fire Burst throws 3 more bolts",
		"kit": "wizard", "is_ability_upgrade": true, "op": "add_projectiles",
		"target": { "graph": "light", "anim": "fireburst" }, "params": { "count": 3 },
	},
	## …and the nova it fires from leaves the floor burning. Ticks are 0.12 of the nova's own
	## damage: the nova is dmg*0.9, so this sits below the Warden's HALLOWED GROUND (0.13 off a
	## dmg*0.9 bash) rather than inheriting Aftershock's still-open over-tuning.
	"wizard_ashfall": {
		"id": "wizard_ashfall", "name": "Ashfall",
		"description": "Fire Burst leaves the floor burning",
		"kit": "wizard", "is_ability_upgrade": true, "op": "add_ground_zone",
		"target": { "graph": "light", "anim": "fireburst" },
		"params": { "zone_id": "wizard_ashfall", "radius": 54.0, "duration": 4.0,
					"tick": 0.5, "damage_mult": 0.12, "element": "fire", "damage_type": "Fire" },
	},
	## Frost Burst's shard ring loops on the Spark for 10s and, until now, did NOTHING — it was
	## pure decoration. This is the pick that makes standing your ground mean something.
	"wizard_shardstorm": {
		"id": "wizard_shardstorm", "name": "Shardstorm",
		"description": "The ice shards bite anything that closes in",
		"kit": "wizard", "is_ability_upgrade": true, "op": "modifier",
		"stat": "ice_aura_damage", "type": "flat", "value": 0.15, "max_rank": 2,
	},
	## The Spark's dash is a blink, and it was the only class dash in the kit that left no mark.
	"wizard_flashpoint": {
		"id": "wizard_flashpoint", "name": "Flashpoint",
		"description": "Blinking detonates the spot you left",
		"kit": "wizard", "is_ability_upgrade": true, "op": "modifier",
		"stat": "blink_nova", "type": "flat", "value": 0.60, "max_rank": 2,
	},

	## ── Blood Mage ────────────────────────────────────────────────────────────
	## The three picks that give the Blood Slam, the drain beat and the pact something of their
	## own. THRALL and GLUTTONY moved up into the main block when they were rebuilt as stats.
	##
	## EXSANGUINATE is the reason _register_blood_pool is keyed on the zone's ID now rather than
	## on the spikes anim: a pool dropped by any other phase used to draw and bleed but never
	## feed, because the heal rides that registration.
	"blood_mage_exsanguinate": {
		"id": "blood_mage_exsanguinate", "name": "Exsanguinate",
		"description": "Blood Slam leaves a feeding pool",
		"kit": "blood_mage", "is_ability_upgrade": true, "op": "add_ground_zone",
		"target": { "graph": "heavy", "anim": "slam" },
		"params": { "zone_id": "blood_pool", "radius": 44.0, "duration": 5.0,
					"tick": 0.5, "damage_mult": 0.14, "element": "poison",
					"tint": Color(1.0, 0.28, 0.30) },
	},
	## The extract beat throws a wider ring than it drains. Distinct from THIRSTING VORTEX
	## (uncommon mod), which widens the drain itself rather than adding a second, visible hit.
	"blood_mage_arterial_spray": {
		"id": "blood_mage_arterial_spray", "name": "Arterial Spray",
		"description": "The drain bursts outward as it rips",
		"kit": "blood_mage", "is_ability_upgrade": true, "op": "add_shockwave",
		"target": { "graph": "channel", "anim": "vampirize" },
		"params": { "radius": 96.0, "damage_mult": 0.55, "color": Color(0.85, 0.12, 0.20, 0.9) },
	},
	## Extract Power pays 5% max HP on the hit frame and leaves the Cursed standing in whatever
	## made her need the damage. i-frames for the cast are what make the pact usable in a pack.
	"blood_mage_blood_ward": {
		"id": "blood_mage_blood_ward", "name": "Blood Ward",
		"description": "Nothing can touch you while you pay",
		"kit": "blood_mage", "is_ability_upgrade": true, "op": "add_iframes",
		"target": { "graph": "light", "anim": "extract" },
	},

	## ── Demonologist ──────────────────────────────────────────────────────────
	## The four phase-op picks that survive the mod diff, all on ops no Demon mod uses.
	## Brimstone, Hell Breach and the hellfire poke each keep exactly one.
	"demon_brimstone_toll": {
		"id": "demon_brimstone_toll", "name": "Brimstone Toll",
		"description": "The circle slams a shockwave out with it",
		"kit": "demonologist", "is_ability_upgrade": true, "op": "add_shockwave",
		"target": { "anim": "brimstone" },
		"params": { "radius": 104.0, "damage_mult": 0.55, "color": Color(1.0, 0.35, 0.12, 0.9) },
	},
	## The heavy is Hellfire poke -> Brimstone, and the poke's window is the only thing between
	## them. Widening it is the pick that makes the kit's one real chain reliable.
	"demon_pact_haste": {
		"id": "demon_pact_haste", "name": "Pact Haste",
		"description": "Hellfire holds its window into Brimstone 50% longer",
		"kit": "demonologist", "is_ability_upgrade": true, "op": "extend_window",
		"target": { "graph": "heavy", "anim": "hellfire_2" }, "params": { "window_mult": 1.50 },
	},
	## Hell Breach is a LEAP - frames 2-4 are airborne (chain_factory's frame notes). i-frames for
	## the jump are the rules of the animation rather than a new promise.
	"demon_unbound": {
		"id": "demon_unbound", "name": "Unbound",
		"description": "Nothing can touch you mid-leap",
		"kit": "demonologist", "is_ability_upgrade": true, "op": "add_iframes",
		"target": { "graph": "light", "anim": "hell_breach" },
	},
	"demon_ember_wake": {
		"id": "demon_ember_wake", "name": "Ember Wake",
		"description": "Hellfire leaves embers on the floor",
		"kit": "demonologist", "is_ability_upgrade": true, "op": "add_ground_zone",
		"target": { "graph": "heavy", "anim": "hellfire_2" },
		"params": { "zone_id": "demon_ember_wake", "radius": 50.0, "duration": 4.0,
					"tick": 0.5, "damage_mult": 0.14, "element": "fire", "damage_type": "Fire" },
	},

	## ── Ravager — level-up-layer pass, 2026-09-21 ─────────────────────────
	##
	## Six of seven picks duplicated a class mod, four of them strictly worse:
	##   SEISMIC SUNDER  sunder r1.40     vs EARTHSPLITTER (rare) r1.45 d1.25, and RAGNAROK too
	##   THUNDER AMP     thunder d1.35    vs CHAINED LIGHTNING (rare) d1.40
	##   HURLED DOOM     hurl r/d 1.30    vs HURLED RUIN (rare) r1.40 d1.30
	##   STORMCALLER     thunder +2 bolts vs STORM VOLLEY and STORMHEART, both +2 on the same anim
	##   GREATER PILE    pile_capacity    vs AVALANCHE (+3 on the identical stat)
	##   BATTLE RAGE     a flat damage stat stick
	## CLEAVING BLOW is the only survivor - attack_2 is the one anim no Ravager mod touches.
	##
	## What nothing in either layer reached: Pile Driver's own numbers (every one a const) and
	## Guard, which blocks a frontal hit OUTRIGHT and deals nothing back - a whole channel with no
	## pick attached, the same cosmetic-only shape as the Spark's ice aura.
	"barbarian_strongman": {
		"id": "barbarian_strongman",
		"name": "Strongman",
		"description": "Thrown bodies land far harder",
		"kit": "barbarian",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "pile_body_damage",
		## FLAT: base 0.0, get_stat is add*(1+bonus). Added to PILE_BODY_DAMAGE, so the chain
		## reads x0.90 -> x1.30 -> x1.70 of the Ravager's damage per body.
		"type": "flat",
		"value": 0.40,
		"max_rank": 2,
	},
	"barbarian_crushing_weight": {
		"id": "barbarian_crushing_weight",
		"name": "Crushing Weight",
		"description": "Every body you carry adds far more to the landing",
		"kit": "barbarian",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "pile_burst",
		"type": "flat",
		"value": 0.15,
		## x0.25 per carried body -> x0.40 -> x0.55. With AVALANCHE equipped that is nine bodies
		## feeding one burst, which is exactly the fantasy.
		"max_rank": 2,
	},
	## The end state, and not another number: the bodies stop being cargo and become munitions.
	## Each one goes off where IT came down rather than at the pile's centre, so a wide throw reads
	## as several separate impacts - the reason to carry six in the first place.
	"barbarian_bodies_as_ordnance": {
		"id": "barbarian_bodies_as_ordnance",
		"name": "Bodies as Ordnance",
		"description": "Every body you throw detonates where it lands",
		"kit": "barbarian",
		"is_ability_upgrade": true,
		"is_capstone": true,
		"requires": ["barbarian_strongman", "barbarian_strongman"],
		"op": "modifier",
		"stat": "pile_blast",
		"type": "flat",
		"value": 0.70,
		"max_rank": 1,
	},
	## Guard, finally worth holding for a reason other than not dying.
	"barbarian_wall_of_iron": {
		"id": "barbarian_wall_of_iron",
		"name": "Wall of Iron",
		"description": "The sword answers what it stops",
		"kit": "barbarian",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "guard_riposte",
		"type": "flat",
		"value": 0.60,
		## Aimed at whoever actually swung, not an area: a block is a one-on-one event.
		"max_rank": 2,
	},
	"barbarian_immovable": {
		"id": "barbarian_immovable",
		"name": "Immovable",
		"description": "The guard covers far more ground",
		"kit": "barbarian",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "guard_arc",
		"type": "flat",
		"value": 0.70,
		## 150 degrees -> ~190. One-shot: _is_guard_blocking clamps at a full circle, and "blocks
		## everything from every direction" is a different ability, not a bigger version of this one.
		"max_rank": 1,
	},
	"barbarian_cleaving_blow": {
		"id": "barbarian_cleaving_blow", "name": "Cleaving Blow",
		"description": "Second chain strike hits +35% damage",
		"kit": "barbarian", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "attack_2" }, "params": { "damage_mult": 1.35 },
	},

	## The four phase-op picks that survive the mod diff. Ravager mods occupy sunder (scale x2),
	## thunder (scale + add_projectiles x2), hurl (scale) and cry (add_status), so these use ops
	## no Ravager mod touches.
	"barbarian_fault_line": {
		"id": "barbarian_fault_line", "name": "Fault Line",
		"description": "Sunder leaves the ground split and burning",
		"kit": "barbarian", "is_ability_upgrade": true, "op": "add_ground_zone",
		"target": { "anim": "sunder" },
		"params": { "zone_id": "barbarian_fault_line", "radius": 56.0, "duration": 4.0,
					"tick": 0.5, "damage_mult": 0.12, "element": "fire", "damage_type": "Fire" },
	},
	## Ancestral-Call shaped, on the ground-breaker rather than a slam: the crack repeats under
	## two other enemies. No Ravager mod uses echo_aoe.
	"barbarian_seismic_echo": {
		"id": "barbarian_seismic_echo", "name": "Seismic Echo",
		"description": "Sunder cracks the ground under two more of them",
		"kit": "barbarian", "is_ability_upgrade": true, "op": "echo_aoe",
		"target": { "anim": "sunder" },
		"params": { "copies": 2, "damage_mult": 0.60, "radius": 170.0, "separation": 40.0 },
	},
	"barbarian_thunderstruck": {
		"id": "barbarian_thunderstruck", "name": "Thunderstruck",
		"description": "Thunder Blade throws a shockwave out with it",
		"kit": "barbarian", "is_ability_upgrade": true, "op": "add_shockwave",
		"target": { "anim": "thunder" },
		"params": { "radius": 96.0, "damage_mult": 0.55, "color": Color(0.60, 0.80, 1.0, 0.9) },
	},
	## Pile Driver spends a long beat with his hands full and six people over his head.
	"barbarian_braced": {
		"id": "barbarian_braced", "name": "Braced",
		"description": "Nothing can touch you with your hands full",
		"kit": "barbarian", "is_ability_upgrade": true, "op": "add_iframes",
		"target": { "graph": "skill_e", "anim": "hurl" },
	},
	## The chain is Cleave -> Cleave II -> Sunder with Thunder hanging off the second beat, so the
	## window on Cleave II gates both finishers.
	"barbarian_warpath": {
		"id": "barbarian_warpath", "name": "Warpath",
		"description": "The second cleave holds its window 50% longer",
		"kit": "barbarian", "is_ability_upgrade": true, "op": "extend_window",
		"target": { "graph": "light", "anim": "attack_2" }, "params": { "window_mult": 1.50 },
	},

	## ── Gunslinger ────────────────────────────────────────────────────────────
	"gunslinger_whipcrack": {
		"id": "gunslinger_whipcrack", "name": "Whipcrack",
		"description": "Whip (E) hits +30% wider and harder",
		"kit": "gunslinger", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "whip" }, "params": { "radius_mult": 1.30, "damage_mult": 1.30 },
	},
	"gunslinger_double_tap": {
		"id": "gunslinger_double_tap", "name": "Double Tap",
		"description": "Second chain shot fires +1 bullet",
		"kit": "gunslinger", "is_ability_upgrade": true, "op": "add_projectiles",
		"target": { "anim": "attack_2" }, "params": { "count": 1 },
	},
	"gunslinger_hollow_points": {
		"id": "gunslinger_hollow_points", "name": "Hollow Points",
		"description": "Fan the Hammer makes enemies bleed",
		"kit": "gunslinger", "is_ability_upgrade": true, "op": "add_projectile_status",
		"target": { "anim": "fan" }, "params": { "status": "bleed", "stacks": 1 },
	},
}

## Ordered ids per kit — controls offer order within the ability slot.
##
## This is the reachability list, not just an ordering: get_upgrades_for_kit() walks it and
## ignores ALL, so an entry missing here is authored, valid, and never offered. validate_kit_order()
## exists so that cannot happen quietly.
const ORDER_BY_KIT: Dictionary = {
	## 4 entries — every other kit has 6. BATTLE RHYTHM and LAST WORD were cut on 2026-09-05
	## rather than rewritten: both keyed off chain depth, a quantity the player cannot see since
	## the pip row became a hit counter, and both paid out in stat nudges too small to feel. The
	## hole is deliberate and should be filled with picks that are legible from their own effect.
	## 11 entries — the most of any kit, on purpose. This is the pilot for the level-up-layer
	## seam and the place build variety gets tested before the other eleven follow.
	"fighter":    ["fighter_thunderclap",           "fighter_spite",
				   "fighter_patient_blade",         "fighter_unbroken",
				   "fighter_ancestral_call",        "fighter_aftershock",
				   "fighter_tempest_break",         "fighter_whirling_dervish",
				   "fighter_rolling_thunder",        "fighter_thunderhead",
				   "fighter_skyfall"],
	## 11 entries — the second kit through the level-up-layer pass (the Fighter was the pilot).
	"paladin":    ["paladin_hammer_storm",          "paladin_hammerdin",
				   "paladin_blessed_storm",         "paladin_wrath_of_heaven",
				   "paladin_judgement",             "paladin_unbreakable_oath",
				   "paladin_ringing_dictum",        "paladin_crusaders_cadence",
				   "paladin_hallowed_ground",       "paladin_zeal",
				   "paladin_sanctuary"],
	## 10 entries — the eleventh kit through the level-up-layer pass.
	"ninja":      ["ninja_blade_storm_focus",       "ninja_perfect_silence",
				   "ninja_endless_edge",            "ninja_twin_fangs",
				   "ninja_shadow_step",             "ninja_shadowburst",
				   "ninja_bloodgrass",              "ninja_mirror_cuts",
				   "ninja_vanishing_act",           "ninja_killing_tempo"],
	## 11 entries — the ninth kit through the level-up-layer pass.
	"cleric":     ["cleric_warden_spirit",          "cleric_long_vigil",
				   "cleric_choir_of_spears",        "cleric_sanctified_smite",
				   "cleric_litany",                 "cleric_censer_sweep",
				   "cleric_consecration",           "cleric_steadfast",
				   "cleric_cadence_of_faith",       "cleric_judgement_echo",
				   "cleric_radiant_volley"],
	## 10 entries — the eighth kit through the level-up-layer pass.
	"druid":      ["druid_ursine_might",            "druid_pack_fangs",
				   "druid_wild_hunt",               "druid_second_grove",
				   "druid_deep_roots",              "druid_verdant_surge",
				   "druid_thorn_volley",            "druid_bramble_bed",
				   "druid_grove_guard",             "druid_patient_growth"],
	## 7 entries — every other kit has 6. The Shade keeps the extra class-flavored pick it has
	## always had (necro_greater_swirl overlaps the SPLINTERING SWIRL class mod almost exactly, so
	## it stays the natural trim if Ben ever wants parity).
	## 11 entries — the sixth kit through the level-up-layer pass.
	"necromancer": ["necro_risen_horror",           "necro_mass_grave",
					"necro_legion_swell",           "necro_volatile_marrow",
					"necro_chain_of_the_dead",      "necro_reapers_due",
					"necro_grave_hunger",           "necro_bone_choir",
					"necro_bone_field",             "necro_deathless",
					"necro_patient_dead"],
	## 10 entries — the tenth kit through the level-up-layer pass.
	"ranger":     ["ranger_mirror_focus",           "ranger_lingering_reflection",
				   "ranger_hall_of_mirrors",        "ranger_triple_volley",
				   "ranger_double_down",            "ranger_knife_work",
				   "ranger_caltrops",               "ranger_quickstep",
				   "ranger_steady_draw",            "ranger_split_volley"],
	## 11 entries — the third kit through the level-up-layer pass.
	"wizard":     ["wizard_fireball_expansion",     "wizard_rising_storm",
				   "wizard_rolling_front",          "wizard_eye_of_the_storm",
				   "wizard_ember_brood",            "wizard_everflame",
				   "wizard_glacial_cast",           "wizard_cinder_ring",
				   "wizard_ashfall",                "wizard_shardstorm",
				   "wizard_flashpoint"],
	## 11 entries — the fourth kit through the level-up-layer pass.
	"blood_mage": ["blood_mage_hemorrhage_wave",    "blood_mage_thrall",
				   "blood_mage_blood_gorged",       "blood_mage_second_vessel",
				   "blood_mage_undying_vessel",     "blood_mage_bloodletting",
				   "blood_mage_gluttony",           "blood_mage_sanguine_pact",
				   "blood_mage_exsanguinate",       "blood_mage_arterial_spray",
				   "blood_mage_blood_ward"],
	## 11 entries — the fifth kit through the level-up-layer pass, and a full replacement:
	## every one of the old six duplicated a class mod or was a generic stat stick.
	"demonologist": ["demon_bound_elite",           "demon_ninefold_pact",
					 "demon_binding_held",          "demon_shared_agony",
					 "demon_infernal_rebirth",      "demon_sundered_earth",
					 "demon_cinder_trail",          "demon_brimstone_toll",
					 "demon_pact_haste",            "demon_unbound",
					 "demon_ember_wake"],
	## 11 entries — the seventh kit through the level-up-layer pass.
	"barbarian":  ["barbarian_strongman",           "barbarian_crushing_weight",
				   "barbarian_bodies_as_ordnance",  "barbarian_wall_of_iron",
				   "barbarian_immovable",           "barbarian_cleaving_blow",
				   "barbarian_fault_line",          "barbarian_thunderstruck",
				   "barbarian_braced",              "barbarian_warpath",
				   "barbarian_seismic_echo"],
	"gunslinger": ["gunslinger_hair_trigger",       "gunslinger_storm_surge",       "gunslinger_cold_steel",
				   "gunslinger_whipcrack",          "gunslinger_double_tap",        "gunslinger_hollow_points"],
}


## Startup check: every entry in ALL must be reachable through ORDER_BY_KIT, and every id listed
## there must exist. Both failures are silent — an unlisted entry is simply never offered, and a
## listed-but-missing id is skipped by get_upgrades_for_kit's is_empty() guard — so nothing about
## either shows up in a playtest. This is the same reasoning as validate_anim_targets().
static func validate_kit_order() -> Array[String]:
	var problems: Array[String] = []
	var listed: Dictionary = {}
	for kit_id: String in ORDER_BY_KIT:
		for up_id: String in ORDER_BY_KIT[kit_id]:
			if listed.has(up_id):
				problems.append("%s is listed twice in ORDER_BY_KIT" % up_id)
			listed[up_id] = true
			var entry: Dictionary = ALL.get(up_id, {})
			if entry.is_empty():
				problems.append("ORDER_BY_KIT[%s] lists '%s', which is not in ALL" % [kit_id, up_id])
			elif entry.get("kit", "") != kit_id:
				problems.append("'%s' is listed under kit '%s' but declares kit '%s'"
						% [up_id, kit_id, entry.get("kit", "")])
	for up_id: String in ALL:
		if not listed.has(up_id):
			problems.append("'%s' is in ALL but no ORDER_BY_KIT list — it can never be offered"
					% up_id)
	## Capstone prerequisites. An unreachable one is the same silent failure as everything else in
	## this file: the entry is authored, valid, and can never be offered because its requirement
	## can never be met.
	for up_id: String in ALL:
		var entry_r: Dictionary = ALL[up_id]
		for req: String in entry_r.get("requires", []):
			if not ALL.has(req):
				problems.append("'%s' requires '%s', which is not in ALL" % [up_id, req])
			elif ALL[req].get("kit", "") != entry_r.get("kit", ""):
				problems.append("'%s' (kit %s) requires '%s' from kit %s — a run can never hold both"
						% [up_id, entry_r.get("kit", ""), req, ALL[req].get("kit", "")])
			elif not listed.has(req):
				problems.append("'%s' requires '%s', which is not in ORDER_BY_KIT and can never "
						% [up_id, req] + "be taken")

	for up_id: String in ALL:
		var entry: Dictionary = ALL[up_id]
		var op: String = entry.get("op", "")
		if op not in ["add_status", "add_projectile_status", "add_iframes", "self_status"]:
			continue
		## Any of these four ranking would be a pick that visibly does nothing on rank 2:
		## appending the same status twice collapses under the stacking rules, setting an
		## already-true boolean changes nothing, and re-applying a permanent self status
		## re-applies what the player is already carrying.
		if max_rank_of(entry) > 1:
			problems.append("'%s' is op '%s' with max_rank %d — repeats would do nothing"
					% [up_id, op, max_rank_of(entry)])
		## add_iframes names no status, so there is nothing further to resolve.
		if op == "add_iframes":
			continue
		## The status id itself. ClassModFactory._status_effect returns null on a miss and the op
		## then appends nothing — the same invisible failure as a dead anim target, one field over.
		## UpgradeManager.validate_status_ids() does NOT cover these: it walks the generic
		## upgrade_pool and the evolution recipes, never an ability upgrade's params.
		##
		## The two shapes are deliberate, not an inconsistency: a phase-targeting op names its
		## status inside `params` alongside stacks and apply_to_self, the way every class mod
		## does; "self_status" has no params at all, so it carries `status_id` at the top level
		## the way the generic pool's entries do.
		var sid: String = ""
		if op == "self_status":
			sid = entry.get("status_id", "")
		else:
			sid = entry.get("params", {}).get("status", "")
		if StatusFactory.get_by_id(sid) == null:
			problems.append("'%s' applies unknown status '%s' — the op will append nothing"
					% [up_id, sid])
	return problems

static func get_upgrades_for_kit(kit_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for up_id: String in ORDER_BY_KIT.get(kit_id, []):
		var entry: Dictionary = ALL.get(up_id, {})
		if not entry.is_empty():
			out.append(entry)
	return out
