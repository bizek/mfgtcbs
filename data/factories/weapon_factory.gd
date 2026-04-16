class_name WeaponFactory
extends RefCounted
## Builds AbilityDefinitions for all weapons from WeaponData.
## Each weapon becomes an auto-attack AbilityDefinition with appropriate effects.
## Called by player.gd during weapon loading.
##
## Weapon behaviors map to engine effect types:
##   projectile/spread → SpawnProjectilesEffect + ProjectileConfig
##   beam              → DealDamageEffect (direct, targeting: nearest_enemy)
##   melee             → AreaDamageEffect (targeting: all_enemies_in_range)
##   artillery         → GroundZoneEffect (delayed detonation)
##   orbit             → handled separately (persistent entities, not an ability)


static func build_weapon_ability(weapon_id: String, weapon_data: Dictionary,
		active_mods: Array = []) -> AbilityDefinition:
	## Build an AbilityDefinition for the given weapon.
	## active_mods modifies the projectile config and adds on-hit effects.
	var behavior: String = weapon_data.get("behavior", "projectile")
	match behavior:
		"projectile":
			return _build_projectile_weapon(weapon_id, weapon_data, active_mods)
		"spread":
			return _build_spread_weapon(weapon_id, weapon_data, active_mods)
		"beam":
			return _build_beam_weapon(weapon_id, weapon_data, active_mods)
		"melee":
			return _build_melee_weapon(weapon_id, weapon_data, active_mods)
		"artillery":
			return _build_artillery_weapon(weapon_id, weapon_data, active_mods)
		"orbit":
			return _build_orbit_weapon(weapon_id, weapon_data, active_mods)
	return _build_projectile_weapon(weapon_id, weapon_data, active_mods)


# --- Projectile weapon (Standard Sidearm, Warden's Repeater, Spark's Pistol, Herald's Beacon) ---

static func _build_projectile_weapon(weapon_id: String, data: Dictionary,
		mods: Array) -> AbilityDefinition:
	var ability := AbilityDefinition.new()
	ability.ability_id = weapon_id
	ability.ability_name = data.get("display_name", weapon_id)
	ability.tags = ["Weapon", "Projectile"]
	ability.cooldown_base = 1.0 / data.get("attack_speed", 1.0)
	ability.mode = "Auto"

	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	ability.targeting = targeting

	var proj_config := _build_projectile_config(data, mods)
	var spawn := SpawnProjectilesEffect.new()
	spawn.projectile = proj_config
	spawn.spawn_pattern = "spread"
	spawn.count = int(data.get("projectile_count", 1))
	spawn.spread_angle = data.get("spread_angle", 10.0)
	ability.effects = [spawn]

	return ability


# --- Spread weapon (Frost Scattergun) ---

static func _build_spread_weapon(weapon_id: String, data: Dictionary,
		mods: Array) -> AbilityDefinition:
	var ability := AbilityDefinition.new()
	ability.ability_id = weapon_id
	ability.ability_name = data.get("display_name", weapon_id)
	ability.tags = ["Weapon", "Projectile", "Spread"]
	ability.cooldown_base = 1.0 / data.get("attack_speed", 1.0)
	ability.mode = "Auto"

	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	ability.targeting = targeting

	var proj_config := _build_projectile_config(data, mods)
	var spawn := SpawnProjectilesEffect.new()
	spawn.projectile = proj_config
	spawn.spawn_pattern = "spread"
	spawn.count = data.get("projectile_count", 5)
	spawn.spread_angle = data.get("spread_angle", 52.0)
	ability.effects = [spawn]

	return ability


# --- Beam weapon (Ember Beam) ---

static func _build_beam_weapon(weapon_id: String, data: Dictionary,
		mods: Array) -> AbilityDefinition:
	var ability := AbilityDefinition.new()
	ability.ability_id = weapon_id
	ability.ability_name = data.get("display_name", weapon_id)
	ability.tags = ["Weapon", "Beam"]
	ability.cooldown_base = 1.0 / data.get("attack_speed", 1.0)
	ability.mode = "Auto"
	ability.cast_range = data.get("range", 285.0)

	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = data.get("range", 285.0)
	ability.targeting = targeting

	var dmg := DealDamageEffect.new()
	dmg.damage_type = _get_damage_type(data)
	dmg.base_damage = data.get("damage", 6.0)
	ability.effects = [dmg]

	# Mod: size → wider reach
	for mod_id in mods:
		var mod_data: Dictionary = ModData.ALL.get(mod_id, {})
		if mod_data.get("effect_type", "") == "size":
			var mult: float = mod_data.get("params", {}).get("size_mult", 1.5)
			ability.cast_range *= mult
			ability.targeting.max_range *= mult
			break

	# Add mod on-hit effects (elemental, dot, chain, explosive)
	_add_mod_on_hit_effects(ability, mods)

	return ability


