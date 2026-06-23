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
		"starting_weapon": "Hurled Steel",
		"passive_id":      "none",
		"passive_name":    "—",
		"passive_desc":    "None — a plain blade and a steady hand.",
		"portrait":        "res://assets/characters/portraits/the_drifter.png",
		"unlock_cost":     0,
		"base_hp":         100.0,
		"base_armor":      0.0,
		"base_move_speed": 120.0,
		"color":           Color(0.92, 0.86, 0.60),   ## warm gold
		"color_body":      Color(0.78, 0.72, 0.58),   ## hub sprite body
		"color_head":      Color(0.94, 0.86, 0.68),   ## hub sprite head
		## Fighter (True Heroes III) — sword-and-shield everyman. See docs/character_overhaul_design.md §2.1
		"sprite": {
			"dir":        "res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Fighter/General_Animations/",
			"frame_size": 32,
			"dir_row":    0,                          ## front/Down-facing row; flip_h handles left/right
			"anims": {                                ## name: [sheet_file, frame_count, fps]
				"idle":   ["Figther_Idle.png",   16,  9.0],
				"walk":   ["Figther_walk.png",    4, 10.0],
				"attack": ["Figther_Attack.png",  4, 20.0],
				"damage": ["Figther_Dmg.png",     4, 15.0],
				"death":  ["Figther_Die.png",    15, 18.0],
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
		"starting_weapon": "Arcane Blade",
		"passive_id":      "scavenger_passive",
		"passive_name":    "Forager's Eye",
		"passive_desc":    "+25% Pickup Radius. +15% Loot Find.",
		"portrait":        "res://assets/characters/portraits/the_scavenger.png",
		"unlock_cost":     1000,
		"base_hp":         80.0,
		"base_armor":      0.0,
		"base_move_speed": 132.0,
		"color":           Color(0.52, 0.88, 0.40),   ## scrap green
		"color_body":      Color(0.42, 0.68, 0.32),
		"color_head":      Color(0.58, 0.82, 0.46),
		## Ranger (True Heroes III) — green hooded archer. No plain Attack sheet → SingleShot. §2.2
		"sprite": {
			"dir":        "res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Ranger/General_Animations/",
			"frame_size": 32,
			"dir_row":    0,
			"anims": {
				"idle":   ["Ranger_Idle.png",                 16,  9.0],
				"walk":   ["Ranger_walk.png",                  4, 10.0],
				"attack": ["Ranger_SingleShot_Orthogonal.png", 10, 50.0],
				"damage": ["Ranger_Dmg.png",                   4, 15.0],
				"death":  ["Ranger_Die.png",                  24, 24.0],
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
		"passive_id":      "warden_passive",
		"passive_name":    "Last Bastion",
		"passive_desc":    "Armor doubles while below 50% HP.",
		"portrait":        "res://assets/characters/portraits/the_warden.png",
		"unlock_cost":     1000,
		"base_hp":         150.0,
		"base_armor":      5.0,
		"base_move_speed": 96.0,
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
		"passive_id":      "spark_passive",
		"passive_name":    "Arcane Overload",
		"portrait":        "res://assets/characters/portraits/the_spark.png",
		"passive_desc":    "+50% Crit Damage (2.25\u00d7 total instead of 1.5\u00d7).",
		"unlock_cost":     1500,
		"base_hp":         60.0,
		"base_armor":      0.0,
		"base_move_speed": 126.0,
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
		"passive_id":      "shade_passive",
		"passive_name":    "Shadowstep",
		"passive_desc":    "15% Dodge Chance. Dodge grants 0.5s invisibility.",
		"portrait":        "res://assets/characters/portraits/the_shade.png",
		"unlock_cost":     2000,
		"base_hp":         75.0,
		"base_armor":      0.0,
		"base_move_speed": 144.0,
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
		"passive_id":      "herald_passive",
		"passive_name":    "Rallying Anthem",
		"passive_desc":    "Abilities +30% damage, -20% cooldown. Extra ability slot.",
		"portrait":        "res://assets/characters/portraits/the_herald.png",
		"unlock_cost":     2500,
		"base_hp":         90.0,
		"base_armor":      0.0,
		"base_move_speed": 120.0,
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
		"passive_id":      "cursed_passive",
		"passive_name":    "Blood Pact",
		"passive_desc":    "Begins each run Unsettled (+instability). +20% to all base stats.",
		"portrait":        "res://assets/characters/portraits/the_cursed.png",
		"unlock_cost":     5000,
		"base_hp":         120.0,
		"base_armor":      3.0,
		"base_move_speed": 126.0,
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
	"The Cursed",
]
