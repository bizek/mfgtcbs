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
	## Both of these read "melee_hit" only until 2026-08-22, which was stale rather than
	## deliberate: the Devout's light/heavy chains fire _divine_fire_bolt and the Verdant's
	## entire moveset is _thorn_bolt / _thorn_volley, both plain SpawnProjectilesEffect
	## (chain_factory.gd:1892, :1680). The tag's only consumer is UpgradeManager's Volley
	## filter, so the miss silently withheld a four-rank crowd pick that works on them today —
	## player.gd:1982 reads projectile_count for ANY kit's combo projectiles.
	"cleric":     ["melee_hit", "projectile"],   ## Divine Fire bolt
	"druid":      ["melee_hit", "projectile"],   ## thorn bolts + Bramble Volley
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


## The pool at a given rarity, walking OUTWARD to neighbouring tiers if that tier is empty.
##
## The caller passes a rarity rolled off the phase weights, which is a 5-tier vocabulary
## (common…legendary) while mods use 3 (uncommon/rare/epic). `LootTables.gear_rarity_from()`
## does that mapping — the same one class weapons use — so a phase-1 "common" roll lands on
## uncommon and a phase-5 "legendary" lands on epic without a second roll.
##
## Walking outward rather than returning empty is the important part: a drop that rolled a
## tier the kit cannot fill must still produce a mod, or the pickup silently vanishes. It
## searches nearer tiers first, so an epic roll degrades to rare before uncommon.
static func droppable_pool_of_rarity(char_id: String, rarity: String) -> Array:
	var kit_id: String = kit_of(char_id)
	if kit_id.is_empty():
		return []
	var want: String = LootTables.gear_rarity_from(rarity)
	var tiers: Array[String] = ClassModData.RARITY_TIERS
	var idx: int = tiers.find(want)
	if idx < 0:
		idx = 0
	## Distance-ordered sweep out from the rolled tier.
	for step in range(tiers.size()):
		for dir in ([0] if step == 0 else [-step, step]):
			var i: int = idx + dir
			if i < 0 or i >= tiers.size():
				continue
			var pool: Array = ClassModData.ids_for_kit_of_rarity(kit_id, tiers[i])
			if not pool.is_empty():
				return pool
	return class_mod_ids_for(char_id)
