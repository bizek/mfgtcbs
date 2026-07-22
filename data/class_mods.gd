class_name ClassModData

## ClassModData — Static database of CLASS mods: the second layer of the two-layer mod model
## (task 31, docs/class_mod_system.md). Where ModData mods tune the (generic) weapon, class mods
## reshape a specific class's COMBO KIT — a combo node, the RMB special, a Q/E skill, or the dash.
##
## Data only, zero behavior (CLAUDE.md). ClassModFactory reads these and mutates the kit
## AbilityDefinitions at build time (player._load_combo). Each entry:
##   id      — unique mod id (also the owned_mods / drop id)
##   name    — display name (armory / pickups)
##   kit     — CharacterData "melee_kit" this mod belongs to (gates applicability + drops)
##   desc    — player-facing text
##   color   — pickup beam / armory tint
##   target  — { "graph"?: "light"|"heavy"|"channel"|"skill_q"|"skill_e"|..., "anim": "<phase anim>" }
##             graph is optional; when omitted the op applies to every graph in the kit. anim is
##             matched against ChoreographyPhase.animation, so a mod can hit a node wherever it
##             appears (e.g. Cataclysm lives in both the light and heavy graphs).
##   op      — how ClassModFactory applies it (see that factory's match):
##             "scale_aoe"           — multiply AreaDamageEffect/DealDamageEffect/GroundZoneEffect/
##                                     SpawnProjectilesEffect nested damage (radius_mult, damage_mult)
##             "add_pull"            — append a toward-player DisplacementEffect (suck enemies in)
##             "add_status"          — append ApplyStatusEffectData to phase.effects (AoE → enemies)
##             "add_projectile_status" — inject ApplyStatusEffectData into projectile on_hit_effects
##             "add_projectiles"     — increment SpawnProjectilesEffect.count
##             "modifier"            — kit-agnostic player ModifierDefinition while equipped
##   params  — op-specific numbers
##
## NOTE (v1): class mods deliberately do NOT participate in the generic elemental combo matrix
## (the 69 pairs in ModComboFactory / Codex). They never enter weapon_mods, so codex discovery
## is untouched. Cross-layer synergies are reserved as future space (see design doc).

