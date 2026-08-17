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
##             "kit_flag"            — NOT a phase mutation. The entity reads the equipped id
##                                     directly and changes its own routing (player._load_combo).
##                                     For mods whose effect is "which graph runs", which no
##                                     per-phase op can express. Use sparingly — a phase op is
##                                     always preferable when one will do.
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
		"rarity": "uncommon",
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
		"rarity": "epic",
		"desc": "Tempest becomes a vortex - enemies are dragged into the blade before it hits.",
		"color": Color(0.55, 0.75, 1.0),
		"target": { "graph": "light", "anim": "tempest" },
		"op": "add_pull",
		"params": { "distance": 260.0, "duration": 0.16, "arc_height": 4.0 },
	},
	"fighter_sustained_whirlwind": {
		"id": "fighter_sustained_whirlwind",
		"name": "SUSTAINED WHIRLWIND",
		"kit": "fighter",
		"rarity": "uncommon",
		"desc": "Whirlwind spins 40% wider - the spin-to-win option.",
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
		"rarity": "rare",
		"desc": "Taunt shockwave ticks chill the ring, slowing enemies caught in its pulse.",
		"color": Color(0.55, 0.85, 1.0),
		"target": { "graph": "channel", "anim": "taunt" },
		"op": "add_status",
		"params": { "status": "chilled", "stacks": 1 },
	},

	"fighter_blood_wages": {
		"id": "fighter_blood_wages",
		"name": "BLOOD WAGES",
		"kit": "fighter",
		"rarity": "uncommon",
		"desc": "The Sellsword takes payment in blood - a share of all damage dealt returns as health.",
		"color": Color(0.85, 0.20, 0.50),
		"op": "modifier",
		"params": { "stat": "leech", "op": "bonus", "value": 0.06 },
	},
	"fighter_opening_cut": {
		"id": "fighter_opening_cut",
		"name": "OPENING CUT",
		"kit": "fighter",
		"rarity": "rare",
		"desc": "The chain's first swing opens a wound that keeps bleeding through the rest of it.",
		"color": Color(0.85, 0.15, 0.15),
		"target": { "graph": "light", "anim": "attack" },
		"op": "add_status",
		"params": { "status": "bleed", "stacks": 1 },
	},
	"fighter_shattering_uppercut": {
		"id": "fighter_shattering_uppercut",
		"name": "SHATTERING UPPERCUT",
		"kit": "fighter",
		"rarity": "uncommon",
		"desc": "The launch hits 25% harder across a 40% wider arc - the whole ring goes up, not one enemy.",
		"color": Color(1.0, 0.75, 0.30),
		"target": { "anim": "uppercut" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.4, "damage_mult": 1.25 },
	},
	"fighter_grappling_rush": {
		"id": "fighter_grappling_rush",
		"name": "GRAPPLING RUSH",
		"kit": "fighter",
		"rarity": "rare",
		"desc": "Rush drags everything it clips along with it, dumping the pack where you stop.",
		"color": Color(0.55, 0.75, 1.0),
		"target": { "graph": "skill_e", "anim": "rush" },
		"op": "add_pull",
		"params": { "distance": 220.0, "duration": 0.18, "arc_height": 5.0 },
	},

	## ── Paladin (The Warden) ──────────────────────────────────────────────────────────────────

	"paladin_thunderous_bash": {
		"id": "paladin_thunderous_bash",
		"name": "THUNDEROUS BASH",
		"kit": "paladin",
		"rarity": "rare",
		"desc": "Shield Bash hits 25% harder across a 35% wider shockwave.",
		"color": Color(1.0, 0.85, 0.2),
		"target": { "anim": "bash" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.35, "damage_mult": 1.25 },
	},
	## The two hammer mods approved in spirit during the 2026-07-20 ability wave and built
	## 2026-08-15. Both are kit_flag: a Holy Hammer is a HolyHammer *entity* spawned by
	## player.gd at the hit frame, not an effect on the phase, so no phase op can reach it.
	## They took the roster slots of BLESSED HAMMER STORM (rare, hammer ×1.40 dmg) and
	## DICTUM'S REACH (uncommon, dictum ×1.45 radius) — RARITY_SHAPE is a hard 1/3/4 per kit, so
	## two had to go. These two cost nothing to retire: both survive verbatim in the level-up pool
	## as `paladin_hammer_storm` and `paladin_ringing_dictum`, and they were the only two Warden
	## mods not pinned as an EVOLUTION requirement. Both were also pure damage/radius numbers,
	## which is the layer ability upgrades are for; class mods should change what a button DOES.
	"paladin_shattering_hammers": {
		"id": "paladin_shattering_hammers",
		"name": "SHATTERING HAMMERS",
		"kit": "paladin",
		"rarity": "rare",
		"desc": "The first thing each blessed hammer strikes breaks a piece off it - two splinters spiral out of the wound.",
		"color": Color(1.0, 1.0, 0.55),
		"op": "kit_flag",
		"params": {},
	},
	"paladin_bound_spiral": {
		"id": "paladin_bound_spiral",
		"name": "BOUND SPIRAL",
		"kit": "paladin",
		"rarity": "uncommon",
		"desc": "The hammers are sworn to the Warden, not to the ground. Their spirals travel with him.",
		"color": Color(0.95, 0.90, 0.65),
		"op": "kit_flag",
		"params": {},
	},
	"paladin_retribution_dome": {
		"id": "paladin_retribution_dome",
		"name": "RETRIBUTION DOME",
		"kit": "paladin",
		"rarity": "epic",
		"desc": "Reckoning's dome Ignites everything that presses against it while held.",
		"color": Color(1.0, 0.45, 0.15),
		"target": { "graph": "channel", "anim": "dome" },
		"op": "add_status",
		"params": { "status": "burning", "stacks": 1 },
	},

	"paladin_aegis_plating": {
		"id": "paladin_aegis_plating",
		"name": "AEGIS PLATING",
		"kit": "paladin",
		"rarity": "uncommon",
		"desc": "Layered plate over the Warden's chest. Physical blows glance off.",
		"color": Color(0.80, 0.82, 0.90),
		"op": "modifier",
		## Armor is NOT a get_stat tag — player.get_armor() reads ("Physical", "resist").
		"params": { "stat": "Physical", "op": "resist", "value": 20.0 },
	},
	"paladin_shield_wall": {
		"id": "paladin_shield_wall",
		"name": "SHIELD WALL",
		"kit": "paladin",
		"rarity": "uncommon",
		"desc": "The shield is always up. Far more incoming hits are turned aside outright.",
		"color": Color(1.0, 0.85, 0.35),
		"op": "modifier",
		"params": { "stat": "block_chance", "op": "add", "value": 0.15 },
	},
	"paladin_sworn_thorns": {
		"id": "paladin_sworn_thorns",
		"name": "SWORN THORNS",
		"kit": "paladin",
		"rarity": "rare",
		"desc": "The Vow answers for you - everything that strikes the Warden is struck back.",
		"color": Color(0.95, 0.95, 0.70),
		"target": { "graph": "skill_q", "anim": "vow" },
		"op": "add_status",
		"params": { "status": "thorns_passive", "stacks": 1, "apply_to_self": true },
	},
	"paladin_relentless_vow": {
		"id": "paladin_relentless_vow",
		"name": "RELENTLESS VOW",
		"kit": "paladin",
		"rarity": "uncommon",
		"desc": "Oaths come round faster. Every cooldown the Warden carries is shortened.",
		"color": Color(1.0, 1.0, 0.55),
		"op": "modifier",
		"params": { "stat": "All", "op": "cooldown_reduce", "value": 0.12 },
	},

	## ── Ninja (The Whisper) ───────────────────────────────────────────────────────────────────

	"ninja_bleeding_blades": {
		"id": "ninja_bleeding_blades",
		"name": "BLEEDING BLADES",
		"kit": "ninja",
		"rarity": "epic",
		"desc": "Every cut in the light chain applies Bleed - even the blade storm.",
		"color": Color(0.85, 0.15, 0.15),
		"target": { "graph": "light" },
		"op": "add_status",
		"params": { "status": "bleed", "stacks": 1 },
	},
	"ninja_endless_storm": {
		"id": "ninja_endless_storm",
		"name": "ENDLESS STORM",
		"kit": "ninja",
		"rarity": "rare",
		"desc": "Thousand Blades Storm expands 50% - the blade nova fills the room.",
		"color": Color(0.35, 0.85, 0.75),
		"target": { "graph": "channel", "anim": "blades" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.5 },
	},
	"ninja_honed_edge": {
		"id": "ninja_honed_edge",
		"name": "HONED EDGE",
		"kit": "ninja",
		"rarity": "uncommon",
		"desc": "The whetstone carries a keener edge - +12% crit chance while equipped.",
		"color": Color(0.7, 0.9, 0.7),
		"op": "modifier",
		## "add", not "bonus": DamageCalculator rolls crit off sum_modifiers("crit_chance", "add")
		## and nothing calls get_stat("crit_chance"), so a "bonus" entry was never read. The value is
		## unchanged because "add" is already the percentage-point convention the level-up
		## Critical Strike upgrade and every passive-tree crit node use (fixed 2026-08-01).
		"params": { "stat": "crit_chance", "op": "add", "value": 0.12 },
	},
	"ninja_choking_smoke": {
		"id": "ninja_choking_smoke",
		"name": "CHOKING SMOKE",
		"kit": "ninja",
		"rarity": "uncommon",
		"desc": "The Whisper's smoky aura weakens enemies - take 12% less damage while equipped.",
		"color": Color(0.5, 0.5, 0.55),
		"op": "modifier",
		## ("All", "damage_taken"), not ("damage_taken", "bonus") — see SkillFactory._ward_buff.
		## DamageCalculator only ever reads reduction as (damage_type|"All", "damage_taken"), so the
		## old pair was never looked up and this mod reduced nothing (fixed 2026-08-01).
		"params": { "stat": "All", "op": "damage_taken", "value": -0.12 },
	},

	"ninja_deep_cut": {
		"id": "ninja_deep_cut",
		"name": "DEEP CUT",
		"kit": "ninja",
		"rarity": "uncommon",
		"desc": "The Whisper knows where to put the blade. Critical hits land far harder.",
		"color": Color(0.90, 0.25, 0.35),
		"op": "modifier",
		"params": { "stat": "crit_multiplier", "op": "add", "value": 0.40 },
	},
	"ninja_blinding_smoke": {
		"id": "ninja_blinding_smoke",
		"name": "BLINDING SMOKE",
		"kit": "ninja",
		"rarity": "rare",
		"desc": "The smoke bites. Anything left standing in it is chilled to a crawl.",
		"color": Color(0.55, 0.85, 1.0),
		"target": { "graph": "skill_e", "anim": "smoke" },
		"op": "add_status",
		"params": { "status": "chilled", "stacks": 1 },
	},
	"ninja_finishing_flourish": {
		"id": "ninja_finishing_flourish",
		"name": "FINISHING FLOURISH",
		"kit": "ninja",
		"rarity": "uncommon",
		"desc": "The storm's last turn hits 30% harder across a 35% wider circle.",
		"color": Color(0.85, 0.90, 1.0),
		"target": { "anim": "blades_end" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.35, "damage_mult": 1.30 },
	},
	"ninja_whetstone_ritual": {
		"id": "ninja_whetstone_ritual",
		"name": "WHETSTONE RITUAL",
		"kit": "ninja",
		"rarity": "rare",
		"desc": "Sharpen leaves a serrated edge behind - every cut afterwards bleeds.",
		"color": Color(0.80, 0.20, 0.20),
		"target": { "graph": "skill_q", "anim": "sharpen" },
		"op": "add_status",
		"params": { "status": "serrated_strikes", "stacks": 1, "apply_to_self": true },
	},

	## ── Cleric (The Devout) ───────────────────────────────────────────────────────────────────

	"cleric_purifying_fire": {
		"id": "cleric_purifying_fire",
		"name": "PURIFYING FIRE",
		"kit": "cleric",
		"rarity": "rare",
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
		"rarity": "rare",
		"desc": "Word of Pain's curse zone spreads 50% wider - fewer escape the Devout's judgment.",
		"color": Color(0.6, 0.2, 0.8),
		"target": { "anim": "pray_pain" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.5 },
	},
	"cleric_radiant_smite": {
		"id": "cleric_radiant_smite",
		"name": "RADIANT SMITE",
		"kit": "cleric",
		"rarity": "rare",
		"desc": "Opening Smite lands 25% harder - the first strike always stings most.",
		"color": Color(1.0, 1.0, 0.7),
		"target": { "anim": "attack" },
		"op": "scale_aoe",
		"params": { "damage_mult": 1.25 },
	},
	"cleric_greater_sanctuary": {
		"id": "cleric_greater_sanctuary",
		"name": "GREATER SANCTUARY",
		"kit": "cleric",
		"rarity": "uncommon",
		"desc": "Sanctuary's blessing runs deeper - take 15% less damage while equipped.",
		"color": Color(0.75, 0.95, 1.0),
		"op": "modifier",
		## ("All", "damage_taken") — the ("damage_taken", "bonus") pair is never read. See above.
		"params": { "stat": "All", "op": "damage_taken", "value": -0.15 },
	},

	"cleric_censer_embers": {
		"id": "cleric_censer_embers",
		"name": "CENSER EMBERS",
		"kit": "cleric",
		"rarity": "epic",
		"desc": "The divine fire clings. Everything it touches goes on burning.",
		"color": Color(1.0, 0.60, 0.20),
		"target": { "anim": "divine_fire" },
		"op": "add_projectile_status",
		"params": { "status": "burning", "stacks": 1 },
	},
	"cleric_guardians_wrath": {
		"id": "cleric_guardians_wrath",
		"name": "GUARDIAN'S WRATH",
		"kit": "cleric",
		"rarity": "uncommon",
		"desc": "The guardian answers with force - 25% harder across a 40% wider circle.",
		"color": Color(1.0, 0.95, 0.65),
		"target": { "graph": "skill_e", "anim": "pray_guardian" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.40, "damage_mult": 1.25 },
	},
	"cleric_lingering_grace": {
		"id": "cleric_lingering_grace",
		"name": "LINGERING GRACE",
		"kit": "cleric",
		"rarity": "uncommon",
		"desc": "Blessings and afflictions alike hold 25% longer.",
		"color": Color(0.90, 0.90, 1.0),
		"op": "modifier",
		"params": { "stat": "status_duration", "op": "bonus", "value": 0.25 },
	},
	"cleric_fervent_prayer": {
		"id": "cleric_fervent_prayer",
		"name": "FERVENT PRAYER",
		"kit": "cleric",
		"rarity": "uncommon",
		"desc": "Every prayer mends more. All healing the Devout performs is 35% stronger.",
		"color": Color(0.70, 1.0, 0.75),
		"op": "modifier",
		"params": { "stat": "Heal", "op": "bonus", "value": 0.35 },
	},

	## ── Druid (The Verdant) ───────────────────────────────────────────────────────────────────

	## Retargeted 2026-08-02 alongside the ability upgrades: the shapeshift kit is gone
	## (0f5dfed), so "beast_attack" and "owl_attack" matched no phase and these two did
	## nothing while equipped. The IDS ARE DELIBERATELY UNCHANGED — class-mod ids are
	## persisted in ProgressionManager.character_mods/owned_mods, and get_active_class_mods
	## silently drops ids it can't resolve, so a rename would quietly delete an equipped mod
	## from a live save. Names/descriptions/targets changed; ids frozen.
	"druid_savage_maul": {
		"id": "druid_savage_maul",
		"name": "SAVAGE THORNS",
		"kit": "druid",
		"rarity": "rare",
		"desc": "The opening Thorn bites 25% harder - the first seed carries the most spite.",
		"color": Color(0.55, 0.85, 0.25),
		"target": { "graph": "light", "anim": "attack" },
		"op": "scale_aoe",
		## No radius_mult: a thorn is a projectile, and _scale_effects has no radius to scale
		## on SpawnProjectilesEffect — it would read as a buff and apply nothing.
		"params": { "damage_mult": 1.25 },
	},
	"druid_diving_owl": {
		"id": "druid_diving_owl",
		"name": "BRISTLING VOLLEY",
		"kit": "druid",
		"rarity": "rare",
		"desc": "Thorn II and Bramble Volley each carry one more thorn.",
		"color": Color(0.8, 0.95, 0.5),
		## "attack_2" is BOTH light phases 1 and 2 — the mod hits both, which is what the
		## description says. graph pins it out of the channel, which shares the anim name.
		"target": { "graph": "light", "anim": "attack_2" },
		"op": "add_projectiles",
		"params": { "count": 1 },
	},
	"druid_strangling_roots": {
		"id": "druid_strangling_roots",
		"name": "STRANGLING ROOTS",
		"kit": "druid",
		"rarity": "rare",
		"desc": "Root Summoning zone spreads 50% further - the forest claims more ground.",
		"color": Color(0.25, 0.6, 0.15),
		"target": { "graph": "heavy", "anim": "root_cast" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.5 },
	},
	"druid_pack_leader": {
		"id": "druid_pack_leader",
		"name": "ENDLESS BRAMBLE",
		"kit": "druid",
		"rarity": "uncommon",
		"desc": "Bramble Barrage beats 20% harder for as long as you hold it.",
		"color": Color(0.7, 0.5, 0.2),
		## Was the Hound Frenzy channel; the channel is Bramble Barrage now and its beat
		## plays "attack_2". Id frozen for save compatibility — see the note above.
		"target": { "graph": "channel", "anim": "attack_2" },
		"op": "scale_aoe",
		"params": { "damage_mult": 1.2 },
	},

	"druid_thorned_seeds": {
		"id": "druid_thorned_seeds",
		"name": "THORNED SEEDS",
		"kit": "druid",
		"rarity": "epic",
		"desc": "Barbed seed pods. Everything the Verdant looses draws blood that keeps running.",
		"color": Color(0.55, 0.80, 0.35),
		"target": { "graph": "light" },
		"op": "add_projectile_status",
		"params": { "status": "bleed", "stacks": 1 },
	},
	"druid_ursine_fury": {
		"id": "druid_ursine_fury",
		"name": "URSINE FURY",
		"kit": "druid",
		"rarity": "uncommon",
		"desc": "The bear arrives angry - its opening maul lands 35% harder.",
		"color": Color(0.70, 0.50, 0.30),
		"target": { "graph": "skill_q", "anim": "summon_bear" },
		"op": "scale_aoe",
		"params": { "damage_mult": 1.35 },
	},
	"druid_pack_hunter": {
		"id": "druid_pack_hunter",
		"name": "PACK HUNTER",
		"kit": "druid",
		"rarity": "uncommon",
		"desc": "The hounds break wide, hitting 20% harder across a 40% broader sweep.",
		"color": Color(0.75, 0.70, 0.55),
		"target": { "graph": "skill_e", "anim": "summon_hounds" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.40, "damage_mult": 1.20 },
	},
	"druid_barkskin": {
		"id": "druid_barkskin",
		"name": "BARKSKIN",
		"kit": "druid",
		"rarity": "uncommon",
		"desc": "Bark closes over skin. Physical blows bite far less deep.",
		"color": Color(0.50, 0.40, 0.25),
		"op": "modifier",
		"params": { "stat": "Physical", "op": "resist", "value": 18.0 },
	},

	## ── Necromancer (The Shade) ──────────────────────────────────────────────────────────────

	"necro_splintering_swirl": {
		"id": "necro_splintering_swirl",
		"name": "SPLINTERING SWIRL",
		"kit": "necromancer",
		"rarity": "rare",
		"desc": "Bone Swirl scatters 40% wider and bites 25% harder.",
		"color": Color(0.7, 0.15, 0.7),
		"target": { "anim": "bone_swirl" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.4, "damage_mult": 1.25 },
	},
	"necro_grave_bond": {
		"id": "necro_grave_bond",
		"name": "GRAVE BOND",
		"kit": "necromancer",
		"rarity": "uncommon",
		"desc": "The dead lend their vigor - +12% Max HP while equipped.",
		"color": Color(0.5, 0.2, 0.55),
		"op": "modifier",
		"params": { "stat": "max_hp", "op": "bonus", "value": 0.12 },
	},
	"necro_dark_haste": {
		"id": "necro_dark_haste",
		"name": "DARK HASTE",
		"kit": "necromancer",
		"rarity": "uncommon",
		"desc": "The grave answers quicker - 12% Cooldown Reduction on all abilities.",
		"color": Color(0.4, 0.25, 0.7),
		"op": "modifier",
		"params": { "stat": "All", "op": "cooldown_reduce", "value": 0.12 },
	},
	"necro_soul_leech": {
		"id": "necro_soul_leech",
		"name": "SOUL LEECH",
		"kit": "necromancer",
		"rarity": "uncommon",
		"desc": "Every wound drinks a little life back - +5% Lifesteal.",
		"color": Color(0.55, 0.1, 0.5),
		"op": "modifier",
		"params": { "stat": "leech", "op": "bonus", "value": 0.05 },
	},

	"necro_marrow_shards": {
		"id": "necro_marrow_shards",
		"name": "MARROW SHARDS",
		"kit": "necromancer",
		"rarity": "rare",
		"desc": "The bones splinter on impact and stay in the wound.",
		"color": Color(0.85, 0.80, 0.70),
		"target": { "anim": "bone_cast" },
		"op": "add_projectile_status",
		"params": { "status": "bleed", "stacks": 1 },
	},
	"necro_endless_bones": {
		"id": "necro_endless_bones",
		"name": "ENDLESS BONES",
		"kit": "necromancer",
		"rarity": "rare",
		"desc": "Two more missiles in every cast. The ossuary does not run dry.",
		"color": Color(0.90, 0.88, 0.80),
		"target": { "anim": "bone_cast" },
		"op": "add_projectiles",
		"params": { "count": 2 },
	},
	"necro_grave_legion": {
		"id": "necro_grave_legion",
		"name": "GRAVE LEGION",
		"kit": "necromancer",
		"rarity": "uncommon",
		"desc": "The legion rises wider and hits 25% harder.",
		"color": Color(0.60, 0.45, 0.75),
		"target": { "graph": "skill_e", "anim": "bone_legion" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.40, "damage_mult": 1.25 },
	},
	## The new home for the retired generic INSTABILITY SIPHON (2026-08-08). It was a universal
	## weapon mod; with the generic layer gone it needed one owner, and soul-harvest is the Shade's
	## whole thesis. `kit_flag` because the effect is "the entity behaves differently on kill" —
	## no per-phase op can express that. player._load_combo reads the equipped id directly.
	"necro_soul_tithe": {
		"id": "necro_soul_tithe",
		"name": "SOUL TITHE",
		"kit": "necromancer",
		"rarity": "epic",
		"desc": "Every soul the Shade takes is paid to the dark. Kills bleed off Instability - manage haul risk through aggression.",
		"color": Color(0.40, 1.0, 0.55),
		"op": "kit_flag",
		"params": {},
	},

	## ── Ranger (The Scavenger) ───────────────────────────────────────────────────────────────

	"ranger_barbed_arrows": {
		"id": "ranger_barbed_arrows",
		"name": "BARBED ARROWS",
		"kit": "ranger",
		"rarity": "rare",
		"desc": "Arrows are barbed - every shot in the volley chain applies Bleed.",
		"color": Color(0.8, 0.4, 0.15),
		"target": { "graph": "light" },
		"op": "add_projectile_status",
		"params": { "status": "bleed", "stacks": 1 },
	},
	"ranger_impaling_knife": {
		"id": "ranger_impaling_knife",
		"name": "IMPALING KNIFE",
		"kit": "ranger",
		"rarity": "uncommon",
		"desc": "Throwing Knife skewers 50% deeper - a heavier, more decisive puncture.",
		"color": Color(0.6, 0.55, 0.3),
		"target": { "anim": "knife" },
		"op": "scale_aoe",
		"params": { "damage_mult": 1.5 },
	},
	"ranger_explosive_tips": {
		"id": "ranger_explosive_tips",
		"name": "EXPLOSIVE TIPS",
		"kit": "ranger",
		"rarity": "rare",
		"desc": "Triple Shot arrows burst on impact - each hit Ignites the target.",
		"color": Color(1.0, 0.55, 0.1),
		"target": { "anim": "triple_shot" },
		"op": "add_projectile_status",
		"params": { "status": "burning", "stacks": 1 },
	},
	"ranger_ghost_step": {
		"id": "ranger_ghost_step",
		"name": "GHOST STEP",
		"kit": "ranger",
		"rarity": "uncommon",
		## Re-flavoured 2026-07-31: Conceal is gone (the E slot is Quiver Swap now), so the mod
		## stands on the Scavenger's own footwork instead of naming a skill that no longer exists.
		## The number is unchanged.
		"desc": "She leaves no trail - +15% move speed while equipped.",
		"color": Color(0.55, 0.7, 0.85),
		"op": "modifier",
		"params": { "stat": "move_speed", "op": "bonus", "value": 0.15 },
	},
	## The Scavenger's rare (Ben 2026-07-31: "a rare mod can change all of her arrows or something
	## and combine the elements too"). Two effects, both routing-level, hence "kit_flag":
	##   1. the loaded head rides the LIGHT chain too — unmodded, neutral LMB is what keeps the
	##      stance a decision rather than a flat upgrade, so lifting that is the mod's whole prize;
	##   2. every armed arrow carries the OFF-hand status underneath its own, applied first. A Fire
	##      arrow therefore lands Chilled then Burning and trips the Frostfire listener chilled
	##      already ships (StatusFactory._build_chilled) on its own hit — a small Fire AoE on every
	##      arrow, self-limiting because Frostfire consumes the chill it just applied.
	## Both are read by player._load_combo / player.apply_quiver; no phase is mutated.
	"ranger_split_quiver": {
		"id": "ranger_split_quiver",
		"name": "SPLIT QUIVER",
		"kit": "ranger",
		"rarity": "epic",
		"desc": "Both heads on every shaft. The loaded element rides your whole chain, and each arrow carries the other element under it - fire detonates its own frost.",
		"color": Color(0.85, 0.55, 0.95),
		"op": "kit_flag",
		"params": {},
	},

	"ranger_hunters_focus": {
		"id": "ranger_hunters_focus",
		"name": "HUNTER'S FOCUS",
		"kit": "ranger",
		"rarity": "uncommon",
		"desc": "Breath held, gap found. The Scavenger crits far more often.",
		"color": Color(1.0, 0.85, 0.40),
		"op": "modifier",
		"params": { "stat": "crit_chance", "op": "add", "value": 0.10 },
	},
	"ranger_pinning_shot": {
		"id": "ranger_pinning_shot",
		"name": "PINNING SHOT",
		"kit": "ranger",
		"rarity": "rare",
		"desc": "The paired arrows pin what they hit - chilled, and easy to keep at range.",
		"color": Color(0.55, 0.85, 1.0),
		"target": { "anim": "double_shot" },
		"op": "add_projectile_status",
		"params": { "status": "chilled", "stacks": 1 },
	},
	"ranger_close_quarters": {
		"id": "ranger_close_quarters",
		"name": "CLOSE QUARTERS",
		"kit": "ranger",
		"rarity": "uncommon",
		"desc": "When they get inside the bow, the answer hits 30% harder over a 35% wider swing.",
		"color": Color(0.80, 0.75, 0.60),
		"target": { "graph": "heavy", "anim": "melee" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.35, "damage_mult": 1.30 },
	},

	## ── Wizard (The Spark) ───────────────────────────────────────────────────────────────────

	"wizard_fireball_scorched_earth": {
		"id": "wizard_fireball_scorched_earth",
		"name": "FIREBALL: SCORCHED EARTH",
		"kit": "wizard",
		"rarity": "rare",
		"desc": "Fireball Ignites every target it touches - scorched earth in its wake.",
		"color": Color(1.0, 0.35, 0.05),
		"target": { "anim": "fireball_2" },
		"op": "add_projectile_status",
		"params": { "status": "burning", "stacks": 1 },
	},
	"wizard_overload_bolts": {
		"id": "wizard_overload_bolts",
		"name": "OVERLOAD BOLTS",
		"kit": "wizard",
		"rarity": "rare",
		"desc": "Staff bolts and the Fireball hit 30% harder - the Spark overloads every cast.",
		"color": Color(1.0, 0.8, 0.2),
		"target": { "graph": "light" },
		"op": "scale_aoe",
		"params": { "damage_mult": 1.3 },
	},
	"wizard_torrent_surge": {
		"id": "wizard_torrent_surge",
		"name": "BURST SURGE",
		"kit": "wizard",
		"rarity": "uncommon",
		"desc": "The Fire Burst finisher blooms 50% wider - the nova fills the room.",
		"color": Color(1.0, 0.55, 0.15),
		"target": { "graph": "light", "anim": "fireburst" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.5 },
	},
	"wizard_ember_familiar": {
		"id": "wizard_ember_familiar",
		"name": "EMBER FAMILIAR",
		"kit": "wizard",
		"rarity": "uncommon",
		"desc": "The familiar burns hotter - +15% damage while equipped.",
		"color": Color(0.9, 0.4, 0.1),
		"op": "modifier",
		"params": { "stat": "damage", "op": "bonus", "value": 0.15 },
	},

	"wizard_arcane_multiplicity": {
		"id": "wizard_arcane_multiplicity",
		"name": "ARCANE MULTIPLICITY",
		"kit": "wizard",
		"rarity": "rare",
		"desc": "One more bolt on every opening cast.",
		"color": Color(0.55, 0.70, 1.0),
		"target": { "graph": "light", "anim": "attack" },
		"op": "add_projectiles",
		"params": { "count": 1 },
	},
	"wizard_deep_freeze": {
		"id": "wizard_deep_freeze",
		"name": "DEEP FREEZE",
		"kit": "wizard",
		"rarity": "epic",
		"desc": "The ice cast no longer slows - it stops. Everything caught is frozen solid.",
		"color": Color(0.45, 0.85, 1.0),
		"target": { "graph": "skill_q", "anim": "ice_cast" },
		"op": "add_status",
		"params": { "status": "frozen", "stacks": 1 },
	},
	"wizard_tempest_call": {
		"id": "wizard_tempest_call",
		"name": "TEMPEST CALL",
		"kit": "wizard",
		"rarity": "uncommon",
		"desc": "The storm answers wider - 45% broader, 20% harder.",
		"color": Color(0.85, 0.90, 1.0),
		"target": { "graph": "skill_e", "anim": "storm_cast" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.45, "damage_mult": 1.20 },
	},
	"wizard_manaburn": {
		"id": "wizard_manaburn",
		"name": "MANABURN",
		"kit": "wizard",
		"rarity": "uncommon",
		"desc": "The Spark burns through reserves recklessly. Every cooldown comes back 15% sooner.",
		"color": Color(0.70, 0.55, 1.0),
		"op": "modifier",
		"params": { "stat": "All", "op": "cooldown_reduce", "value": 0.15 },
	},

	## ── Blood Mage (The Cursed) ──────────────────────────────────────────────────────────────

	"blood_mage_hemorrhage_shards": {
		"id": "blood_mage_hemorrhage_shards",
		"name": "HEMORRHAGE SHARDS",
		"kit": "blood_mage",
		"rarity": "epic",
		"desc": "Blood Shards carry a hemorrhaging edge - every shard applies Bleed.",
		"color": Color(0.75, 0.05, 0.05),
		"target": { "anim": "shards" },
		"op": "add_projectile_status",
		"params": { "status": "bleed", "stacks": 1 },
	},
	"blood_mage_deeper_pact": {
		"id": "blood_mage_deeper_pact",
		"name": "DEEPER PACT",
		"kit": "blood_mage",
		"rarity": "uncommon",
		"desc": "The blood pact runs deeper - +20% damage while equipped.",
		"color": Color(0.85, 0.1, 0.1),
		"op": "modifier",
		"params": { "stat": "damage", "op": "bonus", "value": 0.20 },
	},
	"blood_mage_bloodquake": {
		"id": "blood_mage_bloodquake",
		"name": "BLOODQUAKE",
		"kit": "blood_mage",
		"rarity": "rare",
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
		"rarity": "uncommon",
		"desc": "The drain draws more deeply - +18% damage increases each Vampirize beat's yield.",
		"color": Color(0.6, 0.0, 0.2),
		"op": "modifier",
		"params": { "stat": "damage", "op": "bonus", "value": 0.18 },
	},

	"blood_mage_crimson_feast": {
		"id": "blood_mage_crimson_feast",
		"name": "CRIMSON FEAST",
		"kit": "blood_mage",
		"rarity": "uncommon",
		"desc": "The Cursed drinks from every wound she opens.",
		"color": Color(0.80, 0.10, 0.25),
		"op": "modifier",
		"params": { "stat": "leech", "op": "bonus", "value": 0.08 },
	},
	"blood_mage_rupture": {
		"id": "blood_mage_rupture",
		"name": "RUPTURE",
		"kit": "blood_mage",
		"rarity": "rare",
		"desc": "The slam ruptures the ground - 30% harder across a 40% wider break.",
		"color": Color(0.75, 0.15, 0.30),
		"target": { "graph": "heavy", "anim": "slam" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.40, "damage_mult": 1.30 },
	},
	"blood_mage_thirsting_vortex": {
		"id": "blood_mage_thirsting_vortex",
		"name": "THIRSTING VORTEX",
		"kit": "blood_mage",
		"rarity": "uncommon",
		"desc": "The drain reaches half again as far while held.",
		"color": Color(0.65, 0.10, 0.40),
		"target": { "graph": "channel", "anim": "vampirize" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.50 },
	},
	"blood_mage_hemoplague": {
		"id": "blood_mage_hemoplague",
		"name": "HEMOPLAGUE",
		"kit": "blood_mage",
		"rarity": "rare",
		"desc": "Two more shards in every volley.",
		"color": Color(0.85, 0.20, 0.35),
		"target": { "anim": "shards" },
		"op": "add_projectiles",
		"params": { "count": 2 },
	},

	## ── Demonologist (The Demon) ─────────────────────────────────────────────────────────────

	"demon_searing_hellfire": {
		"id": "demon_searing_hellfire",
		"name": "SEARING HELLFIRE",
		"kit": "demonologist",
		"rarity": "rare",
		"desc": "Hellfire sprays 35% wider and sears 20% harder.",
		"color": Color(1.0, 0.45, 0.15),
		## See ability_upgrades.demon_conflagration: the phase name is "hellfire_2", not "hellfire".
		"target": { "anim": "hellfire_2" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.35, "damage_mult": 1.2 },
	},
	"demon_ninefold_circle": {
		"id": "demon_ninefold_circle",
		"name": "NINEFOLD CIRCLE",
		"kit": "demonologist",
		"rarity": "rare",
		"desc": "The Brimstone Circle is drawn 40% wider and burns 25% hotter.",
		"color": Color(0.95, 0.25, 0.20),
		"target": { "anim": "brimstone" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.4, "damage_mult": 1.25 },
	},
	"demon_infernal_hide": {
		"id": "demon_infernal_hide",
		"name": "INFERNAL HIDE",
		"kit": "demonologist",
		"rarity": "uncommon",
		"desc": "Pact-scarred skin drinks the heat - +25 Fire Resist.",
		"color": Color(0.75, 0.30, 0.15),
		"op": "modifier",
		"params": { "stat": "Fire", "op": "resist", "value": 25.0 },
	},
	"demon_greater_pact": {
		"id": "demon_greater_pact",
		"name": "GREATER PACT",
		"kit": "demonologist",
		"rarity": "uncommon",
		"desc": "He signs for more than he can pay - +15% damage while equipped.",
		"color": Color(0.85, 0.20, 0.35),
		"op": "modifier",
		"params": { "stat": "damage", "op": "bonus", "value": 0.15 },
	},

	"demon_breach_wake": {
		"id": "demon_breach_wake",
		"name": "BREACH WAKE",
		"kit": "demonologist",
		"rarity": "rare",
		"desc": "The tear left by Hell Breach is 40% wider and bites 20% deeper.",
		"color": Color(0.85, 0.25, 0.55),
		"target": { "anim": "hell_breach" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.40, "damage_mult": 1.20 },
	},
	"demon_sustained_torment": {
		"id": "demon_sustained_torment",
		"name": "SUSTAINED TORMENT",
		"kit": "demonologist",
		"rarity": "epic",
		"desc": "The held hellfire sears wounds that will not close.",
		"color": Color(1.0, 0.35, 0.10),
		"target": { "graph": "channel", "anim": "hellfire_ch" },
		"op": "add_status",
		"params": { "status": "searing_wound", "stacks": 1 },
	},
	"demon_archdemons_toll": {
		"id": "demon_archdemons_toll",
		"name": "ARCHDEMON'S TOLL",
		"kit": "demonologist",
		"rarity": "uncommon",
		"desc": "What answers the call arrives larger and hungrier - 45% wider, 25% harder.",
		"color": Color(0.70, 0.15, 0.20),
		"target": { "graph": "skill_e", "anim": "archdemon_call" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.45, "damage_mult": 1.25 },
	},
	"demon_blood_pact": {
		"id": "demon_blood_pact",
		"name": "BLOOD PACT",
		"kit": "demonologist",
		"rarity": "uncommon",
		"desc": "The pact is written in vitality. The Demon carries 15% more of it.",
		"color": Color(0.80, 0.20, 0.30),
		"op": "modifier",
		"params": { "stat": "max_hp", "op": "bonus", "value": 0.15 },
	},

	## ── Barbarian (The Ravager) ───────────────────────────────────────────────────────────────

	"barbarian_earthsplitter": {
		"id": "barbarian_earthsplitter",
		"name": "EARTHSPLITTER",
		"kit": "barbarian",
		"rarity": "rare",
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
		"rarity": "rare",
		"desc": "Thunder Blade crackles 40% harder - the lightning jumps further.",
		"color": Color(0.6, 0.7, 1.0),
		"target": { "anim": "thunder" },
		"op": "scale_aoe",
		"params": { "damage_mult": 1.4 },
	},
	"barbarian_iron_wall": {
		"id": "barbarian_iron_wall",
		"name": "IRON WALL",
		"kit": "barbarian",
		"rarity": "uncommon",
		"desc": "The Ravager's guard is iron - take 18% less damage while equipped.",
		"color": Color(0.65, 0.65, 0.75),
		"op": "modifier",
		## ("All", "damage_taken") — the ("damage_taken", "bonus") pair is never read. See above.
		"params": { "stat": "All", "op": "damage_taken", "value": -0.18 },
	},
	## Took DEAFENING CRY's slot on 2026-08-16 rather than being added alongside it: validate_order
	## enforces an identical rarity shape across all twelve kits (4 uncommon / 3 rare / 1 epic), so
	## a ninth barbarian mod is not a thing that can exist on its own. DEAFENING CRY was the right
	## one to give up — a flat +15% damage named after Battle Cry that never touched Battle Cry, on
	## a character whose passive AND whose Q are both already damage buffs. It is in no evolution
	## recipe; owners are migrated to this id by ProgressionManager v3→v4.
	"barbarian_avalanche": {
		"id": "barbarian_avalanche",
		"name": "AVALANCHE",
		"kit": "barbarian",
		"rarity": "uncommon",
		"desc": "His grip takes three more bodies before it runs out of arms.",
		"color": Color(0.70, 0.72, 0.78),
		## Raises Pile Driver's chain cap through the ordinary stat path — player._pile_capacity()
		## reads get_stat("pile_capacity"), base 6.
		"op": "modifier",
		"params": { "stat": "pile_capacity", "op": "add", "value": 3.0 },
	},

	"barbarian_storm_volley": {
		"id": "barbarian_storm_volley",
		"name": "STORM VOLLEY",
		"kit": "barbarian",
		"rarity": "rare",
		"desc": "Two more bolts leave the blade on every thunder strike.",
		"color": Color(1.0, 0.90, 0.35),
		"target": { "anim": "thunder" },
		"op": "add_projectiles",
		"params": { "count": 2 },
	},
	"barbarian_hurled_ruin": {
		"id": "barbarian_hurled_ruin",
		"name": "HURLED RUIN",
		"kit": "barbarian",
		"rarity": "uncommon",
		"desc": "Whatever the Ravager throws lands 30% harder across a 40% wider crater.",
		"color": Color(0.80, 0.60, 0.35),
		## Retargeted "throw" -> "hurl" when Throw Things became Pile Driver (2026-08-16). The old
		## anim name no longer exists, and a target that matches nothing is silently dead content —
		## which is exactly what validate_anim_targets() exists to catch.
		"target": { "graph": "skill_e", "anim": "hurl" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.40, "damage_mult": 1.30 },
	},
	"barbarian_bloodrage": {
		"id": "barbarian_bloodrage",
		"name": "BLOODRAGE",
		"kit": "barbarian",
		"rarity": "uncommon",
		"desc": "The fight feeds him. A share of all damage dealt comes back as health.",
		"color": Color(0.80, 0.15, 0.15),
		"op": "modifier",
		"params": { "stat": "leech", "op": "bonus", "value": 0.06 },
	},
	"barbarian_terrifying_roar": {
		"id": "barbarian_terrifying_roar",
		"name": "TERRIFYING ROAR",
		"kit": "barbarian",
		"rarity": "epic",
		"desc": "The war cry freezes the blood of everything that hears it.",
		"color": Color(0.60, 0.85, 1.0),
		"target": { "graph": "skill_q", "anim": "cry" },
		"op": "add_status",
		"params": { "status": "chilled", "stacks": 1 },
	},

	## ── Gunslinger (The Deadeye) ─────────────────────────────────────────────────────────────

	"gunslinger_fan_the_hammer_plus2": {
		"id": "gunslinger_fan_the_hammer_plus2",
		"name": "FAN THE HAMMER +2",
		"kit": "gunslinger",
		"rarity": "rare",
		"desc": "Fan the Hammer fires 2 extra bullets - 7 shots, all at once.",
		"color": Color(0.85, 0.85, 0.95),
		"target": { "anim": "fan" },
		"op": "add_projectiles",
		"params": { "count": 2 },
	},
	"gunslinger_hollow_points": {
		"id": "gunslinger_hollow_points",
		"name": "HOLLOW POINTS",
		"kit": "gunslinger",
		"rarity": "epic",
		"desc": "Hollow-point rounds tear through flesh - every shot in the light chain applies Bleed.",
		"color": Color(0.7, 0.15, 0.15),
		"target": { "graph": "light" },
		"op": "add_projectile_status",
		"params": { "status": "bleed", "stacks": 1 },
	},
	"gunslinger_suppressing_storm": {
		"id": "gunslinger_suppressing_storm",
		"name": "SUPPRESSING STORM",
		"kit": "gunslinger",
		"rarity": "uncommon",
		"desc": "Desert Storm volley hits 30% harder - the storm suppresses everything.",
		"color": Color(0.5, 0.6, 0.8),
		"target": { "graph": "channel", "anim": "storm" },
		"op": "scale_aoe",
		"params": { "damage_mult": 1.3 },
	},
	"gunslinger_quickdraw": {
		"id": "gunslinger_quickdraw",
		"name": "QUICKDRAW",
		"kit": "gunslinger",
		"rarity": "uncommon",
		"desc": "Loaded chambers keep the edge sharp - +10% crit chance while equipped.",
		"color": Color(0.9, 0.8, 0.55),
		"op": "modifier",
		## "add", not "bonus" — see ninja_honed_edge above.
		"params": { "stat": "crit_chance", "op": "add", "value": 0.10 },
	},
	"gunslinger_incendiary_rounds": {
		"id": "gunslinger_incendiary_rounds",
		"name": "INCENDIARY ROUNDS",
		"kit": "gunslinger",
		"rarity": "rare",
		"desc": "Every round out of the chain sets what it hits alight.",
		"color": Color(1.0, 0.45, 0.10),
		"target": { "graph": "light" },
		"op": "add_projectile_status",
		"params": { "status": "burning", "stacks": 1 },
	},
	"gunslinger_hot_loads": {
		"id": "gunslinger_hot_loads",
		"name": "HOT LOADS",
		"kit": "gunslinger",
		"rarity": "rare",
		"desc": "Two more rounds per beat while the storm is held down.",
		"color": Color(1.0, 0.75, 0.25),
		"target": { "graph": "channel", "anim": "storm" },
		"op": "add_projectiles",
		"params": { "count": 2 },
	},
	"gunslinger_lash_and_draw": {
		"id": "gunslinger_lash_and_draw",
		"name": "LASH AND DRAW",
		"kit": "gunslinger",
		"rarity": "uncommon",
		"desc": "The whip cracks 30% harder over a 40% wider reach before the guns come up.",
		"color": Color(0.80, 0.65, 0.45),
		"target": { "graph": "skill_e", "anim": "whip" },
		"op": "scale_aoe",
		"params": { "radius_mult": 1.40, "damage_mult": 1.30 },
	},
	"gunslinger_dead_aim": {
		"id": "gunslinger_dead_aim",
		"name": "DEAD AIM",
		"kit": "gunslinger",
		"rarity": "uncommon",
		"desc": "When the Deadeye connects clean, it ends things. Critical hits land far harder.",
		"color": Color(1.0, 0.80, 0.15),
		"op": "modifier",
		"params": { "stat": "crit_multiplier", "op": "add", "value": 0.35 },
	},
}


