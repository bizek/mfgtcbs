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

## Evolution recipes. `requires` names GENERIC POOL ids; listing one TWICE means "take that line
## to rank 2", because _get_available_evolution counts owned copies.
##
## Five of these named ids that stopped existing on 2026-08-08, when the sixteen one-off stat
## sticks collapsed into seven rankable lines (glass_cannon/juggernaut/velocity/assassin wanted
## damage_up, crit_chance_up, max_hp_up, armor_up, move_speed_up, attack_speed_up, crit_damage_up;
## phase_runner wanted fleetfoot). Rewritten onto the surviving lines. The rank requirement is also
## a better gate than the original: Glass Cannon used to unlock the moment you took one damage pick
## and one crit pick, which was usually by level 3.
##
## validate_status_ids() checks every `requires` against the live pool, so the next rename reports
## itself instead of quietly making a capstone unbuildable.
##
## ── The 2026-08-22 renumber ───────────────────────────────────────────────────
## That same 2026-08-08 collapse left the five STAT recipes paying out against a baseline that no
## longer existed, and nothing noticed because the ids all still resolved. `_apply_evolution`
## STRIPS the prerequisites and reverses their stats before applying its own effects, so a recipe
## has to out-pay its whole ingredient list just to break even. It did not:
##
##   JUGGERNAUT    Vitality x2 = +40 HP / +6 Armor  →  granted +40 HP / +5 Armor. Strictly worse.
##   GLASS CANNON  dropped the +20% Atk Spd and +25% Crit Dmg the ingredients had paid for.
##   VELOCITY      dropped +15% Damage and +30% Pickup Radius.
##   ASSASSIN      net +15% Move Speed — three picks for less than one Swiftness rank.
##   PHASE RUNNER  net +30% Dash Dist against -30% Pickup Radius. A wash.
##
## Every recipe below now covers each stat its ingredients provide and beats it. Stats the
## ingredients do NOT provide are free for the designer — that is where Glass Cannon's -20 HP
## lives, and the validator deliberately allows it.
##
## validate_evolution_math() enforces exactly that rule at startup, because this is drift, not a
## typo: the recipes were correct when written and were invalidated from a different file.
var EVOLUTION_RECIPES: Array[Dictionary] = [
	## Pruned per D2: removed fortress (duplicate recipe of juggernaut), bullet_storm, titan_rounds,
	## magnetar (all three required projectile-gated ingredients and were dead picks for melee kits),
	## and overdrive (overlaps with the adrenaline_rush generic upgrade). Remaining 7 are distinctive
	## and their ingredients are all universal (no projectile-gating).
	{
		"id": "glass_cannon",
		"name": "GLASS CANNON",
		"description": "+55% Dmg, +25% Atk Spd, +10% Crit, +50% Crit Dmg, -20 HP",
		"requires": ["might", "might", "precision"],
		"is_evolution": true,
		"effects": [
			{"stat": "damage", "type": "percent", "value": 0.55},
			{"stat": "attack_speed", "type": "percent", "value": 0.25},
			{"stat": "crit_chance", "type": "flat", "value": 0.10},
			{"stat": "crit_multiplier", "type": "flat", "value": 0.50},
			{"stat": "max_hp", "type": "flat", "value": -20.0},
		],
	},
	{
		"id": "juggernaut",
		"name": "JUGGERNAUT",
		"description": "+80 Max HP, +12 Armor",
		"requires": ["vitality", "vitality"],
		"is_evolution": true,
		"effects": [
			{"stat": "max_hp", "type": "flat", "value": 80.0},
			{"stat": "armor", "type": "flat", "value": 12.0},
		],
	},
	{
		"id": "velocity",
		"name": "VELOCITY",
		"description": "+35% Move Spd, +35% Atk Spd, +15% Dmg, +30% Pickup",
		"requires": ["swiftness", "might"],
		"is_evolution": true,
		"effects": [
			{"stat": "move_speed", "type": "percent", "value": 0.35},
			{"stat": "attack_speed", "type": "percent", "value": 0.35},
			{"stat": "damage", "type": "percent", "value": 0.15},
			{"stat": "pickup_radius", "type": "percent", "value": 0.30},
		],
	},
	{
		"id": "assassin",
		"name": "ASSASSIN",
		"description": "+20% Crit Chance, +100% Crit Dmg, +15% Move Spd",
		"requires": ["precision", "precision"],
		"is_evolution": true,
		"effects": [
			{"stat": "crit_chance", "type": "flat", "value": 0.20},
			{"stat": "crit_multiplier", "type": "flat", "value": 1.00},
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
		"description": "+2 Dash Charges, +50% Dash Dist, +30% Spd, +30% Pickup",
		"requires": ["swiftness", "dash_charge_up"],
		"is_evolution": true,
		"effects": [
			{"stat": "dash_charges", "type": "flat", "value": 2.0},
			{"stat": "dash_speed", "type": "percent", "value": 0.50},
			{"stat": "move_speed", "type": "percent", "value": 0.30},
			{"stat": "pickup_radius", "type": "percent", "value": 0.30},
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
		## ── The stat picks. SEVEN rankable entries, collapsed from sixteen one-offs 2026-08-08.
		##
		## The old sixteen were the plan's §2.1 problem: "+20% Damage" next to "+15% Attack Speed"
		## next to "+5% Crit Chance" is not three decisions, it is one decision presented three
		## times, and it crowded the textured picks (the status procs below) out of the menu. Worse,
		## they ran out — sixteen one-time entries meant a long run eventually offered nothing but
		## leftovers nobody wanted.
		##
		## Each of these is now REPEATABLE (see max_rank / _generic_rank), so the menu never runs
		## dry and taking the same line twice is a real build choice rather than a dead end. Roles
		## are carried over unchanged from the 2026-08-03 pass — the reservation and weighting logic
		## above depends on the crowd/space/survive/power spread, so the collapse deliberately kept
		## two power, one survive, two space and two crowd.
		##
		## `merges` records which retired ids each one absorbed. It is not read by anything; it is
		## here because the evolution recipes below name these lines and the mapping is the only way
		## to check a recipe still means what it used to.
		{"id": "might",     "name": "Might",     "description": "+15% Damage, +10% Attack Speed", "role": ROLE_POWER,
			"max_rank": 5, "effects": [
				{"stat": "damage",          "type": "percent", "value": 0.15},
				{"stat": "attack_speed",    "type": "percent", "value": 0.10}],
			"merges": ["damage_up", "attack_speed_up"]},
		{"id": "precision", "name": "Precision", "description": "+5% Crit Chance, +25% Crit Damage", "role": ROLE_POWER,
			"max_rank": 5, "effects": [
				{"stat": "crit_chance",     "type": "flat",    "value": 0.05},
				{"stat": "crit_multiplier", "type": "flat",    "value": 0.25}],
			"merges": ["crit_chance_up", "crit_damage_up"]},
		{"id": "vitality",  "name": "Vitality",  "description": "+20 Max HP, +3 Armor", "role": ROLE_SURVIVE,
			"max_rank": 5, "effects": [
				{"stat": "max_hp",          "type": "flat",    "value": 20.0},
				{"stat": "armor",           "type": "flat",    "value": 3.0}],
			"merges": ["max_hp_up", "armor_up"]},
		{"id": "swiftness", "name": "Swiftness", "description": "+15% Move Speed, +30% Pickup Radius", "role": ROLE_SPACE,
			"max_rank": 5, "effects": [
				{"stat": "move_speed",      "type": "percent", "value": 0.15},
				{"stat": "pickup_radius",   "type": "percent", "value": 0.30}],
			"merges": ["move_speed_up", "fleetfoot", "pickup_radius_up"]},
		{"id": "momentum",  "name": "Momentum",  "description": "+20% Dash Distance, -15% Dash Cooldown", "role": ROLE_SPACE,
			"max_rank": 4, "effects": [
				{"stat": "dash_speed",      "type": "percent", "value": 0.20},
				{"stat": "dash_cooldown",   "type": "percent", "value": -0.15}],
			"merges": ["dash_distance_up", "dash_cooldown_down"]},
		## Reach is CROWD, not space: melee_range multiplies the combo's AoE hit radius (player.gd),
		## so it widens the circle. Universal — every kit lands melee hits.
		{"id": "reach",     "name": "Reach",     "description": "+25% Melee Range", "role": ROLE_CROWD,
			"max_rank": 4, "effects": [
				{"stat": "melee_range",     "type": "percent", "value": 0.25}],
			"merges": ["reach_up"]},
		## Projectile-only — filtered out for kits without the "projectile" capability tag.
		{"id": "volley",    "name": "Volley",    "description": "+1 Projectile, +1 Pierce, +25% Projectile Size",
			"role": ROLE_CROWD, "requires_cap": "projectile",
			"max_rank": 4, "effects": [
				{"stat": "projectile_count","type": "flat",    "value": 1.0},
				{"stat": "pierce",          "type": "flat",    "value": 1.0},
				{"stat": "projectile_size", "type": "percent", "value": 0.25}],
			"merges": ["projectile_count_up", "pierce_up", "projectile_size_up"]},
		## Combo window — the BAR bottom-centre, i.e. how long you have to press again before the
		## chain drops. Universal by nature: every kit chains, and ChoreographyRunner applies the
		## combo_window stat to every "wait" phase, so this one line widens all of them.
		##
		## ROLE_POWER because what it actually buys is uptime on your own offence. It is not a
		## crowd answer and it does not buy distance — a wider window does nothing about a ring.
		{"id": "flow",      "name": "Flow",      "description": "+25% Combo Window", "role": ROLE_POWER,
			"max_rank": 4, "effects": [
				{"stat": "combo_window",    "type": "percent", "value": 0.25}]},
		## Dash charges stayed its own pick: +1 charge is a discrete capability change, not a
		## number going up, and folding it into Momentum would have made that line wildly uneven
		## between rank 1 and rank 2.
		{"id": "dash_charge_up",     "name": "Extra Dash Charge","description": "+1 Dash Charge",      "role": ROLE_SPACE,   "stat": "dash_charges",   "type": "flat",    "value": 1.0, "max_rank": 2},
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

	## Generic pool: filter out one-time status upgrades already owned, stat lines whose ranks are
	## spent, and projectile-only entries for kits that emit no projectiles.
	##
	## Ranks on the stat lines are new (2026-08-08) and are why the sixteen one-off sticks could
	## collapse to seven: a line stays on the menu until its `max_rank` is reached, so the pool
	## never runs dry the way sixteen single-take entries did. `_apply_evolution` strips its
	## prerequisites from player_upgrades, which correctly frees those ranks up again.
	var generic_pool: Array[Dictionary] = []
	for entry: Dictionary in upgrade_pool:
		if entry.get("type") == "status" and entry["id"] in owned_ids:
			continue
		var req_cap: String = entry.get("requires_cap", "")
		if req_cap != "" and req_cap not in char_caps:
			continue
		if entry.get("type", "") != "status":
			var g_rank: int = _generic_rank(entry["id"])
			if g_rank >= int(entry.get("max_rank", 1)):
				continue
			generic_pool.append(_with_rank_label(entry, g_rank + 1))
			continue
		generic_pool.append(entry)

	## Ability upgrade pool: this class's kit-specific upgrades with a rank still to take.
	##
	## This used to be a flat "not yet picked this run" filter, which is why every kit ran out of
	## class identity at level 4: three entries, one guaranteed slot per level-up, done. Entries now
	## carry `max_rank`, and the same upgrade can be offered again until the player holds that many.
	##
	## Stacking needed no new machinery — `apply_upgrade` already appends duplicates to
	## `ability_upgrades`, and `apply_upgrade_dicts_to_kit` applies every dict to a pristine kit on
	## each rebuild, so two copies of a `scale_aoe` multiply twice. Only this filter blocked it.
	var ability_pool: Array[Dictionary] = []
	for entry: Dictionary in AbilityUpgradeData.get_upgrades_for_kit(kit_id):
		var rank: int = _ability_rank(entry["id"])
		if rank >= AbilityUpgradeData.max_rank_of(entry):
			continue
		## Capstones: an entry can name other ability upgrades it builds on, and stays out of the
		## pool until they are owned. Neither existing evolution system could express this —
		## EVOLUTION_RECIPES below gates on GENERIC pool ids, and ClassModData.EVOLUTIONS gates on
		## equipped MODS. This is the same idea one layer over, for kit picks.
		if not _ability_requirements_met(entry):
			continue
		ability_pool.append(_with_rank_label(entry, rank + 1))

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


## Are an ability upgrade's prerequisites satisfied?
##
## Counted, not membership-tested — naming an id TWICE means "at rank 2", exactly the convention
## EVOLUTION_RECIPES uses. A plain `in` check would hand out a capstone at half its cost, which is
## the bug that convention exists to prevent.
##
## Unlike a generic evolution this does NOT consume its prerequisites: Rolling Thunder and its
## capstones all add to the same stat, so removing the base pick would undo the thing the capstone
## is meant to deepen.
func _ability_requirements_met(entry: Dictionary) -> bool:
	var reqs: Array = entry.get("requires", [])
	if reqs.is_empty():
		return true
	var need: Dictionary = {}
	for req: String in reqs:
		need[req] = int(need.get(req, 0)) + 1
	for req: String in need:
		if _ability_rank(req) < int(need[req]):
			return false
	return true


## How many copies of one ability upgrade the player already holds this run.
func _ability_rank(upgrade_id: String) -> int:
	var n: int = 0
	for u: Dictionary in ability_upgrades:
		if u.get("id", "") == upgrade_id:
			n += 1
	return n


## Same, for the generic stat lines. Evolutions live in player_upgrades too but carry their own
## ids, so they never collide with a stat line's count.
func _generic_rank(upgrade_id: String) -> int:
	var n: int = 0
	for u: Dictionary in player_upgrades:
		if u.get("id", "") == upgrade_id:
			n += 1
	return n


const RANK_NUMERALS: Array[String] = ["", "", " II", " III", " IV", " V"]

## Returns the entry ready to offer at `rank`, labelled so the card says which rank is on the
## table. Rank 1 is left completely untouched — an upgrade you have never taken should not read
## as "Extended Whirlwind I", it is just Extended Whirlwind.
##
## The copy is shallow and that is deliberate: `id`, `op`, `target` and `params` must stay
## identical to the source entry, because `_ability_rank` counts by id and ClassModFactory reads
## the op fields straight off the dict that lands in `ability_upgrades`.
func _with_rank_label(entry: Dictionary, rank: int) -> Dictionary:
	if rank <= 1:
		return entry
	var out: Dictionary = entry.duplicate()
	var numeral: String = RANK_NUMERALS[rank] if rank < RANK_NUMERALS.size() else " x%d" % rank
	out["name"] = str(entry.get("name", "")) + numeral
	out["rank"] = rank
	return out


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


## Startup check: an evolution must out-pay the prerequisites it consumes.
##
## `_apply_evolution` removes every id in `requires` and reverses its stats, so a recipe that
## grants less than its ingredients on any stat is a level-up pick that makes the player WEAKER.
## Five of the nine did on 2026-08-22 — see the note on EVOLUTION_RECIPES. Nothing about that is
## visible in play: the card reads like a reward and the numbers quietly go down.
##
## The rule is one-directional on purpose. For every (stat, operation) the INGREDIENTS provide,
## the recipe must provide at least as much. Stats the ingredients never touched are untouched by
## this check, so a deliberate downside (Glass Cannon's -20 Max HP) stays legal.
##
## Status-effect recipes are skipped — a StatusEffectDefinition is not comparable to a number, and
## those four supersede their ingredients by construction.
## Called from GameManager._validate_content in debug builds.
func validate_evolution_math() -> Array[String]:
	var problems: Array[String] = []
	var by_id: Dictionary = {}
	for entry: Dictionary in upgrade_pool:
		by_id[entry["id"]] = entry

	for recipe: Dictionary in EVOLUTION_RECIPES:
		var ingredient: Dictionary = {}
		var skip: bool = false
		for req: String in recipe["requires"]:
			var src: Dictionary = by_id.get(req, {})
			if src.is_empty():
				skip = true  ## already reported by validate_status_ids
				break
			for eff: Dictionary in _stat_effects_of(src):
				var key: String = "%s:%s" % [eff["stat"], eff["type"]]
				ingredient[key] = float(ingredient.get(key, 0.0)) + float(eff["value"])
		if skip or ingredient.is_empty():
			continue

		var granted: Dictionary = {}
		for eff: Dictionary in _stat_effects_of(recipe):
			var key: String = "%s:%s" % [eff["stat"], eff["type"]]
			granted[key] = float(granted.get(key, 0.0)) + float(eff["value"])

		for key: String in ingredient:
			var owed: float = float(ingredient[key])
			var paid: float = float(granted.get(key, 0.0))
			if paid < owed - 0.0001:
				problems.append("evolution '%s' → grants %s of %s but its ingredients already gave %s"
						% [recipe["id"], str(paid), key, str(owed)])
	return problems


## The stat-bearing effects of a pool entry or a recipe, in one shape. Pool entries carry either an
## `effects` array (the seven rankable lines) or bare stat/type/value fields (Extra Dash Charge);
## status entries carry neither and yield nothing.
func _stat_effects_of(entry: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if entry.get("type", "") == "status":
		return out
	if entry.has("effects"):
		for eff: Dictionary in entry["effects"]:
			if eff.get("type", "") == "status" or not eff.has("stat"):
				continue
			out.append(eff)
		return out
	if entry.has("stat"):
		out.append({"stat": entry["stat"], "type": entry["type"], "value": entry["value"]})
	return out


func _get_available_evolution() -> Dictionary:
	var owned_ids: Array[String] = []
	for u: Dictionary in player_upgrades:
		owned_ids.append(u["id"])

	## Requirements are counted, not just membership-tested: a recipe may name the same stat line
	## twice to mean "at rank 2" (see the note on EVOLUTION_RECIPES). A plain `in` check would have
	## let ["might", "might"] pass on a single copy, handing out the capstone at half its cost.
	var owned_counts: Dictionary = {}
	for oid: String in owned_ids:
		owned_counts[oid] = int(owned_counts.get(oid, 0)) + 1

	var eligible: Array[Dictionary] = []
	for recipe: Dictionary in EVOLUTION_RECIPES:
		if recipe["id"] in earned_evolutions:
			continue
		var need: Dictionary = {}
		for req: String in recipe["requires"]:
			need[req] = int(need.get(req, 0)) + 1
		var has_all: bool = true
		for req: String in need:
			if int(owned_counts.get(req, 0)) < int(need[req]):
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
	## "modifier" and "self_status" both apply straight to the player and never mutate a phase,
	## so feeding them to the rebuild would make ClassModFactory look for a target dict they do
	## not have.
	for up: Dictionary in ability_upgrades:
		var op: String = up.get("op", "")
		if up.get("kit", "") == kit_id and op != "modifier" and op != "self_status":
			result.append(up)
	return result


func reset() -> void:
	player_upgrades.clear()
	ability_upgrades.clear()
	earned_evolutions.clear()
