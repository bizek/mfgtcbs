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


## Build an AbilityDefinition for the given weapon.
##
## Took an `active_mods` array until 2026-08-08 and baked the generic weapon mods into the
## ProjectileConfig it returns. That whole path was unreachable: every character has a combo kit,
## and `player.set_combo_ability` disconnects the auto-attack, so the ability built here is only
## ever fired by orbit weapons and the F1 debug auto-fire toggle. 13 of the 18 generic mods —
## pierce, chain, explosive, the three elementals, size, split, gravity, ricochet, accelerating,
## dot_applicator, napalm — did nothing for anyone, and so did ~65 of the 69 interaction pairs.
##
## The parameter is GONE rather than defaulted so it cannot quietly come back. Mods now live
## entirely on the class layer: ClassModData → ClassModFactory → player._load_combo, which mutates
## the kit choreography the player actually plays.
static func build_weapon_ability(weapon_id: String, weapon_data: Dictionary) -> AbilityDefinition:
	var behavior: String = weapon_data.get("behavior", "projectile")
	match behavior:
		"projectile":
			return _build_projectile_weapon(weapon_id, weapon_data)
		"spread":
			return _build_spread_weapon(weapon_id, weapon_data)
		"beam":
			return _build_beam_weapon(weapon_id, weapon_data)
		"melee":
			return _build_melee_weapon(weapon_id, weapon_data)
		"artillery":
			return _build_artillery_weapon(weapon_id, weapon_data)
		"orbit":
			return _build_orbit_weapon(weapon_id, weapon_data)
	return _build_projectile_weapon(weapon_id, weapon_data)


# --- Projectile weapon (Hurled Steel, Warden's Repeater, Spark's Pistol) ---

static func _build_projectile_weapon(weapon_id: String, data: Dictionary) -> AbilityDefinition:
	var ability := AbilityDefinition.new()
	ability.ability_id = weapon_id
	ability.ability_name = data.get("display_name", weapon_id)
	ability.tags = ["Weapon", "Projectile"]
	ability.cooldown_base = 1.0 / data.get("attack_speed", 1.0)
	ability.mode = "Auto"

	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	ability.targeting = targeting

	var proj_config := _build_projectile_config(data)
	if weapon_id == "Hunter's Bow":
		_apply_arrow_sprites(proj_config)
	var spawn := SpawnProjectilesEffect.new()
	spawn.projectile = proj_config
	spawn.spawn_pattern = "spread"
	spawn.count = int(data.get("projectile_count", 1))
	spawn.spread_angle = data.get("spread_angle", 10.0)
	ability.effects = [spawn]

	return ability


# --- Spread weapon (Frost Scattergun) ---

static func _build_spread_weapon(weapon_id: String, data: Dictionary) -> AbilityDefinition:
	var ability := AbilityDefinition.new()
	ability.ability_id = weapon_id
	ability.ability_name = data.get("display_name", weapon_id)
	ability.tags = ["Weapon", "Projectile", "Spread"]
	ability.cooldown_base = 1.0 / data.get("attack_speed", 1.0)
	ability.mode = "Auto"

	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemy"
	ability.targeting = targeting

	var proj_config := _build_projectile_config(data)
	if weapon_id == "Frost Scattergun":
		_apply_frost_sprites(proj_config)
	var spawn := SpawnProjectilesEffect.new()
	spawn.projectile = proj_config
	spawn.spawn_pattern = "spread"
	spawn.count = data.get("projectile_count", 5)
	spawn.spread_angle = data.get("spread_angle", 52.0)
	ability.effects = [spawn]

	return ability


# --- Beam weapon (Ember Beam) ---

static func _build_beam_weapon(weapon_id: String, data: Dictionary) -> AbilityDefinition:
	var ability := AbilityDefinition.new()
	ability.ability_id = weapon_id
	ability.ability_name = data.get("display_name", weapon_id)
	ability.tags = ["Weapon", "Beam"]
	ability.cooldown_base = 1.0 / data.get("attack_speed", 1.0)
	ability.mode = "Auto"
	ability.cast_range = data.get("range", 285.0)

	var targeting := TargetingRule.new()
	targeting.type = "nearest_enemies"
	targeting.max_range = data.get("range", 285.0)
	targeting.max_targets = 1  ## updated at fire time by player projectile_count stat
	ability.targeting = targeting

	var dmg := DealDamageEffect.new()
	dmg.damage_type = _get_damage_type(data)
	dmg.base_damage = data.get("damage", 6.0)
	ability.effects = [dmg]

	return ability


# --- Melee weapon (Arcane Blade) ---

static func _build_melee_weapon(weapon_id: String, data: Dictionary) -> AbilityDefinition:
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

	return ability


# --- Artillery weapon (Void Mortar) ---

static func _build_artillery_weapon(weapon_id: String, data: Dictionary) -> AbilityDefinition:
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

	ability.effects = [zone]

	return ability


# --- Orbit weapon (Lightning Orb) ---

static func _build_orbit_weapon(weapon_id: String, data: Dictionary) -> AbilityDefinition:
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

	return ability


# --- ProjectileConfig builder ---

## Cached projectile SpriteFrames — built once from the scene's texture
static var _projectile_sprite_frames: SpriteFrames = null
static var _frost_projectile_sprite_frames: SpriteFrames = null
static var _frost_impact_sprite_frames: SpriteFrames = null
static var _arrow_sprite_frames: SpriteFrames = null

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
	## clear_all() keeps (re-creates) an empty "default" animation — adding it again errors,
	## which trips the debugger on every projectile-weapon build. Reuse the built-in one.
	frames.clear_all()
	frames.set_animation_loop("default", false)
	frames.add_frame("default", atlas)
	_projectile_sprite_frames = frames
	return frames


