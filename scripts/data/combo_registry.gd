## ComboRegistry — builds the codex's ModCombo entries.
##
## SOURCE CHANGED 2026-08-08. This used to hold 69 authored doubles + 8 triples over the GENERIC
## weapon mods, transcribed from docs/mod_interaction_matrix.md. That whole layer was retired:
## the generic mods baked into a weapon auto-attack that no combo character fires, so ~65 of the
## 69 pairs could be "discovered" in the armory and then do absolutely nothing in a run — the
## codex was describing effects the game never produced.
##
## The codex now enumerates MOD EVOLUTIONS (ClassModData.EVOLUTIONS): two per character, each a
## capstone that fires when both of its roster mods are equipped together. 24 entries, every one
## reachable, authored against a real kit phase, and guarded by ClassModData.validate_order().
##
## Nothing downstream changed shape. CodexManager, CodexEntry, MasteryApplicator and
## codex_grid_panel are all generic over ModCombo, and CodexManager.load_data() already skips
## entries it does not recognise, so an existing save simply drops its stale combo rows.

class_name ComboRegistry


static func build_registry() -> Array[ModCombo]:
	var combos: Array[ModCombo] = []
	for evo_id: String in ClassModData.EVOLUTIONS:
		var evo: Dictionary = ClassModData.EVOLUTIONS[evo_id]
		var reqs: Array[StringName] = []
		for r: String in evo.get("requires", []):
			reqs.append(StringName(r))
		combos.append(_create_combo(
			StringName(evo_id),
			str(evo.get("name", evo_id)),
			reqs,
			str(evo.get("desc", "")),
			_type_for_op(str(evo.get("op", ""))),
			str(evo.get("op", "")),
			_bonus_for_op(str(evo.get("op", "")))
		))
	return combos


## Codex "type" is cosmetic — it drives the mastery blurb and the grid's grouping colour. Mapping
## the op onto the existing enum keeps the panel's five categories meaningful without inventing a
## new vocabulary for 24 entries.
static func _type_for_op(op: String) -> ModCombo.ComboType:
	match op:
		"scale_aoe", "add_projectiles":
			return ModCombo.ComboType.BEHAVIOR_BEHAVIOR
		"add_status", "add_projectile_status":
			return ModCombo.ComboType.BEHAVIOR_ELEMENTAL
		"modifier":
			return ModCombo.ComboType.STAT_INTERACTION
	return ModCombo.ComboType.TRIPLE_LEGENDARY


static func _bonus_for_op(op: String) -> MasteryBonus:
	match op:
		"scale_aoe":
			return _make_bonus(MasteryBonus.BonusType.RADIUS_INCREASE, 0.12, "+12% effect radius")
		"add_projectiles":
			return _make_bonus(MasteryBonus.BonusType.DAMAGE_INCREASE, 0.12, "+12% projectile damage")
		"add_status", "add_projectile_status":
			return _make_bonus(MasteryBonus.BonusType.DAMAGE_INCREASE, 0.10, "+10% status damage")
	return _make_bonus(MasteryBonus.BonusType.DAMAGE_INCREASE, 0.10, "+10% effect potency")


static func _create_combo(
	combo_id: StringName,
	combo_name: String,
	mods: Array[StringName],
	description: String,
	combo_type: ModCombo.ComboType,
	vfx_hint: String,
	mastery_bonus: MasteryBonus = null
) -> ModCombo:
	var combo := ModCombo.new()
	combo.combo_id = combo_id
	combo.combo_name = combo_name
	combo.required_mods = mods
	combo.description = description
	combo.combo_type = combo_type
	combo.vfx_hint = vfx_hint
	combo.mastery_bonus = mastery_bonus
	combo.is_authored = true
	return combo


static func _make_bonus(bonus_type: MasteryBonus.BonusType, value: float,
		description: String) -> MasteryBonus:
	var bonus := MasteryBonus.new()
	bonus.bonus_type = bonus_type
	bonus.bonus_value = value      ## NOT `value` — the export is named bonus_value
	bonus.description = description
	return bonus
