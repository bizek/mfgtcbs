class_name ModApplicability

## ModApplicability — the ONE shared resolver for mod applicability.
## docs/class_mod_system.md is the design doc.
##
## Answers a single question everywhere it's asked (loot rolls, merchant, armory, level-up pool):
## "does this mod DO anything for the character the player is currently running?"
##
## Was a two-layer model (task 31): generic mods gated by capability TAGS, plus class mods bound to
## a kit. The generic layer retired 2026-08-08 — 13 of its 18 entries baked into a weapon
## auto-attack that no combo character fires, so they did nothing for anyone. Mods are now one
## class-locked roster per character (ClassModData, 8 per kit), and applicability is the simple
## question `mod.kit == your kit`.
##
## KIT_CAPABILITIES survives because it is still the right abstraction and is read elsewhere —
## UpgradeManager filters projectile-only level-up entries through
## `capabilities_for_character`. It declares what each combo kit EMITS, authored by reading every
## kit in ChainFactory / SkillFactory (not invented):
##   "melee_hit"  — the kit lands melee / player-centered AoE hits (every combo kit has this)
##   "projectile" — the kit fires projectiles as part of its combo (arrows, bolts, shards, bombs…)


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


## Mod definition by id, or {} if the id is unknown (e.g. a retired generic mod still sitting in
## an old save). Callers use the empty dict as the "does not exist" signal — keep that contract.
static func get_mod(mod_id: String) -> Dictionary:
	return ClassModData.ALL.get(mod_id, {})


static func is_class_mod(mod_id: String) -> bool:
	return ClassModData.ALL.has(mod_id)


## True if the mod is bound to the given character's kit.
static func class_applies(mod_id: String, char_id: String) -> bool:
	var mod: Dictionary = ClassModData.ALL.get(mod_id, {})
	if mod.is_empty():
		return false
	return mod.get("kit", "") == kit_of(char_id)


## Applicability by id. Unknown ids are not applicable.
static func applies(mod_id: String, char_id: String) -> bool:
	return class_applies(mod_id, char_id)


## Mods bound to this character's kit (in ClassModData ORDER).
static func class_mod_ids_for(char_id: String) -> Array:
	var kit_id: String = kit_of(char_id)
	if kit_id.is_empty():
		return []
	return ClassModData.ids_for_kit(kit_id)


## The droppable pool for the CURRENT character — its eight class mods. Loot, the merchant and
## the boss reward all draw from this, so an unusable mod can never drop mid-run.
static func droppable_pool(char_id: String) -> Array:
	return class_mod_ids_for(char_id)