# --- Melee weapon (Plasma Blade) ---

static func _build_melee_weapon(weapon_id: String, data: Dictionary,
		mods: Array) -> AbilityDefinition:
	var ability := AbilityDefinition.new()
	ability.ability_id = weapon_id
	ability.ability_name = data.get("display_name", weapon_id)
	ability.tags = ["Weapon", "Melee"]
	ability.cooldown_base = 1.0 / data.get("attack_speed", 1.0)
	ability.mode = "Auto"

	var targeting := TargetingRule.new()
	targeting.type = "all_enemies_in_range"
	targeting.max_range = data.get("range", 55.0)
	ability.targeting = targeting

	var dmg := DealDamageEffect.new()
	dmg.damage_type = _get_damage_type(data)
	dmg.base_damage = data.get("damage", 42.0)
	ability.effects = [dmg]

	# Mod: size → longer swing reach
	for mod_id in mods:
		var mod_data: Dictionary = ModData.ALL.get(mod_id, {})
		if mod_data.get("effect_type", "") == "size":
			ability.targeting.max_range *= mod_data.get("params", {}).get("size_mult", 1.5)
			break

	_add_mod_on_hit_effects(ability, mods)

	return ability


# --- Artillery weapon (Void Mortar) ---

static func _build_artillery_weapon(weapon_id: String, data: Dictionary,
		mods: Array) -> AbilityDefinition:
	var ability := AbilityDefinition.new()
	ability.ability_id = weapon_id
	ability.ability_name = data.get("display_name", weapon_id)
	ability.tags = ["Weapon", "Artillery"]
	ability.cooldown_base = 1.0 / data.get("attack_speed", 1.0)
	ability.mode = "Auto"
	ability.cast_range = data.get("range", 380.0)

	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	targeting.max_range = data.get("range", 380.0)
	ability.targeting = targeting

	var zone := GroundZoneEffect.new()
	zone.zone_id = weapon_id + "_impact"
	zone.radius = data.get("aoe_radius", 64.0)
	zone.duration = data.get("fuse_time", 1.0)
	zone.tick_interval = data.get("fuse_time", 1.0)  # Single tick = detonation
	zone.target_faction = "enemy"

	var zone_dmg := DealDamageEffect.new()
	zone_dmg.damage_type = _get_damage_type(data)
	zone_dmg.base_damage = data.get("damage", 52.0)
	zone.tick_effects = [zone_dmg]

	# Apply mods to the blast zone
	StatusFactory.build_all()
	var base_dmg: float = data.get("damage", 52.0)
	var dmg_type: String = _get_damage_type(data)
	for mod_id in mods:
		var mod_data: Dictionary = ModData.ALL.get(mod_id, {})
		var params: Dictionary = mod_data.get("params", {})
		match mod_data.get("effect_type", ""):
			"size":
				zone.radius *= params.get("size_mult", 1.5)
			"explosive":
				## Secondary micro-blast on each blast victim — rewards hitting clusters
				var splash := AreaDamageEffect.new()
				splash.damage_type = dmg_type
				splash.base_damage = base_dmg * params.get("damage_mult", 0.3)
				splash.aoe_radius  = params.get("radius", 40.0)
				zone.tick_effects.append(splash)
			"chain":
				var chain_dmg := AreaDamageEffect.new()
				chain_dmg.damage_type = dmg_type
				chain_dmg.base_damage = base_dmg * params.get("chain_damage_mult", 0.6)
				chain_dmg.aoe_radius  = params.get("chain_range", 120.0)
				zone.tick_effects.append(chain_dmg)
			"elemental":
				var element: String = params.get("element", "")
				var status_def: StatusEffectDefinition = StatusFactory.get_by_id(element)
				if status_def:
					var apply := ApplyStatusEffectData.new()
					apply.status = status_def
					apply.stacks = 1
					zone.tick_effects.append(apply)
			"dot_applicator":
				var apply := ApplyStatusEffectData.new()
				apply.status = StatusFactory.bleed
				apply.stacks = 1
				zone.tick_effects.append(apply)

	ability.effects = [zone]

	return ability


