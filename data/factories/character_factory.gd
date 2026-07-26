class_name CharacterFactory
extends RefCounted
## Builds ModifierDefinition arrays for player character stats and passives.
## Mirrors the enemy data factory pattern — content lives here, not in player.gd.
## Called by player._load_character_stats() and player._apply_passive_mods().


## Returns base-stat and armor ModifierDefinitions for the given character.
## base_stats must already have max_hp/move_speed overridden from CharacterData.
static func build_base_modifiers(char_id: String, base_stats: Dictionary) -> Array[ModifierDefinition]:
	var char_data: Dictionary = CharacterData.ALL.get(char_id, CharacterData.ALL["The Drifter"])
	var mods: Array[ModifierDefinition] = []

	for stat_name in base_stats:
		var mod := ModifierDefinition.new()
		mod.target_tag = stat_name
		mod.operation  = "add"
		mod.value      = float(base_stats[stat_name])
		mod.source_name = "base"
		mods.append(mod)

	var base_armor: float = char_data.get("base_armor", 0.0)
	if base_armor > 0.0:
		var armor_mod := ModifierDefinition.new()
		armor_mod.target_tag  = "Physical"
		armor_mod.operation   = "resist"
		armor_mod.value       = base_armor
		armor_mod.source_name = "base_armor"
		mods.append(armor_mod)

	return mods


## Returns passive ModifierDefinitions for the given passive_id.
## Health re-setup for cursed_passive is handled by the caller (needs health component).
static func build_passive_modifiers(passive_id: String) -> Array[ModifierDefinition]:
	var mods: Array[ModifierDefinition] = []
	match passive_id:
		"scavenger_passive":
			mods.append(_mod("pickup_radius", "bonus",        0.25, "passive_scavenger"))
		"spark_passive":
			mods.append(_mod("crit_multiplier", "add",        0.75, "passive_spark"))
		"necro_soul_harvest":
			pass  # Soul Harvest (kills drop souls → heal + empowered summon) fires in player._on_kill_soul_harvest — no flat mods
		"demon_hellborn":
			mods.append(_mod("Fire", "bonus",                 0.25, "passive_demon"))
			mods.append(_mod("Fire", "resist",               30.0, "passive_demon"))
		"cursed_passive":
			mods.append(_mod("max_hp",     "bonus",           0.20, "passive_cursed"))
			mods.append(_mod("Physical",   "resist",          0.20, "passive_cursed"))
			mods.append(_mod("move_speed", "bonus",           0.20, "passive_cursed"))
			mods.append(_mod("All",        "bonus",           0.20, "passive_cursed"))
		"warden_passive":
			pass  # Armor-doubling is a conditional query in player.get_armor() — no flat mods needed
		"ravager_passive":
			pass  # Bloodrage (+30% damage below half HP) toggles in player._update_bloodrage() — no flat mods
		"whisper_passive":
			mods.append(_mod("crit_chance",     "add", 0.10, "passive_whisper"))
			mods.append(_mod("crit_multiplier", "add", 0.25, "passive_whisper"))
		"deadeye_passive":
			pass  # Calm Hands (+25% damage above 80% HP) toggles in player._update_calm_hands() — no flat mods
		"verdant_passive":
			mods.append(_mod("max_hp", "bonus", 0.25, "passive_verdant"))
			# Primal Vigor's regen-while-safe polls in player._physics_process — no flat mod
		"devout_passive":
			pass  # Last Rites (heal 4 on kill) fires in player._on_kill_siphon — no flat mods
	return mods


static func _mod(tag: String, op: String, value: float, source: String) -> ModifierDefinition:
	var mod := ModifierDefinition.new()
	mod.target_tag  = tag
	mod.operation   = op
	mod.value       = value
	mod.source_name = source
	return mod