static func _get_frost_projectile_sprite_frames() -> SpriteFrames:
	if _frost_projectile_sprite_frames:
		return _frost_projectile_sprite_frames
	const TEX_PATH := "res://assets/minifantasy/Minifantasy_Spell Effects_v1.0/Minifantasy_Spell_Effects_Assets/Ice/Tileable_Effect/Tileable_Ice.png"
	if not ResourceLoader.exists(TEX_PATH):
		return null
	var sheet: Texture2D = load(TEX_PATH)
	var frames := SpriteFrames.new()
	# Shard variation 1 — Loop row at y=8, 8 frames of 8×8 (fresh SpriteFrames already
	# carries an empty "default" — re-adding it errors and trips the debugger)
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", 10.0)
	for col in 8:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(col * 8, 8, 8, 8)
		atlas.filter_clip = true
		frames.add_frame("default", atlas)
	# Shard variation 2 — Loop row at y=40, 8 frames
	frames.add_animation("shard2")
	frames.set_animation_loop("shard2", true)
	frames.set_animation_speed("shard2", 10.0)
	for col in 8:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(col * 8, 40, 8, 8)
		atlas.filter_clip = true
		frames.add_frame("shard2", atlas)
	# Shard variation 3 — Loop row at y=72, 8 frames
	frames.add_animation("shard3")
	frames.set_animation_loop("shard3", true)
	frames.set_animation_speed("shard3", 10.0)
	for col in 8:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(col * 8, 72, 8, 8)
		atlas.filter_clip = true
		frames.add_frame("shard3", atlas)
	_frost_projectile_sprite_frames = frames
	return frames


static func _get_frost_impact_sprite_frames() -> SpriteFrames:
	if _frost_impact_sprite_frames:
		return _frost_impact_sprite_frames
	const TEX_PATH := "res://assets/minifantasy/Minifantasy_Spell Effects_v1.0/Minifantasy_Spell_Effects_Assets/Ice/Burst/Burst_Ice.png"
	if not ResourceLoader.exists(TEX_PATH):
		return null
	var sheet: Texture2D = load(TEX_PATH)
	var frames := SpriteFrames.new()
	## Fresh SpriteFrames already carries an empty "default" — reuse it (re-adding errors).
	frames.set_animation_loop("default", false)
	frames.set_animation_speed("default", 15.0)  ## 15 fps — crisp 1-second burst
	for col in 15:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(col * 32, 0, 32, 32)
		atlas.filter_clip = true
		frames.add_frame("default", atlas)
	_frost_impact_sprite_frames = frames
	return frames


## Single east-pointing arrow frame from the Cherub 96×96 3×3 directional sheet (cell col2,row1).
## The projectile rotates this to its travel direction, so we pick the cardinal-east cell and
## use rotation_offset 0 (arrow already points +x). If it renders rotated 90°/180° in-engine,
## adjust rotation_offset (e.g. PI for a left-pointing arrow).
static func _get_arrow_sprite_frames() -> SpriteFrames:
	if _arrow_sprite_frames:
		return _arrow_sprite_frames
	const ARROW_TEX := "res://assets/minifantasy/Minifantasy_Enchanted_Companions_v1.0/Minifantasy_Enchanted_Companions_Assets/Companions/Cherub/Arrow_Projectile.png"
	if not ResourceLoader.exists(ARROW_TEX):
		return null
	var sheet: Texture2D = load(ARROW_TEX)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(64, 32, 32, 32)   ## east-pointing arrow (col 2, row 1)
	atlas.filter_clip = true
	var frames := SpriteFrames.new()
	## SpriteFrames.new() already ships an empty "default" animation — configure + fill it
	## directly (calling add_animation("default") again just spams a harmless error).
	frames.set_animation_loop("default", false)
	frames.add_frame("default", atlas)
	_arrow_sprite_frames = frames
	return frames


static func _apply_arrow_sprites(config: ProjectileConfig) -> void:
	var sf := _get_arrow_sprite_frames()
	if sf:
		config.sprite_frames = sf
		config.animation = "default"
		config.use_directional_anims = false
		config.rotation_offset = 0.0   ## east arrow already aligned with +x travel direction
		config.fallback_color = Color(0.85, 0.78, 0.55)


static func _apply_frost_sprites(config: ProjectileConfig) -> void:
	var proj_sf := _get_frost_projectile_sprite_frames()
	if proj_sf:
		config.sprite_frames = proj_sf
		config.animation = "default"
		config.use_directional_anims = false
		config.rotation_offset = 0.0
		config.visual_scale = Vector2(1.5, 1.5)
		config.fallback_color = Color(0.55, 0.88, 1.0, 0.9)
	var impact_sf := _get_frost_impact_sprite_frames()
	if impact_sf:
		config.impact_sprite_frames = impact_sf
		config.impact_animation = "default"


static func _build_projectile_config(data: Dictionary) -> ProjectileConfig:
	var config := ProjectileConfig.new()
	config.motion_type = "directional"
	config.speed = data.get("projectile_speed", 400.0)
	config.max_range = config.speed * data.get("lifetime", 3.0)
	config.hit_radius = 8.0
	config.sprite_frames = _get_projectile_sprite_frames()
	config.use_directional_anims = false
	config.animation = "default"
	config.rotation_offset = PI / 2.0  ## Sword sprite points down; rotate to align with travel direction

	# Base on-hit: deal damage
	var dmg := DealDamageEffect.new()
	dmg.damage_type = _get_damage_type(data)
	dmg.base_damage = data.get("damage", 18.0)
	config.on_hit_effects = [dmg]

	return config


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