# --- Orbit weapon (Lightning Orb) ---

static func _build_orbit_weapon(weapon_id: String, data: Dictionary,
		mods: Array) -> AbilityDefinition:
	## Orbit weapons are persistent entities, not projectiles. The AbilityDefinition
	## serves as metadata; ability.effects carries on-hit effects for each orb to apply.
	var ability := AbilityDefinition.new()
	ability.ability_id = weapon_id
	ability.ability_name = data.get("display_name", weapon_id)
	ability.tags = ["Weapon", "Orbit"]
	ability.cooldown_base = 0.0  # Passive — no fire rate
	ability.mode = "Auto"

	var targeting := TargetingRule.new()
	targeting.type = "self"
	ability.targeting = targeting

	# Build on-hit effects from mods; player._setup_orbit_orbs passes these to each orb.
	# size mod is handled separately (orb visual/hitbox scale) in player._setup_orbit_orbs.
	StatusFactory.build_all()
	var base_dmg: float = data.get("damage", 28.0)
	var dmg_type: String = _get_damage_type(data)
	for mod_id in mods:
		var mod_data: Dictionary = ModData.ALL.get(mod_id, {})
		var params: Dictionary = mod_data.get("params", {})
		match mod_data.get("effect_type", ""):
			"elemental":
				var element: String = params.get("element", "")
				var status_def: StatusEffectDefinition = StatusFactory.get_by_id(element)
				if status_def:
					var apply := ApplyStatusEffectData.new()
					apply.status = status_def
					apply.stacks = 1
					ability.effects.append(apply)
			"dot_applicator":
				var apply := ApplyStatusEffectData.new()
				apply.status = StatusFactory.bleed
				apply.stacks = 1
				ability.effects.append(apply)
			"chain":
				var chain_dmg := AreaDamageEffect.new()
				chain_dmg.damage_type = dmg_type
				chain_dmg.base_damage = base_dmg * params.get("chain_damage_mult", 0.6)
				chain_dmg.aoe_radius  = params.get("chain_range", 120.0)
				ability.effects.append(chain_dmg)
			"explosive":
				var aoe := AreaDamageEffect.new()
				aoe.damage_type = dmg_type
				aoe.base_damage = base_dmg * params.get("damage_mult", 0.3)
				aoe.aoe_radius  = params.get("radius", 40.0)
				ability.effects.append(aoe)

	return ability


# --- ProjectileConfig builder ---

## Cached projectile SpriteFrames — built once from the scene's texture
static var _projectile_sprite_frames: SpriteFrames = null

static func _get_projectile_sprite_frames() -> SpriteFrames:
	if _projectile_sprite_frames:
		return _projectile_sprite_frames
	## Build SpriteFrames from the same texture the old projectile.tscn uses
	const PROJ_TEX_PATH := "res://assets/minifantasy/Minifantasy_Enchanted_Companions_v1.0/Minifantasy_Enchanted_Companions_Assets/Companions/Sword/Sword_Fly_Idle.png"
	if not ResourceLoader.exists(PROJ_TEX_PATH):
		return null
	var sheet: Texture2D = load(PROJ_TEX_PATH)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(0, 0, 32, 32)
	atlas.filter_clip = true
	var frames := SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_loop("default", false)
	frames.add_frame("default", atlas)
	_projectile_sprite_frames = frames
	return frames


