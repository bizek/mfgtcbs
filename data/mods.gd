class_name ModData

## ModData — Static database of all weapon mod definitions.
## Mods are extractable loot that permanently modify weapon behavior when equipped.
## Access anywhere as ModData.ALL or ModData.ORDER.

const ALL: Dictionary = {
	"pierce": {
		"id": "pierce",
		"name": "PIERCE",
		"desc": "Projectiles pass through up to 3 enemies.",
		"color": Color(0.55, 0.95, 1.0),
		"effect_type": "pierce",
		"params": { "pierce_count": 3 },
	},
	"chain": {
		"id": "chain",
		"name": "CHAIN",
		"desc": "Hits bounce to 1 nearby enemy within 120px for 60% damage.",
		"color": Color(0.35, 0.75, 1.0),
		"effect_type": "chain",
		"params": { "chain_range": 120.0, "chain_damage_mult": 0.6 },
	},
	"explosive": {
		"id": "explosive",
		"name": "EXPLOSIVE",
		"desc": "Hits cause an AOE explosion at impact point (30% damage, 40px radius).",
		"color": Color(1.0, 0.50, 0.10),
		"effect_type": "explosive",
		"params": { "radius": 40.0, "damage_mult": 0.3 },
	},
	"fire": {
		"id": "fire",
		"name": "ELEMENTAL: FIRE",
		"desc": "Converts damage to Fire. Hits apply Burning: 3 dmg/sec for 3 seconds.",
		"color": Color(1.0, 0.28, 0.0),
		"effect_type": "elemental",
		"params": { "element": "fire", "dot_damage": 3.0, "dot_duration": 3.0 },
	},
	"cryo": {
		"id": "cryo",
		"name": "ELEMENTAL: CRYO",
		"desc": "Converts damage to Cryo. Hits apply Chilled (30% slow, 3s). 3 stacks = Frozen (1.5s stun).",
		"color": Color(0.30, 0.70, 1.0),
		"effect_type": "elemental",
		"params": {
			"element": "cryo",
			"slow_pct": 0.3,
			"duration": 3.0,
			"freeze_stacks": 3,
			"freeze_duration": 1.5,
		},
	},
	"shock": {
		"id": "shock",
		"name": "ELEMENTAL: SHOCK",
		"desc": "Converts damage to Shock. Hits apply Shocked — next hit chains 50% damage to a nearby enemy.",
		"color": Color(1.0, 0.90, 0.10),
		"effect_type": "elemental",
		"params": { "element": "shock", "chain_damage_pct": 0.5, "chain_range": 100.0 },
	},
	"lifesteal": {
		"id": "lifesteal",
		"name": "LIFESTEAL",
		"desc": "5% of damage dealt returns as HP.",
		"color": Color(0.85, 0.20, 0.50),
		"effect_type": "lifesteal",
		"params": { "steal_pct": 0.05 },
	},
	"size": {
		"id": "size",
		"name": "SIZE INCREASE",
		"desc": "Projectiles and hitboxes are 50% larger.",
		"color": Color(0.72, 0.40, 0.95),
		"effect_type": "size",
		"params": { "size_mult": 1.5 },
	},
	"crit_amp": {
		"id": "crit_amp",
		"name": "CRIT AMPLIFIER",
		"desc": "+15% crit chance and +0.3x crit damage for this weapon.",
		"color": Color(1.0, 0.80, 0.10),
		"effect_type": "crit",
		"params": { "crit_chance_bonus": 0.15, "crit_mult_bonus": 0.3 },
	},
	"instability_siphon": {
		"id": "instability_siphon",
		"name": "INSTABILITY SIPHON",
		"desc": "Kills reduce Instability by 1. Manage loot risk through aggression.",
		"color": Color(0.40, 1.0, 0.55),
		"effect_type": "instability_siphon",
		"params": {},
	},
	"split": {
		"id": "split",
		"name": "SPLIT",
		"desc": "Projectiles split into 3 smaller shots on hit or expiry.",
		"color": Color(0.90, 0.55, 0.95),
		"effect_type": "split",
		"params": { "split_count": 3, "split_damage_mult": 0.4 },
	},
	"gravity": {
		"id": "gravity",
		"name": "GRAVITY",
		"desc": "Projectiles curve toward the nearest enemy.",
		"color": Color(0.50, 0.20, 0.80),
		"effect_type": "gravity",
		"params": { "pull_strength": 300.0, "seek_range": 150.0 },
	},
	"ricochet": {
		"id": "ricochet",
		"name": "RICOCHET",
		"desc": "Projectiles bounce off arena walls up to 3 times.",
		"color": Color(0.75, 0.85, 0.95),
		"effect_type": "ricochet",
		"params": { "max_bounces": 3 },
	},
	"accelerating": {
		"id": "accelerating",
		"name": "ACCELERATING",
		"desc": "Attack speed ramps up by 50% over 3 seconds of sustained fire.",
		"color": Color(0.95, 0.65, 0.15),
		"effect_type": "accelerating",
		"params": { "max_bonus": 0.5, "ramp_time": 3.0 },
	},
	"dot_applicator": {
		"id": "dot_applicator",
		"name": "DOT APPLICATOR",
		"desc": "All hits apply Bleed: 2 dmg/sec for 4 seconds. Stacks duration.",
		"color": Color(0.85, 0.15, 0.15),
		"effect_type": "dot_applicator",
		"params": { "dot_damage": 2.0, "dot_duration": 4.0 },
	},
}

## Stable display order for armory / debug panels
const ORDER: Array = [
	"pierce", "chain", "explosive",
	"fire", "cryo", "shock",
	"lifesteal", "size", "crit_amp", "instability_siphon", "split", "gravity", "ricochet",
	"accelerating", "dot_applicator",
]
