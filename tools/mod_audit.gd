@tool
extends RefCounted

## Class-mod audit — does every mod actually CHANGE something?
##
## GameManager._validate_content already proves each entry's `target` resolves to a real phase.
## That is necessary but not sufficient: an op can resolve its phase perfectly and still mutate
## nothing. `add_projectile_status` on a phase with no SpawnProjectilesEffect appends to nobody;
## `add_projectiles` with no projectile effect increments nothing; `_status_effect` returns null
## for an unknown status id and the append is skipped. All three are silent — same shape as the
## dead anim targets, one layer deeper.
##
## Method: build the kit pristine, deep-fingerprint every AbilityDefinition by VALUE, build it
## again with exactly one mod applied, fingerprint again. Identical fingerprints mean the mod is
## inert. Value-based because `_scale_effects` duplicates statuses before mutating them, so
## object identity changes even when nothing meaningful does.
##
## Deliberately NOT given a class_name: godot-mcp serves stale results for globally-named scripts
## (see the reference memory), and this is edited and re-run repeatedly.

## Must clear the DEEPEST real chain, which is longer than it looks:
##   AbilityDefinition > choreography > phases[] > phase > effects[] > SpawnProjectilesEffect
##   > projectile > on_hit_effects[] > DealDamageEffect > base_damage
## is already 15 levels, and a status with nested tick_effects goes deeper still. At 14 this
## harness truncated every leaf scalar to "<max-depth>", so the two fingerprints compared EQUAL
## and six perfectly working mods were reported dead. Verified by hand afterwards: the ranger
## knife goes 50.40 -> 75.60 under ranger_impaling_knife, exactly its 1.5x.
##
## The cap exists only to bound a self-referencing status, so it can afford to be far above any
## real chain.
const MAX_DEPTH: int = 40


## Recursive value fingerprint of any Resource's script-declared (@export) properties. The effect
## Resources are pure data by project rule, so their exported properties ARE their behaviour.
static func fp_obj(o: Object, depth: int) -> String:
	if o == null:
		return "<null>"
	if depth > MAX_DEPTH:
		return "<max-depth>"
	var parts: Array[String] = [o.get_class()]
	for p: Dictionary in o.get_property_list():
		var usage: int = int(p.get("usage", 0))
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var nm: String = str(p.get("name", ""))
		parts.append(nm + "=" + fp_val(o.get(nm), depth + 1))
	return "{" + "|".join(parts) + "}"


static func fp_val(v: Variant, depth: int) -> String:
	if depth > MAX_DEPTH:
		return "<max-depth>"
	if v is Array:
		var arr: Array = v
		var out: Array[String] = []
		for i in arr.size():
			out.append(fp_val(arr[i], depth + 1))
		return "[" + ",".join(out) + "]"
	if v is Dictionary:
		var d: Dictionary = v
		var keys: Array = d.keys()
		keys.sort()
		var out2: Array[String] = []
		for k in keys:
			out2.append(str(k) + ":" + fp_val(d[k], depth + 1))
		return "{" + ",".join(out2) + "}"
	if v is Object:
		return fp_obj(v, depth + 1)
	return str(v)


## One pristine kit: combo graphs plus Q/E skills, merged the same way validate_anim_targets
## merges them (the game applies them in two calls, but every op walks the same dict shape).
static func build_kit(kit_id: String) -> Dictionary:
	var abilities: Dictionary = ChainFactory.build_kit(kit_id, {})
	var skills: Dictionary = SkillFactory.build_kit_skills(kit_id, {})
	for slot: String in skills:
		abilities[slot] = skills[slot]
	return abilities


static func fp_kit(abilities: Dictionary) -> String:
	var keys: Array = abilities.keys()
	keys.sort()
	var out: Array[String] = []
	for k in keys:
		out.append(str(k) + "=>" + fp_val(abilities[k], 0))
	return "\n".join(out)