static func _build_projectile_config(data: Dictionary, mods: Array) -> ProjectileConfig:
	var config := ProjectileConfig.new()
	config.motion_type = "directional"
	config.speed = data.get("projectile_speed", 400.0)
	config.max_range = config.speed * data.get("lifetime", 3.0)
	config.hit_radius = 8.0
	config.sprite_frames = _get_projectile_sprite_frames()
	config.use_directional_anims = false
	config.animation = "default"
	config.rotation_offset = PI / 2.0  ## Sword sprite points down; rotate to align with travel direction

	# Mod: pierce, gravity, size, ricochet
	for mod_id in mods:
		var mod_data: Dictionary = ModData.ALL.get(mod_id, {})
		var params: Dictionary = mod_data.get("params", {})
		match mod_data.get("effect_type", ""):
			"pierce":
				config.pierce_count = maxi(config.pierce_count, params.get("pierce_count", 3))
			"gravity":
				config.motion_type = "homing"
			"size":
				config.visual_scale *= params.get("size_mult", 1.5)
			"ricochet":
				config.bounce_count = maxi(config.bounce_count, params.get("max_bounces", 3))

	# Base on-hit: deal damage
	var dmg := DealDamageEffect.new()
	dmg.damage_type = _get_damage_type(data)
	dmg.base_damage = data.get("damage", 18.0)
	config.on_hit_effects = [dmg]

	# Mod on-hit effects
	_add_projectile_mod_effects(config, mods)

	# Mod: explosive → impact AOE
	for mod_id in mods:
		var mod_data: Dictionary = ModData.ALL.get(mod_id, {})
		var params: Dictionary = mod_data.get("params", {})
		match mod_data.get("effect_type", ""):
			"explosive":
				config.impact_aoe_radius = maxf(config.impact_aoe_radius, params.get("radius", 40.0))
				var aoe_dmg := DealDamageEffect.new()
				aoe_dmg.damage_type = _get_damage_type(data)
				aoe_dmg.base_damage = data.get("damage", 18.0) * params.get("damage_mult", 0.3)
				config.impact_aoe_effects.append(aoe_dmg)   ## append, not assign
			"split":
				var split_config := ProjectileConfig.new()
				split_config.motion_type = "directional"
				split_config.speed = data.get("projectile_speed", 400.0) * 0.8
				split_config.max_range = split_config.speed * maxf(data.get("lifetime", 3.0) * 0.5, 0.5)
				split_config.hit_radius = 8.0
				split_config.sprite_frames = config.sprite_frames
				split_config.use_directional_anims = false
				split_config.animation = config.animation
				split_config.visual_scale = config.visual_scale * 0.7
				var split_dmg := DealDamageEffect.new()
				split_dmg.damage_type = _get_damage_type(data)
				split_dmg.base_damage = data.get("damage", 18.0) * params.get("split_damage_mult", 0.4)
				split_config.on_hit_effects = [split_dmg]
				var split_spawn := SpawnProjectilesEffect.new()
				split_spawn.projectile = split_config
				split_spawn.spawn_pattern = "radial"
				split_spawn.count = params.get("split_count", 3)
				config.on_expire_effects = [split_spawn]

	## Apply all named mod combo effects (pairwise + triple interactions)
	ModComboFactory.apply_projectile_combos(config, mods, data)

	return config


static func _add_projectile_mod_effects(config: ProjectileConfig, mods: Array) -> void:
	## Add on-hit effects to projectile config from weapon mods.
	StatusFactory.build_all()
	for mod_id in mods:
		var mod_data: Dictionary = ModData.ALL.get(mod_id, {})
		var params: Dictionary = mod_data.get("params", {})
		match mod_data.get("effect_type", ""):
			"elemental":
				var element: String = params.get("element", "")
				var status_def: StatusEffectDefinition = StatusFactory.get_by_id(element)
				if status_def:
					var apply := ApplyStatusEffectData.new()
					apply.status = status_def
					apply.stacks = 1
					config.on_hit_effects.append(apply)
			"lifesteal":
				# Lifesteal handled via leech modifier on player, not per-projectile
				pass
			"dot_applicator":
				var apply := ApplyStatusEffectData.new()
				apply.status = StatusFactory.bleed
				apply.stacks = 1
				config.on_hit_effects.append(apply)
			"chain":
				## Chain: deal damage to enemies near the hit target (AreaDamageEffect in
				## on_hit_effects, centered on primary hit target, excluding that target).
				## This correctly fires on every pierce hit and doesn't require impact_aoe_radius.
				var chain_dmg := AreaDamageEffect.new()
				chain_dmg.damage_type = _get_damage_type_from_config(config)
				chain_dmg.base_damage = config.on_hit_effects[0].base_damage * params.get("chain_damage_mult", 0.6) if not config.on_hit_effects.is_empty() else 10.0
				chain_dmg.aoe_radius = params.get("chain_range", 120.0)
				config.on_hit_effects.append(chain_dmg)


