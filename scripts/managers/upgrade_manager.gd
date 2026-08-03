extends Node

## UpgradeManager — Level-up choices, stat upgrades, and ability upgrades for in-run progression.
##
## Pool = filtered generic stats + the current class's ability upgrades (task 33).
## Filtering uses ModApplicability capability tags (task 31), replacing the old requires_melee flag.
## One slot per generate_choices call is reserved for an ability upgrade (if any remain unpicked).
## Evolutions replace a generic slot (never the ability upgrade slot) when their requirements land.

signal level_up_ready(choices: Array)
signal upgrade_chosen(upgrade: Dictionary)

## --- Role bias (2026-08-03) ---
## Every pool entry carries a `role`. The pool used to be sixteen stat sticks and six procs, and
## a player being overrun could level three times without ever being offered something that
## answered the actual problem. Enemies spawn on a 340px ring around the player
## (EnemySpawnManager) against a 320px screen half-width — they arrive just off-screen and
## converge from every side. A ring is not answered by +20% damage.
##
##   "crowd"   — hits many at once (AoE, pierce, auras, corpse bursts)
##   "space"   — buys distance or the mobility to leave (slows, dashes, move speed)
##   "survive" — soaks what does land (HP, armor, sustain)
##   "power"   — the raw sticks; still here, just no longer the whole menu
const ROLE_CROWD: String = "crowd"
const ROLE_SPACE: String = "space"
const ROLE_SURVIVE: String = "survive"
const ROLE_POWER: String = "power"

const ANSWER_ROLES: Array[String] = [ROLE_CROWD, ROLE_SPACE]

## A slot is RESERVED for a crowd/space answer until the player owns this many of them. The
## guarantee tapers on purpose: someone drowning at level 2 should never open the menu and find
## three stat sticks, but someone who has already built into crowd clear should get their menu
## back. Forcing an answer every level-up for the whole run measured at 83% of generic slots and
## squeezed power picks down to 7.6% — that is not "biased toward answers", that is deleting builds.
const ANSWER_GUARANTEE_UNTIL: int = 2

## Relative draw weight for unreserved slots. Deliberately MILD — the reservation above is what
## delivers the design intent, so this only needs to lean, not shove. Measured over 2000 level-ups
## with the taper spent: space 34% · power 24% · survive 22% · crowd 20%.
const ROLE_WEIGHT: Dictionary = {
	ROLE_CROWD: 1.25,
	ROLE_SPACE: 1.15,
	ROLE_SURVIVE: 1.0,
	ROLE_POWER: 1.0,
}

## Generic stat / status upgrades — run-scoped, applied to the player directly.
var player_upgrades: Array[Dictionary] = []

## Run-scoped ability upgrades picked this run. Kit-mutation entries feed _load_combo;
## modifier entries add a ModifierDefinition with source "ability_upgrade".
var ability_upgrades: Array[Dictionary] = []

