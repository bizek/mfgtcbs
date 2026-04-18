extends Node

## LootTables — Static data for drop rates, rarity weights, instability values.
## All loot/economy tuning lives here. No logic in this file — just data + lookups.


# ═══════════════════════════════════════════════════════════════════════════════
# ENEMY DROP RATES — per enemy_id, chance of each loot category per kill
# ═══════════════════════════════════════════════════════════════════════════════

const ENEMY_DROP_RATES: Dictionary = {
	"fodder":   { "resource": 0.03,  "weapon_mod": 0.0,   },
	"swarmer":  { "resource": 0.045, "weapon_mod": 0.005, },
	"brute":    { "resource": 0.20,  "weapon_mod": 0.08,  },
	"caster":   { "resource": 0.10,  "weapon_mod": 0.04,  },
	"stalker":  { "resource": 0.10,  "weapon_mod": 0.04,  },
	"carrier":  { "resource": 0.30,  "weapon_mod": 0.50,  },
	"herald":   { "resource": 0.25,  "weapon_mod": 0.25,  },
	"guardian":  { "resource": 0.30,  "weapon_mod": 0.40,  },
	"anchor":   { "resource": 0.15,  "weapon_mod": 0.08,  },
	"warped_colossus":    { "resource": 1.0,  "weapon_mod": 0.90, },
	"heart_of_the_deep":  { "resource": 1.0,  "weapon_mod": 1.00, },
}

## Fallback for unknown enemy types
const DEFAULT_DROP_RATES: Dictionary = { "resource": 0.05, "weapon_mod": 0.0 }


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE RARITY WEIGHTS — weighted random selection per phase
# ═══════════════════════════════════════════════════════════════════════════════

const PHASE_RARITY_WEIGHTS: Dictionary = {
	1: { "common": 80, "uncommon": 18, "rare": 2,  "epic": 0,  "legendary": 0  },
	2: { "common": 60, "uncommon": 30, "rare": 8,  "epic": 2,  "legendary": 0  },
	3: { "common": 40, "uncommon": 35, "rare": 18, "epic": 6,  "legendary": 1  },
	4: { "common": 20, "uncommon": 30, "rare": 30, "epic": 15, "legendary": 5  },
	5: { "common": 5,  "uncommon": 20, "rare": 35, "epic": 25, "legendary": 15 },
}


# ═══════════════════════════════════════════════════════════════════════════════
# INSTABILITY — per-item costs and tier thresholds
# ═══════════════════════════════════════════════════════════════════════════════

const RARITY_INSTABILITY: Dictionary = {
	"common": 5, "uncommon": 8, "rare": 12, "epic": 18, "legendary": 25,
}

const RESOURCE_INSTABILITY: Dictionary = {
	"small": 1, "medium": 3, "large": 5,
}

## Resource drop value ranges per phase: [min, max]
const RESOURCE_VALUES: Dictionary = {
	1: [3, 8],
	2: [6, 14],
	3: [10, 22],
	4: [16, 32],
	5: [24, 48],
}

## Resource size weights per phase — higher phases skew toward larger drops
const RESOURCE_SIZE_WEIGHTS: Dictionary = {
	1: { "small": 70, "medium": 25, "large": 5  },
	2: { "small": 50, "medium": 35, "large": 15 },
	3: { "small": 30, "medium": 40, "large": 30 },
	4: { "small": 15, "medium": 40, "large": 45 },
	5: { "small": 5,  "medium": 30, "large": 65 },
}

const INSTABILITY_TIERS: Array = [
	{ "name": "STABLE",    "threshold": 0,   "stat_bonus": 0.0,  "elite_bonus": 0.0,  "color": Color(0.3, 0.9, 0.3)  },
	{ "name": "UNSETTLED", "threshold": 31,  "stat_bonus": 0.12, "elite_bonus": 0.05, "color": Color(1.0, 0.9, 0.2)  },
	{ "name": "VOLATILE",  "threshold": 71,  "stat_bonus": 0.28, "elite_bonus": 0.12, "color": Color(1.0, 0.55, 0.1) },
	{ "name": "CRITICAL",  "threshold": 121, "stat_bonus": 0.50, "elite_bonus": 0.20, "color": Color(0.9, 0.15, 0.1) },
]


# ═══════════════════════════════════════════════════════════════════════════════
# RARITY COLORS — for pickup visuals and UI labels
# ═══════════════════════════════════════════════════════════════════════════════

const RARITY_COLORS: Dictionary = {
	"common":    Color(0.85, 0.85, 0.85),
	"uncommon":  Color(0.3, 0.9, 0.3),
	"rare":      Color(0.3, 0.5, 1.0),
	"epic":      Color(0.7, 0.3, 1.0),
	"legendary": Color(1.0, 0.8, 0.15),
}

## Keystone drop chance (elite only, independent roll)
const KEYSTONE_ELITE_CHANCE: float = 0.05


# ═══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

static func get_drop_table(enemy_id: String) -> Dictionary:
	## Returns drop rates for an enemy type. Warped variants inherit base type.
	if ENEMY_DROP_RATES.has(enemy_id):
		return ENEMY_DROP_RATES[enemy_id]
	# Strip warped_ prefix
	var base_id: String = enemy_id.replace("warped_", "")
	if ENEMY_DROP_RATES.has(base_id):
		return ENEMY_DROP_RATES[base_id]
	return DEFAULT_DROP_RATES


static func roll_rarity(phase: int) -> String:
	## Weighted random rarity selection based on current phase.
	var weights: Dictionary = PHASE_RARITY_WEIGHTS.get(clampi(phase, 1, 5), PHASE_RARITY_WEIGHTS[1])
	var total: int = 0
	for w in weights.values():
		total += w
	var roll: int = randi() % total
	var cumulative: int = 0
	for rarity in weights:
		cumulative += weights[rarity]
		if roll < cumulative:
			return rarity
	return "common"


static func roll_resource_size(phase: int) -> String:
	## Weighted random resource size based on current phase.
	var weights: Dictionary = RESOURCE_SIZE_WEIGHTS.get(clampi(phase, 1, 5), RESOURCE_SIZE_WEIGHTS[1])
	var total: int = 0
	for w in weights.values():
		total += w
	var roll: int = randi() % total
	var cumulative: int = 0
	for size in weights:
		cumulative += weights[size]
		if roll < cumulative:
			return size
	return "medium"


static func get_resource_value(phase: int) -> float:
	## Random resource drop value scaled by phase.
	var range_arr: Array = RESOURCE_VALUES.get(clampi(phase, 1, 5), RESOURCE_VALUES[1])
	return randf_range(float(range_arr[0]), float(range_arr[1]))


static func get_instability_tier(instability: float) -> Dictionary:
	## Returns the current instability tier dict for a given instability value.
	var result: Dictionary = INSTABILITY_TIERS[0]
	for tier in INSTABILITY_TIERS:
		if instability >= tier.threshold:
			result = tier
	return result