## Display / draw order. THE only route into loot, armory and merchant — `ids_for_kit` walks this,
## not ALL, so anything missing here is unobtainable. `validate_order()` guards both directions.
##
## Eight per character as of 2026-08-08 (was four). The roster grew when the generic mod layer was
## retired: 13 of its 18 entries were dead — baked into a weapon auto-attack that no combo
## character fires — so folding the two layers into one class-locked roster cost almost nothing
## real and gave every character a build space of C(8,3) = 56 loadouts against 3 equip slots.
const ORDER: Array = [
	## Fighter
	"fighter_overcharged_cataclysm",
	"fighter_tempest_vortex",
	"fighter_sustained_whirlwind",
	"fighter_concussive_taunt",
	"fighter_blood_wages",
	"fighter_opening_cut",
	"fighter_shattering_uppercut",
	"fighter_grappling_rush",
	## Paladin
	"paladin_thunderous_bash",
	"paladin_shattering_hammers",
	"paladin_bound_spiral",
	"paladin_retribution_dome",
	"paladin_aegis_plating",
	"paladin_shield_wall",
	"paladin_sworn_thorns",
	"paladin_relentless_vow",
	## Ninja
	"ninja_bleeding_blades",
	"ninja_endless_storm",
	"ninja_honed_edge",
	"ninja_choking_smoke",
	"ninja_deep_cut",
	"ninja_blinding_smoke",
	"ninja_finishing_flourish",
	"ninja_whetstone_ritual",
	## Cleric
	"cleric_purifying_fire",
	"cleric_words_of_agony",
	"cleric_radiant_smite",
	"cleric_greater_sanctuary",
	"cleric_censer_embers",
	"cleric_guardians_wrath",
	"cleric_lingering_grace",
	"cleric_fervent_prayer",
	## Druid
	"druid_savage_maul",
	"druid_diving_owl",
	"druid_strangling_roots",
	"druid_pack_leader",
	"druid_thorned_seeds",
	"druid_ursine_fury",
	"druid_pack_hunter",
	"druid_barkskin",
	## Necromancer
	"necro_splintering_swirl",
	"necro_grave_bond",
	"necro_dark_haste",
	"necro_soul_leech",
	"necro_marrow_shards",
	"necro_endless_bones",
	"necro_grave_legion",
	"necro_soul_tithe",
	## Ranger
	"ranger_barbed_arrows",
	"ranger_impaling_knife",
	"ranger_explosive_tips",
	"ranger_ghost_step",
	"ranger_split_quiver",
	"ranger_hunters_focus",
	"ranger_pinning_shot",
	"ranger_close_quarters",
	## Wizard
	"wizard_fireball_scorched_earth",
	"wizard_overload_bolts",
	"wizard_torrent_surge",
	"wizard_ember_familiar",
	"wizard_arcane_multiplicity",
	"wizard_deep_freeze",
	"wizard_tempest_call",
	"wizard_manaburn",
	## Blood Mage
	"blood_mage_hemorrhage_shards",
	"blood_mage_deeper_pact",
	"blood_mage_bloodquake",
	"blood_mage_sanguine_drain",
	"blood_mage_crimson_feast",
	"blood_mage_rupture",
	"blood_mage_thirsting_vortex",
	"blood_mage_hemoplague",
	## Demonologist
	"demon_searing_hellfire",
	"demon_ninefold_circle",
	"demon_infernal_hide",
	"demon_greater_pact",
	"demon_breach_wake",
	"demon_sustained_torment",
	"demon_archdemons_toll",
	"demon_blood_pact",
	## Barbarian
	"barbarian_earthsplitter",
	"barbarian_chained_lightning",
	"barbarian_iron_wall",
	"barbarian_avalanche",
	"barbarian_storm_volley",
	"barbarian_hurled_ruin",
	"barbarian_bloodrage",
	"barbarian_terrifying_roar",
	## Gunslinger
	"gunslinger_fan_the_hammer_plus2",
	"gunslinger_hollow_points",
	"gunslinger_suppressing_storm",
	"gunslinger_quickdraw",
	"gunslinger_incendiary_rounds",
	"gunslinger_hot_loads",
	"gunslinger_lash_and_draw",
	"gunslinger_dead_aim",
]


