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
}

## Ordered ids per kit — controls offer order within the ability slot.
const ORDER_BY_KIT: Dictionary = {
	"fighter":    ["fighter_extended_whirlwind",    "fighter_cataclysm_aftershock", "fighter_tempest_rush"],
	"paladin":    ["paladin_hammer_storm",          "paladin_consecrated_bash",     "paladin_iron_faith"],
	"ninja":      ["ninja_blade_storm_surge",       "ninja_killing_edge",           "ninja_smoke_ambush"],
	"cleric":     ["cleric_divine_wrath",           "cleric_greater_word",          "cleric_sanctified_smite"],
	"druid":      ["druid_wild_maul",               "druid_strangling_roots",       "druid_pack_frenzy"],
	## 4 entries — every other kit has 3. The Shade gets one extra class-flavored pick per run
	## until Ben decides whether to cut one (necro_greater_swirl overlaps the SPLINTERING SWIRL
	## class mod almost exactly, so it's the natural trim).
	"necromancer": ["necro_bone_barrage",           "necro_greater_swirl",          "necro_grave_vigor",
					"necro_bone_choir"],
	"ranger":     ["ranger_triple_volley",          "ranger_keen_blade",            "ranger_eagle_eye"],
	"wizard":     ["wizard_fireball_expansion",     "wizard_torrent_mastery",       "wizard_arcane_surge"],
	"blood_mage": ["blood_mage_hemorrhage_wave",    "blood_mage_spike_field",       "blood_mage_blood_frenzy"],
	"demonologist": ["demon_conflagration",        "demon_wider_circle",           "demon_hellfire_heart"],
	"barbarian":  ["barbarian_seismic_sunder",      "barbarian_thunder_amp",        "barbarian_battle_rage"],
	"gunslinger": ["gunslinger_hair_trigger",       "gunslinger_storm_surge",       "gunslinger_cold_steel"],
}

static func get_upgrades_for_kit(kit_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for up_id: String in ORDER_BY_KIT.get(kit_id, []):
		var entry: Dictionary = ALL.get(up_id, {})
		if not entry.is_empty():
			out.append(entry)
	return out
