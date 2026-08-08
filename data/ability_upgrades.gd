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
}

## How many times this upgrade may be taken in one run. Explicit "max_rank" wins; otherwise the
## op's default; otherwise 1, so an op added later is one-shot until someone decides it stacks.
static func max_rank_of(entry: Dictionary) -> int:
	if entry.has("max_rank"):
		return maxi(1, int(entry["max_rank"]))
	return int(MAX_RANK_BY_OP.get(entry.get("op", ""), 1))

const ALL: Dictionary = {

	## ── Fighter (The Sellsword) ────────────────────────────────────────────────
	"fighter_extended_whirlwind": {
		"id": "fighter_extended_whirlwind",
		"name": "Extended Whirlwind",
		"description": "Swirl hits +30% radius, wider clearing arc",
		"kit": "fighter",
		"is_ability_upgrade": true,
		"op": "scale_aoe",
		"target": { "anim": "swirl" },
		"params": { "radius_mult": 1.30 },
	},
	"fighter_cataclysm_aftershock": {
		"id": "fighter_cataclysm_aftershock",
		"name": "Cataclysm Aftershock",
		"description": "Cataclysm chills all enemies hit",
		"kit": "fighter",
		"is_ability_upgrade": true,
		"op": "add_status",
		"target": { "anim": "cataclysm" },
		"params": { "status": "chilled", "stacks": 1 },
	},
	"fighter_tempest_rush": {
		"id": "fighter_tempest_rush",
		"name": "Tempest Rush",
		"description": "+15% Dash Distance this run",
		"kit": "fighter",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "dash_speed",
		"type": "percent",
		"value": 0.15,
	},

	## ── Paladin (The Warden) ──────────────────────────────────────────────────
	"paladin_hammer_storm": {
		"id": "paladin_hammer_storm",
		"name": "Hammer Storm",
		"description": "Holy Hammer hits +40% damage",
		"kit": "paladin",
		"is_ability_upgrade": true,
		"op": "scale_aoe",
		"target": { "anim": "hammer" },
		"params": { "damage_mult": 1.40 },
	},
	"paladin_consecrated_bash": {
		"id": "paladin_consecrated_bash",
		"name": "Consecrated Bash",
		"description": "Shield Bash ignites enemies hit",
		"kit": "paladin",
		"is_ability_upgrade": true,
		"op": "add_status",
		"target": { "anim": "bash" },
		"params": { "status": "burning", "stacks": 1 },
	},
	"paladin_iron_faith": {
		"id": "paladin_iron_faith",
		"name": "Iron Faith",
		"description": "+4 Armor this run",
		"kit": "paladin",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "armor",
		"type": "flat",
		"value": 4.0,
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
		"description": "Bone Swirl carries +1 bone — it orbits, then it flies",
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
	"wizard_torrent_mastery": {
		"id": "wizard_torrent_mastery",
		"name": "Burst Mastery",
		"description": "Fire Burst AoE +40% radius",
		"kit": "wizard",
		"is_ability_upgrade": true,
		"op": "scale_aoe",
		"target": { "anim": "fireburst" },
		"params": { "radius_mult": 1.40 },
	},
	"wizard_arcane_surge": {
		"id": "wizard_arcane_surge",
		"name": "Arcane Surge",
		"description": "+15% Damage this run",
		"kit": "wizard",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "damage",
		"type": "percent",
		"value": 0.15,
	},

	## ── Blood Mage (The Cursed) ───────────────────────────────────────────────
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
	"blood_mage_spike_field": {
		"id": "blood_mage_spike_field",
		"name": "Spike Field",
		"description": "Blood Spikes zone +40% radius",
		"kit": "blood_mage",
		"is_ability_upgrade": true,
		"op": "scale_aoe",
		"target": { "anim": "spikes" },
		"params": { "radius_mult": 1.40 },
	},
	"blood_mage_blood_frenzy": {
		"id": "blood_mage_blood_frenzy",
		"name": "Blood Frenzy",
		"description": "+20% Damage this run",
		"kit": "blood_mage",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "damage",
		"type": "percent",
		"value": 0.20,
	},

	## ── Demonologist (The Demon) ──────────────────────────────────────────────
	"demon_conflagration": {
		"id": "demon_conflagration",
		"name": "Conflagration",
		"description": "Hellfire +35% damage, +20% radius",
		"kit": "demonologist",
		"is_ability_upgrade": true,
		"op": "scale_aoe",
		## "hellfire_2" is the heavy's poke phase — the Demon's body sheet is "hellfire" but the
		## phase carries a distinct NAME so it can re-fire back-to-back (chain_factory.build_demon_heavy).
		## Targeting "hellfire" matched nothing and this upgrade did nothing at all.
		"target": { "anim": "hellfire_2" },
		"params": { "damage_mult": 1.35, "radius_mult": 1.20 },
	},
	"demon_wider_circle": {
		"id": "demon_wider_circle",
		"name": "Wider Circle",
		"description": "Brimstone Circle +40% radius, +20% damage",
		"kit": "demonologist",
		"is_ability_upgrade": true,
		"op": "scale_aoe",
		"target": { "anim": "brimstone" },
		"params": { "radius_mult": 1.40, "damage_mult": 1.20 },
	},
	"demon_hellfire_heart": {
		"id": "demon_hellfire_heart",
		"name": "Hellfire Heart",
		"description": "+20% Damage this run",
		"kit": "demonologist",
		"is_ability_upgrade": true,
		"op": "modifier",
		"stat": "damage",
		"type": "percent",
		"value": 0.20,
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

	## ── Fighter ───────────────────────────────────────────────────────────────
	"fighter_rushing_tempest": {
		"id": "fighter_rushing_tempest", "name": "Rushing Tempest",
		"description": "Tempest sweeps +35% wider",
		"kit": "fighter", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "tempest" }, "params": { "radius_mult": 1.35 },
	},
	"fighter_skullcrusher": {
		"id": "fighter_skullcrusher", "name": "Skullcrusher",
		"description": "Uppercut hits +45% damage",
		"kit": "fighter", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "uppercut" }, "params": { "damage_mult": 1.45 },
	},
	"fighter_shoulder_charge": {
		"id": "fighter_shoulder_charge", "name": "Shoulder Charge",
		"description": "Rush (E) hits +30% wider and harder",
		"kit": "fighter", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "rush" }, "params": { "radius_mult": 1.30, "damage_mult": 1.30 },
	},

	## ── Paladin ───────────────────────────────────────────────────────────────
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
	"paladin_searing_hammer": {
		"id": "paladin_searing_hammer", "name": "Searing Hammer",
		"description": "Holy Hammer sets enemies burning",
		"kit": "paladin", "is_ability_upgrade": true, "op": "add_status",
		"target": { "anim": "hammer" }, "params": { "status": "burning", "stacks": 1 },
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
	"wizard_glacial_cast": {
		"id": "wizard_glacial_cast", "name": "Glacial Cast",
		"description": "Ice (Q) freezes a +35% wider circle",
		"kit": "wizard", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "ice_cast" }, "params": { "radius_mult": 1.35 },
	},
	"wizard_tempest_call": {
		"id": "wizard_tempest_call", "name": "Tempest Call",
		"description": "Storm (E) hits +40% damage",
		"kit": "wizard", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "storm_cast" }, "params": { "damage_mult": 1.40 },
	},
	"wizard_familiar_fury": {
		"id": "wizard_familiar_fury", "name": "Familiar Fury",
		"description": "The summon's burst hits +35% damage",
		"kit": "wizard", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "summon" }, "params": { "damage_mult": 1.35 },
	},

	## ── Blood Mage ────────────────────────────────────────────────────────────
	"blood_mage_crimson_slam": {
		"id": "blood_mage_crimson_slam", "name": "Crimson Slam",
		"description": "Slam lands +35% wider",
		"kit": "blood_mage", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "slam" }, "params": { "radius_mult": 1.35 },
	},
	"blood_mage_gluttony": {
		"id": "blood_mage_gluttony", "name": "Gluttony",
		"description": "Consume drains +40% harder",
		"kit": "blood_mage", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "consume" }, "params": { "damage_mult": 1.40 },
	},
	"blood_mage_thrall": {
		"id": "blood_mage_thrall", "name": "Thrall",
		"description": "Blood summon (Q) hits +35% damage",
		"kit": "blood_mage", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "summon_blood" }, "params": { "damage_mult": 1.35 },
	},

	## ── Demonologist ──────────────────────────────────────────────────────────
	"demon_wider_breach": {
		"id": "demon_wider_breach", "name": "Wider Breach",
		"description": "Hell Breach tears open +35% wider",
		"kit": "demonologist", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "hell_breach" }, "params": { "radius_mult": 1.35 },
	},
	"demon_sustained_hellfire": {
		"id": "demon_sustained_hellfire", "name": "Sustained Hellfire",
		"description": "Channelled hellfire burns +35% harder",
		"kit": "demonologist", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "hellfire_ch" }, "params": { "damage_mult": 1.35 },
	},
	"demon_archdemon_wrath": {
		"id": "demon_archdemon_wrath", "name": "Archdemon's Wrath",
		"description": "Archdemon (E) scorches +30% wider and harder",
		"kit": "demonologist", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "archdemon_call" }, "params": { "radius_mult": 1.30, "damage_mult": 1.30 },
	},

	## ── Barbarian ─────────────────────────────────────────────────────────────
	"barbarian_hurled_doom": {
		"id": "barbarian_hurled_doom", "name": "Hurled Doom",
		"description": "Thrown axe (E) hits +30% wider and harder",
		"kit": "barbarian", "is_ability_upgrade": true, "op": "scale_aoe",
		"target": { "anim": "throw" }, "params": { "radius_mult": 1.30, "damage_mult": 1.30 },
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
	"fighter":    ["fighter_extended_whirlwind",    "fighter_cataclysm_aftershock", "fighter_tempest_rush",
				   "fighter_rushing_tempest",       "fighter_skullcrusher",         "fighter_shoulder_charge"],
	"paladin":    ["paladin_hammer_storm",          "paladin_consecrated_bash",     "paladin_iron_faith",
				   "paladin_ringing_dictum",        "paladin_crusaders_cadence",    "paladin_searing_hammer"],
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
	"wizard":     ["wizard_fireball_expansion",     "wizard_torrent_mastery",       "wizard_arcane_surge",
				   "wizard_glacial_cast",           "wizard_tempest_call",          "wizard_familiar_fury"],
	"blood_mage": ["blood_mage_hemorrhage_wave",    "blood_mage_spike_field",       "blood_mage_blood_frenzy",
				   "blood_mage_crimson_slam",       "blood_mage_gluttony",          "blood_mage_thrall"],
	"demonologist": ["demon_conflagration",         "demon_wider_circle",           "demon_hellfire_heart",
					 "demon_wider_breach",          "demon_sustained_hellfire",     "demon_archdemon_wrath"],
	"barbarian":  ["barbarian_seismic_sunder",      "barbarian_thunder_amp",        "barbarian_battle_rage",
				   "barbarian_hurled_doom",         "barbarian_cleaving_blow",      "barbarian_stormcaller"],
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
	for up_id: String in ALL:
		var entry: Dictionary = ALL[up_id]
		var op: String = entry.get("op", "")
		if op not in ["add_status", "add_projectile_status"]:
			continue
		## An add_status that could rank would be a pick that visibly does nothing on rank 2.
		if max_rank_of(entry) > 1:
			problems.append("'%s' is op '%s' with max_rank %d — repeats would re-apply the same "
					% [up_id, op, max_rank_of(entry)] + "status and do nothing")
		## The status id itself. ClassModFactory._status_effect returns null on a miss and the op
		## then appends nothing — the same invisible failure as a dead anim target, one field over.
		## UpgradeManager.validate_status_ids() does NOT cover these: it walks the generic
		## upgrade_pool and the evolution recipes, never an ability upgrade's params.
		var sid: String = entry.get("params", {}).get("status", "")
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
