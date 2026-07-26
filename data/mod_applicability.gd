class_name ModApplicability

## ModApplicability — the ONE shared resolver for the two-layer mod model (task 31).
## docs/class_mod_system.md is the design doc.
##
## Answers a single question everywhere it's asked (loot rolls, merchant, armory, and — task 33 —
## the level-up pool): "does this mod DO anything for the character the player is currently running?"
##
##   GENERIC mods (ModData.ALL) carry a `requires` array of KIT CAPABILITY TAGS.
##   CLASS mods  (ClassModData.ALL) are bound to one `kit` and only apply to that kit.
##
## KIT_CAPABILITIES declares what each combo kit EMITS — authored by reading every kit in
## ChainFactory / SkillFactory (not invented). A generic mod is applicable when its `requires`
## is empty (universal) OR shares at least one tag with the kit's capabilities.
##
## Capability vocabulary (v1):
##   "melee_hit"  — the kit lands melee / player-centered AoE hits (every combo kit has this)
##   "projectile" — the kit fires projectiles as part of its combo (arrows, bolts, shards, bombs…)
## Universal player-stat / global mods (crit, lifesteal, instability siphon) declare requires: []
## and so surface for everyone. Everything else is gated to "projectile" today, because combo
## characters DROP weapon auto-fire (player.set_combo_ability) — the projectile/on-hit generic
## mods only bite when the kit actually launches projectiles. Melee kits get their build depth
## from the CLASS layer instead; routing generic elemental/status mods into melee combo hits is
## noted as future space in the design doc.


## What each kit emits. Keyed by CharacterData "melee_kit" id. "melee_hit" is implicit for every
## kit (all combos land AoE hits) but listed explicitly so the table reads as a full declaration.
const KIT_CAPABILITIES: Dictionary = {
	"fighter":    ["melee_hit"],
	"paladin":    ["melee_hit"],
	"ninja":      ["melee_hit"],
	"cleric":     ["melee_hit"],
	"druid":      ["melee_hit"],
	"necromancer": ["melee_hit", "projectile"],  ## staff-cast jabs + bone missiles
	"ranger":     ["melee_hit", "projectile"],   ## arrow volleys + throwing knife
	"wizard":     ["melee_hit", "projectile"],   ## bolts + charged fireball
	"blood_mage": ["melee_hit", "projectile"],   ## blood shard volleys
	"demonologist": ["melee_hit"],               ## the Demonologist pack ships NO projectile sheets —
												 ## Hellfire's motes are baked into the body anim, so
												 ## every hit this kit lands is a player-centred AoE
	"barbarian":  ["melee_hit", "projectile"],   ## thunder blade bolt
	"gunslinger": ["melee_hit", "projectile"],   ## gunfire volleys
}


## Resolve a character id → its kit's capability tags.
static func capabilities_for_character(char_id: String) -> Array:
	var kit_id: String = CharacterData.ALL.get(char_id, {}).get("melee_kit", "")
	return KIT_CAPABILITIES.get(kit_id, ["melee_hit"])


## Resolve a character id → its kit id ("" if none).
static func kit_of(char_id: String) -> String:
	return CharacterData.ALL.get(char_id, {}).get("melee_kit", "")


## Unified lookup across BOTH registries. Returns {} if the id is unknown.
## Used by pickups / armory / insurance so they don't need to know which layer a mod came from.
static func get_mod(mod_id: String) -> Dictionary:
	if ModData.ALL.has(mod_id):
		return ModData.ALL[mod_id]
	if ClassModData.ALL.has(mod_id):
		return ClassModData.ALL[mod_id]
	return {}


static func is_class_mod(mod_id: String) -> bool:
	return ClassModData.ALL.has(mod_id)


static func is_generic_mod(mod_id: String) -> bool:
	return ModData.ALL.has(mod_id)


## True if the generic mod does something for the given character's kit.
static func generic_applies(mod_id: String, char_id: String) -> bool:
	var mod: Dictionary = ModData.ALL.get(mod_id, {})
	if mod.is_empty():
		return false
	var requires: Array = mod.get("requires", [])
	if requires.is_empty():
		return true   ## universal
	var caps: Array = capabilities_for_character(char_id)
	for tag: String in requires:
		if tag in caps:
			return true
	return false


## True if the class mod is bound to the given character's kit.
static func class_applies(mod_id: String, char_id: String) -> bool:
	var mod: Dictionary = ClassModData.ALL.get(mod_id, {})
	if mod.is_empty():
		return false
	return mod.get("kit", "") == kit_of(char_id)


## Unified applicability — works for either layer. Unknown ids are not applicable.
static func applies(mod_id: String, char_id: String) -> bool:
	if ModData.ALL.has(mod_id):
		return generic_applies(mod_id, char_id)
	if ClassModData.ALL.has(mod_id):
		return class_applies(mod_id, char_id)
	return false


## Generic mods (in ModData.ORDER — excludes boss uniques) applicable to this character.
static func applicable_generic_ids(char_id: String) -> Array:
	var out: Array = []
	for mod_id: String in ModData.ORDER:
		if generic_applies(mod_id, char_id):
			out.append(mod_id)
	return out


## Class mods bound to this character's kit (in ClassModData ORDER).
static func class_mod_ids_for(char_id: String) -> Array:
	var kit_id: String = kit_of(char_id)
	if kit_id.is_empty():
		return []
	return ClassModData.ids_for_kit(kit_id)


## The full droppable pool for the CURRENT character: applicable generics + this class's mods.
## Loot rolls draw from this so an unusable mod can never drop mid-run.
static func droppable_pool(char_id: String) -> Array:
	var pool: Array = applicable_generic_ids(char_id)
	pool.append_array(class_mod_ids_for(char_id))
	return pool