## Returns { dead: [...], inert_modifier: [...], kit_flags: [...], checked: int, by_op: {} }
static func audit() -> Dictionary:
	var kit_ids: Dictionary = {}
	for src: Dictionary in [ClassModData.ALL, ClassModData.EVOLUTIONS]:
		for entry_id: String in src:
			var k: String = str((src[entry_id] as Dictionary).get("kit", ""))
			if k != "":
				kit_ids[k] = true

	var dead: Array[String] = []
	var inert_modifier: Array[String] = []
	var kit_flags: Array[String] = []
	var mod_pairs: Array[String] = []
	var checked: int = 0
	var by_op: Dictionary = {}

	for kit_id: String in kit_ids:
		var base_fp: String = fp_kit(build_kit(kit_id))

		## ── ALL: applied through the real production path (active_ids -> ClassModData.ALL) ──
		for mod_id: String in ClassModData.ALL:
			var mod: Dictionary = ClassModData.ALL[mod_id]
			if str(mod.get("kit", "")) != kit_id:
				continue
			var op: String = str(mod.get("op", ""))
			checked += 1
			by_op[op] = int(by_op.get(op, 0)) + 1

			if op == "modifier":
				var mods: Array[ModifierDefinition] = ClassModFactory.build_modifiers(kit_id, [mod_id])
				if mods.is_empty():
					inert_modifier.append("%s (%s): op 'modifier' produced NO ModifierDefinition" % [mod_id, kit_id])
				else:
					for m: ModifierDefinition in mods:
						mod_pairs.append("%s\t%s\t%s\t%s" % [mod_id, kit_id, m.target_tag, m.operation])
				continue

			if op == "kit_flag":
				## Cannot be proven here — the entity reads the equipped id directly. Reported so
				## the caller can grep for each id in the entity scripts.
				kit_flags.append("%s\t%s" % [mod_id, kit_id])
				continue

			var fresh: Dictionary = build_kit(kit_id)
			ClassModFactory.apply_to_kit(kit_id, fresh, [mod_id])
			if fp_kit(fresh) == base_fp:
				dead.append("%s (%s): op '%s' target %s resolved but changed NOTHING"
					% [mod_id, kit_id, op, str(mod.get("target", {}))])

		## ── EVOLUTIONS: applied as raw dicts so each is isolated from its own prerequisites ──
		for evo_id: String in ClassModData.EVOLUTIONS:
			var evo: Dictionary = ClassModData.EVOLUTIONS[evo_id]
			if str(evo.get("kit", "")) != kit_id:
				continue
			var eop: String = str(evo.get("op", ""))
			checked += 1
			by_op[eop] = int(by_op.get(eop, 0)) + 1

			if eop == "modifier":
				var emods: Array[ModifierDefinition] = ClassModFactory.build_modifiers(
					kit_id, evo.get("requires", []))
				var found: bool = false
				for m: ModifierDefinition in emods:
					if str(m.source_name) == "classmod_" + evo_id:
						found = true
						mod_pairs.append("%s\t%s\t%s\t%s" % [evo_id, kit_id, m.target_tag, m.operation])
				if not found:
					inert_modifier.append("%s (%s): evolution 'modifier' produced NO ModifierDefinition" % [evo_id, kit_id])
				continue
			if eop == "kit_flag":
				kit_flags.append("%s\t%s" % [evo_id, kit_id])
				continue

			var efresh: Dictionary = build_kit(kit_id)
			ClassModFactory.apply_upgrade_dicts_to_kit(kit_id, efresh, [evo])
			if fp_kit(efresh) == base_fp:
				dead.append("%s (%s): EVOLUTION op '%s' target %s resolved but changed NOTHING"
					% [evo_id, kit_id, eop, str(evo.get("target", {}))])

	return {
		"dead": dead,
		"inert_modifier": inert_modifier,
		"kit_flags": kit_flags,
		"mod_pairs": mod_pairs,
		"checked": checked,
		"by_op": by_op,
		"kits": kit_ids.keys(),
	}
