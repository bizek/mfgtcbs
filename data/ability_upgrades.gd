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

	## ── Ninja (The Whisper) ───────────────────────────────────────────────────
	"ninja_blade_storm_surge": {
		"id": "ninja_blade_storm_surge",
		"name": "Blade Storm Surge",
		"description": "Thousand Blades +40% radius",
		"kit": "ninja",
		"is_ability_upgrade": true,
		"op": "scale_aoe",
		"target": { "anim": "blades" },
		"params": { "radius_mult": 1.40 },
	},
	"ninja_killing_edge": {
		"id": "ninja_killing_edge",
		"name": "Killing Edge",
		"description": "+10% Crit Chance this run",
		"kit": "ninja",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "crit_chance",
		"type": "flat",
		"value": 0.10,
	},
	"ninja_smoke_ambush": {
		"id": "ninja_smoke_ambush",
		"name": "Smoke Ambush",
		"description": "Smoke Bomb chills all nearby enemies",
		"kit": "ninja",
		"is_ability_upgrade": true,
		"op": "add_status",
		"target": { "anim": "smoke" },
		"params": { "status": "chilled", "stacks": 1 },
	},

	## ── Cleric (The Devout) ───────────────────────────────────────────────────
	"cleric_divine_wrath": {
		"id": "cleric_divine_wrath",
		"name": "Divine Wrath",
		"description": "Divine Fire bolt +30% damage",
		"kit": "cleric",
		"is_ability_upgrade": true,
		"op": "scale_aoe",
		"target": { "anim": "divine_fire" },
		"params": { "damage_mult": 1.30 },
	},
	"cleric_greater_word": {
		"id": "cleric_greater_word",
		"name": "Greater Word of Pain",
		"description": "Word of Pain zone +40% radius",
		"kit": "cleric",
		"is_ability_upgrade": true,
		"op": "scale_aoe",
		"target": { "anim": "pray_pain" },
		"params": { "radius_mult": 1.40 },
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

	## ── Druid (The Verdant) ───────────────────────────────────────────────────
	## Retargeted 2026-08-02. These were written for the shapeshift kit, which is gone
	## (0f5dfed — Ben: "i dont like the transformations at all"). "beast_attack" and
	## "hound_attack" stopped being phase animations anywhere in the game, so Wild Maul and
	## Pack Frenzy matched no phase and silently did nothing — the Verdant ran on ONE live
	## ability upgrade out of three. Rewritten against the thorn-caster kit, one per graph:
	## light opener · heavy root zone · channel barrage.
	##
	## Note there is deliberately no summon-scaling upgrade here: ForestCompanion reads the
	## player's live damage stat at strike time (forest_companion.gd:218), so the only lever
	## this system has on the bear/hounds is a global +damage stat stick. A real pet dial is
	## rework territory — see docs/mod_levelup_rework_plan.md §3.
	"druid_seedstorm": {
		"id": "druid_seedstorm",
		"name": "Seedstorm",
		"description": "Thorn looses a second seed",
		"kit": "druid",
		"is_ability_upgrade": true,
		"op": "add_projectiles",
		## Light phase 0 is the only "attack" phase in the kit. aimed_single fans the extra
		## shot 6° off the aim line and keeps shot #0 dead on the cursor.
		"target": { "graph": "light", "anim": "attack" },
		"params": { "count": 1 },
	},
	"druid_strangling_roots": {
		"id": "druid_strangling_roots",
		"name": "Strangling Roots",
		"description": "Root Summoning zone +40% radius",
		"kit": "druid",
		"is_ability_upgrade": true,
		"op": "scale_aoe",
		"target": { "anim": "root_cast" },
		"params": { "radius_mult": 1.40 },
	},
	"druid_wild_barrage": {
		"id": "druid_wild_barrage",
		"name": "Wild Barrage",
		"description": "Bramble Barrage beats +30% damage",
		"kit": "druid",
		"is_ability_upgrade": true,
		"op": "scale_aoe",
		## graph pins this to the channel — "attack_2" is also light phases 1 and 2.
		## radius_mult is omitted deliberately: the beat looses a projectile, and _scale_effects
		## has no radius to scale on a SpawnProjectilesEffect.
		"target": { "graph": "channel", "anim": "attack_2" },
		"params": { "damage_mult": 1.30 },
	},

	## ── Necromancer (The Shade) ───────────────────────────────────────────────
	"necro_bone_barrage": {
		"id": "necro_bone_barrage",
		"name": "Bone Barrage",
		"description": "Bone Missile looses +1 splinter",
		"kit": "necromancer",
		"is_ability_upgrade": true,
		"op": "add_projectiles",
		"target": { "anim": "bone_cast" },
		"params": { "count": 1 },
	},
	"necro_greater_swirl": {
		"id": "necro_greater_swirl",
		"name": "Greater Swirl",
		"description": "Bone Swirl +35% damage, +20% radius",
		"kit": "necromancer",
		"is_ability_upgrade": true,
		"op": "scale_aoe",
		"target": { "anim": "bone_swirl" },
		"params": { "damage_mult": 1.35, "radius_mult": 1.20 },
	},
	## The bone-count dial. Bone Swirl's orbiting bones ARE its outgoing volley, so one op grows
	## both: an extra bone rides the ring (player.gd draws the count) and an extra bolt flies out.
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
	"necro_grave_vigor": {
		"id": "necro_grave_vigor",
		"name": "Grave Vigor",
		"description": "+12% Max HP this run",
		"kit": "necromancer",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "max_hp",
		"type": "percent",
		"value": 0.12,
	},

	## ── Ranger (The Scavenger) ────────────────────────────────────────────────
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
	"ranger_keen_blade": {
		"id": "ranger_keen_blade",
		"name": "Keen Blade",
		"description": "Throwing Knife +50% damage",
		"kit": "ranger",
		"is_ability_upgrade": true,
		"op": "scale_aoe",
		"target": { "anim": "knife" },
		"params": { "damage_mult": 1.50 },
	},
	"ranger_eagle_eye": {
		"id": "ranger_eagle_eye",
		"name": "Eagle Eye",
		"description": "+5% Crit Chance this run",
		"kit": "ranger",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "crit_chance",
		"type": "flat",
		"value": 0.05,
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

	## ── Barbarian (The Ravager) ───────────────────────────────────────────────
	"barbarian_seismic_sunder": {
		"id": "barbarian_seismic_sunder",
		"name": "Seismic Sunder",
		"description": "Sunder cleave +40% radius",
		"kit": "barbarian",
		"is_ability_upgrade": true,
		"op": "scale_aoe",
		"target": { "anim": "sunder" },
		"params": { "radius_mult": 1.40 },
	},
	"barbarian_thunder_amp": {
		"id": "barbarian_thunder_amp",
		"name": "Thunder Amp",
		"description": "Thunder Blade hits +35% damage",
		"kit": "barbarian",
		"is_ability_upgrade": true,
		"op": "scale_aoe",
		"target": { "anim": "thunder" },
		"params": { "damage_mult": 1.35 },
	},
	"barbarian_battle_rage": {
		"id": "barbarian_battle_rage",
		"name": "Battle Rage",
		"description": "+20% Damage this run",
		"kit": "barbarian",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "damage",
		"type": "percent",
		"value": 0.20,
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

	## ── Ninja ─────────────────────────────────────────────────────────────────
	"ninja_final_cut": {
		"id": "ninja_final_cut", "name": "Final Cut",
		"description": "Blade Storm's finisher hits +45% damage",
		"kit": "ninja", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "blades_end" }, "params": { "damage_mult": 1.45 },
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

	## ── Cleric ────────────────────────────────────────────────────────────────
	"cleric_guardians_wrath": {
		"id": "cleric_guardians_wrath", "name": "Guardian's Wrath",
		"description": "Guardian (E) strikes +30% wider and harder",
		"kit": "cleric", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "pray_guardian" }, "params": { "radius_mult": 1.30, "damage_mult": 1.30 },
	},
	"cleric_litany": {
		"id": "cleric_litany", "name": "Litany",
		"description": "Second chain strike hits +30% damage",
		"kit": "cleric", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "attack_2" }, "params": { "damage_mult": 1.30 },
	},
	"cleric_kindled_fire": {
		"id": "cleric_kindled_fire", "name": "Kindled Fire",
		"description": "Divine Fire sets what it hits burning",
		"kit": "cleric", "is_ability_upgrade": true, "op": "add_projectile_status",
		"target": { "anim": "divine_fire" }, "params": { "status": "burning", "stacks": 1 },
	},

	## ── Druid ─────────────────────────────────────────────────────────────────
	"druid_greater_bear": {
		"id": "druid_greater_bear", "name": "Greater Bear",
		"description": "Bear (Q) mauls +35% wider and harder",
		"kit": "druid", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "summon_bear" }, "params": { "radius_mult": 1.35, "damage_mult": 1.35 },
	},
	"druid_pack_leader": {
		"id": "druid_pack_leader", "name": "Pack Leader",
		"description": "Hounds (E) hit +40% damage",
		"kit": "druid", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "summon_hounds" }, "params": { "damage_mult": 1.40 },
	},
	"druid_thorned_seeds": {
		"id": "druid_thorned_seeds", "name": "Thorned Seeds",
		"description": "Seeds make enemies bleed",
		"kit": "druid", "is_ability_upgrade": true, "op": "add_projectile_status",
		"target": { "anim": "attack" }, "params": { "status": "bleed", "stacks": 1 },
	},

	## ── Necromancer ───────────────────────────────────────────────────────────
	"necro_risen_horror": {
		"id": "necro_risen_horror", "name": "Risen Horror",
		"description": "Rise Corpse (Q) hits +40% damage",
		"kit": "necromancer", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "rise_corpse" }, "params": { "damage_mult": 1.40 },
	},
	"necro_legion_swell": {
		"id": "necro_legion_swell", "name": "Legion Swell",
		"description": "Bone Legion (E) hits +30% wider and harder",
		"kit": "necromancer", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "bone_legion" }, "params": { "radius_mult": 1.30, "damage_mult": 1.30 },
	},
	"necro_marrow_rot": {
		"id": "necro_marrow_rot", "name": "Marrow Rot",
		"description": "Bone missiles make enemies bleed",
		"kit": "necromancer", "is_ability_upgrade": true, "op": "add_projectile_status",
		"target": { "anim": "bone_cast" }, "params": { "status": "bleed", "stacks": 1 },
	},

	## ── Ranger ────────────────────────────────────────────────────────────────
	"ranger_double_down": {
		"id": "ranger_double_down", "name": "Double Down",
		"description": "Double Shot fires +1 arrow",
		"kit": "ranger", "is_ability_upgrade": true, "op": "add_projectiles",
		"target": { "anim": "double_shot" }, "params": { "count": 1 },
	},
	"ranger_riposte": {
		"id": "ranger_riposte", "name": "Riposte",
		"description": "Close-quarters strikes hit +40% damage",
		"kit": "ranger", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "melee" }, "params": { "damage_mult": 1.40 },
	},
	"ranger_venom_tips": {
		"id": "ranger_venom_tips", "name": "Venom Tips",
		"description": "Arrows make enemies bleed",
		"kit": "ranger", "is_ability_upgrade": true, "op": "add_projectile_status",
		"target": { "anim": "attack" }, "params": { "status": "bleed", "stacks": 1 },
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

	## ── Barbarian ─────────────────────────────────────────────────────────────
	"barbarian_hurled_doom": {
		"id": "barbarian_hurled_doom", "name": "Hurled Doom",
		"description": "Pile Driver (E) lands +30% wider and harder",
		"kit": "barbarian", "is_ability_upgrade": true, "op": "scale_aoe",
		## Retargeted "throw" -> "hurl" with the Pile Driver rebuild (2026-08-16).
		"target": { "anim": "hurl" }, "params": { "radius_mult": 1.30, "damage_mult": 1.30 },
	},
	"barbarian_greater_pile": {
		"id": "barbarian_greater_pile", "name": "Greater Pile",
		"description": "Pile Driver (E) carries +2 more enemies",
		## "modifier" op on the pile_capacity stat — same seam AVALANCHE uses, so a run can stack
		## the mod and up to three ranks of this (6 base → 15 at the ceiling). Rankable because
		## MAX_RANK_BY_OP allows modifier x3 and the picks genuinely compound here.
		"kit": "barbarian", "is_ability_upgrade": true, "op": "modifier",
		"stat": "pile_capacity", "type": "flat", "value": 2.0,
	},
	"barbarian_cleaving_blow": {
		"id": "barbarian_cleaving_blow", "name": "Cleaving Blow",
		"description": "Second chain strike hits +35% damage",
		"kit": "barbarian", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "attack_2" }, "params": { "damage_mult": 1.35 },
	},
	"barbarian_stormcaller": {
		"id": "barbarian_stormcaller", "name": "Stormcaller",
		"description": "Thunder Blade throws +2 bolts",
		"kit": "barbarian", "is_ability_upgrade": true, "op": "add_projectiles",
		"target": { "anim": "thunder" }, "params": { "count": 2 },
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
	"ninja":      ["ninja_blade_storm_surge",       "ninja_killing_edge",           "ninja_smoke_ambush",
				   "ninja_final_cut",               "ninja_twin_fangs",             "ninja_shadow_step"],
	"cleric":     ["cleric_divine_wrath",           "cleric_greater_word",          "cleric_sanctified_smite",
				   "cleric_guardians_wrath",        "cleric_litany",                "cleric_kindled_fire"],
	"druid":      ["druid_seedstorm",               "druid_strangling_roots",       "druid_wild_barrage",
				   "druid_greater_bear",            "druid_pack_leader",            "druid_thorned_seeds"],
	## 7 entries — every other kit has 6. The Shade keeps the extra class-flavored pick it has
	## always had (necro_greater_swirl overlaps the SPLINTERING SWIRL class mod almost exactly, so
	## it stays the natural trim if Ben ever wants parity).
	"necromancer": ["necro_bone_barrage",           "necro_greater_swirl",          "necro_grave_vigor",
					"necro_bone_choir",             "necro_risen_horror",           "necro_legion_swell",
					"necro_marrow_rot"],
	"ranger":     ["ranger_triple_volley",          "ranger_keen_blade",            "ranger_eagle_eye",
				   "ranger_double_down",            "ranger_riposte",               "ranger_venom_tips"],
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
	## 7 entries — the extra one is GREATER PILE, the level-up half of Pile Driver's expandable
	## chain cap (AVALANCHE is the class-mod half). Same deliberate overshoot as the Shade above.
	"barbarian":  ["barbarian_seismic_sunder",      "barbarian_thunder_amp",        "barbarian_battle_rage",
				   "barbarian_hurled_doom",         "barbarian_cleaving_blow",      "barbarian_stormcaller",
				   "barbarian_greater_pile"],
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
