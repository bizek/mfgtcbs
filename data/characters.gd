## CharacterData — Static database of all playable characters.
## Each entry defines base stats, starting weapon, passive ID, unlock cost, and display info.
## Passive IDs are checked in player.gd (_apply_passive_mods, get_armor, take_damage, etc.)
class_name CharacterData

## Unlock order and costs match systems_design_part3.md.
## The Drifter is always unlocked (unlock_cost: 0, always in unlocked_characters).
const ALL: Dictionary = {

	## ─── The Drifter ──────────────────────────────────────────────────────────
	## Baseline. No gimmick. Learn-the-game character.
	"The Drifter": {
		"id":              "The Drifter",
		"display_name":    "THE SELLSWORD",
		"char_class":      "Fighter",
		"description":     "A nameless blade-for-hire. No magic, no tricks - just steel.",
		"starting_weapon": "Mercenary's Edge",   ## Fighter GREEN (task 34 class gear)
		"melee_kit":       "fighter",        ## drives the combo-chain moveset (ChainFactory/SkillFactory)
		"passive_id":      "none",
		"passive_name":    "-",
		"passive_desc":    "None - a plain blade and a steady hand.",
		"portrait":        "res://assets/characters/portraits/the_drifter.png",
		"unlock_cost":     0,
		"base_hp":         100.0,
		"base_armor":      0.0,
		"base_move_speed": 54.0,   ## deliberate-pacing rebalance 2 2026-07-07 (was 66, orig 120) — see docs/pacing_rebalance.md
		"color":           Color(0.92, 0.86, 0.60),   ## warm gold
		"color_body":      Color(0.78, 0.72, 0.58),   ## hub sprite body
		"color_head":      Color(0.94, 0.86, 0.68),   ## hub sprite head
		## Fighter (True Heroes III) — sword-and-shield everyman. See docs/character_overhaul_design.md §2.1
		"sprite": {
			"dir":        "res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Fighter/General_Animations/",
			"frame_size": 32,
			"dir_row":    0,                          ## fallback row only. CharacterSpriteFactory slices
													  ## ALL four facing rows as "<anim>_<facing>" and
													  ## player._facing_variant() picks by cursor quadrant.
													  ## No flip_h substitution — see CLAUDE.md asset rule.
			"anims": {                                ## name: [sheet_file, frame_count, fps, {meta}?]
				"idle":   ["Figther_Idle.png",   16,  9.0],
				"walk":   ["Figther_walk.png",    4, 10.0],
				"attack": ["Figther_Attack.png",  4, 20.0],
				"damage": ["Figther_Dmg.png",     4, 15.0],
				"death":  ["Figther_Die.png",    15, 18.0],
				## Combo specials (Special_Animations/ subfolders → absolute res:// paths).
				## Timing/damage live in ChainFactory.build_fighter_combo (provisional).
				"swirl":     ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Fighter/Special_Animations/Swirl/Figther_Swirl.png",         4, 18.0],
				"tempest":   ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Fighter/Special_Animations/Tempest/Figther_Tempest.png",      7, 18.0, {"cancel_open": 5}],
				"cataclysm": ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Fighter/Special_Animations/Cataclysm/Figther_Cataclysm.png", 12, 18.0],
				## Swing-effect overlays (the white slash). Played on a separate ComboFx sprite,
				## scaled by COMBO_FX_SCALE × melee_range so the visual tracks the (scalable) hit range.
				"attack_fx":    ["Figther_Attack_Effect.png", 4, 20.0],
				"swirl_fx":     ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Fighter/Special_Animations/Swirl/Figther_Swirl_Effect.png",      4, 18.0],
				"tempest_fx":   ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Fighter/Special_Animations/Tempest/Figther_Tempest_Effect.png",  7, 18.0],
				"cataclysm_fx": ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Fighter/Special_Animations/Cataclysm/Cataclysm_Effect.png",      12, 18.0],
				## Neutral specials: Uppercut (RMB tap, launcher) + Taunt (RMB hold, shockwave).
				"uppercut":     ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Fighter/Special_Animations/Uppercut/Figther_Uppercut.png",        4, 18.0],
				"uppercut_fx":  ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Fighter/Special_Animations/Uppercut/Figther_Uppercut_Effect.png", 4, 18.0],
				"taunt":        ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Fighter/Special_Animations/Taunt/Figther_Taunt.png",              9, 16.0],
				## Q/E skill re-slices (SkillFactory). "rally" = a single shield smack (Ben
				## 2026-07-20: wanted Second Wind to bang the shield once, not swing) — it rides the
				## Taunt sheet, played once (the channel loops the same sheet). The green heal
				## ring/flash is host-side. "rush" = the Attack sheet fast (Shield Rush charge body);
				## the dash motion + corridor drag + slam are host-side hooks.
				"rally":        ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Fighter/Special_Animations/Taunt/Figther_Taunt.png", 9, 16.0],
				"rush":         ["Figther_Attack.png",  4, 24.0],
			},
		},
	},

	## ─── The Scavenger ────────────────────────────────────────────────────────
	## Extraction optimizer. Wider pickup radius and bonus loot find.
	"The Scavenger": {
		"id":              "The Scavenger",
		"display_name":    "THE SCAVENGER",
		"char_class":      "Ranger",
		"description":     "A wilds-runner who reads every battlefield for salvage.",
		"starting_weapon": "Hunter's Bow",   ## Ranger = bow/arrows (2026-06-24)
		"melee_kit":       "ranger",         ## drives the combo-chain moveset (ChainFactory)
		"passive_id":      "scavenger_passive",
		"passive_name":    "Forager's Eye",
		"passive_desc":    "+25% Pickup Radius. +15% Loot Find.",
		"portrait":        "res://assets/characters/portraits/the_scavenger.png",
		"unlock_cost":     1000,
		"base_hp":         80.0,
		"base_armor":      0.0,
		"base_move_speed": 60.0,   ## deliberate-pacing rebalance 2 2026-07-07 (was 72, orig 132)
		"color":           Color(0.52, 0.88, 0.40),   ## scrap green
		"color_body":      Color(0.42, 0.68, 0.32),
		"color_head":      Color(0.58, 0.82, 0.46),
		## Ranger (True Heroes III) — green hooded archer. No plain Attack sheet → SingleShot. §2.2
		"sprite": {
			"dir":        "res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Ranger/General_Animations/",
			"frame_size": 32,
			"dir_row":    0,
			"anims": {
				"idle":   ["Ranger_Idle.png",               16,  9.0],
				"walk":   ["Ranger_walk.png",                4, 10.0],
				## Diagonal shot sheet — rows match the quadrant facing system (the old
				## Orthogonal @50fps was the auto-fire fire_delay hack; combos don't need it).
				"attack": ["Ranger_SingleShot_Diagonal.png", 10, 24.0, {"cancel_open": 7}],
				"damage": ["Ranger_Dmg.png",                 4, 15.0],
				"death":  ["Ranger_Die.png",                24, 24.0],
				## Combo specials — timing/damage in ChainFactory.build_ranger_* (provisional).
				## Arrow/knife projectiles + knife-ground impact are wired in ChainFactory;
				## Conceal is a 2-row sheet (no facing variants — base row only, by design).
				"double_shot": ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Ranger/Special_Animations/Double_Shot/Ranger_DoubleShot_Diagonal.png",           11, 20.0, {"cancel_open": 8}],
				"triple_shot": ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Ranger/Special_Animations/Triple_Shot/Ranger_TripleShot.png",                    12, 20.0, {"cancel_open": 9}],
				"knife":       ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Ranger/Special_Animations/Throwing_Knife/Throwing_Knife_Diagonal.png",           11, 20.0],
				"melee":       ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Ranger/Special_Animations/Single_Melee_Attack/Ranger_Single_Melee_Attack.png",    5, 16.0, {"cancel_open": 4}],
				"melee_fx":    ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Ranger/Special_Animations/Single_Melee_Attack/Single_Melee_Attack_Effect.png",    5, 16.0],
				"melee_2":     ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Ranger/Special_Animations/Double_Melee_Attack/Ranger_Double_Melee_Attack.png",    5, 16.0],
				"melee_2_fx":  ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Ranger/Special_Animations/Double_Melee_Attack/Double_Melee_Attack_Effect.png",    5, 16.0],
				"conceal":     ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Ranger/Special_Animations/Conceal/Ranger_Conceal.png",                           14, 16.0],
			},
		},
	},

	## ─── The Warden ───────────────────────────────────────────────────────────
	## Immovable wall. High HP and armor that doubles when wounded.
	"The Warden": {
		"id":              "The Warden",
		"display_name":    "THE WARDEN",
		"char_class":      "Paladin",
		"description":     "An oathbound guardian who plants their feet and dares the horde to move them.",
		"starting_weapon": "Warden's Repeater",
		"melee_kit":       "paladin",        ## drives the combo-chain moveset (ChainFactory)
		"passive_id":      "warden_passive",
		"passive_name":    "Last Bastion",
		"passive_desc":    "Armor doubles while below 50% HP.",
		"portrait":        "res://assets/characters/portraits/the_warden.png",
		"unlock_cost":     1000,
		"base_hp":         150.0,
		"base_armor":      5.0,
		"base_move_speed": 48.0,   ## deliberate-pacing rebalance 2 2026-07-07 (was 58, orig 96) — slowest; kept a touch above scale so the tank isn't sluggish
		"color":           Color(0.82, 0.64, 0.28),   ## iron bronze
		"color_body":      Color(0.55, 0.48, 0.28),
		"color_head":      Color(0.75, 0.65, 0.40),
		## Paladin (True Heroes II) — blue/gold shield-knight. §2.3
		"sprite": {
			"dir":        "res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/General_Animations/",
			"frame_size": 32,
			"dir_row":    0,
			"anims": {
				"idle":   ["PaladinIdle.png",   12,  8.0],
				"walk":   ["PaladinWalk.png",    4,  9.0],
				"attack": ["PaladinAttack.png",  6, 30.0],
				"damage": ["PaladinDmg.png",     4, 15.0],
				"death":  ["PaladinDie.png",    20, 22.0],
				## Combo specials (Special_Animations/ subfolders → absolute res:// paths).
				## Timing/damage live in ChainFactory.build_paladin_* (provisional).
				## "attack_2" re-slices the Attack sheet slower (heavier follow-through) under a
				## distinct anim NAME so play() restarts it on back-to-back strike phases.
				## "dictum" and "dome" both slice the same cast sheet — distinct names so each
				## channel picks its own frame-matched _fx overlay (blades vs dome).
				"attack_2":  ["PaladinAttack.png", 6, 22.0],
				## Shield Bash sheets are CARDINAL 4-row (down/up/left/right), not diagonal — so the bash
				## fires up/down/left/right (Ben 2026-07-20). Row order is a best guess; if a direction
				## faces wrong, remap in the Lab (dirs.<cardinal>.row). Diagonal aims snap to nearest.
				"bash":      ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Shield_Bash/PaladinShieldBash.png",       8, 18.0, {"cardinal": true, "cancel_open": 5}],
				"bash_fx":   ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Shield_Bash/ShieldBashEffect.png",        8, 18.0, {"cardinal": true}],
				## Hammer throw uses the DIAGONAL char sheet — its rows match the quadrant facing
				## system (the Orthogonal sheet's N/E/S/W rows are reserved for a future 8-way pass).
				"hammer":    ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Holy_Hammer/PaladinHolyHammerDiagonal.png", 12, 18.0, {"cancel_open": 9}],
				"dictum":    ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Dictums/_PaladinDictum.png",             15, 20.0],
				"dictum_fx": ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Dictums/BladesDictumEffect.png",         15, 20.0],
				"dome":      ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Dictums/_PaladinDictum.png",             15, 20.0],
				"dome_fx":   ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Dictums/DomeDictumEffect.png",           15, 20.0],
				## Q skill re-slice (SkillFactory): "vow" = the Dictum cast quicker, paired with the
				## protective Dome effect overlay (Aegis Vow).
				"vow":       ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Dictums/_PaladinDictum.png",             15, 24.0],
				"vow_fx":    ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Dictums/DomeDictumEffect.png",           15, 24.0],
				## E skill re-slice (Lay on Hands, Ben 2026-07-20): a prayer-mend — the Dictum cast body
				## carries the Cleric's HealingWords overlay borrowed as "heal_word_fx".
				"heal_word":    ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Dictums/_PaladinDictum.png",          15, 20.0],
				"heal_word_fx": ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Cleric/Special_Animations/Prayers/HealingWordsPrayEffect.png",   22, 20.0],
			},
		},
	},

	## ─── The Spark ────────────────────────────────────────────────────────────
	## Glass cannon. Lowest HP, highest crit damage multiplier.
	"The Spark": {
		"id":              "The Spark",
		"display_name":    "THE SPARK",
		"char_class":      "Wizard",
		"description":     "A reckless arcanist who overcharges every spell - devastating, one misstep from ash.",
		"starting_weapon": "Apprentice Flame",   ## Wizard GREEN (task 34 class gear)
		"melee_kit":       "wizard",         ## drives the combo-chain moveset (ChainFactory)
		"dash_style":      "teleport",       ## Space = blink (class-flavored dash, player.gd)
		"passive_id":      "spark_passive",
		"passive_name":    "Arcane Overload",
		"portrait":        "res://assets/characters/portraits/the_spark.png",
		"passive_desc":    "+50% Crit Damage (2.25\u00d7 total instead of 1.5\u00d7).",
		"unlock_cost":     1500,
		"base_hp":         60.0,
		"base_armor":      0.0,
		"base_move_speed": 58.0,   ## deliberate-pacing rebalance 2 2026-07-07 (was 70, orig 126)
		"color":           Color(1.0, 0.82, 0.12),    ## electric yellow
		"color_body":      Color(0.88, 0.72, 0.12),
		"color_head":      Color(1.0, 0.92, 0.44),
		## Wizard (True Heroes III) — pointy-hat arcanist. Robe is red; yellow stays as FX/UI accent. §2.4
		"sprite": {
			"dir":        "res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Wizard/General_Animations/",
			"frame_size": 32,
			"dir_row":    0,
			"anims": {
				"idle":   ["Wizard_Idle.png",   16,  9.0],
				"walk":   ["Wizard_Walk.png",    4, 10.0],
				"attack": ["Wizard_Attack.png",  6, 30.0],
				"damage": ["Wizard_Dmg.png",     4, 15.0],
				"death":  ["Wizard_Die.png",    20, 22.0],
				## Combo specials — timing/damage in ChainFactory.build_wizard_* (provisional).
				## Diagonal special sheets are used (rows match the quadrant facing system);
				## Fireball/teleport projectile + torrent effect sheets are wired host-side
				## (player.gd / ChainFactory) as world/overlay visuals, not body anims.
				"attack_2":     ["Wizard_Attack.png",        6, 24.0],
				"attack_fx":    ["Wizard_Attack_Effect.png", 6, 30.0],
				"attack_2_fx":  ["Wizard_Attack_Effect.png", 6, 24.0],
				## Q/E cast bodies — the IDLE sheet, not the Attack sheet. The Wizard's Attack art has a
				## fire swing baked into the BODY frames (it's a fire-mage pack), so re-slicing it dragged
				## the flame onto the ice/lightning skills (Ben 2026-07-20). Idle is the only fire-free
				## wizard body; the Burst_Ice / Aura / lightning-strike VFX carry the cast. Facing rows
				## intact (idle is 4-row), so the caster still faces the cursor.
				"ice_cast":     ["Wizard_Idle.png", 8, 14.0],
				"storm_cast":   ["Wizard_Idle.png", 8, 14.0],
				## "fireball" = the RMB-hold Charge — TRIMMED to the wind-up (7f) so it holds the
				## wound-up pose while held instead of playing the throw (fixes the old "fires
				## twice" look, Ben 2026-07-20). "fireball_2" plays the full cast fast on Release.
				"fireball":     ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Wizard/Special_Animations/Fireball/Wizard_Fireball_Diagonal.png",            7, 20.0],
				"fireball_2":   ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Wizard/Special_Animations/Fireball/Wizard_Fireball_Diagonal.png",           11, 28.0],
				## Fire Burst finisher (LMB chain 3rd hit): the cast body re-slices the Attack sheet;
				## the Spell-Effects pack's Burst_Fire (32px, 15f) rides the ComboFx overlay while
				## eight firebolts radiate out (ChainFactory._fire_burst_bolts).
				"fireburst":    ["Wizard_Attack.png", 6, 22.0],
				"fireburst_fx": ["res://assets/minifantasy/Minifantasy_Spell Effects_v1.0/Minifantasy_Spell_Effects_Assets/Fire/Burst/Burst_Fire.png", 15, 15.0, 32],
				"summon":       ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Wizard/Special_Animations/Fire_Familiar/Wizard_Summon_Fire_Familiar.png",  12, 18.0],
				## Teleport (Space blink) — 8-way (Ben 2026-07-20): Diagonal sheet supplies the four
				## diagonal facings, the Orthogonal companion the four cardinals, so a straight
				## up/down/left/right blink plays its true row. Ortho row order is a best guess —
				## verify/remap in the Lab (dirs.<cardinal>.row) if a cardinal blink faces wrong.
				"teleport_out": ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Wizard/Special_Animations/Teleport/Wizard_Teleport_Start_Diagonal.png",    13, 26.0, {"ortho": "res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Wizard/Special_Animations/Teleport/Wizard_Teleport_Start_Orthogonal.png"}],
				"teleport_in":  ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Wizard/Special_Animations/Teleport/Wizard_Teleport_End_Diagonal.png",      13, 26.0, {"ortho": "res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Wizard/Special_Animations/Teleport/Wizard_Teleport_End_Orthogonal.png"}],
				## "torrent" retained as a spare sheet (Fire Torrent cut 2026-07-20; unused by any kit).
				"torrent":      ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Wizard/Special_Animations/Fire_Torrent/Wizard_Fire_Torrent.png",           20, 30.0],
			},
		},
	},

	## ─── The Shade ────────────────────────────────────────────────────────────
	## Necromancer. A summoner-caster: bone missiles, a void nova, and raised dead.
	"The Shade": {
		"id":              "The Shade",
		"display_name":    "THE SHADE",
		"char_class":      "Necromancer",
		"description":     "A shrouded reaper who empties graves against the horde - bone, void, and the risen dead answer the call.",
		"starting_weapon": "Boneculler Staff",   ## Necromancer GREEN (task 34 class gear)
		"melee_kit":       "necromancer",         ## drives the combo-chain moveset (ChainFactory/SkillFactory)
		"passive_id":      "necro_soul_harvest",
		"passive_name":    "Soul Harvest",
		"passive_desc":    "Kills reap souls - a little life each, and every 3rd empowers your next summon.",
		"dash_style":      "planeshift",          ## Plane Shift: dematerialize to the invulnerable Soul form
		"portrait":        "res://assets/characters/portraits/the_shade.png",
		"unlock_cost":     2000,
		"base_hp":         95.0,
		"base_armor":      2.0,
		"base_move_speed": 46.0,   ## slow summoner-caster — leans on minions and range, not footwork
		"color":           Color(0.65, 0.38, 0.92),   ## deep violet
		"color_body":      Color(0.35, 0.22, 0.55),
		"color_head":      Color(0.58, 0.38, 0.78),
		## Supreme Necromancer (True Villains I) — bare sheet filenames (no class-name prefix); the
		## villain pack bakes its glow into the base sheets (Only_Effect/No_Effect split), so no _fx
		## overlays are needed. Combo timing/damage live in ChainFactory.build_necro_* / SkillFactory.
		"sprite": {
			"dir":        "res://assets/minifantasy/Minifantasy_True_Villains_I_v1.0/_Minifantasy_True_Villains_Assets/Supreme_Necromancer/General_Animations/",
			"frame_size": 32,
			"dir_row":    0,
			"anims": {
				"idle":   ["Idle.png",   27, 12.0],
				"walk":   ["Walk.png",     4,  9.0],
				"attack": ["Attack.png",  13, 24.0, {"cancel_open": 10}],
				"damage": ["Dmg.png",      4, 15.0],
				"death":  ["Die.png",     22, 24.0],
				## "attack_2" re-slices the cast faster — a distinct anim NAME so the runner's play()
				## restarts it on back-to-back cast phases (same-anim play() doesn't restart mid-anim).
				"attack_2":   ["Attack.png", 13, 30.0, {"cancel_open": 10}],
				## "bone_cast" re-slices the cast for the Bone Missile finisher + barrage channel; the
				## bolt itself is a world-anchored projectile built in ChainFactory (not a body anim).
				"bone_cast":  ["Attack.png", 13, 26.0, {"cancel_open": 10}],
				## Bone Swirl heavy nova — the pack's cast pose (Bone_Swirl_Cast, 32px, 4 rows).
				"bone_swirl": ["res://assets/minifantasy/Minifantasy_True_Villains_I_v1.0/_Minifantasy_True_Villains_Assets/Supreme_Necromancer/Special_Animations/Bone_Swirl/Bone_Swirl_Cast.png", 29, 26.0],
				## Summons: one shared Rise_Corpse cast body under two anim NAMES so the host branches
				## (rise_corpse → persistent champion; bone_legion → short-lived swarm).
				"rise_corpse":["res://assets/minifantasy/Minifantasy_True_Villains_I_v1.0/_Minifantasy_True_Villains_Assets/Supreme_Necromancer/Special_Animations/Rise_Corpse/Rise_Corpse.png", 18, 18.0],
				"bone_legion":["res://assets/minifantasy/Minifantasy_True_Villains_I_v1.0/_Minifantasy_True_Villains_Assets/Supreme_Necromancer/Special_Animations/Rise_Corpse/Rise_Corpse.png", 18, 18.0],
				## "dodge" is mapped to the Soul form (Plane_Shift/Soul_Shape) so the planeshift dash
				## plays the invulnerable soul flight via the shared dash-anim path in player.gd.
				"dodge":      ["res://assets/minifantasy/Minifantasy_True_Villains_I_v1.0/_Minifantasy_True_Villains_Assets/Supreme_Necromancer/Special_Animations/Plane_Shift/Soul_Shape/Soul_Fly.png", 4, 16.0],
			},
		},
	},

	## ─── The Demon ────────────────────────────────────────────────────────────
	## Demonologist. A close-range hellfire bruiser who binds what he burns: fire bursts,
	## a brimstone pact circle, one bound Angry Demon, and the Archdemon on a long cooldown.
	"The Demon": {
		"id":              "The Demon",
		"display_name":    "THE DEMON",
		"char_class":      "Demonologist",
		"description":     "A pact-scarred binder who calls the pit up through the floor - hellfire, brimstone, and something with horns.",
		"starting_weapon": "Pact-Brand Stave",   ## Demonologist GREEN (task 34 class gear)
		"melee_kit":       "demonologist",       ## drives the combo-chain moveset (ChainFactory/SkillFactory)
		"passive_id":      "demon_hellborn",
		"passive_name":    "Hellborn",
		"passive_desc":    "+25% Fire Damage. +30 Fire Resist - hell does not burn its own.",
		"dash_style":      "ashenstep",          ## Ashen Step: hop clear and leave the ground burning
		"portrait":        "res://assets/characters/portraits/the_demon.png",
		"unlock_cost":     2500,
		"base_hp":         100.0,
		"base_armor":      1.0,
		"base_move_speed": 52.0,   ## close-range caster — has to walk into his own hellfire
		"color":           Color(0.95, 0.30, 0.20),   ## infernal red
		"color_body":      Color(0.55, 0.15, 0.15),
		"color_head":      Color(0.85, 0.45, 0.30),
		## Demonologist (True Villains I) — bare sheet filenames (no class-name prefix); the villain
		## pack bakes its glow into the base sheets (No_Effect/Only_Effect split), so no _fx overlays.
		## The pack ships NO projectile sheets — Hellfire's motes are baked into the body — so this kit
		## is short-range by construction (see ModApplicability: "melee_hit" only).
		## Combo timing/damage live in ChainFactory.build_demon_* / SkillFactory.
		"sprite": {
			"dir":        "res://assets/minifantasy/Minifantasy_True_Villains_I_v1.0/_Minifantasy_True_Villains_Assets/Demonologist/General_Animations/",
			"frame_size": 32,
			"dir_row":    0,
			## `cancel_open` (4th spec element) is the frame a chain node may first be cancelled by a
			## buffered tap — player.choreo_min_advance_time enforces it, and the Animation Lab can
			## retune it live. It exists because this pack's bodies are 10-15 frames where the True
			## Heroes packs are 4-7: the flat 0.22s spam cadence alone cut Hellfire at frame 5 of 15,
			## so its fire never drew (Ben, 2026-07-26). Each value is that anim's commitment point —
			## the frame after which the action reads as done and the recovery can be skipped.
			"anims": {
				"idle":   ["Idle.png",   24, 12.0],
				"walk":   ["Walk.png",    4,  9.0],
				## Staff swing: white arc lands frames 4-5, frames 6-9 are recovery.
				"attack": ["Attack.png", 10, 20.0, {"cancel_open": 6}],
				"damage": ["Dmg.png",     4, 15.0],
				"death":  ["Die.png",    27, 24.0],
				## Hellfire does double duty (light finisher / heavy opener) plus the RMB-hold channel
				## beat, each a separate NAME at its own tempo so re-entry always restarts the spray.
				## The motes fly frames 3-12 and fade 13-14 — cancelling before ~10 hides the fire,
				## which IS the ability.
				"hellfire":    ["res://assets/minifantasy/Minifantasy_True_Villains_I_v1.0/_Minifantasy_True_Villains_Assets/Demonologist/Special_Animations/Hellfire/Hellfire.png", 15, 22.0, {"cancel_open": 11}],
				"hellfire_2":  ["res://assets/minifantasy/Minifantasy_True_Villains_I_v1.0/_Minifantasy_True_Villains_Assets/Demonologist/Special_Animations/Hellfire/Hellfire.png", 15, 26.0, {"cancel_open": 11}],
				## Hell Breach — the hop-and-slam. Moved off the dash and INTO the light chain
				## (Ben 2026-07-26: the chain's 2nd beat was a second Hellfire, which is just the
				## RMB tap again; no kit should ship a repeated move). It reads swing → slam on the
				## spot — the leap is VERTICAL and lands on the tile it left, so nothing displaces
				## him. 13 frames: f1 crouch, f2-4 airborne, f5 slam (hit frame), f6-8 the impact
				## ring, f9-12 recovery — hence cancel_open 8, once the ring has done its work.
				"hell_breach": ["res://assets/minifantasy/Minifantasy_True_Villains_I_v1.0/_Minifantasy_True_Villains_Assets/Demonologist/Special_Animations/Hell_Breach/Hell_Breach.png", 13, 24.0, {"cancel_open": 8}],
				"hellfire_ch": ["res://assets/minifantasy/Minifantasy_True_Villains_I_v1.0/_Minifantasy_True_Villains_Assets/Demonologist/Special_Animations/Hellfire/Hellfire.png", 15, 20.0],
				## One shared Summon_Ritual cast body under two anim NAMES so the host branches:
				## "brimstone" → the gated pact-circle finisher, "pact_ritual" → the Q summon.
				## NB: neither may start with "summon" — player.choreo_fire_effects routes any
				## anim beginning "summon" to the Wizard's Fire Familiar.
				## 36fps, not 26 (Ben 2026-07-30: "RMB 2nd chain animation FPS is too slow, looks bad").
				## At 26 the 19-frame ritual ran 0.73s with its hit at 0.54s — half a second of dead
				## wind-up, and the slowest beat in the kit by a mile when every other node lands in
				## 0.12-0.21s. 36fps puts it at 0.53s / hit 0.39s, in line with attack (0.50s) and
				## hell_breach (0.54s). "pact_ritual" below shares this sheet and deliberately stays
				## slow — the Q summon IS meant to read as a ceremony.
				"brimstone":   ["res://assets/minifantasy/Minifantasy_True_Villains_I_v1.0/_Minifantasy_True_Villains_Assets/Demonologist/Special_Animations/Summon_Demon/Summon_Ritual.png", 19, 36.0],
				"pact_ritual": ["res://assets/minifantasy/Minifantasy_True_Villains_I_v1.0/_Minifantasy_True_Villains_Assets/Demonologist/Special_Animations/Summon_Demon/Summon_Ritual.png", 19, 16.0],
				## Archdemon's Call (E): the long cast; the 27-frame Archdemon_Call_Spell erupts at the
				## cursor as a world-anchored VFX over the ground zone (host-side).
				"archdemon_call": ["res://assets/minifantasy/Minifantasy_True_Villains_I_v1.0/_Minifantasy_True_Villains_Assets/Demonologist/Special_Animations/Archdemon_Call/Archdemon_Call_Cast.png", 19, 15.0],
				## "dodge" is the pack's own General_Animations/Jump — a 4-frame hop that was the
				## last completely unused sheet in the Demonologist folder. It became the dash body
				## when Hell Breach moved into the light chain; see dash_style "ashenstep".
				"dodge":       ["res://assets/minifantasy/Minifantasy_True_Villains_I_v1.0/_Minifantasy_True_Villains_Assets/Demonologist/General_Animations/Jump.png", 4, 15.0],
			},
		},
	},

	## ─── The Cursed ───────────────────────────────────────────────────────────
	## Expert character. Starts every run at Unsettled instability; all stats +20%.
	"The Cursed": {
		"id":              "The Cursed",
		"display_name":    "THE CURSED",
		"char_class":      "Blood Mage",
		"description":     "A heretic who pays in their own blood for power no sane mage would touch.",
		"starting_weapon": "Void Mortar",
		"melee_kit":       "blood_mage",     ## drives the combo-chain moveset (ChainFactory)
		"passive_id":      "cursed_passive",
		"passive_name":    "Blood Pact",
		"passive_desc":    "Begins each run Unsettled (+instability). +20% to all base stats.",
		"portrait":        "res://assets/characters/portraits/the_cursed.png",
		"unlock_cost":     5000,
		"base_hp":         120.0,
		"base_armor":      3.0,
		"base_move_speed": 58.0,   ## deliberate-pacing rebalance 2 2026-07-07 (was 70, orig 126); Blood Pact +20% → effective 70 (expert-tier)
		"color":           Color(0.90, 0.22, 0.22),   ## blood red
		"color_body":      Color(0.55, 0.14, 0.14),
		"color_head":      Color(0.78, 0.28, 0.28),
		## Blood Mage (True Heroes IV) — crimson sinister caster. Generic sheet filenames. §2.7
		"sprite": {
			"dir":        "res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/General_Animations/",
			"frame_size": 32,
			"dir_row":    0,
			"anims": {
				"idle":   ["Idle.png",   16,  9.0],
				"walk":   ["Walk.png",    4, 10.0],
				"attack": ["Attack.png",  6, 30.0],
				"damage": ["Dmg.png",     4, 15.0],
				"death":  ["Die.png",    23, 24.0],
				## Combo specials — timing/damage in ChainFactory.build_blood_mage_* (provisional).
				## Diagonal shard-cast sheet matches the quadrant facings; the shard projectile,
				## impact, spikes ground burst, and drain wisps are wired host-side
				## (player.gd / ChainFactory), not body anims.
				"attack_2":    ["Attack.png",        6, 24.0],
				"attack_fx":   ["Attack_Effect.png", 6, 30.0],
				"attack_2_fx": ["Attack_Effect.png", 6, 24.0],
				"shards":       ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Blood_Shard/Blood_Shards_Diagonal.png",        10, 20.0, {"cancel_open": 8}],
				"shards_fx":    ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Blood_Shard/Blood_Shards_Diagonal_Effect.png", 10, 20.0],
				"slam":         ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Blood_Slam/Blood_Slam.png",                     6, 18.0, {"cancel_open": 5}],
				"slam_fx":      ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Blood_Slam/Blood_Slam_Effect.png",              6, 18.0],
				"spikes":       ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Blood_Spikes/Blood_Spikes.png",                 8, 16.0],
				"spikes_fx":    ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Blood_Spikes/Blood_Spikes_Effect.png",          8, 16.0],
				"extract":      ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Extract_Power/Extract_Power.png",               7, 14.0],
				"summon_blood": ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Summon_Blood_Elemental/Summon_Blood_Elemental.png", 16, 18.0],
				"vampirize":    ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Vampirize/Extract_Blood.png",                    7, 14.0],
				"consume":      ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Vampirize/Consume_Blood.png",                    7, 14.0],
			},
		},
	},

	## ─── The Ravager ──────────────────────────────────────────────────────────
	## Berserker brawler. Gets stronger as the blood flows — his or theirs.
	"The Ravager": {
		"id":              "The Ravager",
		"display_name":    "THE RAVAGER",
		"char_class":      "Barbarian",
		"description":     "A mountain of scars and fury. The storm follows his blade because it's afraid to be left behind.",
		"starting_weapon": "Ravager's Cleaver",    ## Barbarian GREEN (task 34 class gear)
		"melee_kit":       "barbarian",       ## drives the combo-chain moveset (ChainFactory/SkillFactory)
		"passive_id":      "ravager_passive",
		"passive_name":    "Bloodrage",
		"passive_desc":    "+30% Damage while below 50% HP.",
		"portrait":        "res://assets/characters/portraits/the_ravager.png",
		"unlock_cost":     3000,
		"base_hp":         130.0,
		"base_armor":      2.0,
		"base_move_speed": 52.0,   ## deliberate-pacing rebalance 2 2026-07-07 (was 62) — heavier than the Fighter (54), quicker than the Warden (48)
		"color":           Color(0.90, 0.48, 0.18),   ## storm-forge orange
		"color_body":      Color(0.62, 0.34, 0.16),
		"color_head":      Color(0.85, 0.62, 0.42),
		## Barbarian (True Heroes I) — bare-chested berserker. Full special package wired:
		## Battle_Cry (+frame-matched effect front layer as cry_fx), Guard, Throw_Things
		## (split into hoist/hurl for Pile Driver — see below), Thunder_Blade (+its own 4-frame
		## directional lightning projectile, ChainFactory).
		"sprite": {
			"dir":        "res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Barbarian/General_Animations/",
			"frame_size": 32,
			"dir_row":    0,
			"anims": {
				"idle":   ["Minifantasy_TrueHeroesBarbarianIdle.png",   16,  9.0],
				"walk":   ["Minifantasy_TrueHeroesBarbarianWalk.png",    4, 10.0],
				"attack": ["Minifantasy_TrueHeroesBarbarianAttack.png",  6, 20.0],
				"damage": ["Minifantasy_TrueHeroesBarbarianDmg.png",     4, 15.0],
				"death":  ["Minifantasy_TrueHeroesBarbarianDie.png",    20, 22.0],
				## Combo specials — timing/damage in ChainFactory.build_barbarian_* (provisional).
				## "attack_2" re-slices the Attack sheet slower (heavier follow-through) under a
				## distinct anim NAME so play() restarts it on back-to-back cleave phases.
				"attack_2": ["Minifantasy_TrueHeroesBarbarianAttack.png",            6, 16.0, {"cancel_open": 4}],
				## AttackBrokenGround is an EFFECT-ONLY sheet (ground cracks, no body) frame-matched
				## to the Attack sheet — so Sunder's body is a third Attack re-slice and the cracks
				## ride the automatic "<anim>_fx" ComboFx overlay.
				"sunder":    ["Minifantasy_TrueHeroesBarbarianAttack.png",            6, 13.0, {"cancel_open": 4}],
				"sunder_fx": ["Minifantasy_TrueHeroesBarbarianAttackBrokenGround.png", 6, 13.0],
				"thunder":  ["res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Barbarian/Special_Animations/Thunder_Blade_Attack/Minifantasy_TrueHeroesBarbarianThunderBlade.png", 17, 22.0],
				## Pile Driver (E) — the Throw_Things sheet is ONE animation on disk and TWO beats in
				## the game, so it is sliced at the beats the artist already drew (verified frame by
				## frame, row 0): f4 he crouches and closes his hands on something, f6-8 he has it
				## hoisted overhead, f9 is the release flash, f10+ recovery.
				##   "hoist" = f0-8, freezing on the overhead pose the hold phase parks in;
				##   "hurl"  = f8-15, starting ON that same pose so the handoff is seamless.
				## hit_frame indices in SkillFactory are LOCAL to each slice (hurl's release = 1).
				"hoist":    ["res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Barbarian/Special_Animations/Throw_Things/Minifantasy_TrueHeroesBarbarianThrowThings.png",           9, 20.0, {"from": 0, "to": 8}],
				"hurl":     ["res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Barbarian/Special_Animations/Throw_Things/Minifantasy_TrueHeroesBarbarianThrowThings.png",           8, 20.0, {"from": 8, "to": 15}],
				## Carry locomotion (Clerveu, 2026-08-17): purpose-drawn 4x4 sheets, arms overhead in
				## every frame, neutral pose matching Throw_Things frame 8. The hoist phase names
				## them via ChoreographyPhase.recovery_locomotion = "carry": once the grab body
				## finishes drawing, the runner's normal recovery release hands the sprite to the
				## locomotion block, which plays "<prefix>_walk"/"<prefix>_idle" (player.gd). Both
				## loop (CharacterSpriteFactory.LOOPING_ANIMS). The idle has a 1-2px hand bob and
				## the walk a 1px vertical one — the carried pile follows the HANDS, found per frame
				## from the art (player._pile_hands_anchor), so no offsets are keyed here.
				## fps: the base Idle is 16 @ 9 (a ~1.8s cycle); 4 frames @ 4.5 keeps a slow strain.
				## The walk matches the base Walk's 4-frame stride, slowed for the -35% carry speed.
				"carry_idle": ["res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Barbarian/Special_Animations/Throw_Things/Minifantasy_TrueHeroesBarbarianCarryIdle.png", 4, 4.5],
				"carry_walk": ["res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Barbarian/Special_Animations/Throw_Things/Minifantasy_TrueHeroesBarbarianCarryWalk.png", 4, 7.0],
				"cry":      ["res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Barbarian/Special_Animations/Battle_Cry/Minifantasy_TrueHeroesBarbarianBattleCry.png",              11, 14.0],
				"cry_fx":   ["res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Barbarian/Special_Animations/Battle_Cry/Minifantasy_TrueHeroesBarbarianBattleCryEffectFrontLayer.png", 11, 14.0],
				"guard":        ["res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Barbarian/Special_Animations/Guard/Minifantasy_TrueHeroesBarbarianBlockGuardUp.png",   4,  8.0],
				## BlockImpact flashes on the ComboFx overlay each time the Guard stops a hit.
				"guard_impact": ["res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Barbarian/Special_Animations/Guard/Minifantasy_TrueHeroesBarbarianBlockImpact.png", 4, 20.0],
			},
		},
	},

	## ─── The Whisper ──────────────────────────────────────────────────────────
	## Assassin. Fast knives, a blade storm, and never quite where you saw them.
	"The Whisper": {
		"id":              "The Whisper",
		"display_name":    "THE WHISPER",
		"char_class":      "Ninja",
		"description":     "You won't hear the blade. You won't hear anything at all.",
		"starting_weapon": "Whisper's Kiss",    ## Ninja GREEN (task 34 class gear)
		"melee_kit":       "ninja",           ## drives the combo-chain moveset (ChainFactory/SkillFactory)
		"dash_style":      "deadly",          ## Space = Deadly Dash — strikes enemies along the path
		"passive_id":      "whisper_passive",
		"passive_name":    "Killing Intent",
		"passive_desc":    "+10% Crit Chance. +25% Crit Damage.",
		"portrait":        "res://assets/characters/portraits/the_whisper.png",
		"unlock_cost":     4000,
		"base_hp":         70.0,
		"base_armor":      0.0,
		"base_move_speed": 64.0,   ## deliberate-pacing rebalance 2 2026-07-07 (was 78) — a hair under the Shade (66) — second-fastest
		"color":           Color(0.42, 0.50, 0.62),   ## gunmetal smoke
		"color_body":      Color(0.24, 0.28, 0.36),
		"color_head":      Color(0.46, 0.52, 0.62),
		## Ninja_Assassin (True Heroes IV) — generic sheet filenames, keyed by folder. Full
		## special package wired: Thousand_Blades (Start/Effect-overlay/End), Sharpen, Smoke_Bomb
		## (Disappear = the vanish; Appear reserved for a reappear polish pass), Deadly_Dash
		## (Start ghosts at launch via dash_style "deadly", End is the dash body anim).
		"sprite": {
			"dir":        "res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Ninja_Assassin/General_Animations/",
			"frame_size": 32,
			"dir_row":    0,
			"anims": {
				"idle":   ["Idle.png",   16,  9.0],
				"walk":   ["Walk.png",    4, 10.0],
				"attack": ["Attack.png",  6, 24.0],
				"damage": ["Dmg.png",     4, 15.0],
				"death":  ["Die.png",    18, 20.0],
				"attack_fx":    ["Attack_Effect.png", 6, 24.0],
				"attack_2":     ["Attack.png",        6, 18.0],
				"attack_2_fx":  ["Attack_Effect.png", 6, 18.0],
				## Thousand Blades: Start = crouch wind-up; "blades" re-slices Start slower as
				## the storm-loop body while the effect-only blade nova rides blades_fx.
				"blades_start": ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Ninja_Assassin/Special_Animations/Thousand_Blades/Thousand_Blades_Start.png",   4, 16.0],
				"blades":       ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Ninja_Assassin/Special_Animations/Thousand_Blades/Thousand_Blades_Start.png",   4, 10.0],
				"blades_fx":    ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Ninja_Assassin/Special_Animations/Thousand_Blades/Thousand_Blades_Effect.png", 12, 30.0],
				"blades_end":   ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Ninja_Assassin/Special_Animations/Thousand_Blades/Thousand_Blades_End.png",     6, 18.0],
				"sharpen":      ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Ninja_Assassin/Special_Animations/Sharpen/Sharpen.png",                        27, 24.0],
				"smoke":        ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Ninja_Assassin/Special_Animations/Smoke_Bomb/Smoke_Bomb_Disappear.png",        16, 20.0],
				"smoke_in":     ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Ninja_Assassin/Special_Animations/Smoke_Bomb/Smoke_Bomb_Appear.png",            8, 18.0],
				"dash_out":     ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Ninja_Assassin/Special_Animations/Deadly_Dash/Deadly_Dash_Start.png",           4, 28.0],
				"dodge":        ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Ninja_Assassin/Special_Animations/Deadly_Dash/Deadly_Dash_End.png",             7, 26.0],
			},
		},
	},

	## ─── The Deadeye ──────────────────────────────────────────────────────────
	## Tech-augmented gunslinger. Every tap is a trigger pull; the storm never misses twice.
	"The Deadeye": {
		"id":              "The Deadeye",
		"display_name":    "THE DEADEYE",
		"char_class":      "Gunslinger",
		"description":     "Half flesh, half firing mechanism. The desert taught the rest.",
		"starting_weapon": "Peacemaker",  ## Gunslinger GREEN (task 34 class gear)
		"melee_kit":       "gunslinger",      ## drives the combo-chain moveset (ChainFactory/SkillFactory)
		"passive_id":      "deadeye_passive",
		"passive_name":    "Calm Hands",
		"passive_desc":    "+25% Damage while above 80% HP.",
		"portrait":        "res://assets/characters/portraits/the_deadeye.png",
		"unlock_cost":     6000,
		"base_hp":         85.0,
		"base_armor":      0.0,
		"base_move_speed": 58.0,   ## deliberate-pacing rebalance 2 2026-07-07 (was 70) — matches Spark/Cursed tier
		"color":           Color(0.89, 0.58, 0.28),   ## sun-scorched brass
		"color_body":      Color(0.60, 0.38, 0.20),
		"color_head":      Color(0.86, 0.66, 0.44),
		## Tech-Augmented_Gunslinger (True Heroes IV) — generic sheet filenames, keyed by
		## folder. Full special package wired: Shot ortho/diag + Projectile_Impact (bullet
		## tracer + landing), Fan_The_Hammer (+its own impact), Desert_Storm (+the 8
		## directional barrage strips as the host storm overlay), Reload, Whip_Attack
		## (+frame-matched effect).
		"sprite": {
			"dir":        "res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Tech-Augmented_Gunslinger/General_Animations/",
			"frame_size": 32,
			"dir_row":    0,
			"anims": {
				"idle":   ["Idle.png",           16,  9.0],
				"walk":   ["Walk.png",            4, 10.0],
				"attack": ["Shot_Diagonal.png",   7, 24.0],
				"damage": ["Dmg.png",             4, 15.0],
				"death":  ["Die.png",            21, 22.0],
				## "attack_2" re-slices the shot at a different pace so back-to-back pulls restart.
				"attack_2": ["Shot_Diagonal.png", 7, 20.0, {"cancel_open": 5}],
				"fan":      ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Tech-Augmented_Gunslinger/Special_Animations/Fan_The_Hammer/FTH_Diagonal.png", 15, 24.0],
				"storm":    ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Tech-Augmented_Gunslinger/Special_Animations/Desert_Storm/DS_Diagonal.png",    14, 20.0],
				"reload":   ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Tech-Augmented_Gunslinger/Special_Animations/Reload/Reload.png",              37, 30.0],
				"whip":     ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Tech-Augmented_Gunslinger/Special_Animations/Whip_Attack/Whip_Attack.png",     6, 18.0],
				"whip_fx":  ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Tech-Augmented_Gunslinger/Special_Animations/Whip_Attack/Whip_Attack_Effect.png", 6, 18.0],
			},
		},
	},

	## ─── The Verdant ──────────────────────────────────────────────────────────
	## Shapeshifter. Nature magic, snaring roots, and the beast/hound/owl forms.
	"The Verdant": {
		"id":              "The Verdant",
		"display_name":    "THE VERDANT",
		"char_class":      "Druid",
		"description":     "A wilds-keeper who wears the shapes of the forest - claw, fang, and wing.",
		"starting_weapon": "Thornstaff",    ## Druid GREEN (task 34 class gear)
		"melee_kit":       "druid",           ## drives the combo-chain moveset (ChainFactory/SkillFactory)
		"passive_id":      "verdant_passive",
		"passive_name":    "Primal Vigor",
		"passive_desc":    "+25% Max HP. Regenerate while not recently hit.",
		"portrait":        "res://assets/characters/portraits/the_verdant.png",
		"unlock_cost":     7000,
		"base_hp":         110.0,
		"base_armor":      2.0,
		"base_move_speed": 56.0,   ## mid-tier; a hair under the Fighter's 54? no — nature-quick, above the Ravager (52)
		"color":           Color(0.36, 0.72, 0.36),   ## forest green
		"color_body":      Color(0.24, 0.48, 0.24),
		"color_head":      Color(0.56, 0.76, 0.48),
		## Druid (True Heroes I) — hooded nature-caster. Shapeshift forms appear as combo-finisher
		## stances (Beast maul / Owl swoop) + the Hound-frenzy channel body; the morph sheets are the
		## finisher wind-ups. Pack I long "Minifantasy_TrueHeroesDruid*" prefix. See design §2.8.
		"sprite": {
			"dir":        "res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Druid/General_Animations/",
			"frame_size": 32,
			"dir_row":    0,
			"anims": {
				"idle":   ["Minifantasy_TrueHeroesDruidIdle.png",   16,  9.0],
				"walk":   ["Minifantasy_TrueHeroesDruidWalk.png",    4, 10.0],
				"attack": ["Minifantasy_TrueHeroesDruidAttack.png",  4, 20.0],
				"damage": ["Minifantasy_TrueHeroesDruidDmg.png",     4, 15.0],
				"death":  ["Minifantasy_TrueHeroesDruidDie.png",    31, 24.0],
				## Combo specials — timing/damage in ChainFactory.build_druid_* (provisional).
				## "attack_2" re-slices the Attack sheet faster for the combo filler / neutral skills.
				"attack_2":     ["Minifantasy_TrueHeroesDruidAttack.png", 4, 26.0],
				## Root Summoning: the cast; the erupted RootAttack rides a host ground decal.
				"root_cast":    ["res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Druid/Special_Animations/Root_Summoning/Minifantasy_TrueHeroesDruidRootSummoning.png", 7, 16.0],
				## The two calls of the wild (Q: Summon Bear · E: Summon Hounds). Both re-slice the Root
				## Summoning cast — the Verdant calling something up out of the ground is the same gesture
				## either way — but they carry DISTINCT NAMES because the host branches its spawn hook off
				## the anim name (player.choreo_fire_effects), the same trick the Shade's
				## rise_corpse/bone_legion pair uses to reach two different summons from one body.
				##
				## The forms' own sheets are NOT listed here any more: the Forest Beast and Forest Hound are
				## summoned companions now, not bodies the player wears, so ForestCompanion slices those
				## sheets itself. The shapeshift morph/revert sheets and the whole Forest Owl set are
				## consequently unused — see the note in ChainFactory's Verdant section (Ben 2026-08-01:
				## "i dont like the transformations at all").
				"summon_bear":  ["res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Druid/Special_Animations/Root_Summoning/Minifantasy_TrueHeroesDruidRootSummoning.png", 7, 14.0],
				"summon_hounds":["res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Druid/Special_Animations/Root_Summoning/Minifantasy_TrueHeroesDruidRootSummoning.png", 7, 18.0],

				## The Verdant's own leap — his dash body, and the last unwired General_Animations sheet.
				"dodge":        ["Minifantasy_TrueHeroesDruidJump.png", 4, 18.0],
			},
		},
	},

	## ─── The Devout ───────────────────────────────────────────────────────────
	## Holy support-caster. Divine Fire, Word of Pain, Healing Words, and Spirit Guardians.
	"The Devout": {
		"id":              "The Devout",
		"display_name":    "THE DEVOUT",
		"char_class":      "Cleric",
		"description":     "A field-priest who answers the horde with holy fire, a word of pain, and guardians of light.",
		"starting_weapon": "Ember Censer",    ## Cleric GREEN (task 34 class gear)
		"melee_kit":       "cleric",          ## drives the combo-chain moveset (ChainFactory/SkillFactory)
		"passive_id":      "devout_passive",
		"passive_name":    "Last Rites",
		"passive_desc":    "Killing an enemy restores 4 HP.",
		"portrait":        "res://assets/characters/portraits/the_devout.png",
		"unlock_cost":     8000,
		"base_hp":         100.0,
		"base_armor":      4.0,
		"base_move_speed": 52.0,   ## armored support — steady, matches the Ravager tier
		"color":           Color(0.98, 0.90, 0.58),   ## luminous gold
		"color_body":      Color(0.82, 0.74, 0.46),
		"color_head":      Color(1.0, 0.94, 0.74),
		## Cleric (True Heroes II) — plate-and-faith support. Three prayers share the one 22f pray
		## body under distinct anim NAMES so each picks its own frame-matched _fx overlay AND so the
		## host can branch (pray_guardian → summon). Pack II "Cleric*" prefix. See design §2.9.
		"sprite": {
			"dir":        "res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Cleric/General_Animations/",
			"frame_size": 32,
			"dir_row":    0,
			"anims": {
				"idle":   ["ClericIdle.png",   12,  8.0],
				"walk":   ["ClericWalk.png",    4,  9.0],
				"attack": ["ClericAttack.png",  6, 30.0],
				"damage": ["ClericDmg.png",     4, 15.0],
				"death":  ["ClericDie.png",    35, 26.0],
				## "attack_2" re-slices the smite slower for the combo filler.
				"attack_2":  ["ClericAttack.png", 6, 24.0],
				## Divine Fire finisher cast (looses the holy bolt at the cursor).
				"divine_fire": ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Cleric/Special_Animations/Divine Fire/ClericDivineFireDiagonal.png", 12, 22.0, {"cancel_open": 9}],
				## Prayers: one shared 22f pray body, three names → three frame-matched _fx overlays.
				"pray_pain":        ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Cleric/Special_Animations/Prayers/_ClericPray.png",              22, 20.0],
				"pray_pain_fx":     ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Cleric/Special_Animations/Prayers/WordOfPainPrayEffect.png",       22, 20.0],
				"pray_heal":        ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Cleric/Special_Animations/Prayers/_ClericPray.png",              22, 20.0],
				"pray_heal_fx":     ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Cleric/Special_Animations/Prayers/HealingWordsPrayEffect.png",     22, 20.0],
				"pray_guardian":    ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Cleric/Special_Animations/Prayers/_ClericPray.png",              22, 20.0],
				"pray_guardian_fx": ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Cleric/Special_Animations/Prayers/SpiritGuardianPrayEffect.png",  22, 20.0],
			},
		},
	},
}

## Ordered list for display (unlock order).
const ORDER: Array = [
	"The Drifter",
	"The Scavenger",
	"The Warden",
	"The Spark",
	"The Shade",
	"The Demon",
	"The Ravager",
	"The Whisper",
	"The Cursed",
	"The Deadeye",
	"The Verdant",
	"The Devout",
]
