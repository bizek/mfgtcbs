class_name PassiveTreeData

## Static passive skill tree node data — all 59 nodes.
## Zero behavior; logic lives in ProgressionManager (economy) and player.gd (application).
##
## Node dict keys:
##   name       : display name
##   branch     : "core" | "might" | "finesse" | "arcana" | "bridge"
##   tier       : 0-4 (gate level within a branch)
##   cost       : passive points per rank (1 = normal, 2 = notable, 3 = keystone)
##   max_ranks  : how many times the node can be purchased
##   desc       : human-readable tooltip
##   effects    : Array of {stat, op, value} — absent on behavior-only nodes
##   behavior   : string id resolved by PassiveTreeFactory (prompt 27); skipped at run-start this session
##   kind       : absent = normal | "notable" | "keystone"  (UI styling)
##   bridges    : [branch_a, branch_b] — only present on bridge nodes

const NODES: Dictionary = {
	## ── CORE (11, tier 0, always available) ─────────────────────────────────────
	"c_vigor": {
		"name": "Vigor", "branch": "core", "tier": 0, "cost": 1, "max_ranks": 3,
		"desc": "+12 Max HP per rank",
		"effects": [{"stat": "max_hp", "op": "add", "value": 12.0}],
	},
	"c_power": {
		"name": "Power", "branch": "core", "tier": 0, "cost": 1, "max_ranks": 3,
		"desc": "+5% Damage per rank",
		"effects": [{"stat": "All", "op": "bonus", "value": 0.05}],
	},
	"c_haste": {
		"name": "Haste", "branch": "core", "tier": 0, "cost": 1, "max_ranks": 3,
		"desc": "+4% Attack Speed per rank",
		"effects": [{"stat": "attack_speed", "op": "bonus", "value": 0.04}],
	},
	"c_swift": {
		"name": "Swiftness", "branch": "core", "tier": 0, "cost": 1, "max_ranks": 3,
		"desc": "+3% Move Speed per rank",
		"effects": [{"stat": "move_speed", "op": "bonus", "value": 0.03}],
	},
	"c_magnet": {
		"name": "Magnetism", "branch": "core", "tier": 0, "cost": 1, "max_ranks": 2,
		"desc": "+12% Pickup Radius per rank",
		"effects": [{"stat": "pickup_radius", "op": "bonus", "value": 0.12}],
	},
	"c_fortune": {
		"name": "Fortune", "branch": "core", "tier": 0, "cost": 1, "max_ranks": 2,
		"desc": "+2% Crit Chance per rank",
		"effects": [{"stat": "crit_chance", "op": "add", "value": 0.02}],
	},
	"c_bulwark": {
		"name": "Bulwark", "branch": "core", "tier": 0, "cost": 1, "max_ranks": 2,
		"desc": "+6 Armor (Physical Resist) per rank",
		"effects": [{"stat": "Physical", "op": "resist", "value": 6.0}],
	},
	"c_resolve": {
		"name": "Resolve", "branch": "core", "tier": 0, "cost": 1, "max_ranks": 2,
		"desc": "-3% All Damage Taken per rank",
		"effects": [{"stat": "All", "op": "damage_taken", "value": -0.03}],
	},
	"c_reflex": {
		"name": "Reflex", "branch": "core", "tier": 0, "cost": 1, "max_ranks": 2,
		"desc": "-6% Dash Cooldown per rank",
		"effects": [{"stat": "dash_cooldown", "op": "bonus", "value": -0.06}],
	},
	"c_evasion": {
		"name": "Evasion", "branch": "core", "tier": 0, "cost": 1, "max_ranks": 2,
		"desc": "+1.5% Dodge Chance per rank",
		"effects": [{"stat": "dodge_chance", "op": "add", "value": 0.015}],
	},
	"c_greed": {
		"name": "Greed", "branch": "core", "tier": 0, "cost": 1, "max_ranks": 2,
		"desc": "+8% XP Gain per rank",
		"effects": [{"stat": "xp_gain", "op": "bonus", "value": 0.08}],
	},

	## ── MIGHT (15) ────────────────────────────────────────────────────────────
	"m_heavy_hands": {
		"name": "Heavy Hands", "branch": "might", "tier": 0, "cost": 1, "max_ranks": 3,
		"desc": "+6% Damage per rank",
		"effects": [{"stat": "All", "op": "bonus", "value": 0.06}],
	},
	"m_reach": {
		"name": "Reach", "branch": "might", "tier": 0, "cost": 1, "max_ranks": 3,
		"desc": "+8% Melee Range per rank",
		"effects": [{"stat": "melee_range", "op": "bonus", "value": 0.08}],
	},
	"m_thick_hide": {
		"name": "Thick Hide", "branch": "might", "tier": 1, "cost": 1, "max_ranks": 2,
		"desc": "+8 Armor per rank",
		"effects": [{"stat": "Physical", "op": "resist", "value": 8.0}],
	},
	"m_bloodied_fists": {
		"name": "Bloodied Fists", "branch": "might", "tier": 1, "cost": 1, "max_ranks": 2,
		"desc": "+15 Max HP per rank",
		"effects": [{"stat": "max_hp", "op": "add", "value": 15.0}],
	},
	"m_battle_rhythm": {
		"name": "Battle Rhythm", "branch": "might", "tier": 1, "cost": 1, "max_ranks": 2,
		"desc": "+4% Attack Speed per rank",
		"effects": [{"stat": "attack_speed", "op": "bonus", "value": 0.04}],
	},
	"m_crusher": {
		"name": "Crusher", "branch": "might", "tier": 2, "cost": 1, "max_ranks": 2,
		"desc": "+12% Crit Multiplier per rank",
		"effects": [{"stat": "crit_multiplier", "op": "bonus", "value": 0.12}],
	},
	"m_juggernaut": {
		"name": "Juggernaut", "branch": "might", "tier": 2, "cost": 1, "max_ranks": 2,
		"desc": "-4% All Damage Taken per rank",
		"effects": [{"stat": "All", "op": "damage_taken", "value": -0.04}],
	},
	"m_unstoppable": {
		"name": "Unstoppable", "branch": "might", "tier": 2, "cost": 1, "max_ranks": 2,
		"desc": "+8% Dash Speed per rank",
		"effects": [{"stat": "dash_speed", "op": "bonus", "value": 0.08}],
	},
	"m_colossus": {
		"name": "Colossus", "branch": "might", "tier": 2, "cost": 2, "max_ranks": 2,
		"kind": "notable",
		"desc": "+10% Melee Range AND +15 Max HP per rank",
		"effects": [
			{"stat": "melee_range", "op": "bonus", "value": 0.10},
			{"stat": "max_hp", "op": "add", "value": 15.0},
		],
	},
	"m_bloodletter": {
		"name": "Bloodletter", "branch": "might", "tier": 3, "cost": 2, "max_ranks": 1,
		"kind": "notable",
		"desc": "On Kill: 10% chance to heal 2 HP",
		"behavior": "bloodletter",
	},
	"m_iron_wall": {
		"name": "Iron Wall", "branch": "might", "tier": 3, "cost": 2, "max_ranks": 2,
		"kind": "notable",
		"desc": "+4% Block Chance AND +10% Block Mitigation per rank",
		"effects": [
			{"stat": "block_chance", "op": "add", "value": 0.04},
			{"stat": "block_mitigation", "op": "add", "value": 0.10},
		],
	},
	"m_warlord": {
		"name": "Warlord", "branch": "might", "tier": 3, "cost": 2, "max_ranks": 2,
		"kind": "notable",
		"desc": "+8% Damage AND +8% Crit Multiplier per rank",
		"effects": [
			{"stat": "All", "op": "bonus", "value": 0.08},
			{"stat": "crit_multiplier", "op": "bonus", "value": 0.08},
		],
	},
	"m_titan_grip": {
		"name": "Titan Grip", "branch": "might", "tier": 3, "cost": 1, "max_ranks": 2,
		"desc": "+6% Damage per rank",
		"effects": [{"stat": "All", "op": "bonus", "value": 0.06}],
	},
	"m_second_wind": {
		"name": "Second Wind", "branch": "might", "tier": 3, "cost": 2, "max_ranks": 1,
		"kind": "notable",
		"desc": "Hit below 30% HP: +25% Move Speed for 2s (8s CD)",
		"behavior": "second_wind",
	},
	"m_keystone": {
		"name": "Berserker's Cadence", "branch": "might", "tier": 4, "cost": 3, "max_ranks": 1,
		"kind": "keystone",
		"desc": "Combo finisher grants Frenzy: +25% Atk Spd, +15% Move Spd (3s)",
		"behavior": "berserkers_cadence",
	},

	## ── FINESSE (15) ──────────────────────────────────────────────────────────
	"f_deadeye": {
		"name": "Deadeye", "branch": "finesse", "tier": 0, "cost": 1, "max_ranks": 3,
		"desc": "+2% Crit Chance per rank",
		"effects": [{"stat": "crit_chance", "op": "add", "value": 0.02}],
	},
	"f_lightfoot": {
		"name": "Lightfoot", "branch": "finesse", "tier": 0, "cost": 1, "max_ranks": 3,
		"desc": "+4% Move Speed per rank",
		"effects": [{"stat": "move_speed", "op": "bonus", "value": 0.04}],
	},
	"f_sharpened": {
		"name": "Sharpened Edges", "branch": "finesse", "tier": 1, "cost": 1, "max_ranks": 2,
		"desc": "+10% Crit Multiplier per rank",
		"effects": [{"stat": "crit_multiplier", "op": "bonus", "value": 0.10}],
	},
	"f_quickdraw": {
		"name": "Quickdraw", "branch": "finesse", "tier": 1, "cost": 1, "max_ranks": 2,
		"desc": "+5% Attack Speed per rank",
		"effects": [{"stat": "attack_speed", "op": "bonus", "value": 0.05}],
	},
	"f_acrobat": {
		"name": "Acrobat", "branch": "finesse", "tier": 1, "cost": 1, "max_ranks": 2,
		"desc": "-8% Dash Cooldown per rank",
		"effects": [{"stat": "dash_cooldown", "op": "bonus", "value": -0.08}],
	},
	"f_long_stride": {
		"name": "Long Stride", "branch": "finesse", "tier": 2, "cost": 1, "max_ranks": 2,
		"desc": "+8% Dash Speed per rank",
		"effects": [{"stat": "dash_speed", "op": "bonus", "value": 0.08}],
	},
	"f_evasion": {
		"name": "Uncanny Evasion", "branch": "finesse", "tier": 2, "cost": 1, "max_ranks": 2,
		"desc": "+2% Dodge Chance per rank",
		"effects": [{"stat": "dodge_chance", "op": "add", "value": 0.02}],
	},
	"f_windrunner": {
		"name": "Windrunner", "branch": "finesse", "tier": 2, "cost": 1, "max_ranks": 2,
		"desc": "+3% Move Speed AND +4% Dash Speed per rank",
		"effects": [
			{"stat": "move_speed", "op": "bonus", "value": 0.03},
			{"stat": "dash_speed", "op": "bonus", "value": 0.04},
		],
	},
	"f_fletcher": {
		"name": "Fletcher", "branch": "finesse", "tier": 2, "cost": 2, "max_ranks": 2,
		"kind": "notable",
		"desc": "+1 Pierce per rank",
		"effects": [{"stat": "pierce", "op": "add", "value": 1.0}],
	},
	"f_hunters_eye": {
		"name": "Hunter's Eye", "branch": "finesse", "tier": 3, "cost": 2, "max_ranks": 1,
		"kind": "notable",
		"desc": "+3% Crit Chance AND +15% Crit Multiplier",
		"effects": [
			{"stat": "crit_chance", "op": "add", "value": 0.03},
			{"stat": "crit_multiplier", "op": "bonus", "value": 0.15},
		],
	},
	"f_opportunist": {
		"name": "Opportunist", "branch": "finesse", "tier": 3, "cost": 2, "max_ranks": 1,
		"kind": "notable",
		"desc": "On Dodge: +20% Damage for 2s",
		"behavior": "opportunist",
	},
	"f_precision": {
		"name": "Precision", "branch": "finesse", "tier": 3, "cost": 1, "max_ranks": 2,
		"desc": "+2% Crit Chance per rank",
		"effects": [{"stat": "crit_chance", "op": "add", "value": 0.02}],
	},
	"f_ghost": {
		"name": "Ghost", "branch": "finesse", "tier": 3, "cost": 2, "max_ranks": 1,
		"kind": "notable",
		"desc": "+1 Dash Charge",
		"effects": [{"stat": "dash_charges", "op": "add", "value": 1.0}],
	},
	"f_split_shot": {
		"name": "Split Shot", "branch": "finesse", "tier": 3, "cost": 2, "max_ranks": 1,
		"kind": "notable",
		"desc": "+1 Projectile Count",
		"effects": [{"stat": "projectile_count", "op": "add", "value": 1.0}],
	},
	"f_keystone": {
		"name": "Slipstream", "branch": "finesse", "tier": 4, "cost": 3, "max_ranks": 1,
		"kind": "keystone",
		"desc": "Dashing grants Slipstream: +30% Atk Spd, +15% Damage (2.5s)",
		"behavior": "slipstream",
	},

	## ── ARCANA (15) ───────────────────────────────────────────────────────────
	"a_attunement": {
		"name": "Attunement", "branch": "arcana", "tier": 0, "cost": 1, "max_ranks": 3,
		"desc": "+5% Damage per rank",
		"effects": [{"stat": "All", "op": "bonus", "value": 0.05}],
	},
	"a_broad_bolts": {
		"name": "Broad Bolts", "branch": "arcana", "tier": 0, "cost": 1, "max_ranks": 3,
		"desc": "+10% Projectile Size per rank",
		"effects": [{"stat": "projectile_size", "op": "bonus", "value": 0.10}],
	},
	"a_focus": {
		"name": "Focus", "branch": "arcana", "tier": 1, "cost": 1, "max_ranks": 2,
		"desc": "+4% Attack Speed per rank",
		"effects": [{"stat": "attack_speed", "op": "bonus", "value": 0.04}],
	},
	"a_leyline": {
		"name": "Leyline", "branch": "arcana", "tier": 1, "cost": 1, "max_ranks": 2,
		"desc": "+10% Pickup Radius per rank",
		"effects": [{"stat": "pickup_radius", "op": "bonus", "value": 0.10}],
	},
	"a_scholar": {
		"name": "Scholar", "branch": "arcana", "tier": 1, "cost": 1, "max_ranks": 2,
		"desc": "+10% XP Gain per rank",
		"effects": [{"stat": "xp_gain", "op": "bonus", "value": 0.10}],
	},
	"a_wards": {
		"name": "Elemental Wards", "branch": "arcana", "tier": 2, "cost": 1, "max_ranks": 2,
		"desc": "+8 Fire, Cold, Lightning Resist per rank",
		"effects": [
			{"stat": "Fire", "op": "resist", "value": 8.0},
			{"stat": "Cold", "op": "resist", "value": 8.0},
			{"stat": "Lightning", "op": "resist", "value": 8.0},
		],
	},
	"a_barrier": {
		"name": "Barrier", "branch": "arcana", "tier": 2, "cost": 1, "max_ranks": 2,
		"desc": "+3% Block Chance per rank",
		"effects": [{"stat": "block_chance", "op": "add", "value": 0.03}],
	},
	"a_conduit": {
		"name": "Conduit", "branch": "arcana", "tier": 2, "cost": 1, "max_ranks": 2,
		"desc": "+4% Attack Speed AND +4% Damage per rank",
		"effects": [
			{"stat": "attack_speed", "op": "bonus", "value": 0.04},
			{"stat": "All", "op": "bonus", "value": 0.04},
		],
	},
	"a_elementalist": {
		"name": "Elementalist", "branch": "arcana", "tier": 2, "cost": 2, "max_ranks": 2,
		"kind": "notable",
		"desc": "+6% Damage AND +8% Projectile Size per rank",
		"effects": [
			{"stat": "All", "op": "bonus", "value": 0.06},
			{"stat": "projectile_size", "op": "bonus", "value": 0.08},
		],
	},
	"a_siphon": {
		"name": "Siphon", "branch": "arcana", "tier": 3, "cost": 2, "max_ranks": 2,
		"kind": "notable",
		"desc": "+1.5% Lifesteal per rank",
		"effects": [{"stat": "leech", "op": "bonus", "value": 0.015}],
	},
	"a_ignition": {
		"name": "Ignition", "branch": "arcana", "tier": 3, "cost": 2, "max_ranks": 1,
		"kind": "notable",
		"desc": "On Crit: apply Burn to the target",
		"behavior": "ignition",
	},
	"a_sage": {
		"name": "Sage", "branch": "arcana", "tier": 3, "cost": 1, "max_ranks": 2,
		"desc": "+8% XP Gain AND +8% Pickup Radius per rank",
		"effects": [
			{"stat": "xp_gain", "op": "bonus", "value": 0.08},
			{"stat": "pickup_radius", "op": "bonus", "value": 0.08},
		],
	},
	"a_catalyst": {
		"name": "Catalyst", "branch": "arcana", "tier": 3, "cost": 2, "max_ranks": 1,
		"kind": "notable",
		"desc": "Statuses you apply last +20% longer",
		"effects": [{"stat": "status_duration", "op": "bonus", "value": 0.20}],
	},
	"a_runeward": {
		"name": "Runeward", "branch": "arcana", "tier": 3, "cost": 1, "max_ranks": 2,
		"desc": "-3% All Damage Taken per rank",
		"effects": [{"stat": "All", "op": "damage_taken", "value": -0.03}],
	},
	"a_keystone": {
		"name": "Volatile Souls", "branch": "arcana", "tier": 4, "cost": 3, "max_ranks": 1,
		"kind": "keystone",
		"desc": "Killing afflicted enemies: 25% chance to explode (~40% weapon dmg AoE)",
		"behavior": "volatile_souls",
	},

	## ── BRIDGES (3) ───────────────────────────────────────────────────────────
	"b_warpath": {
		"name": "Warpath", "branch": "bridge", "tier": 0, "cost": 1, "max_ranks": 2,
		"bridges": ["might", "finesse"],
		"desc": "+3% Move Speed AND +3% Damage per rank",
		"effects": [
			{"stat": "move_speed", "op": "bonus", "value": 0.03},
			{"stat": "All", "op": "bonus", "value": 0.03},
		],
	},
	"b_spellblade": {
		"name": "Spellblade", "branch": "bridge", "tier": 0, "cost": 1, "max_ranks": 2,
		"bridges": ["might", "arcana"],
		"desc": "+4% Melee Range AND +4% Projectile Size per rank",
		"effects": [
			{"stat": "melee_range", "op": "bonus", "value": 0.04},
			{"stat": "projectile_size", "op": "bonus", "value": 0.04},
		],
	},
	"b_trickster": {
		"name": "Trickster", "branch": "bridge", "tier": 0, "cost": 1, "max_ranks": 2,
		"bridges": ["finesse", "arcana"],
		"desc": "+2% Crit Chance AND +4% Attack Speed per rank",
		"effects": [
			{"stat": "crit_chance", "op": "add", "value": 0.02},
			{"stat": "attack_speed", "op": "bonus", "value": 0.04},
		],
	},
}


static func nodes_in_branch(branch: String) -> Array:
	var result: Array = []
	for node_id: String in NODES:
		if NODES[node_id].get("branch") == branch:
			result.append(node_id)
	return result
