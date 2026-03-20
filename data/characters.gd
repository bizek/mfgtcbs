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
		"display_name":    "THE DRIFTER",
		"description":     "The learn-the-game character. Reliable, no surprises.",
		"starting_weapon": "Standard Sidearm",
		"passive_id":      "none",
		"passive_desc":    "None — the baseline.",
		"unlock_cost":     0,
		"base_hp":         100.0,
		"base_armor":      0.0,
		"base_move_speed": 200.0,
		"color":           Color(0.92, 0.86, 0.60),   ## warm gold
		"color_body":      Color(0.78, 0.72, 0.58),   ## hub sprite body
		"color_head":      Color(0.94, 0.86, 0.68),   ## hub sprite head
	},

	## ─── The Scavenger ────────────────────────────────────────────────────────
	## Extraction optimizer. Wider pickup radius and bonus loot find.
	"The Scavenger": {
		"id":              "The Scavenger",
		"display_name":    "THE SCAVENGER",
		"description":     "Extraction optimizer. Finds more, fights less efficiently.",
		"starting_weapon": "Plasma Blade",
		"passive_id":      "scavenger_passive",
		"passive_desc":    "+25% Pickup Radius. +15% Loot Find.",
		"unlock_cost":     1000,
		"base_hp":         80.0,
		"base_armor":      0.0,
		"base_move_speed": 220.0,
		"color":           Color(0.52, 0.88, 0.40),   ## scrap green
		"color_body":      Color(0.42, 0.68, 0.32),
		"color_head":      Color(0.58, 0.82, 0.46),
	},

	## ─── The Warden ───────────────────────────────────────────────────────────
	## Immovable wall. High HP and armor that doubles when wounded.
	"The Warden": {
		"id":              "The Warden",
		"display_name":    "THE WARDEN",
		"description":     "Immovable wall. Survives deep phases through sheer toughness.",
		"starting_weapon": "Warden's Repeater",
		"passive_id":      "warden_passive",
		"passive_desc":    "Armor doubles when below 50% HP.",
		"unlock_cost":     1000,
		"base_hp":         150.0,
		"base_armor":      5.0,
		"base_move_speed": 160.0,
		"color":           Color(0.82, 0.64, 0.28),   ## iron bronze
		"color_body":      Color(0.55, 0.48, 0.28),
		"color_head":      Color(0.75, 0.65, 0.40),
	},

	## ─── The Spark ────────────────────────────────────────────────────────────
	## Glass cannon. Lowest HP, highest crit damage multiplier.
	"The Spark": {
		"id":              "The Spark",
		"display_name":    "THE SPARK",
		"description":     "Glass cannon. Kills everything fast or dies trying.",
		"starting_weapon": "Spark's Pistol",
		"passive_id":      "spark_passive",
		"passive_desc":    "+50% Crit Damage (2.25\u00d7 total instead of 1.5\u00d7).",
		"unlock_cost":     1500,
		"base_hp":         60.0,
		"base_armor":      0.0,
		"base_move_speed": 210.0,
		"color":           Color(1.0, 0.82, 0.12),    ## electric yellow
		"color_body":      Color(0.88, 0.72, 0.12),
		"color_head":      Color(1.0, 0.92, 0.44),
	},

	## ─── The Shade ────────────────────────────────────────────────────────────
	## Untouchable. Highest move speed; dodges grant brief invisibility.
	"The Shade": {
		"id":              "The Shade",
		"display_name":    "THE SHADE",
		"description":     "Untouchable. Weaves through danger.",
		"starting_weapon": "Plasma Blade",
		"passive_id":      "shade_passive",
		"passive_desc":    "15% Dodge Chance. Dodge grants 0.5s invisibility.",
		"unlock_cost":     2000,
		"base_hp":         75.0,
		"base_armor":      0.0,
		"base_move_speed": 240.0,
		"color":           Color(0.65, 0.38, 0.92),   ## deep violet
		"color_body":      Color(0.35, 0.22, 0.55),
		"color_head":      Color(0.58, 0.38, 0.78),
	},

	## ─── The Herald ───────────────────────────────────────────────────────────
	## Ability specialist. Mediocre weapon; active abilities are supercharged.
	"The Herald": {
		"id":              "The Herald",
		"display_name":    "THE HERALD",
		"description":     "Ability specialist. Weapon is weak, abilities are everything.",
		"starting_weapon": "Herald's Beacon",
		"passive_id":      "herald_passive",
		"passive_desc":    "Abilities +30% damage, -20% cooldown. Extra ability slot.",
		"unlock_cost":     2500,
		"base_hp":         90.0,
		"base_armor":      0.0,
		"base_move_speed": 200.0,
		"color":           Color(0.30, 0.86, 0.96),   ## signal teal
		"color_body":      Color(0.20, 0.58, 0.75),
		"color_head":      Color(0.38, 0.82, 0.95),
	},

	## ─── The Cursed ───────────────────────────────────────────────────────────
	## Expert character. Starts every run at Unsettled instability; all stats +20%.
	"The Cursed": {
		"id":              "The Cursed",
		"display_name":    "THE CURSED",
		"description":     "Expert character. Maximum risk, maximum power.",
		"starting_weapon": "Void Mortar",
		"passive_id":      "cursed_passive",
		"passive_desc":    "Starts Unsettled (+instability). +20% to all base stats.",
		"unlock_cost":     5000,
		"base_hp":         120.0,
		"base_armor":      3.0,
		"base_move_speed": 210.0,
		"color":           Color(0.90, 0.22, 0.22),   ## blood red
		"color_body":      Color(0.55, 0.14, 0.14),
		"color_head":      Color(0.78, 0.28, 0.28),
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