var EVOLUTION_RECIPES: Array[Dictionary] = [
	## Pruned per D2: removed fortress (duplicate recipe of juggernaut), bullet_storm, titan_rounds,
	## magnetar (all three required projectile-gated ingredients and were dead picks for melee kits),
	## and overdrive (overlaps with the adrenaline_rush generic upgrade). Remaining 7 are distinctive
	## and their ingredients are all universal (no projectile-gating).
	{
		"id": "glass_cannon",
		"name": "GLASS CANNON",
		"description": "+40% Damage, +10% Crit Chance, -15 Max HP",
		"requires": ["damage_up", "crit_chance_up"],
		"is_evolution": true,
		"effects": [
			{"stat": "damage", "type": "percent", "value": 0.40},
			{"stat": "crit_chance", "type": "flat", "value": 0.10},
			{"stat": "max_hp", "type": "flat", "value": -15.0},
		],
	},
	{
		"id": "juggernaut",
		"name": "JUGGERNAUT",
		"description": "+40 Max HP, +5 Armor",
		"requires": ["max_hp_up", "armor_up"],
		"is_evolution": true,
		"effects": [
			{"stat": "max_hp", "type": "flat", "value": 40.0},
			{"stat": "armor", "type": "flat", "value": 5.0},
		],
	},
	{
		"id": "velocity",
		"name": "VELOCITY",
		"description": "+25% Move Speed, +20% Attack Speed",
		"requires": ["move_speed_up", "attack_speed_up"],
		"is_evolution": true,
		"effects": [
			{"stat": "move_speed", "type": "percent", "value": 0.25},
			{"stat": "attack_speed", "type": "percent", "value": 0.20},
		],
	},
	{
		"id": "assassin",
		"name": "ASSASSIN",
		"description": "+10% Crit Chance, +50% Crit Damage, +15% Move Speed",
		"requires": ["crit_chance_up", "crit_damage_up"],
		"is_evolution": true,
		"effects": [
			{"stat": "crit_chance", "type": "flat", "value": 0.10},
			{"stat": "crit_multiplier", "type": "flat", "value": 0.50},
			{"stat": "move_speed", "type": "percent", "value": 0.15},
		],
	},
	{
		"id": "vampiric_blade",
		"name": "VAMPIRIC BLADE",
		"description": "Hits apply Bleed + On Kill: Heal 8% Max HP",
		"requires": ["bloodthirst", "serrated_strikes"],
		"is_evolution": true,
		"effects": [
			{"type": "status", "status_id": "vampiric_blade"},
		],
	},
	{
		"id": "phase_runner",
		"name": "PHASE RUNNER",
		"description": "+1 Dash Charge, +30% Dash Dist, +15% Speed",
		"requires": ["fleetfoot", "dash_charge_up"],
		"is_evolution": true,
		"effects": [
			{"stat": "dash_charges", "type": "flat", "value": 1.0},
			{"stat": "dash_speed", "type": "percent", "value": 0.30},
			{"stat": "move_speed", "type": "percent", "value": 0.15},
		],
	},
	{
		"id": "lightning_reflexes",
		"name": "LIGHTNING REFLEXES",
		"description": "On Crit: 20 Lightning AoE + On Dodge: Heal 5%",
		"requires": ["static_discharge", "second_wind"],
		"is_evolution": true,
		"effects": [
			{"type": "status", "status_id": "lightning_reflexes"},
		],
	},
	## Top end for the crowd branch (2026-08-03). Without these the new crowd answers were the
	## only upgrades in the pool with nothing to build toward.
	{
		"id": "pyre",
		"name": "PYRE",
		"description": "Wider burning ring + bigger corpse blasts",
		"requires": ["cinder_skin", "volatile_remains"],
		"is_evolution": true,
		"effects": [
			{"type": "status", "status_id": "pyre"},
		],
	},
	{
		"id": "bulwark",
		"name": "BULWARK",
		"description": "Bigger chill nova + Surrounded: -30% dmg, +25% spd",
		"requires": ["glacial_guard", "last_stand"],
		"is_evolution": true,
		"effects": [
			{"type": "status", "status_id": "bulwark"},
		],
	},
]

var upgrade_pool: Array[Dictionary] = []
var earned_evolutions: Array[String] = []

func _ready() -> void:
	_build_upgrade_pool()