## ── Mod evolutions ────────────────────────────────────────────────────────────────────────────
## The replacement for the 69-pair generic interaction matrix (retired 2026-08-08).
##
## An evolution is a capstone that fires when BOTH of its required mods are equipped together. Two
## per class, drawn from that class's own roster — 24 authored pairs instead of 69 combinatorial
## ones, and every one of them is reachable, testable and belongs to a character. The pattern is
## deliberately the one already in the game: UpgradeManager.EVOLUTION_RECIPES, which does the same
## thing one layer up for level-up picks.
##
## Shape is a class mod's, plus `requires`. ClassModFactory applies it exactly like any other entry
## once the requirement is met, so no new op vocabulary was needed. `codex_id` is the CodexManager
## entry it unlocks; ComboRegistry builds the whole codex from this table.
##
## Why pairs and not a synergy table: the old matrix's problem was not that pairs are bad, it is
## that 69 of them could not be authored honestly or tested. Three equip slots over eight mods is
## 56 loadouts per class; picking two of those to be special is a design act, not combinatorics.
const EVOLUTIONS: Dictionary = {
	"evo_fighter_bloodstorm": {
		"id": "evo_fighter_bloodstorm", "name": "BLOODSTORM", "kit": "fighter",
		"requires": ["fighter_sustained_whirlwind", "fighter_blood_wages"],
		"desc": "The wider spin drinks from everything it clips - the whirlwind sustains itself.",
		"color": Color(0.85, 0.25, 0.35),
		"target": { "graph": "light", "anim": "swirl" },
		"op": "add_status", "params": { "status": "bleed", "stacks": 1 },
	},
	"evo_fighter_earthbreaker": {
		"id": "evo_fighter_earthbreaker", "name": "EARTHBREAKER", "kit": "fighter",
		"requires": ["fighter_overcharged_cataclysm", "fighter_shattering_uppercut"],
		"desc": "Launch into crater. The full sequence lands with the weight of a siege engine.",
		"color": Color(1.0, 0.60, 0.20),
		"target": { "anim": "cataclysm" },
		"op": "scale_aoe", "params": { "radius_mult": 1.25, "damage_mult": 1.30 },
	},
	"evo_paladin_bulwark_of_dawn": {
		"id": "evo_paladin_bulwark_of_dawn", "name": "BULWARK OF DAWN", "kit": "paladin",
		"requires": ["paladin_aegis_plating", "paladin_shield_wall"],
		"desc": "Plate and shield as one doctrine. What the Warden turns aside, it turns back.",
		"color": Color(1.0, 0.90, 0.50),
		"op": "modifier", "params": { "stat": "All", "op": "damage_taken", "value": -0.15 },
	},
	"evo_paladin_hammer_of_judgement": {
		"id": "evo_paladin_hammer_of_judgement", "name": "HAMMER OF JUDGEMENT", "kit": "paladin",
		"requires": ["paladin_shattering_hammers", "paladin_relentless_vow"],
		"desc": "The hammer falls, and falls again. Judgement stops waiting its turn.",
		"color": Color(1.0, 1.0, 0.70),
		"target": { "anim": "hammer" },
		"op": "scale_aoe", "params": { "radius_mult": 1.35 },
	},
	"evo_ninja_thousand_cuts": {
		"id": "evo_ninja_thousand_cuts", "name": "THOUSAND CUTS", "kit": "ninja",
		"requires": ["ninja_bleeding_blades", "ninja_whetstone_ritual"],
		"desc": "Serrated steel on an endless chain. Nothing the Whisper touches stops bleeding.",
		"color": Color(0.80, 0.15, 0.20),
		"target": { "anim": "blades" },
		"op": "add_status", "params": { "status": "bleed", "stacks": 2 },
	},
	"evo_ninja_shadowkill": {
		"id": "evo_ninja_shadowkill", "name": "SHADOWKILL", "kit": "ninja",
		"requires": ["ninja_honed_edge", "ninja_deep_cut"],
		"desc": "Finds the gap, and puts everything through it.",
		"color": Color(0.90, 0.30, 0.40),
		"op": "modifier", "params": { "stat": "crit_multiplier", "op": "add", "value": 0.35 },
	},
	"evo_cleric_pyre_of_faith": {
		"id": "evo_cleric_pyre_of_faith", "name": "PYRE OF FAITH", "kit": "cleric",
		"requires": ["cleric_censer_embers", "cleric_purifying_fire"],
		"desc": "The censer's fire no longer goes out. It spreads.",
		"color": Color(1.0, 0.70, 0.25),
		"target": { "anim": "divine_fire" },
		"op": "add_projectile_status", "params": { "status": "searing_wound", "stacks": 1 },
	},
	"evo_cleric_unending_vigil": {
		"id": "evo_cleric_unending_vigil", "name": "UNENDING VIGIL", "kit": "cleric",
		"requires": ["cleric_fervent_prayer", "cleric_lingering_grace"],
		"desc": "Stronger mending that holds far longer. The Devout simply does not fall.",
		"color": Color(0.75, 1.0, 0.85),
		"op": "modifier", "params": { "stat": "Heal", "op": "bonus", "value": 0.25 },
	},
	"evo_druid_wild_hunt": {
		"id": "evo_druid_wild_hunt", "name": "WILD HUNT", "kit": "druid",
		"requires": ["druid_ursine_fury", "druid_pack_hunter"],
		"desc": "Bear and hounds hunt as one. The whole wood answers the Verdant.",
		"color": Color(0.60, 0.75, 0.35),
		"target": { "graph": "skill_e", "anim": "summon_hounds" },
		"op": "scale_aoe", "params": { "radius_mult": 1.25, "damage_mult": 1.30 },
	},
	"evo_druid_bramble_tide": {
		"id": "evo_druid_bramble_tide", "name": "BRAMBLE TIDE", "kit": "druid",
		"requires": ["druid_thorned_seeds", "druid_diving_owl"],
		"desc": "More seeds, every one of them barbed. The volley becomes a thicket.",
		"color": Color(0.50, 0.70, 0.30),
		"target": { "graph": "light", "anim": "attack_2" },
		"op": "add_projectiles", "params": { "count": 2 },
	},
	"evo_necro_ossuary": {
		"id": "evo_necro_ossuary", "name": "THE OSSUARY", "kit": "necromancer",
		"requires": ["necro_endless_bones", "necro_marrow_shards"],
		"desc": "A storm of splintering bone. The Shade never runs out and never stops the bleeding.",
		"color": Color(0.90, 0.85, 0.75),
		"target": { "anim": "bone_cast" },
		"op": "add_projectiles", "params": { "count": 2 },
	},
	"evo_necro_soul_engine": {
		"id": "evo_necro_soul_engine", "name": "SOUL ENGINE", "kit": "necromancer",
		"requires": ["necro_soul_tithe", "necro_soul_leech"],
		"desc": "Every soul taken pays twice - once to the dark, once to the Shade.",
		"color": Color(0.45, 0.95, 0.60),
		"op": "modifier", "params": { "stat": "leech", "op": "bonus", "value": 0.06 },
	},
	"evo_ranger_deadfall": {
		"id": "evo_ranger_deadfall", "name": "DEADFALL", "kit": "ranger",
		"requires": ["ranger_barbed_arrows", "ranger_pinning_shot"],
		"desc": "Pinned, then bled. Nothing the Scavenger marks gets back out of range.",
		"color": Color(0.70, 0.80, 0.95),
		"target": { "graph": "light" },
		"op": "add_projectile_status", "params": { "status": "chilled", "stacks": 1 },
	},
	"evo_ranger_perfect_shot": {
		"id": "evo_ranger_perfect_shot", "name": "PERFECT SHOT", "kit": "ranger",
		"requires": ["ranger_hunters_focus", "ranger_impaling_knife"],
		"desc": "Held breath, thrown steel. The knife finds the same gap the arrow does.",
		"color": Color(1.0, 0.90, 0.50),
		"target": { "anim": "knife" },
		"op": "scale_aoe", "params": { "damage_mult": 1.35 },
	},
	"evo_wizard_conflagration": {
		"id": "evo_wizard_conflagration", "name": "CONFLAGRATION", "kit": "wizard",
		"requires": ["wizard_fireball_scorched_earth", "wizard_torrent_surge"],
		"desc": "The burst feeds the fireball's wake. The Spark leaves a field on fire.",
		"color": Color(1.0, 0.50, 0.15),
		"target": { "graph": "light", "anim": "fireburst" },
		"op": "add_status", "params": { "status": "burning", "stacks": 2 },
	},
	"evo_wizard_absolute_zero": {
		"id": "evo_wizard_absolute_zero", "name": "ABSOLUTE ZERO", "kit": "wizard",
		"requires": ["wizard_deep_freeze", "wizard_manaburn"],
		"desc": "The freeze comes back before the last one has thawed.",
		"color": Color(0.55, 0.90, 1.0),
		"op": "modifier", "params": { "stat": "All", "op": "cooldown_reduce", "value": 0.10 },
	},
	"evo_blood_mage_exsanguinate": {
		"id": "evo_blood_mage_exsanguinate", "name": "EXSANGUINATE", "kit": "blood_mage",
		"requires": ["blood_mage_hemorrhage_shards", "blood_mage_hemoplague"],
		"desc": "A wall of shards, every one of them opening a vein.",
		"color": Color(0.85, 0.15, 0.30),
		"target": { "anim": "shards" },
		"op": "add_projectiles", "params": { "count": 2 },
	},
	"evo_blood_mage_red_harvest": {
		"id": "evo_blood_mage_red_harvest", "name": "RED HARVEST", "kit": "blood_mage",
		"requires": ["blood_mage_crimson_feast", "blood_mage_thirsting_vortex"],
		"desc": "The vortex reaches further and the Cursed drinks deeper from all of it.",
		"color": Color(0.70, 0.10, 0.35),
		"target": { "graph": "channel", "anim": "vampirize" },
		"op": "scale_aoe", "params": { "radius_mult": 1.25, "damage_mult": 1.25 },
	},
	"evo_demon_infernal_engine": {
		"id": "evo_demon_infernal_engine", "name": "INFERNAL ENGINE", "kit": "demonologist",
		"requires": ["demon_searing_hellfire", "demon_sustained_torment"],
		"desc": "Held hellfire that never lets a wound close.",
		"color": Color(1.0, 0.30, 0.10),
		"target": { "graph": "channel", "anim": "hellfire_ch" },
		"op": "scale_aoe", "params": { "radius_mult": 1.30, "damage_mult": 1.25 },
	},
	"evo_demon_the_ninth_gate": {
		"id": "evo_demon_the_ninth_gate", "name": "THE NINTH GATE", "kit": "demonologist",
		"requires": ["demon_ninefold_circle", "demon_breach_wake"],
		"desc": "Circle and breach align. What comes through does not close behind it.",
		"color": Color(0.80, 0.20, 0.45),
		"target": { "anim": "brimstone" },
		"op": "add_status", "params": { "status": "burning", "stacks": 2 },
	},
	"evo_barbarian_ragnarok": {
		"id": "evo_barbarian_ragnarok", "name": "RAGNAROK", "kit": "barbarian",
		"requires": ["barbarian_earthsplitter", "barbarian_hurled_ruin"],
		"desc": "Everything the Ravager swings or throws breaks the ground it lands on.",
		"color": Color(0.90, 0.55, 0.25),
		"target": { "anim": "sunder" },
		"op": "scale_aoe", "params": { "radius_mult": 1.25, "damage_mult": 1.30 },
	},
	"evo_barbarian_stormheart": {
		"id": "evo_barbarian_stormheart", "name": "STORMHEART", "kit": "barbarian",
		"requires": ["barbarian_chained_lightning", "barbarian_storm_volley"],
		"desc": "More bolts, each one heavier. The blade becomes weather.",
		"color": Color(1.0, 0.95, 0.45),
		"target": { "anim": "thunder" },
		"op": "add_projectiles", "params": { "count": 2 },
	},
	"evo_gunslinger_hellfire_iron": {
		"id": "evo_gunslinger_hellfire_iron", "name": "HELLFIRE IRON", "kit": "gunslinger",
		"requires": ["gunslinger_incendiary_rounds", "gunslinger_hollow_points"],
		"desc": "Rounds that open a wound and light it. The Deadeye stops needing a second shot.",
		"color": Color(1.0, 0.55, 0.15),
		"target": { "graph": "light" },
		"op": "add_projectile_status", "params": { "status": "searing_wound", "stacks": 1 },
	},
	"evo_gunslinger_leadstorm": {
		"id": "evo_gunslinger_leadstorm", "name": "LEADSTORM", "kit": "gunslinger",
		"requires": ["gunslinger_fan_the_hammer_plus2", "gunslinger_hot_loads"],
		"desc": "The fan and the storm feed each other. Both hammers, all the way down.",
		"color": Color(1.0, 0.80, 0.30),
		"target": { "anim": "fan" },
		"op": "add_projectiles", "params": { "count": 2 },
	},
}