const ALL: Dictionary = {

	## ── Fighter (The Sellsword) ────────────────────────────────────────────────────────────────
	## 2 pilots shipped in task 31; 2 new here.

	"fighter_overcharged_cataclysm": {
		"id": "fighter_overcharged_cataclysm",
		"name": "OVERCHARGED CATACLYSM",
		"kit": "fighter",
		"desc": "Cataclysm lands 35% harder across a 40% wider crater.",
		"color": Color(1.0, 0.55, 0.15),
		"target": { "anim": "cataclysm" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.4, "damage_mult": 1.35 },
	},
	"fighter_tempest_vortex": {
		"id": "fighter_tempest_vortex",
		"name": "TEMPEST VORTEX",
		"kit": "fighter",
		"desc": "Tempest becomes a vortex — enemies are dragged into the blade before it hits.",
		"color": Color(0.55, 0.75, 1.0),
		"target": { "graph": "light", "anim": "tempest" },
		"op": "add_pull",
		"params": { "distance": 260.0, "duration": 0.16, "arc_height": 4.0 },
	},
	"fighter_sustained_whirlwind": {
		"id": "fighter_sustained_whirlwind",
		"name": "SUSTAINED WHIRLWIND",
		"kit": "fighter",
		"desc": "Whirlwind spins 40% wider — the spin-to-win option.",
		"color": Color(0.9, 0.7, 0.2),
		## targets both the Swirl step and the Whirlwind loop (same anim name "swirl")
		"target": { "graph": "light", "anim": "swirl" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.4 },
	},
	"fighter_concussive_taunt": {
		"id": "fighter_concussive_taunt",
		"name": "CONCUSSIVE TAUNT",
		"kit": "fighter",
		"desc": "Taunt shockwave ticks chill the ring, slowing enemies caught in its pulse.",
		"color": Color(0.55, 0.85, 1.0),
		"target": { "graph": "channel", "anim": "taunt" },
		"op": "add_status",
		"params": { "status": "chilled", "stacks": 1 },
	},

	## ── Paladin (The Warden) ──────────────────────────────────────────────────────────────────

	"paladin_thunderous_bash": {
		"id": "paladin_thunderous_bash",
		"name": "THUNDEROUS BASH",
		"kit": "paladin",
		"desc": "Shield Bash hits 25% harder across a 35% wider shockwave.",
		"color": Color(1.0, 0.85, 0.2),
		"target": { "anim": "bash" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.35, "damage_mult": 1.25 },
	},
	"paladin_blessed_hammer_storm": {
		"id": "paladin_blessed_hammer_storm",
		"name": "BLESSED HAMMER STORM",
		"kit": "paladin",
		"desc": "Holy Hammer descends 40% harder — the hammerdin moment magnified.",
		"color": Color(1.0, 1.0, 0.55),
		"target": { "anim": "hammer" },
		"op": "scale_aoe",
		"params": { "damage_mult": 1.4 },
	},
	"paladin_dictums_reach": {
		"id": "paladin_dictums_reach",
		"name": "DICTUM'S REACH",
		"kit": "paladin",
		"desc": "Blades of Justice orbit 45% further from the Warden's body.",
		"color": Color(0.85, 0.95, 1.0),
		"target": { "anim": "dictum" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.45 },
	},
	"paladin_retribution_dome": {
		"id": "paladin_retribution_dome",
		"name": "RETRIBUTION DOME",
		"kit": "paladin",
		"desc": "Reckoning's dome Ignites everything that presses against it while held.",
		"color": Color(1.0, 0.45, 0.15),
		"target": { "graph": "channel", "anim": "dome" },
		"op": "add_status",
		"params": { "status": "burning", "stacks": 1 },
	},

	## ── Ninja (The Whisper) ───────────────────────────────────────────────────────────────────

	"ninja_bleeding_blades": {
		"id": "ninja_bleeding_blades",
		"name": "BLEEDING BLADES",
		"kit": "ninja",
		"desc": "Every cut in the light chain applies Bleed — even the blade storm.",
		"color": Color(0.85, 0.15, 0.15),
		"target": { "graph": "light" },
		"op": "add_status",
		"params": { "status": "bleed", "stacks": 1 },
	},
	"ninja_endless_storm": {
		"id": "ninja_endless_storm",
		"name": "ENDLESS STORM",
		"kit": "ninja",
		"desc": "Thousand Blades Storm expands 50% — the blade nova fills the room.",
		"color": Color(0.35, 0.85, 0.75),
		"target": { "graph": "channel", "anim": "blades" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.5 },
	},
	"ninja_honed_edge": {
		"id": "ninja_honed_edge",
		"name": "HONED EDGE",
		"kit": "ninja",
		"desc": "The whetstone carries a keener edge — +12% crit chance while equipped.",
		"color": Color(0.7, 0.9, 0.7),
		"op": "modifier",
		"params": { "stat": "crit_chance", "op": "bonus", "value": 0.12 },
	},
	"ninja_choking_smoke": {
		"id": "ninja_choking_smoke",
		"name": "CHOKING SMOKE",
		"kit": "ninja",
		"desc": "The Whisper's smoky aura weakens enemies — take 12% less damage while equipped.",
		"color": Color(0.5, 0.5, 0.55),
		"op": "modifier",
		"params": { "stat": "damage_taken", "op": "bonus", "value": -0.12 },
	},

	## ── Cleric (The Devout) ───────────────────────────────────────────────────────────────────

	"cleric_purifying_fire": {
		"id": "cleric_purifying_fire",
		"name": "PURIFYING FIRE",
		"kit": "cleric",
		"desc": "Divine Fire strikes 35% harder and sets the impure ablaze.",
		"color": Color(1.0, 0.75, 0.3),
		"target": { "anim": "divine_fire" },
		"op": "scale_aoe",
		"params": { "damage_mult": 1.35 },
	},
	"cleric_words_of_agony": {
		"id": "cleric_words_of_agony",
		"name": "WORDS OF AGONY",
		"kit": "cleric",
		"desc": "Word of Pain's curse zone spreads 50% wider — fewer escape the Devout's judgment.",
		"color": Color(0.6, 0.2, 0.8),
		"target": { "anim": "pray_pain" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.5 },
	},
	"cleric_radiant_smite": {
		"id": "cleric_radiant_smite",
		"name": "RADIANT SMITE",
		"kit": "cleric",
		"desc": "Opening Smite lands 25% harder — the first strike always stings most.",
		"color": Color(1.0, 1.0, 0.7),
		"target": { "anim": "attack" },
		"op": "scale_aoe",
		"params": { "damage_mult": 1.25 },
	},
	"cleric_greater_sanctuary": {
		"id": "cleric_greater_sanctuary",
		"name": "GREATER SANCTUARY",
		"kit": "cleric",
		"desc": "Sanctuary's blessing runs deeper — take 15% less damage while equipped.",
		"color": Color(0.75, 0.95, 1.0),
		"op": "modifier",
		"params": { "stat": "damage_taken", "op": "bonus", "value": -0.15 },
	},

	## ── Druid (The Verdant) ───────────────────────────────────────────────────────────────────

	"druid_savage_maul": {
		"id": "druid_savage_maul",
		"name": "SAVAGE MAUL",
		"kit": "druid",
		"desc": "Beast Maul tears 25% harder across a 30% wider arc of claws.",
		"color": Color(0.55, 0.85, 0.25),
		"target": { "anim": "beast_attack" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.3, "damage_mult": 1.25 },
	},
	"druid_diving_owl": {
		"id": "druid_diving_owl",
		"name": "DIVING OWL",
		"kit": "druid",
		"desc": "Owl Swoop arcs 40% wider — nothing survives the dive.",
		"color": Color(0.8, 0.95, 0.5),
		"target": { "anim": "owl_attack" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.4 },
	},
	"druid_strangling_roots": {
		"id": "druid_strangling_roots",
		"name": "STRANGLING ROOTS",
		"kit": "druid",
		"desc": "Root Summoning zone spreads 50% further — the forest claims more ground.",
		"color": Color(0.25, 0.6, 0.15),
		"target": { "graph": "heavy", "anim": "root_cast" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.5 },
	},
	"druid_pack_leader": {
		"id": "druid_pack_leader",
		"name": "PACK LEADER",
		"kit": "druid",
		"desc": "Hound Frenzy bites 20% harder in a 35% wider frenzy.",
		"color": Color(0.7, 0.5, 0.2),
		"target": { "graph": "channel", "anim": "hound_attack" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.35, "damage_mult": 1.2 },
	},

	## ── Rogue (The Shade) ────────────────────────────────────────────────────────────────────

	"rogue_serrated_shuriken": {
		"id": "rogue_serrated_shuriken",
		"name": "SERRATED SHURIKEN",
		"kit": "rogue",
		"desc": "Shuriken Fan's blades are serrated — every hit applies Bleed.",
		"color": Color(0.9, 0.2, 0.3),
		"target": { "anim": "fan" },
		"op": "add_projectile_status",
		"params": { "status": "bleed", "stacks": 1 },
	},
	"rogue_bigger_bomb": {
		"id": "rogue_bigger_bomb",
		"name": "BIGGER BOMB",
		"kit": "rogue",
		"desc": "Bomb detonates 35% harder across a 40% wider blast radius.",
		"color": Color(1.0, 0.5, 0.1),
		"target": { "anim": "bomb" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.4, "damage_mult": 1.35 },
	},
	"rogue_twin_fan": {
		"id": "rogue_twin_fan",
		"name": "TWIN FAN",
		"kit": "rogue",
		"desc": "Fan of Blades channel covers 45% more area — cast a wider shadow.",
		"color": Color(0.7, 0.15, 0.7),
		"target": { "graph": "channel", "anim": "fan" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.45 },
	},
	"rogue_deep_cuts": {
		"id": "rogue_deep_cuts",
		"name": "DEEP CUTS",
		"kit": "rogue",
		"desc": "The Shade's blades find the gaps — +12% crit chance while equipped.",
		"color": Color(0.55, 0.1, 0.5),
		"op": "modifier",
		"params": { "stat": "crit_chance", "op": "bonus", "value": 0.12 },
	},

	## ── Ranger (The Scavenger) ───────────────────────────────────────────────────────────────

	"ranger_barbed_arrows": {
		"id": "ranger_barbed_arrows",
		"name": "BARBED ARROWS",
		"kit": "ranger",
		"desc": "Arrows are barbed — every shot in the volley chain applies Bleed.",
		"color": Color(0.8, 0.4, 0.15),
		"target": { "graph": "light" },
		"op": "add_projectile_status",
		"params": { "status": "bleed", "stacks": 1 },
	},
	"ranger_impaling_knife": {
		"id": "ranger_impaling_knife",
		"name": "IMPALING KNIFE",
		"kit": "ranger",
		"desc": "Throwing Knife skewers 50% deeper — a heavier, more decisive puncture.",
		"color": Color(0.6, 0.55, 0.3),
		"target": { "anim": "knife" },
		"op": "scale_aoe",
		"params": { "damage_mult": 1.5 },
	},
	"ranger_explosive_tips": {
		"id": "ranger_explosive_tips",
		"name": "EXPLOSIVE TIPS",
		"kit": "ranger",
		"desc": "Triple Shot arrows burst on impact — each hit Ignites the target.",
		"color": Color(1.0, 0.55, 0.1),
		"target": { "anim": "triple_shot" },
		"op": "add_projectile_status",
		"params": { "status": "burning", "stacks": 1 },
	},
	"ranger_ghost_step": {
		"id": "ranger_ghost_step",
		"name": "GHOST STEP",
		"kit": "ranger",
		"desc": "Conceal comes naturally — +15% move speed while equipped.",
		"color": Color(0.55, 0.7, 0.85),
		"op": "modifier",
		"params": { "stat": "move_speed", "op": "bonus", "value": 0.15 },
	},

	## ── Wizard (The Spark) ───────────────────────────────────────────────────────────────────

	"wizard_fireball_scorched_earth": {
		"id": "wizard_fireball_scorched_earth",
		"name": "FIREBALL: SCORCHED EARTH",
		"kit": "wizard",
		"desc": "Fireball Ignites every target it touches — scorched earth in its wake.",
		"color": Color(1.0, 0.35, 0.05),
		"target": { "anim": "fireball_2" },
		"op": "add_projectile_status",
		"params": { "status": "burning", "stacks": 1 },
	},
	"wizard_overload_bolts": {
		"id": "wizard_overload_bolts",
		"name": "OVERLOAD BOLTS",
		"kit": "wizard",
		"desc": "Staff bolts and the Fireball hit 30% harder — the Spark overloads every cast.",
		"color": Color(1.0, 0.8, 0.2),
		"target": { "graph": "light" },
		"op": "scale_aoe",
		"params": { "damage_mult": 1.3 },
	},
	"wizard_torrent_surge": {
		"id": "wizard_torrent_surge",
		"name": "BURST SURGE",
		"kit": "wizard",
		"desc": "The Fire Burst finisher blooms 50% wider — the nova fills the room.",
		"color": Color(1.0, 0.55, 0.15),
		"target": { "graph": "light", "anim": "fireburst" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.5 },
	},
	"wizard_ember_familiar": {
		"id": "wizard_ember_familiar",
		"name": "EMBER FAMILIAR",
		"kit": "wizard",
		"desc": "The familiar burns hotter — +15% damage while equipped.",
		"color": Color(0.9, 0.4, 0.1),
		"op": "modifier",
		"params": { "stat": "damage", "op": "bonus", "value": 0.15 },
	},

	## ── Blood Mage (The Cursed) ──────────────────────────────────────────────────────────────

	"blood_mage_hemorrhage_shards": {
		"id": "blood_mage_hemorrhage_shards",
		"name": "HEMORRHAGE SHARDS",
		"kit": "blood_mage",
		"desc": "Blood Shards carry a hemorrhaging edge — every shard applies Bleed.",
		"color": Color(0.75, 0.05, 0.05),
		"target": { "anim": "shards" },
		"op": "add_projectile_status",
		"params": { "status": "bleed", "stacks": 1 },
	},
	"blood_mage_deeper_pact": {
		"id": "blood_mage_deeper_pact",
		"name": "DEEPER PACT",
		"kit": "blood_mage",
		"desc": "The blood pact runs deeper — +20% damage while equipped.",
		"color": Color(0.85, 0.1, 0.1),
		"op": "modifier",
		"params": { "stat": "damage", "op": "bonus", "value": 0.20 },
	},
	"blood_mage_bloodquake": {
		"id": "blood_mage_bloodquake",
		"name": "BLOODQUAKE",
		"kit": "blood_mage",
		"desc": "Blood Spikes erupt 20% harder across a 45% wider crimson field.",
		"color": Color(0.9, 0.2, 0.15),
		"target": { "anim": "spikes" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.45, "damage_mult": 1.2 },
	},
	"blood_mage_sanguine_drain": {
		"id": "blood_mage_sanguine_drain",
		"name": "SANGUINE DRAIN",
		"kit": "blood_mage",
		"desc": "The drain draws more deeply — +18% damage increases each Vampirize beat's yield.",
		"color": Color(0.6, 0.0, 0.2),
		"op": "modifier",
		"params": { "stat": "damage", "op": "bonus", "value": 0.18 },
	},

	## ── Bard (The Herald) ────────────────────────────────────────────────────────────────────

	"bard_piercing_chord": {
		"id": "bard_piercing_chord",
		"name": "PIERCING CHORD",
		"kit": "bard",
		"desc": "Dissonant Chord rings 35% louder — the sound-bolt hits harder.",
		"color": Color(0.75, 0.35, 1.0),
		"target": { "anim": "chord" },
		"op": "scale_aoe",
		"params": { "damage_mult": 1.35 },
	},
	"bard_cruel_mockery": {
		"id": "bard_cruel_mockery",
		"name": "CRUEL MOCKERY",
		"kit": "bard",
		"desc": "Vicious Mockery insults a 35% wider crowd, hitting each victim 20% harder.",
		"color": Color(0.9, 0.3, 0.7),
		"target": { "anim": "mockery" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.35, "damage_mult": 1.2 },
	},
	"bard_rousing_ballad": {
		"id": "bard_rousing_ballad",
		"name": "ROUSING BALLAD",
		"kit": "bard",
		"desc": "The ballad lifts the Herald's spirit — +15% damage while equipped.",
		"color": Color(0.8, 0.55, 1.0),
		"op": "modifier",
		"params": { "stat": "damage", "op": "bonus", "value": 0.15 },
	},
	"bard_encore": {
		"id": "bard_encore",
		"name": "ENCORE",
		"kit": "bard",
		"desc": "Apotheosis divine burst is 25% stronger across a 50% wider radius — they beg for more.",
		"color": Color(1.0, 0.85, 0.4),
		"target": { "anim": "apotheosis" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.5, "damage_mult": 1.25 },
	},

	## ── Barbarian (The Ravager) ───────────────────────────────────────────────────────────────

	"barbarian_earthsplitter": {
		"id": "barbarian_earthsplitter",
		"name": "EARTHSPLITTER",
		"kit": "barbarian",
		"desc": "Sunder fractures the ground 25% harder across a 45% wider break.",
		"color": Color(0.85, 0.4, 0.05),
		"target": { "anim": "sunder" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.45, "damage_mult": 1.25 },
	},
	"barbarian_chained_lightning": {
		"id": "barbarian_chained_lightning",
		"name": "CHAINED LIGHTNING",
		"kit": "barbarian",
		"desc": "Thunder Blade crackles 40% harder — the lightning jumps further.",
		"color": Color(0.6, 0.7, 1.0),
		"target": { "anim": "thunder" },
		"op": "scale_aoe",
		"params": { "damage_mult": 1.4 },
	},
	"barbarian_iron_wall": {
		"id": "barbarian_iron_wall",
		"name": "IRON WALL",
		"kit": "barbarian",
		"desc": "The Ravager's guard is iron — take 18% less damage while equipped.",
		"color": Color(0.65, 0.65, 0.75),
		"op": "modifier",
		"params": { "stat": "damage_taken", "op": "bonus", "value": -0.18 },
	},
	"barbarian_deafening_cry": {
		"id": "barbarian_deafening_cry",
		"name": "DEAFENING CRY",
		"kit": "barbarian",
		"desc": "Battle Cry echoes with pure fury — +15% damage while equipped.",
		"color": Color(1.0, 0.3, 0.05),
		"op": "modifier",
		"params": { "stat": "damage", "op": "bonus", "value": 0.15 },
	},

	## ── Gunslinger (The Deadeye) ─────────────────────────────────────────────────────────────

	"gunslinger_fan_the_hammer_plus2": {
		"id": "gunslinger_fan_the_hammer_plus2",
		"name": "FAN THE HAMMER +2",
		"kit": "gunslinger",
		"desc": "Fan the Hammer fires 2 extra bullets — 7 shots, all at once.",
		"color": Color(0.85, 0.85, 0.95),
		"target": { "anim": "fan" },
		"op": "add_projectiles",
		"params": { "count": 2 },
	},
	"gunslinger_hollow_points": {
		"id": "gunslinger_hollow_points",
		"name": "HOLLOW POINTS",
		"kit": "gunslinger",
		"desc": "Hollow-point rounds tear through flesh — every shot in the light chain applies Bleed.",
		"color": Color(0.7, 0.15, 0.15),
		"target": { "graph": "light" },
		"op": "add_projectile_status",
		"params": { "status": "bleed", "stacks": 1 },
	},
	"gunslinger_suppressing_storm": {
		"id": "gunslinger_suppressing_storm",
		"name": "SUPPRESSING STORM",
		"kit": "gunslinger",
		"desc": "Desert Storm volley hits 30% harder — the storm suppresses everything.",
		"color": Color(0.5, 0.6, 0.8),
		"target": { "graph": "channel", "anim": "storm" },
		"op": "scale_aoe",
		"params": { "damage_mult": 1.3 },
	},
	"gunslinger_quickdraw": {
		"id": "gunslinger_quickdraw",
		"name": "QUICKDRAW",
		"kit": "gunslinger",
		"desc": "Loaded chambers keep the edge sharp — +10% crit chance while equipped.",
		"color": Color(0.9, 0.8, 0.55),
		"op": "modifier",
		"params": { "stat": "crit_chance", "op": "bonus", "value": 0.10 },
	},
}