func _build_upgrade_pool() -> void:
	upgrade_pool = [
		{"id": "damage_up",          "name": "Damage Up",        "description": "+20% Damage",         "role": ROLE_POWER,   "stat": "damage",         "type": "percent", "value": 0.20},
		{"id": "attack_speed_up",    "name": "Attack Speed Up",  "description": "+15% Attack Speed",   "role": ROLE_POWER,   "stat": "attack_speed",   "type": "percent", "value": 0.15},
		{"id": "max_hp_up",          "name": "Max HP Up",        "description": "+20 Max HP",          "role": ROLE_SURVIVE, "stat": "max_hp",         "type": "flat",    "value": 20.0},
		{"id": "move_speed_up",      "name": "Speed Up",         "description": "+15% Move Speed",     "role": ROLE_SPACE,   "stat": "move_speed",     "type": "percent", "value": 0.15},
		{"id": "fleetfoot",          "name": "Fleetfoot",        "description": "+12 Move Speed",      "role": ROLE_SPACE,   "stat": "move_speed",     "type": "flat",    "value": 12.0},
		{"id": "crit_chance_up",     "name": "Critical Strike",  "description": "+5% Crit Chance",     "role": ROLE_POWER,   "stat": "crit_chance",    "type": "flat",    "value": 0.05},
		{"id": "crit_damage_up",     "name": "Critical Power",   "description": "+25% Crit Damage",    "role": ROLE_POWER,   "stat": "crit_multiplier","type": "flat",    "value": 0.25},
		{"id": "pickup_radius_up",   "name": "Magnetism",        "description": "+30% Pickup Radius",  "role": ROLE_POWER,   "stat": "pickup_radius",  "type": "percent", "value": 0.30},
		{"id": "armor_up",           "name": "Armor Up",         "description": "+3 Armor",            "role": ROLE_SURVIVE, "stat": "armor",          "type": "flat",    "value": 3.0},
		## Projectile-only — filtered out for kits without the "projectile" capability tag.
		## All three are crowd picks: more shots, shots that pass THROUGH a line, fatter shots.
		{"id": "projectile_count_up","name": "Multi Shot",       "description": "+1 Projectile",       "role": ROLE_CROWD,   "stat": "projectile_count","type": "flat",   "value": 1.0,  "requires_cap": "projectile"},
		{"id": "pierce_up",          "name": "Pierce",           "description": "+1 Pierce",           "role": ROLE_CROWD,   "stat": "pierce",         "type": "flat",    "value": 1.0,  "requires_cap": "projectile"},
		{"id": "projectile_size_up", "name": "Bigger Shots",     "description": "+25% Projectile Size","role": ROLE_CROWD,   "stat": "projectile_size","type": "percent", "value": 0.25, "requires_cap": "projectile"},
		## Universal — all kits land melee hits so Reach always applies. Reach is CROWD, not space:
		## melee_range multiplies the combo's AoE hit radius (player.gd), so it widens the circle.
		{"id": "reach_up",           "name": "Reach",            "description": "+25% Melee Range",    "role": ROLE_CROWD,   "stat": "melee_range",    "type": "percent", "value": 0.25},
		{"id": "dash_distance_up",   "name": "Dash Distance",    "description": "+20% Dash Distance",  "role": ROLE_SPACE,   "stat": "dash_speed",     "type": "percent", "value": 0.20},
		{"id": "dash_charge_up",     "name": "Extra Dash Charge","description": "+1 Dash Charge",      "role": ROLE_SPACE,   "stat": "dash_charges",   "type": "flat",    "value": 1.0},
		{"id": "dash_cooldown_down",  "name": "Quick Recovery",  "description": "-15% Dash Cooldown",  "role": ROLE_SPACE,   "stat": "dash_cooldown",  "type": "percent", "value": -0.15},
		{"id": "bloodthirst",        "name": "Bloodthirst",      "description": "On Kill: Heal 5% Max HP",        "role": ROLE_SURVIVE, "type": "status", "status_id": "bloodthirst"},
		{"id": "static_discharge",   "name": "Static Discharge", "description": "On Crit: Lightning AOE",         "role": ROLE_CROWD,   "type": "status", "status_id": "static_discharge"},
		{"id": "serrated_strikes",   "name": "Serrated Strikes", "description": "Hits apply Bleed",               "role": ROLE_POWER,   "type": "status", "status_id": "serrated_strikes"},
		{"id": "adrenaline_rush",    "name": "Adrenaline Rush",  "description": "On Kill: +25% Speed (3s)",       "role": ROLE_SPACE,   "type": "status", "status_id": "adrenaline_rush"},
		{"id": "thorns_passive",     "name": "Thorns",           "description": "Reflect 8 damage when hit",      "role": ROLE_SURVIVE, "type": "status", "status_id": "thorns_passive"},
		{"id": "second_wind",        "name": "Second Wind",      "description": "On Dodge: Heal 3% Max HP",       "role": ROLE_SURVIVE, "type": "status", "status_id": "second_wind"},
		## The crowd answers (2026-08-03). Universal on purpose — melee kits drown hardest, and
		## gating these behind "projectile" would have handed the fix to the kits least in need.
		{"id": "cinder_skin",        "name": "Cinder Skin",      "description": "Burn everything within reach",   "role": ROLE_CROWD,   "type": "status", "status_id": "cinder_skin"},
		{"id": "volatile_remains",   "name": "Volatile Remains", "description": "On Kill: the corpse detonates",  "role": ROLE_CROWD,   "type": "status", "status_id": "volatile_remains"},
		{"id": "glacial_guard",      "name": "Glacial Guard",    "description": "When hit: chill the whole ring", "role": ROLE_SPACE,   "type": "status", "status_id": "glacial_guard"},
		{"id": "last_stand",         "name": "Last Stand",       "description": "Surrounded: -20% dmg, +20% spd", "role": ROLE_SPACE,   "type": "status", "status_id": "last_stand"},
	]