## Evolutions whose requirements are ALL satisfied by `active_ids`.
static func active_evolutions(kit_id: String, active_ids: Array) -> Array:
	var out: Array = []
	for evo_id: String in EVOLUTIONS:
		var evo: Dictionary = EVOLUTIONS[evo_id]
		if evo.get("kit", "") != kit_id:
			continue
		var have_all: bool = true
		for req: String in evo.get("requires", []):
			if req not in active_ids:
				have_all = false
				break
		if have_all:
			out.append(evo_id)
	return out


## Evolution ids belonging to a kit, in table order.
static func evolutions_for_kit(kit_id: String) -> Array:
	var out: Array = []
	for evo_id: String in EVOLUTIONS:
		if EVOLUTIONS[evo_id].get("kit", "") == kit_id:
			out.append(evo_id)
	return out


## All class-mod ids bound to a kit, in ORDER.
static func ids_for_kit(kit_id: String) -> Array:
	var out: Array = []
	for mod_id: String in ORDER:
		if ALL.get(mod_id, {}).get("kit", "") == kit_id:
			out.append(mod_id)
	return out


## ── Rarity ───────────────────────────────────────────────────────────────────
## Every class mod carries a rarity, and every kit carries the SAME shape:
## 1 epic / 3 rare / 4 uncommon. Symmetry is deliberate — the roster is already
## 8-per-character with 3 slots and 2 evolutions each, and a character whose mods
## happened to be numeric would otherwise have no chase item at all.
##
## The initial tiering ranks each kit's eight by how much the op TRANSFORMS the
## move rather than by how big its numbers are: kit_flag > add_pull > add_status >
## add_projectile_status > add_projectiles > scale_aoe / modifier, ties broken by
## ORDER position. That is why every epic is the characterful one — SPLIT QUIVER,
## SOUL TITHE, TEMPEST VORTEX — and never a flat +damage.
##
## It is stored per entry rather than computed so it can be argued with: move a
## line and the drop tables, the pickup colour and the merchant price all follow.
##
## Three tiers, not five, matching `LootTables.gear_rarity_from()` — mods and class
## weapons speak the same vocabulary rather than two parallel ones.
const RARITY_TIERS: Array[String] = ["uncommon", "rare", "epic"]
const RARITY_SHAPE: Dictionary = { "epic": 1, "rare": 3, "uncommon": 4 }


