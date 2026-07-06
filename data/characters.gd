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
		"description":     "A nameless blade-for-hire. No magic, no tricks — just steel.",
		"starting_weapon": "Arcane Blade",   ## Fighter = melee (swapped with Ranger 2026-06-24)
		"melee_kit":       "fighter",        ## drives the combo-chain moveset (ChainFactory/SkillFactory)
		"passive_id":      "none",
		"passive_name":    "—",
		"passive_desc":    "None — a plain blade and a steady hand.",
		"portrait":        "res://assets/characters/portraits/the_drifter.png",
		"unlock_cost":     0,
		"base_hp":         100.0,
		"base_armor":      0.0,
		"base_move_speed": 66.0,   ## deliberate-pacing rebalance 2026-06-23 (was 120) — see docs/pacing_rebalance.md
		"color":           Color(0.92, 0.86, 0.60),   ## warm gold
		"color_body":      Color(0.78, 0.72, 0.58),   ## hub sprite body
		"color_head":      Color(0.94, 0.86, 0.68),   ## hub sprite head
		## Fighter (True Heroes III) — sword-and-shield everyman. See docs/character_overhaul_design.md §2.1
		"sprite": {
			"dir":        "res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Fighter/General_Animations/",
			"frame_size": 32,
			"dir_row":    0,                          ## front/Down-facing row; flip_h handles left/right
			"anims": {                                ## name: [sheet_file, frame_count, fps, {meta}?]
				"idle":   ["Figther_Idle.png",   16,  9.0],
				"walk":   ["Figther_walk.png",    4, 10.0],
				"attack": ["Figther_Attack.png",  4, 20.0],
				"damage": ["Figther_Dmg.png",     4, 15.0],
				"death":  ["Figther_Die.png",    15, 18.0],
				## Combo specials (Special_Animations/ subfolders → absolute res:// paths).
				## Timing/damage live in ChainFactory.build_fighter_combo (provisional).
				"swirl":     ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Fighter/Special_Animations/Swirl/Figther_Swirl.png",         4, 18.0],
				"tempest":   ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Fighter/Special_Animations/Tempest/Figther_Tempest.png",      7, 18.0],
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
		"base_move_speed": 72.0,   ## deliberate-pacing rebalance 2026-06-23 (was 132)
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
				"attack": ["Ranger_SingleShot_Diagonal.png", 10, 24.0],
				"damage": ["Ranger_Dmg.png",                 4, 15.0],
				"death":  ["Ranger_Die.png",                24, 24.0],
				## Combo specials — timing/damage in ChainFactory.build_ranger_* (provisional).
				## Arrow/knife projectiles + knife-ground impact are wired in ChainFactory;
				## Conceal is a 2-row sheet (no facing variants — base row only, by design).
				"double_shot": ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Ranger/Special_Animations/Double_Shot/Ranger_DoubleShot_Diagonal.png",           11, 20.0],
				"triple_shot": ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Ranger/Special_Animations/Triple_Shot/Ranger_TripleShot.png",                    12, 20.0],
				"knife":       ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Ranger/Special_Animations/Throwing_Knife/Throwing_Knife_Diagonal.png",           11, 20.0],
				"melee":       ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Ranger/Special_Animations/Single_Melee_Attack/Ranger_Single_Melee_Attack.png",    5, 16.0],
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
		"base_move_speed": 58.0,   ## deliberate-pacing rebalance 2026-06-23 (was 96) — slowest; kept a touch above ×0.55 so the tank isn't sluggish
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
				"bash":      ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Shield_Bash/PaladinShieldBash.png",       8, 18.0],
				"bash_fx":   ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Shield_Bash/ShieldBashEffect.png",        8, 18.0],
				## Hammer throw uses the DIAGONAL char sheet — its rows match the quadrant facing
				## system (the Orthogonal sheet's N/E/S/W rows are reserved for a future 8-way pass).
				"hammer":    ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Holy_Hammer/PaladinHolyHammerDiagonal.png", 12, 18.0],
				"dictum":    ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Dictums/_PaladinDictum.png",             15, 20.0],
				"dictum_fx": ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Dictums/BladesDictumEffect.png",         15, 20.0],
				"dome":      ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Dictums/_PaladinDictum.png",             15, 20.0],
				"dome_fx":   ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Paladin/Special_Animations/Dictums/DomeDictumEffect.png",           15, 20.0],
			},
		},
	},

	## ─── The Spark ────────────────────────────────────────────────────────────
	## Glass cannon. Lowest HP, highest crit damage multiplier.
	"The Spark": {
		"id":              "The Spark",
		"display_name":    "THE SPARK",
		"char_class":      "Wizard",
		"description":     "A reckless arcanist who overcharges every spell — devastating, one misstep from ash.",
		"starting_weapon": "Spark's Pistol",
		"melee_kit":       "wizard",         ## drives the combo-chain moveset (ChainFactory)
		"dash_style":      "teleport",       ## Space = blink (class-flavored dash, player.gd)
		"passive_id":      "spark_passive",
		"passive_name":    "Arcane Overload",
		"portrait":        "res://assets/characters/portraits/the_spark.png",
		"passive_desc":    "+50% Crit Damage (2.25\u00d7 total instead of 1.5\u00d7).",
		"unlock_cost":     1500,
		"base_hp":         60.0,
		"base_armor":      0.0,
		"base_move_speed": 70.0,   ## deliberate-pacing rebalance 2026-06-23 (was 126)
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
				## "fireball" = the Charge (runner crawls it at telegraph speed); "fireball_2"
				## re-slices the same sheet fast for the Release so play() restarts the cast.
				"fireball":     ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Wizard/Special_Animations/Fireball/Wizard_Fireball_Diagonal.png",           11, 20.0],
				"fireball_2":   ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Wizard/Special_Animations/Fireball/Wizard_Fireball_Diagonal.png",           11, 28.0],
				"summon":       ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Wizard/Special_Animations/Fire_Familiar/Wizard_Summon_Fire_Familiar.png",  12, 18.0],
				"teleport_out": ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Wizard/Special_Animations/Teleport/Wizard_Teleport_Start_Diagonal.png",    13, 26.0],
				"teleport_in":  ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Wizard/Special_Animations/Teleport/Wizard_Teleport_End_Diagonal.png",      13, 26.0],
				"torrent":      ["res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Wizard/Special_Animations/Fire_Torrent/Wizard_Fire_Torrent.png",           20, 30.0],
			},
		},
	},

	## ─── The Shade ────────────────────────────────────────────────────────────
	## Untouchable. Highest move speed; dodges grant brief invisibility.
	"The Shade": {
		"id":              "The Shade",
		"display_name":    "THE SHADE",
		"char_class":      "Rogue",
		"description":     "A cutthroat who simply isn't where the blow lands — gone in a wisp of shadow.",
		"starting_weapon": "Arcane Blade",
		"melee_kit":       "rogue",          ## drives the combo-chain moveset (ChainFactory)
		"passive_id":      "shade_passive",
		"passive_name":    "Shadowstep",
		"passive_desc":    "15% Dodge Chance. Dodge grants 0.5s invisibility.",
		"portrait":        "res://assets/characters/portraits/the_shade.png",
		"unlock_cost":     2000,
		"base_hp":         75.0,
		"base_armor":      0.0,
		"base_move_speed": 80.0,   ## deliberate-pacing rebalance 2026-06-23 (was 144) — fastest character
		"color":           Color(0.65, 0.38, 0.92),   ## deep violet
		"color_body":      Color(0.35, 0.22, 0.55),
		"color_head":      Color(0.58, 0.38, 0.78),
		## Rogue (True Heroes I) — hooded cutthroat; native Dodge anim suits the dodge passive. §2.5
		"sprite": {
			"dir":        "res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Rogue/General_Animations/",
			"frame_size": 32,
			"dir_row":    0,
			"anims": {
				"idle":   ["Minifantasy_TrueHeroesRogueIdle.png",   16,  9.0],
				"walk":   ["Minifantasy_TrueHeroesRogueWalk.png",    4, 10.0],
				"attack": ["Minifantasy_TrueHeroesRogueAttack.png",  4, 20.0],
				"damage": ["Minifantasy_TrueHeroesRogueDmg.png",     4, 15.0],
				"death":  ["Minifantasy_TrueHeroesRogueDie.png",    26, 26.0],
				## Class-flavored dash: the pack's real Dodge roll plays during Space dashes.
				"dodge":  ["res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Rogue/Special_Animations/Mobility/Minifantasy_TrueHeroesRogueDodge.png", 8, 30.0],
				## Combo specials (Special_Animations/ subfolders → absolute res:// paths).
				## Timing/damage live in ChainFactory.build_rogue_* (provisional).
				## "attack_2" re-slices the Attack sheet at a higher fps: a distinct anim NAME so
				## the runner's play() restarts it on back-to-back slash phases (same-anim play()
				## doesn't restart mid-anim).
				## The Throw Bomb package's projectile + explosion sheets are wired directly in
				## player.gd (BOMB_PROJ_SHEETS / BOMB_EXPLOSION_SHEET) — world-anchored visuals,
				## not body-overlay anims, so they don't slice into the character SpriteFrames.
				"attack_2": ["Minifantasy_TrueHeroesRogueAttack.png", 4, 26.0],
				"fan":      ["res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Rogue/Special_Animations/Shurikens/Minifantasy_TrueHeroesRogueShurikens.png", 15, 30.0],
				"bomb":     ["res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Rogue/Special_Animations/Throw Bomb/Minifantasy_TrueHeroesRogueThrowBomb.png", 11, 18.0],
			},
		},
	},

	## ─── The Herald ───────────────────────────────────────────────────────────
	## Ability specialist. Mediocre weapon; active abilities are supercharged.
	"The Herald": {
		"id":              "The Herald",
		"display_name":    "THE HERALD",
		"char_class":      "Bard",
		"description":     "A battle-bard whose songs do the real damage — the blade is just punctuation.",
		"starting_weapon": "Herald's Call",
		"melee_kit":       "bard",           ## drives the combo-chain moveset (ChainFactory)
		"passive_id":      "herald_passive",
		"passive_name":    "Rallying Anthem",
		"passive_desc":    "Abilities +30% damage, -20% cooldown. Extra ability slot.",
		"portrait":        "res://assets/characters/portraits/the_herald.png",
		"unlock_cost":     2500,
		"base_hp":         90.0,
		"base_armor":      0.0,
		"base_move_speed": 66.0,   ## deliberate-pacing rebalance 2026-06-23 (was 120)
		"color":           Color(0.30, 0.86, 0.96),   ## signal teal
		"color_body":      Color(0.20, 0.58, 0.75),
		"color_head":      Color(0.38, 0.82, 0.95),
		## Bard (True Heroes II) — teal performer; the instrument is "the Call". §2.6
		"sprite": {
			"dir":        "res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Bard/General_Animations/",
			"frame_size": 32,
			"dir_row":    0,
			"anims": {
				"idle":   ["BardIdle.png",   16,  9.0],
				"walk":   ["BardWalk.png",    4, 10.0],
				"attack": ["BardAttack.png",  4, 20.0],
				"damage": ["BardDmg.png",     4, 15.0],
				"death":  ["BardDie.png",    25, 25.0],
				## Combo specials — timing/damage in ChainFactory.build_bard_* (provisional).
				## Chord projectile/impact + ballad note and mockery wisps are wired host-side;
				## apotheosis_fx is frame-matched, song_enhance_fx is the 8f shimmer overlay.
				"attack_2":       ["BardAttack.png", 4, 26.0],
				"chord":          ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Bard/Special_Animations/Dissonant_Chord/BardDissonantChordDiagonal.png", 12, 20.0],
				"apotheosis":     ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Bard/Special_Animations/Apotheosis/BardApotheosis.png",                  13, 18.0],
				"apotheosis_fx":  ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Bard/Special_Animations/Apotheosis/ApotheosisEffect.png",                13, 18.0],
				"mockery":        ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Bard/Special_Animations/Songs/ViciousMockerySong.png",                   16, 18.0],
				"song_enhance":   ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Bard/Special_Animations/Songs/EnhancementSong.png",                      16, 20.0],
				"song_enhance_fx": ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Bard/Special_Animations/Songs/Enhancement/Enhamcement.png",              8, 10.0],
				"song_ballad":    ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Bard/Special_Animations/Songs/BalladSong.png",                           16, 20.0],
				"serenade":       ["res://assets/minifantasy/Minifantasy_True_Heroes_II_v1.0/Minifantasy_True_Heroes_II_Assets/Bard/Special_Animations/Songs/_BardSinging.png",                       16, 18.0],
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
		"base_move_speed": 70.0,   ## deliberate-pacing rebalance 2026-06-23 (was 126); Blood Pact +20% → effective 84 (expert-tier)
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
				"shards":       ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Blood_Shard/Blood_Shards_Diagonal.png",        10, 20.0],
				"shards_fx":    ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Blood_Shard/Blood_Shards_Diagonal_Effect.png", 10, 20.0],
				"slam":         ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Blood_Slam/Blood_Slam.png",                     6, 18.0],
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
		"starting_weapon": "Arcane Blade",    ## Barbarian = melee; the combo IS the attack
		"melee_kit":       "barbarian",       ## drives the combo-chain moveset (ChainFactory/SkillFactory)
		"passive_id":      "ravager_passive",
		"passive_name":    "Bloodrage",
		"passive_desc":    "+30% Damage while below 50% HP.",
		"portrait":        "res://assets/characters/portraits/the_ravager.png",
		"unlock_cost":     3000,
		"base_hp":         130.0,
		"base_armor":      2.0,
		"base_move_speed": 62.0,   ## heavier than the Fighter (66), quicker than the Warden (58)
		"color":           Color(0.90, 0.48, 0.18),   ## storm-forge orange
		"color_body":      Color(0.62, 0.34, 0.16),
		"color_head":      Color(0.85, 0.62, 0.42),
		## Barbarian (True Heroes I) — bare-chested berserker. Full special package wired:
		## Battle_Cry (+frame-matched effect front layer as cry_fx), Guard, Throw_Things,
		## Thunder_Blade (+its own 4-frame directional lightning projectile, ChainFactory).
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
				"attack_2": ["Minifantasy_TrueHeroesBarbarianAttack.png",            6, 16.0],
				## AttackBrokenGround is an EFFECT-ONLY sheet (ground cracks, no body) frame-matched
				## to the Attack sheet — so Sunder's body is a third Attack re-slice and the cracks
				## ride the automatic "<anim>_fx" ComboFx overlay.
				"sunder":    ["Minifantasy_TrueHeroesBarbarianAttack.png",            6, 13.0],
				"sunder_fx": ["Minifantasy_TrueHeroesBarbarianAttackBrokenGround.png", 6, 13.0],
				"thunder":  ["res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Barbarian/Special_Animations/Thunder_Blade_Attack/Minifantasy_TrueHeroesBarbarianThunderBlade.png", 17, 22.0],
				"throw":    ["res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Barbarian/Special_Animations/Throw_Things/Minifantasy_TrueHeroesBarbarianThrowThings.png",          16, 20.0],
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
		"starting_weapon": "Arcane Blade",    ## Ninja = knives; the combo IS the attack
		"melee_kit":       "ninja",           ## drives the combo-chain moveset (ChainFactory/SkillFactory)
		"dash_style":      "deadly",          ## Space = Deadly Dash — strikes enemies along the path
		"passive_id":      "whisper_passive",
		"passive_name":    "Killing Intent",
		"passive_desc":    "+10% Crit Chance. +25% Crit Damage.",
		"portrait":        "res://assets/characters/portraits/the_whisper.png",
		"unlock_cost":     4000,
		"base_hp":         70.0,
		"base_armor":      0.0,
		"base_move_speed": 78.0,   ## a hair under the Shade (80) — second-fastest
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
		"starting_weapon": "Spark's Pistol",  ## Gunslinger = sidearm; the combo IS the attack
		"melee_kit":       "gunslinger",      ## drives the combo-chain moveset (ChainFactory/SkillFactory)
		"passive_id":      "deadeye_passive",
		"passive_name":    "Calm Hands",
		"passive_desc":    "+25% Damage while above 80% HP.",
		"portrait":        "res://assets/characters/portraits/the_deadeye.png",
		"unlock_cost":     6000,
		"base_hp":         85.0,
		"base_armor":      0.0,
		"base_move_speed": 70.0,
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
				"attack_2": ["Shot_Diagonal.png", 7, 20.0],
				"fan":      ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Tech-Augmented_Gunslinger/Special_Animations/Fan_The_Hammer/FTH_Diagonal.png", 15, 24.0],
				"storm":    ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Tech-Augmented_Gunslinger/Special_Animations/Desert_Storm/DS_Diagonal.png",    14, 20.0],
				"reload":   ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Tech-Augmented_Gunslinger/Special_Animations/Reload/Reload.png",              37, 30.0],
				"whip":     ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Tech-Augmented_Gunslinger/Special_Animations/Whip_Attack/Whip_Attack.png",     6, 18.0],
				"whip_fx":  ["res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Tech-Augmented_Gunslinger/Special_Animations/Whip_Attack/Whip_Attack_Effect.png", 6, 18.0],
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
	"The Herald",
	"The Ravager",
	"The Whisper",
	"The Cursed",
	"The Deadeye",
]