func generate_choices(count: int = 3) -> Array[Dictionary]:
	var char_id: String = ProgressionManager.selected_character
	var char_caps: Array = ModApplicability.capabilities_for_character(char_id)
	var kit_id: String = ModApplicability.kit_of(char_id)

	## Build set of already-owned upgrade ids (generic + ability upgrades).
	var owned_ids: Array[String] = []
	for u: Dictionary in player_upgrades:
		owned_ids.append(u["id"])
	for u: Dictionary in ability_upgrades:
		owned_ids.append(u["id"])

	## Generic pool: filter out one-time status upgrades already owned and projectile-only
	## entries for kits that emit no projectiles (capability-tag resolver from task 31).
	var generic_pool: Array[Dictionary] = []
	for entry: Dictionary in upgrade_pool:
		if entry.get("type") == "status" and entry["id"] in owned_ids:
			continue
		var req_cap: String = entry.get("requires_cap", "")
		if req_cap != "" and req_cap not in char_caps:
			continue
		generic_pool.append(entry)

	## Ability upgrade pool: this class's kit-specific upgrades not yet picked this run.
	var ability_pool: Array[Dictionary] = []
	for entry: Dictionary in AbilityUpgradeData.get_upgrades_for_kit(kit_id):
		if entry["id"] not in owned_ids:
			ability_pool.append(entry)

	## Weighting, in slot order:
	##   1. one ability upgrade (guaranteed class flavour until the kit's list is exhausted)
	##   2. one crowd/space "answer" — the standing offer of a way out of being swarmed
	##   3. the rest, drawn weighted by role so power picks appear without dominating
	var choices: Array[Dictionary] = []
	ability_pool.shuffle()

	if not ability_pool.is_empty():
		choices.append(ability_pool[0])

	var chosen_ids: Array[String] = []
	for c: Dictionary in choices:
		chosen_ids.append(c["id"])

	## Slot 2 — reserved answer, while the taper is still in effect. Skipped when the player has
	## already built into crowd/space, when they own every such option, or when there is exactly
	## one slot left to fill (the ability upgrade took it).
	if choices.size() < count - 1 and _owned_answer_count() < ANSWER_GUARANTEE_UNTIL:
		var answer_pool: Array[Dictionary] = []
		for entry: Dictionary in generic_pool:
			if entry.get("role", ROLE_POWER) in ANSWER_ROLES:
				answer_pool.append(entry)
		if not answer_pool.is_empty():
			var pick: Dictionary = answer_pool[randi() % answer_pool.size()]
			choices.append(pick)
			chosen_ids.append(pick["id"])

	## Remaining slots — weighted draw over everything not already picked.
	_weighted_shuffle(generic_pool)
	for entry: Dictionary in generic_pool:
		if entry["id"] in chosen_ids:
			continue
		choices.append(entry)
		chosen_ids.append(entry["id"])
		if choices.size() >= count:
			break

	## Evolution: replace the last GENERIC slot (never the ability upgrade slot) if eligible.
	var available_evo: Dictionary = _get_available_evolution()
	if not available_evo.is_empty() and not choices.is_empty():
		var replace_idx: int = choices.size() - 1
		for i: int in range(choices.size() - 1, -1, -1):
			if not choices[i].get("is_ability_upgrade", false) \
					and not choices[i].get("is_evolution", false):
				replace_idx = i
				break
		choices[replace_idx] = available_evo

	return choices


## How many crowd/space upgrades the player has actually taken this run. Evolutions land in
## player_upgrades too and carry no role, so they read as ROLE_POWER and do not count — which is
## right: an evolution is a reward for a build, not the build's answer to being swarmed.
func _owned_answer_count() -> int:
	var owned: int = 0
	for u: Dictionary in player_upgrades:
		if u.get("role", ROLE_POWER) in ANSWER_ROLES:
			owned += 1
	return owned


## Shuffle in place, biased by role weight. Uses the Efraimidis–Spirakis key trick
## (key = randf() ^ (1/weight), sort descending), which yields a draw order exactly proportional
## to weight in one pass — no rejection loop, no chance of an infinite retry on a small pool.
func _weighted_shuffle(pool: Array[Dictionary]) -> void:
	var keyed: Array[Dictionary] = []
	for entry: Dictionary in pool:
		var role: String = entry.get("role", ROLE_POWER)
		var weight: float = float(ROLE_WEIGHT.get(role, 1.0))
		keyed.append({"key": pow(randf(), 1.0 / maxf(weight, 0.01)), "entry": entry})
	keyed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["key"] > b["key"])
	pool.clear()
	for item: Dictionary in keyed:
		var entry: Dictionary = item["entry"]
		pool.append(entry)


