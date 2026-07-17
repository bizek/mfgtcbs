## TrinketData — universal (class-agnostic) equip items (task 34 class-gear system).
## Trinkets fill the 2 universal trinket slots every character carries (+1 via the
## Workshop). They are pure stat items: `modifiers` are intrinsic stat lines applied
## on equip (player.gd), and purple trinkets add ONE `unique` (GearUniqueFactory).
## Trinkets carry NO weapon mods (mod slots live on weapons).
##
## Rarity reuses the shipped 3-of-5 tiers: green="uncommon", blue="rare", purple="epic".
## Selected by the smart-loot drop system from the universal pool (no class bias).
class_name TrinketData

const ALL: Dictionary = {

	# ─── GREEN (uncommon) ───────────────────────────────────────────────────
	"Worn Locket": {
		"id": "Worn Locket", "display_name": "Worn Locket",
		"description": "Someone's face, worn smooth. It steadies the heart.",
		"rarity": "uncommon", "tier": "green", "tint": Color(0.85, 0.85, 0.90),
		"modifiers": [ {"tag": "max_hp", "op": "add", "value": 20.0} ],
	},
	"Lucky Coin": {
		"id": "Lucky Coin", "display_name": "Lucky Coin",
		"description": "Two-headed. You've stopped questioning it.",
		"rarity": "uncommon", "tier": "green", "tint": Color(0.90, 0.82, 0.45),
		"modifiers": [ {"tag": "crit_chance", "op": "add", "value": 0.04} ],
	},
	"Traveler's Boots": {
		"id": "Traveler's Boots", "display_name": "Traveler's Boots",
		"description": "Broken in over a thousand miles of running.",
		"rarity": "uncommon", "tier": "green", "tint": Color(0.70, 0.60, 0.45),
		"modifiers": [ {"tag": "move_speed", "op": "bonus", "value": 0.08} ],
	},

	# ─── BLUE (rare) ────────────────────────────────────────────────────────
	"Vital Charm": {
		"id": "Vital Charm", "display_name": "Vital Charm",
		"description": "Warm to the touch. It wants you to keep going.",
		"rarity": "rare", "tier": "blue", "tint": Color(0.40, 0.85, 0.55),
		"modifiers": [ {"tag": "max_hp", "op": "add", "value": 35.0} ],
	},
	"Keen Sigil": {
		"id": "Keen Sigil", "display_name": "Keen Sigil",
		"description": "Etched to find the soft places.",
		"rarity": "rare", "tier": "blue", "tint": Color(0.55, 0.70, 1.0),
		"modifiers": [
			{"tag": "crit_chance", "op": "add", "value": 0.05},
			{"tag": "crit_multiplier", "op": "add", "value": 0.15},
		],
	},
	"Warding Band": {
		"id": "Warding Band", "display_name": "Warding Band",
		"description": "Old iron, older prayers. It turns a blade.",
		"rarity": "rare", "tier": "blue", "tint": Color(0.65, 0.70, 0.78),
		"modifiers": [
			{"tag": "Physical", "op": "resist", "value": 8.0},
			{"tag": "max_hp", "op": "add", "value": 15.0},
		],
	},

	# ─── PURPLE (epic) — each carries ONE unique ────────────────────────────
	"Bloodring": {
		"id": "Bloodring", "display_name": "Bloodring",
		"description": "It drinks a little of what you spill, and gives some back.",
		"rarity": "epic", "tier": "purple", "tint": Color(0.80, 0.25, 0.35),
		"modifiers": [], "unique": "t_bloodring",
	},
	"Stormcore": {
		"id": "Stormcore", "display_name": "Stormcore",
		"description": "A caged shard of storm. Your blows carry its charge.",
		"rarity": "epic", "tier": "purple", "tint": Color(0.55, 0.80, 1.0),
		"modifiers": [], "unique": "t_stormcore",
	},
	"Ember Heart": {
		"id": "Ember Heart", "display_name": "Ember Heart",
		"description": "It beats faster when the killing's good.",
		"rarity": "epic", "tier": "purple", "tint": Color(1.0, 0.50, 0.20),
		"modifiers": [], "unique": "t_emberheart",
	},
}


## All trinket ids of a given rarity ("uncommon"/"rare"/"epic").
static func ids_of_rarity(rarity: String) -> Array:
	var result: Array = []
	for id in ALL:
		if ALL[id].get("rarity", "") == rarity:
			result.append(id)
	return result

## All trinket ids (used to bank/inventory).
static func all_ids() -> Array:
	return ALL.keys()

static func get_rarity(trinket_id: String) -> String:
	return str(ALL.get(trinket_id, {}).get("rarity", ""))

static func get_tier(trinket_id: String) -> String:
	return str(ALL.get(trinket_id, {}).get("tier", ""))

static func get_modifiers(trinket_id: String) -> Array:
	return ALL.get(trinket_id, {}).get("modifiers", [])

static func get_unique(trinket_id: String) -> String:
	return str(ALL.get(trinket_id, {}).get("unique", ""))

static func is_trinket(item_id: String) -> bool:
	return ALL.has(item_id)