## Stable display order per kit (armory / pickers). Only ids present here appear in the class-mod
## drop pool and armory list — mirrors ModData.ORDER excluding hidden/unique entries.
const ORDER: Array = [
	## Fighter
	"fighter_overcharged_cataclysm",
	"fighter_tempest_vortex",
	"fighter_sustained_whirlwind",
	"fighter_concussive_taunt",
	## Paladin
	"paladin_thunderous_bash",
	"paladin_blessed_hammer_storm",
	"paladin_dictums_reach",
	"paladin_retribution_dome",
	## Ninja
	"ninja_bleeding_blades",
	"ninja_endless_storm",
	"ninja_honed_edge",
	"ninja_choking_smoke",
	## Cleric
	"cleric_purifying_fire",
	"cleric_words_of_agony",
	"cleric_radiant_smite",
	"cleric_greater_sanctuary",
	## Druid
	"druid_savage_maul",
	"druid_diving_owl",
	"druid_strangling_roots",
	"druid_pack_leader",
	## Rogue
	"rogue_serrated_shuriken",
	"rogue_bigger_bomb",
	"rogue_twin_fan",
	"rogue_deep_cuts",
	## Ranger
	"ranger_barbed_arrows",
	"ranger_impaling_knife",
	"ranger_explosive_tips",
	"ranger_ghost_step",
	## Wizard
	"wizard_fireball_scorched_earth",
	"wizard_overload_bolts",
	"wizard_torrent_surge",
	"wizard_ember_familiar",
	## Blood Mage
	"blood_mage_hemorrhage_shards",
	"blood_mage_deeper_pact",
	"blood_mage_bloodquake",
	"blood_mage_sanguine_drain",
	## Bard
	"bard_piercing_chord",
	"bard_cruel_mockery",
	"bard_rousing_ballad",
	"bard_encore",
	## Barbarian
	"barbarian_earthsplitter",
	"barbarian_chained_lightning",
	"barbarian_iron_wall",
	"barbarian_deafening_cry",
	## Gunslinger
	"gunslinger_fan_the_hammer_plus2",
	"gunslinger_hollow_points",
	"gunslinger_suppressing_storm",
	"gunslinger_quickdraw",
]


## All class-mod ids bound to a kit, in ORDER.
static func ids_for_kit(kit_id: String) -> Array:
	var out: Array = []
	for mod_id: String in ORDER:
		if ALL.get(mod_id, {}).get("kit", "") == kit_id:
			out.append(mod_id)
	return out