## Startup check: every status_id referenced by the pool or an evolution must resolve in
## StatusFactory. A miss is SILENT at runtime — apply_stat_upgrade gets null back from
## get_by_id and simply applies nothing, so the pick looks fine and does nothing forever.
## Called from GameManager._validate_content in debug builds.
func validate_status_ids() -> Array[String]:
	var problems: Array[String] = []
	for entry: Dictionary in upgrade_pool:
		if entry.get("type", "") != "status":
			continue
		var sid: String = entry.get("status_id", "")
		if StatusFactory.get_by_id(sid) == null:
			problems.append("upgrade '%s' → unknown status '%s'" % [entry["id"], sid])
	var pool_ids: Array[String] = []
	for entry: Dictionary in upgrade_pool:
		pool_ids.append(entry["id"])
	for recipe: Dictionary in EVOLUTION_RECIPES:
		for req: String in recipe["requires"]:
			if req not in pool_ids:
				problems.append("evolution '%s' → requires '%s', which is not in the pool"
						% [recipe["id"], req])
		for effect: Dictionary in recipe["effects"]:
			if effect.get("type", "") != "status":
				continue
			var esid: String = effect.get("status_id", "")
			if StatusFactory.get_by_id(esid) == null:
				problems.append("evolution '%s' → unknown status '%s'" % [recipe["id"], esid])
	return problems


func _get_available_evolution() -> Dictionary:
	var owned_ids: Array[String] = []
	for u: Dictionary in player_upgrades:
		owned_ids.append(u["id"])

	var eligible: Array[Dictionary] = []
	for recipe: Dictionary in EVOLUTION_RECIPES:
		if recipe["id"] in earned_evolutions:
			continue
		var has_all: bool = true
		for req: String in recipe["requires"]:
			if req not in owned_ids:
				has_all = false
				break
		if has_all:
			eligible.append(recipe)

	if eligible.is_empty():
		return {}
	return eligible[randi() % eligible.size()]


func apply_upgrade(upgrade: Dictionary, player: Node) -> void:
	if upgrade.get("is_evolution", false):
		_apply_evolution(upgrade, player)
	elif upgrade.get("is_ability_upgrade", false):
		ability_upgrades.append(upgrade)
		if player.has_method("apply_ability_upgrade"):
			player.apply_ability_upgrade(upgrade)
	else:
		player_upgrades.append(upgrade)
		if player.has_method("apply_stat_upgrade"):
			player.apply_stat_upgrade(upgrade)
	upgrade_chosen.emit(upgrade)


func _apply_evolution(evo: Dictionary, player: Node) -> void:
	## Remove prerequisite upgrades and reverse their stats.
	for req_id: String in evo["requires"]:
		for i: int in range(player_upgrades.size() - 1, -1, -1):
			if player_upgrades[i]["id"] == req_id:
				var old: Dictionary = player_upgrades[i]
				if player.has_method("remove_stat_upgrade"):
					player.remove_stat_upgrade(old)
				player_upgrades.remove_at(i)
				break

	## Apply each effect in the evolution.
	for effect: Dictionary in evo["effects"]:
		var pseudo_upgrade: Dictionary
		if effect.get("type") == "status":
			pseudo_upgrade = {"id": evo["id"], "type": "status", "status_id": effect["status_id"]}
		else:
			pseudo_upgrade = {"id": evo["id"], "stat": effect["stat"], "type": effect["type"], "value": effect["value"]}
		if player.has_method("apply_stat_upgrade"):
			player.apply_stat_upgrade(pseudo_upgrade)

	player_upgrades.append(evo)
	earned_evolutions.append(evo["id"])


## Returns kit-mutation ability upgrades for the given kit (excludes modifier ops, which are
## applied directly to the modifier component and do not need a _load_combo pass).
func get_kit_mutation_upgrades_for_kit(kit_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for up: Dictionary in ability_upgrades:
		if up.get("kit", "") == kit_id and up.get("op", "") != "modifier":
			result.append(up)
	return result


func reset() -> void:
	player_upgrades.clear()
	ability_upgrades.clear()
	earned_evolutions.clear()