static func rarity_of(mod_id: String) -> String:
	return str(ALL.get(mod_id, {}).get("rarity", "uncommon"))


## This kit's mods at one tier, in ORDER. Empty if the kit has none at that tier —
## callers must handle that rather than assume, which is why the drop path below
## walks outward to neighbouring tiers instead of indexing blind.
static func ids_for_kit_of_rarity(kit_id: String, rarity: String) -> Array:
	var out: Array = []
	for mod_id: String in ids_for_kit(kit_id):
		if rarity_of(mod_id) == rarity:
			out.append(mod_id)
	return out


## Startup check: ORDER is the ONLY route into the game. `ids_for_kit` walks it, and every
## consumer — ModApplicability.droppable_pool (loot), the armory picker, the merchant — goes
## through `ids_for_kit`. An entry in ALL but not in ORDER is therefore fully authored, wired,
## and unobtainable, with no error anywhere.
##
## This had already shipped: `ranger_split_quiver` (read by player._load_combo:1497) was in ALL
## and absent from ORDER, so SPLIT QUIVER could never drop and never appeared in the armory.
## Found 2026-08-08. Same failure shape as AbilityUpgradeData.validate_kit_order(), one layer
## down — which is exactly why this needs its own check rather than trusting the other one.
static func validate_order() -> Array[String]:
	var problems: Array[String] = []
	var listed: Dictionary = {}
	for mod_id: String in ORDER:
		if listed.has(mod_id):
			problems.append("class mod '%s' is listed twice in ORDER" % mod_id)
		listed[mod_id] = true
		if not ALL.has(mod_id):
			problems.append("ORDER lists class mod '%s', which is not in ALL" % mod_id)
	for mod_id: String in ALL:
		if not listed.has(mod_id):
			problems.append("class mod '%s' is in ALL but not in ORDER — it can never drop "
					% mod_id + "or be equipped")
		if ALL[mod_id].get("kit", "") == "":
			problems.append("class mod '%s' declares no kit — it belongs to no character" % mod_id)
		var rar: String = str(ALL[mod_id].get("rarity", ""))
		if rar == "":
			problems.append("class mod '%s' has no rarity — it would price and drop as the "
					% mod_id + "cheapest tier by default")
		elif not RARITY_TIERS.has(rar):
			problems.append("class mod '%s' has rarity '%s', which is not one of %s"
					% [mod_id, rar, str(RARITY_TIERS)])

	## Every kit must carry the SAME rarity shape. Without this a kit could quietly end up with
	## no epic — meaning that character has no chase mod and its high-rarity drops silently
	## degrade to rare forever, which is exactly the kind of asymmetry nothing else would report.
	var per_kit: Dictionary = {}
	for mod_id: String in ALL:
		var kit_id: String = str(ALL[mod_id].get("kit", ""))
		if kit_id == "":
			continue
		if not per_kit.has(kit_id):
			per_kit[kit_id] = {}
		var r: String = str(ALL[mod_id].get("rarity", "?"))
		per_kit[kit_id][r] = int(per_kit[kit_id].get(r, 0)) + 1
	for kit_id: String in per_kit:
		for tier: String in RARITY_SHAPE:
			var want: int = int(RARITY_SHAPE[tier])
			var got: int = int(per_kit[kit_id].get(tier, 0))
			if got != want:
				problems.append("kit '%s' has %d %s mod(s), expected %d — the rarity shape "
						% [kit_id, got, tier, want] + "must match across every kit")
	## Evolutions: an unreachable requirement is the same silent failure one level up. A recipe
	## naming an id that is not in ALL, or is bound to a different kit, can never be assembled and
	## leaves a permanently-UNKNOWN codex entry with no way to earn it.
	for evo_id: String in EVOLUTIONS:
		var evo: Dictionary = EVOLUTIONS[evo_id]
		var kit: String = evo.get("kit", "")
		if kit == "":
			problems.append("evolution '%s' declares no kit" % evo_id)
		var reqs: Array = evo.get("requires", [])
		if reqs.size() < 2:
			problems.append("evolution '%s' has %d requirement(s) — needs at least 2"
					% [evo_id, reqs.size()])
		for req: String in reqs:
			if not ALL.has(req):
				problems.append("evolution '%s' requires '%s', which is not a class mod"
						% [evo_id, req])
			elif ALL[req].get("kit", "") != kit:
				problems.append("evolution '%s' (kit '%s') requires '%s', which belongs to kit '%s'"
						% [evo_id, kit, req, ALL[req].get("kit", "")])
		## Three equip slots: a recipe needing more than three mods can never be satisfied.
		if reqs.size() > 3:
			problems.append("evolution '%s' requires %d mods but a character has 3 slots"
					% [evo_id, reqs.size()])
	return problems
