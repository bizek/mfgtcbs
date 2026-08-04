class_name ModData

## ModData — Static database of all GENERIC weapon mod definitions.
## Mods are extractable loot that permanently modify weapon behavior when equipped.
## Access anywhere as ModData.ALL or ModData.ORDER.
##
## ── Two-layer mod model (task 31, docs/class_mod_system.md) ──────────────────────
## This file is the GENERIC layer. The CLASS layer lives in ClassModData (data/class_mods.gd).
## Every mod here carries a `requires` array of KIT CAPABILITY TAGS. ModApplicability
## (data/mod_applicability.gd) matches these against the capabilities a character's kit emits,
## so loot / merchant / armory only ever surface mods that DO something for the current class:
##   • requires: []               → universal (player-stat / global behavior; every kit benefits)
##   • requires: ["projectile"]   → only meaningful for kits that fire projectiles in their combo
## A mod is applicable to a kit when `requires` is empty OR it shares a tag with the kit's caps.
## When adding a mod, set `requires` here — the resolver reads it directly (no second table).

const ALL: Dictionary = {
	"pierce": {
		"id": "pierce",
		"name": "PIERCE",
		"desc": "Projectiles pass through up to 3 enemies.",
		"color": Color(0.55, 0.95, 1.0),
		"effect_type": "pierce",
		"requires": ["projectile"],
		"params": { "pierce_count": 3 },
	},
	"chain": {
		"id": "chain",
		"name": "CHAIN",
		"desc": "Hits bounce to 1 nearby enemy within 120px for 60% damage.",
		"color": Color(0.35, 0.75, 1.0),
		"effect_type": "chain",
		"requires": ["projectile"],
		"params": { "chain_range": 120.0, "chain_damage_mult": 0.6 },
	},
	"explosive": {
		"id": "explosive",
		"name": "EXPLOSIVE",
		"desc": "Hits cause an AOE explosion at impact point (30% damage, 40px radius).",
		"color": Color(1.0, 0.50, 0.10),
		"effect_type": "explosive",
		"requires": ["projectile"],
		"params": { "radius": 40.0, "damage_mult": 0.3 },
	},
	"fire": {
		"id": "fire",
		"name": "ELEMENTAL: FIRE",
		"desc": "Converts damage to Fire. Hits apply Burning: 3 dmg/sec for 3 seconds.",
		"color": Color(1.0, 0.28, 0.0),
		"effect_type": "elemental",
		"requires": ["projectile"],
		"params": { "element": "fire", "dot_damage": 3.0, "dot_duration": 3.0 },
	},
	"cryo": {
		"id": "cryo",
		"name": "ELEMENTAL: CRYO",
		"desc": "Converts damage to Cryo. Hits apply Chilled (30% slow, 3s). 3 stacks = Frozen (1.5s stun).",
		"color": Color(0.30, 0.70, 1.0),
		"effect_type": "elemental",
		"requires": ["projectile"],
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
		"requires": ["projectile"],
		"params": { "element": "shock", "chain_damage_pct": 0.5, "chain_range": 100.0 },
	},
	"lifesteal": {
		"id": "lifesteal",
		"name": "LIFESTEAL",
		"desc": "5% of damage dealt returns as HP.",
		"color": Color(0.85, 0.20, 0.50),
		"effect_type": "lifesteal",
		"requires": [],   ## universal — leech modifier on the player, applies to all outgoing damage
		"params": { "steal_pct": 0.05 },
	},
	"size": {
		"id": "size",
		"name": "SIZE INCREASE",
		"desc": "Projectiles and hitboxes are 50% larger.",
		"color": Color(0.72, 0.40, 0.95),
		"effect_type": "size",
		"requires": ["projectile"],
		"params": { "size_mult": 1.5 },
	},
	"crit_amp": {
		"id": "crit_amp",
		"name": "CRIT AMPLIFIER",
		"desc": "+15% crit chance and +0.3x crit damage for this weapon.",
		"color": Color(1.0, 0.80, 0.10),
		"effect_type": "crit",
		"requires": [],   ## universal — crit modifiers on the player, every hit can crit
		"params": { "crit_chance_bonus": 0.15, "crit_mult_bonus": 0.3 },
	},
	"instability_siphon": {
		"id": "instability_siphon",
		"name": "INSTABILITY SIPHON",
		"desc": "Kills reduce Instability by 1. Manage haul risk through aggression.",
		"color": Color(0.40, 1.0, 0.55),
		"effect_type": "instability_siphon",
		"requires": [],   ## universal — kill-triggered global behavior, kit-agnostic
		"params": {},
	},
	"split": {
		"id": "split",
		"name": "SPLIT",
		"desc": "Projectiles split into 3 smaller shots on hit or expiry.",
		"color": Color(0.90, 0.55, 0.95),
		"effect_type": "split",
		"requires": ["projectile"],
		"params": { "split_count": 3, "split_damage_mult": 0.4 },
	},
	"gravity": {
		"id": "gravity",
		"name": "GRAVITY",
		"desc": "Projectiles curve toward the nearest enemy.",
		"color": Color(0.50, 0.20, 0.80),
		"effect_type": "gravity",
		"requires": ["projectile"],
		"params": { "pull_strength": 300.0, "seek_range": 150.0 },
	},
	"ricochet": {
		"id": "ricochet",
		"name": "RICOCHET",
		"desc": "Projectiles bounce off arena walls up to 3 times.",
		"color": Color(0.75, 0.85, 0.95),
		"effect_type": "ricochet",
		"requires": ["projectile"],
		"params": { "max_bounces": 3 },
	},
	"accelerating": {
		"id": "accelerating",
		"name": "ACCELERATING",
		"desc": "Attack speed ramps up by 50% over 3 seconds of sustained fire.",
		"color": Color(0.95, 0.65, 0.15),
		"effect_type": "accelerating",
		"requires": ["projectile"],
		"params": { "max_bonus": 0.5, "ramp_time": 3.0 },
	},
	"dot_applicator": {
		"id": "dot_applicator",
		"name": "DOT APPLICATOR",
		"desc": "All hits apply Bleed: 2 dmg/sec for 4 seconds. Stacks duration.",
		"color": Color(0.85, 0.15, 0.15),
		"effect_type": "dot_applicator",
		"requires": ["projectile"],
		"params": { "dot_damage": 2.0, "dot_duration": 4.0 },
	},
	"multishot": {
		"id": "multishot",
		"name": "MULTISHOT",
		"desc": "Fire at 2 targets simultaneously. Beams: split into 2 parallel beams.",
		"color": Color(1.0, 0.78, 0.20),
		"effect_type": "multishot",
		"requires": ["projectile"],
		"params": { "count_bonus": 1 },
	},
	"napalm": {
		"id": "napalm",
		"name": "NAPALM",
		"desc": "Ember Beam scorches the ground along its path. Patches deal 5 fire dmg/sec for 10s.",
		"color": Color(1.0, 0.40, 0.0),
		"effect_type": "napalm",
		"requires": ["projectile"],
		"params": { "patch_damage": 5.0, "patch_duration": 10.0, "patch_radius": 30.0, "patch_count": 5 },
	},
	## ── Boss-exclusive uniques ──────────────────────────────────────────────
	## NOT listed in ORDER → never appears in the random drop spray, debug
	## "give all", or codex. Only the Heart of the Deep drops it. Still fully
	## equippable: the armory lists mods from owned_mods and looks up ModData.ALL.
	"abyssal_pull": {
		"id": "abyssal_pull",
		"name": "THE DEEP'S PULL",
		"desc": "Heart of the Deep relic. Projectiles curve into enemies and pierce all, dragging a void wake that slows everything they pass through.",
		"color": Color(0.45, 0.20, 0.75),
		"effect_type": "deep_pull",
		"requires": ["projectile"],
		"exclusive": true,
		"params": {},
	},
}

## Stable display order for armory / debug panels
const ORDER: Array = [
	"pierce", "chain", "explosive",
	"fire", "cryo", "shock",
	"lifesteal", "size", "crit_amp", "instability_siphon", "split", "gravity", "ricochet",
	"accelerating", "dot_applicator", "multishot", "napalm",
]
