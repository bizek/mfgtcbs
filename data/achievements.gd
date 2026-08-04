class_name AchievementData
extends RefCounted

## Static achievement definitions. AchievementManager (autoload) owns detection and
## unlock state; this file only describes what exists.
##
## Fields:
##   title, description : String
##   secret   : bool    — if true, description (not title) is hidden as "???" while locked
##   icon     : String  — short glyph shown in the Records badge (no texture atlas wired yet)
##   color    : Color   — badge accent color
##   kind     : "event" or "threshold"
##   stat_key : String  — for "threshold" kind, which AchievementManager.get_progress() case to use
##   threshold: float   — for "threshold" kind (ignored for stat_key "roster_size", which reads
##                        CharacterData.ORDER.size() at runtime instead)

const ALL: Dictionary = {
	"first_extraction": {
		"title": "Made It Out",
		"description": "Successfully extract for the first time.",
		"secret": false,
		"icon": "⬆",
		"color": Color(0.40, 0.85, 0.55),
		"kind": "event",
	},
	"first_boss_kill": {
		"title": "Trophy Hunter",
		"description": "Defeat a Descent boss.",
		"secret": false,
		"icon": "☠",
		"color": Color(0.85, 0.35, 0.35),
		"kind": "event",
	},
	"game_cleared": {
		"title": "Inferno Cleared",
		"description": "Clear the final biome and extract.",
		"secret": false,
		"icon": "★",
		"color": Color(1.0, 0.85, 0.0),
		"kind": "event",
	},
	"kills_500": {
		"title": "Exterminator",
		"description": "Kill 500 enemies (lifetime).",
		"secret": false,
		"icon": "⚔",
		"color": Color(0.80, 0.69, 0.565),
		"kind": "threshold",
		"stat_key": "total_kills",
		"threshold": 500,
	},
	"kills_5000": {
		"title": "Harvester",
		"description": "Kill 5000 enemies (lifetime).",
		"secret": false,
		"icon": "⚔",
		"color": Color(0.831, 0.447, 0.102),
		"kind": "threshold",
		"stat_key": "total_kills",
		"threshold": 5000,
	},
	"extractions_5": {
		"title": "Getting the Hang of It",
		"description": "Successfully extract 5 times.",
		"secret": false,
		"icon": "⬆",
		"color": Color(0.40, 0.85, 0.55),
		"kind": "threshold",
		"stat_key": "successful_extractions",
		"threshold": 5,
	},
	"extractions_25": {
		"title": "Veteran Extractor",
		"description": "Successfully extract 25 times.",
		"secret": false,
		"icon": "⬆",
		"color": Color(0.2, 0.9, 0.6),
		"kind": "threshold",
		"stat_key": "successful_extractions",
		"threshold": 25,
	},
	"roster_complete": {
		"title": "Full Roster",
		"description": "Unlock every character.",
		"secret": false,
		"icon": "◆",
		"color": Color(0.45, 0.52, 0.95),
		"kind": "threshold",
		"stat_key": "roster_size",
		"threshold": -1,  ## resolved at runtime from CharacterData.ORDER.size()
	},
	"cleared_with_3": {
		"title": "Multi-Class Mastery",
		"description": "Clear the game with 3 different characters.",
		"secret": false,
		"icon": "★",
		"color": Color(1.0, 0.85, 0.0),
		"kind": "threshold",
		"stat_key": "cleared_characters",
		"threshold": 3,
	},
	"combo_discoverer": {
		"title": "Alchemist's Eye",
		"description": "Discover 10 mod combos.",
		"secret": false,
		"icon": "⚛",
		"color": Color(0.6, 0.4, 1.0),
		"kind": "threshold",
		"stat_key": "combos_discovered",
		"threshold": 10,
	},
	"gold_hoarder": {
		"title": "Gilded",
		"description": "Bank 5000 to your Vault across all runs.",
		"secret": false,
		"icon": "◉",
		"color": Color(1.0, 0.92, 0.4),
		"kind": "threshold",
		"stat_key": "total_gold_earned",
		"threshold": 5000,
	},
	"untouchable": {
		"title": "Untouchable",
		"description": "Extract from depth phase 2 or deeper without taking a single hit.",
		"secret": true,
		"icon": "✦",
		"color": Color(0.8, 0.8, 0.9),
		"kind": "event",
	},
}

## Display order for the Records panel.
const ORDER: Array = [
	"first_extraction",
	"first_boss_kill",
	"extractions_5",
	"extractions_25",
	"kills_500",
	"kills_5000",
	"combo_discoverer",
	"gold_hoarder",
	"untouchable",
	"roster_complete",
	"cleared_with_3",
	"game_cleared",
]