static func _add_mod_on_hit_effects(ability: AbilityDefinition, mods: Array) -> void:
	## Add on-hit effects to a direct-damage ability from weapon mods.
	## Handles: elemental, dot_applicator, chain, explosive.
	## Reads base_damage and damage_type from ability.effects[0] (DealDamageEffect).
	StatusFactory.build_all()
	var base_dmg: float = 10.0
	var dmg_type: String = "Physical"
	if not ability.effects.is_empty() and ability.effects[0] is DealDamageEffect:
		base_dmg = ability.effects[0].base_damage
		dmg_type  = ability.effects[0].damage_type
	for mod_id in mods:
		var mod_data: Dictionary = ModData.ALL.get(mod_id, {})
		var params: Dictionary = mod_data.get("params", {})
		match mod_data.get("effect_type", ""):
			"elemental":
				var element: String = params.get("element", "")
				var status_def: StatusEffectDefinition = StatusFactory.get_by_id(element)
				if status_def:
					var apply := ApplyStatusEffectData.new()
					apply.status = status_def
					apply.stacks = 1
					ability.effects.append(apply)
			"dot_applicator":
				var apply := ApplyStatusEffectData.new()
				apply.status = StatusFactory.bleed
				apply.stacks = 1
				ability.effects.append(apply)
			"chain":
				var chain_dmg := AreaDamageEffect.new()
				chain_dmg.damage_type = dmg_type
				chain_dmg.base_damage = base_dmg * params.get("chain_damage_mult", 0.6)
				chain_dmg.aoe_radius  = params.get("chain_range", 120.0)
				ability.effects.append(chain_dmg)
			"explosive":
				var aoe := AreaDamageEffect.new()
				aoe.damage_type = dmg_type
				aoe.base_damage = base_dmg * params.get("damage_mult", 0.3)
				aoe.aoe_radius  = params.get("radius", 40.0)
				ability.effects.append(aoe)


static func _get_damage_type(data: Dictionary) -> String:
	var dt: String = data.get("damage_type", "physical")
	match dt:
		"physical": return "Physical"
		"fire": return "Fire"
		"cryo": return "Ice"
		"shock": return "Lightning"
		"void": return "Void"
	return "Physical"


static func _get_damage_type_from_config(config: ProjectileConfig) -> String:
	if not config.on_hit_effects.is_empty() and config.on_hit_effects[0] is DealDamageEffect:
		return config.on_hit_effects[0].damage_type
	return "Physical"


## Build StatusEffectDefinitions for player-level combo passives (runtime trigger effects).
## Apply each returned definition to the player's status_effect_component when weapon loads.
static func build_combo_passives(active_mods: Array) -> Array[StatusEffectDefinition]:
	return ModComboFactory.build_combo_passives(active_mods)


## Build extra ModifierDefinitions from mod combo interactions (e.g. Size+Crit bonus chance).
## Append to the stat_mods returned by build_mod_modifiers.
static func build_combo_modifiers(active_mods: Array) -> Array[ModifierDefinition]:
	return ModComboFactory.build_combo_modifiers(active_mods)


## Build ModifierDefinitions for weapon mods that modify stats (not on-hit behavior).
## Applied to the player's modifier_component when weapon is equipped.
static func build_mod_modifiers(active_mods: Array) -> Array[ModifierDefinition]:
	var result: Array[ModifierDefinition] = []
	for mod_id in active_mods:
		var mod_data: Dictionary = ModData.ALL.get(mod_id, {})
		var params: Dictionary = mod_data.get("params", {})
		match mod_data.get("effect_type", ""):
			"crit":
				var cc := ModifierDefinition.new()
				cc.target_tag = "crit_chance"
				cc.operation = "add"
				cc.value = params.get("crit_chance_bonus", 0.0)
				cc.source_name = "mod_" + mod_id
				result.append(cc)
				var cm := ModifierDefinition.new()
				cm.target_tag = "crit_multiplier"
				cm.operation = "add"
				cm.value = params.get("crit_mult_bonus", 0.0)
				cm.source_name = "mod_" + mod_id
				result.append(cm)
			"lifesteal":
				var ls := ModifierDefinition.new()
				ls.target_tag = "leech"
				ls.operation = "bonus"
				ls.value = params.get("steal_pct", 0.05)
				ls.source_name = "mod_" + mod_id
				result.append(ls)
	return result
