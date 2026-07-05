extends CharacterBody2D

## Player — Movement, stats, health, leveling, and passive abilities.
## Uses engine component system for stats, damage pipeline, and status effects.
## Weapon firing through BehaviorComponent → EffectDispatcher pipeline.

signal health_changed(current: float, maximum: float)
signal xp_changed(current: float, needed: float)
signal leveled_up(new_level: int)
signal died

## Engine entity interface
var faction: int = 0  ## 0 = player/allies, 1 = enemies
var is_alive: bool = true
var is_attacking: bool = false
var is_channeling: bool = false
var is_invulnerable: bool = false
var is_untargetable: bool = false
var attack_target: Node2D = null
var last_hit_by: Node2D = null
var last_hit_time: float = -1e18
var _last_hit_time_by_tag: Dictionary = {}
var talent_picks: Array[String] = []
var combat_manager: Node2D = null
var spatial_grid: SpatialGrid = null
var combat_role: String = "MELEE"

## Base stats — initial values, modified by ModifierComponent
var _base_stats: Dictionary = {
	"max_hp":          100.0,
	"damage":          18.0,
	"attack_speed":    1.0,
	"crit_chance":     0.05,
	"crit_multiplier": 1.5,
	"move_speed":      66.0,   ## deliberate-pacing rebalance 2026-06-23 (was 120); overridden per-character by CharacterData.base_move_speed in _load_character_stats
	"pickup_radius":   50.0,
	"melee_range":     1.0,    ## multiplier on melee-combo hit radius + swing-effect size (mod/upgrade hook)
	"projectile_count": 1,
	"pierce":          0,
	"projectile_size": 1.0,
	## Dash (modifier-driven so the passive tree / upgrades can scale them).
	## Read via get_stat() — a +1 charge or -20% cooldown upgrade is just a ModifierDefinition.
	"dash_speed":      520.0,  ## impulse speed at dash start (px/s)
	"dash_cooldown":   1.6,    ## per-charge refill time (s)
	"dash_charges":    1.0,    ## max charges (clamped to int >= 1 at read time)
}

## XP and leveling
var xp: float = 0.0
var level: int = 1
var xp_base: float = 10.0
var xp_growth: float = 0.3

## Weapon (engine AbilityDefinition)
var _weapon_id: String = ""
var _weapon_data: Dictionary = {}
var _weapon_ability: AbilityDefinition = null

## Mod system
var _active_mods: Array = []
var _has_instability_siphon: bool = false

## Cached base projectile stats (read from built ProjectileConfig, used for live stat sync)
var _base_proj_pierce: int = 0
var _base_proj_scale: Vector2 = Vector2.ONE
var _base_proj_hit_radius: float = 8.0

## Character passive
var _passive_id: String = "none"

## State
var god_mode: bool = false

## Hit iframes
var _iframes_timer: float = 0.0
const IFRAME_DURATION: float = 0.55
var _hit_flash_tween: Tween = null

## Animation state flags — prevent walk/idle logic from clobbering one-shot anims
var _attack_anim_active: bool = false
var _damage_anim_active: bool = false
var _is_dying: bool = false

## Pending fire — ability + targets stored at swing-start, executed at swing-end
var _pending_ability: AbilityDefinition = null
var _pending_targets: Array = []
## Manual-aim direction locked in at swing-start (Vector2.ZERO = auto-fire / not manual).
## When set, the shot aims/renders toward the cursor instead of the resolved enemy.
var _pending_aim_dir: Vector2 = Vector2.ZERO

## Knockback
var knockback_velocity: Vector2 = Vector2.ZERO

## Manual fire is the DEFAULT: hold the "fire" action (left-click) to shoot toward the mouse
## cursor at the weapon's normal cadence (per-class aim in _resolve_manual_targets). The F1
## debug panel can flip this off to restore legacy auto-fire (aim at nearest enemy) for
## A/B testing. See docs/manual_fire.md.
var manual_fire_mode: bool = true
var _aim_marker: Node2D = null

## Dash — snappy, high-speed impulse with i-frames, charges + per-charge cooldown.
## Distance/cooldown/charge COUNT are modifier-driven (see _base_stats: dash_speed,
## dash_cooldown, dash_charges); the timing constants below are fixed feel values.
const DASH_DURATION: float = 0.16        ## active dash window in seconds (~80px at dash_speed 520)
const DASH_EASE_OUT: float = 0.25        ## tail deceleration amount (0 = constant speed, 1 = stops dead)
var _dash_timer: float = 0.0             ## counts down the active dash; >0 means dashing
var _dash_dir: Vector2 = Vector2.ZERO    ## locked-in dash direction
var _dash_speed_current: float = 0.0     ## dash_speed snapshotted at dash start
var _dash_charges: int = 1               ## currently available charges
var _dash_cooldown_timer: float = 0.0    ## counts down to the next charge refill
var _last_move_dir: Vector2 = Vector2.RIGHT  ## fallback dash direction when no input is held

## Orbit orbs (Lightning Orb weapon)
var _orbit_orbs: Array = []
const OrbitOrbScript     := preload("res://scripts/entities/orbit_orb.gd")
const WeaponPickupScript := preload("res://scripts/pickups/weapon_pickup.gd")
const AimMarkerScript    := preload("res://scripts/entities/aim_marker.gd")

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var pickup_area: Area2D = $PickupCollector
@onready var pickup_shape: CollisionShape2D = $PickupCollector/CollisionShape

## Engine components (created at runtime)
var health: HealthComponent = null
var modifier_component: ModifierComponent = null
var ability_component: AbilityComponent = null
var behavior_component: BehaviorComponent = null
var status_effect_component: StatusEffectComponent = null
var trigger_component: TriggerComponent = null

## Melee combo system (docs/combat_chain_architecture.md). _combo_ability is null for ranged
## characters — all combo plumbing below is inert until a melee-combo weapon/character sets it.
var choreography_runner: ChoreographyRunner = null
var _combat_input: CombatInputBuffer = null
## Melee-kit entry abilities (null for non-melee characters). LMB → light, RMB tap → heavy
## (Uppercut→Cataclysm), RMB hold → channel (Taunt). _combo_ability == light gates the whole system.
var _combo_ability: AbilityDefinition = null
var _combo_heavy: AbilityDefinition = null
var _combo_channel: AbilityDefinition = null
## Swing-effect overlay (the white slash), centered on the player and scaled per-node so the white's
## outer edge lands on that node's actual hit-zone radius — the visual IS the hitbox guide.
var _combo_fx: AnimatedSprite2D = null
const FX_NATIVE_RADIUS: float = 14.0   ## radius (px) the white slash reaches inside the 32px frame
const COMBO_FX_SCALE: float = 2.4   ## fallback upscale for nodes with no AreaDamage radius
## Rogue Bomb visuals (Throw Bomb asset package): the spinning bomb projectile arcs a short hop in
## the facing direction during the wind-up, then "bomb_fx" (the package explosion) plays where it
## lands. The projectile sheets are 3×3 directional grids; we slice the right-facing cell + flip_h.
var _bomb_toss: AnimatedSprite2D = null
var _bomb_tween: Tween = null
var _bomb_start: Vector2 = Vector2.ZERO   ## world-space toss origin (bomb is NOT player-attached)
var _bomb_land: Vector2 = Vector2.ZERO    ## world-space landing/detonation point
var _bomb_atlases: Array = []             ## the spin frames' AtlasTextures (region re-aimed per toss)
## Four-way facing driven by the aim cursor. The True Heroes rows are DIAGONAL facings
## (down_left / down_right / up_left / up_right — Minifantasy oblique style);
## CharacterSpriteFactory slices them as "<anim>_<facing>" and _play_anim picks the variant.
var _facing: String = "down_left"
var _has_dir_anims: bool = false
const BOMB_PROJ_SHEETS: Array[String] = [
	"res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Rogue/Special_Animations/Throw Bomb/Minifantasy_TrueHeroesRogueBombProjectileFrame1.png",
	"res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Rogue/Special_Animations/Throw Bomb/Minifantasy_TrueHeroesRogueBombProjectileFrame2.png",
]
const BOMB_EXPLOSION_SHEET: String = "res://assets/minifantasy/Minifantasy_TrueHeroes_v1.0/Minifantasy_TrueHeroes_Assets/Rogue/Special_Animations/Throw Bomb/Minifantasy_TrueHeroesRogueBombExplosion.png"
const BOMB_THROW_MAX: float = 60.0   ## bomb lands at the cursor, clamped to this throw range
const BOMB_TOSS_TIME: float = 0.33   ## ≈ time to hit_frame 6 @ 18fps
const BOMB_ARC_H: float = 14.0
## Wizard kit (The Spark): Teleport blink range, Fire Torrent forward offset, and the
## directional 64px torrent flame sheet (4 facing rows, drawn ahead of the caster).
const TELEPORT_RANGE: float = 100.0
const TORRENT_FORWARD: float = 36.0
const TORRENT_FX_SHEET: String = "res://assets/minifantasy/Minifantasy_True_Heroes_III_v1.1/Minifantasy_True_Heroes_III_Assets/Wizard/Special_Animations/Fire_Torrent/Fire_Torrent_Effect.png"
var _fire_familiar: Node2D = null
var _torrent_fx: AnimatedSprite2D = null
## Blood Mage kit (The Cursed): Extract Power HP cost, Vampirize heal-per-drink, and the
## Vampirize/Blood_Spikes loose effect sheets (drawn host-side, not body anims).
const BLOOD_COST_FRAC: float = 0.05      ## Extract Power costs 5% max HP (never lethal)
const VAMP_HEAL_FRAC: float = 0.02       ## Consume beat heals 2% max HP if the drain connected
const SPIKES_AOE_SHEET: String = "res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Blood_Spikes/Blood_Spikes_AOE.png"
const FLOATING_BLOOD_SHEET: String = "res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Vampirize/Floating_Blood.png"
const DRAIN_WISP_SHEET: String = "res://assets/minifantasy/Minifantasy_True_Heroes_IV_v1.1/Minifantasy_True_Heroes_IV_Assets/Blood_Mage/Special_Animations/Vampirize/Drain_Effect.png"
var _blood_elemental: Node2D = null
var _vamp_fx: AnimatedSprite2D = null
var _vamp_hit: bool = false              ## last extract beat found blood to drink
## Reach cap: base hit zones (ChainFactory) are ~half the "loved" size; full Reach mods scale them
## up to ~2× = the end-of-the-road size. Capped so it tops out there instead of growing forever.
const MELEE_RANGE_MAX: float = 2.0
var skill_component: SkillComponent = null   ## infra for future numbered skills (unused by Fighter)
var _rmb_pending: bool = false      ## a neutral RMB press is waiting to resolve as tap vs hold
const TAUNT_HOLD_THRESHOLD: float = 0.20   ## hold RMB this long (from neutral) → Taunt channel, else heavy


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("player")
	_setup_components()
	_load_character_stats()
	_apply_character_sprite()
	_load_equipped_weapon()
	_apply_passive_mods()
	_load_weapon_mods()
	_load_combo()
	_update_pickup_radius()
	_reset_dash_state()
	health_changed.emit(health.current_hp, health.max_hp)
	pickup_area.area_entered.connect(_on_pickup_area_entered)
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	sprite.frame_changed.connect(_on_sprite_frame_changed)

	# Shade passive: dodge triggers invisibility
	EventBus.on_dodge.connect(_on_dodge_received)

	if _has_instability_siphon:
		EventBus.on_kill.connect(_on_kill_siphon)

	# Void instability debuff: auto-apply void_touched at high instability
	GameManager.instability_changed.connect(_on_instability_changed)
	GameManager.phase_started.connect(_on_phase_started)


func _setup_components() -> void:
	modifier_component = ModifierComponent.new()
	modifier_component.name = "ModifierComponent"
	add_child(modifier_component)

	health = HealthComponent.new()
	health.name = "HealthComponent"
	add_child(health)
	health.health_changed.connect(func(hp, max_hp): health_changed.emit(hp, max_hp))
	health.died.connect(_on_health_died)

	status_effect_component = StatusEffectComponent.new()
	status_effect_component.name = "StatusEffectComponent"
	add_child(status_effect_component)
	status_effect_component.setup(modifier_component)

	trigger_component = TriggerComponent.new()
	trigger_component.name = "TriggerComponent"
	add_child(trigger_component)

	ability_component = AbilityComponent.new()
	ability_component.name = "AbilityComponent"
	add_child(ability_component)

	behavior_component = BehaviorComponent.new()
	behavior_component.name = "BehaviorComponent"
	add_child(behavior_component)
	behavior_component.setup(modifier_component)

	choreography_runner = ChoreographyRunner.new()
	choreography_runner.name = "ChoreographyRunner"
	add_child(choreography_runner)
	choreography_runner.setup(self)

	_combat_input = CombatInputBuffer.new()
	_combat_input.setup(["light_attack", "heavy_attack"])

	skill_component = SkillComponent.new()
	skill_component.name = "SkillComponent"
	add_child(skill_component)
	skill_component.setup(self, choreography_runner)


# --- Character loading ---

func _load_character_stats() -> void:
	var char_id: String = ProgressionManager.selected_character
	var char_data: Dictionary = CharacterData.ALL.get(char_id, CharacterData.ALL["The Drifter"])
	_base_stats["max_hp"]     = char_data.get("base_hp", 100.0)
	_base_stats["move_speed"] = char_data.get("base_move_speed", 200.0)
	_passive_id               = char_data.get("passive_id", "none")
	for mod in CharacterFactory.build_base_modifiers(char_id, _base_stats):
		modifier_component.add_modifier(mod)
	health.setup(_base_stats["max_hp"])


# --- Character sprite ---

func _apply_character_sprite() -> void:
	## Swap the scene's placeholder SpriteFrames for the selected character's class
	## sprite, built data-driven from CharacterData.ALL[id]["sprite"] (see
	## docs/character_overhaul_design.md). Falls back to the scene's baked frames
	## if the character has no sprite metadata or its sheets fail to load.
	var char_id: String = ProgressionManager.selected_character
	var frames: SpriteFrames = CharacterSpriteFactory.build(char_id)
	if frames != null:
		sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	## Factory-built frames carry all four facing rows ("<anim>_<dir>"); baked scene frames don't.
	_has_dir_anims = sprite.sprite_frames != null \
			and sprite.sprite_frames.has_animation("idle_down_right")
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		_play_anim("idle")
	_setup_combo_fx(frames)


func _setup_combo_fx(frames: SpriteFrames) -> void:
	## Overlay sprite that plays the "<node>_fx" swing-effect anim on top of the body. Shares the
	## character SpriteFrames (which now carries the *_fx animations). Hidden until a combo fires.
	if frames == null or not _has_any_fx_anim(frames):
		return  ## character has no swing-effect sheets — skip
	if _combo_fx == null:
		_combo_fx = AnimatedSprite2D.new()
		_combo_fx.name = "ComboFx"
		_combo_fx.centered = true
		_combo_fx.visible = false
		_combo_fx.z_index = 1   ## draw above the body
		_combo_fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_combo_fx)
		_combo_fx.animation_finished.connect(_on_combo_fx_finished)
	_combo_fx.sprite_frames = frames


## Facing follows the aim cursor, not movement — combat reads from where you're pointing.
## The cursor's QUADRANT picks the row (the rows are diagonal facings): south of the player
## always shows a front row, north always a back row — never inverted.
func _update_facing() -> void:
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	if to_mouse.length_squared() < 4.0:
		return   ## cursor on top of the player — keep the last facing
	_facing = ("down" if to_mouse.y >= 0.0 else "up") \
			+ ("_right" if to_mouse.x >= 0.0 else "_left")


## Play `base` in the row matching the current facing when the frames carry it (4-row sheets);
## fall back to the base slice (single-row sheets like death, or baked scene frames).
func _play_anim(base: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var dir_name: String = base + "_" + _facing
	if sprite.sprite_frames.has_animation(dir_name):
		sprite.flip_h = false   ## real left row — never mirror on top of it
		sprite.play(dir_name)
	else:
		sprite.play(base)


## Resolve a canonical anim name to its facing variant (ChoreographyRunner host hook — combo
## phases play the row matching the cursor; hit_frame indices are identical across rows).
func choreo_anim_name(base: String) -> String:
	if sprite and sprite.sprite_frames \
			and sprite.sprite_frames.has_animation(base + "_" + _facing):
		return base + "_" + _facing
	return base


## True if the character SpriteFrames carries any "<node>_fx" swing-effect animation. Not every
## kit has an fx sheet for its basic attack (e.g. Paladin only ships bash/dictum/dome effects),
## so the overlay must exist whenever ANY node can use it.
func _has_any_fx_anim(frames: SpriteFrames) -> bool:
	for anim_name in frames.get_animation_names():
		if String(anim_name).ends_with("_fx"):
			return true
	return false


# --- Weapon loading ---

func _load_equipped_weapon() -> void:
	var char_id: String = ProgressionManager.selected_character
	var char_data: Dictionary = CharacterData.ALL.get(char_id, CharacterData.ALL["The Drifter"])
	## Per-character loadout: every character runs its own chosen weapon (slot 1), which
	## defaults to its signature starting_weapon. See ProgressionManager.character_loadouts.
	var weapon_id: String = ProgressionManager.get_character_weapon(char_id, 1)
	if weapon_id.is_empty():
		weapon_id = char_data.get("starting_weapon", "Hurled Steel")

	_weapon_id   = weapon_id
	_weapon_data = WeaponData.ALL.get(weapon_id, WeaponData.ALL["Hurled Steel"])

	# Weapon stats override base damage/attack_speed/projectile_count
	_set_base_stat("damage", _weapon_data.get("damage", 18.0))
	_set_base_stat("attack_speed", _weapon_data.get("attack_speed", 1.0))
	_set_base_stat("projectile_count", _weapon_data.get("projectile_count", 1))

	# Orbit weapons spawn persistent orbs (deferred so scene tree is ready)
	if _weapon_data.get("behavior") == "orbit":
		call_deferred("_setup_orbit_orbs")


# --- Passive application ---

func _apply_passive_mods() -> void:
	for mod in CharacterFactory.build_passive_modifiers(_passive_id):
		modifier_component.add_modifier(mod)
	if _passive_id == "cursed_passive":
		health.setup(get_stat("max_hp"))


# --- Mod loading ---

func _load_weapon_mods() -> void:
	_active_mods = ProgressionManager.get_weapon_mods(_weapon_id)
	_has_instability_siphon = "instability_siphon" in _active_mods

	# Stat mods (crit, lifesteal) as ModifierDefinitions
	var stat_mods: Array[ModifierDefinition] = WeaponFactory.build_mod_modifiers(_active_mods)
	for mod in stat_mods:
		modifier_component.add_modifier(mod)

	# Combo modifier bonuses (Size+Crit, Crit+Ricochet, etc.)
	var combo_mods: Array[ModifierDefinition] = WeaponFactory.build_combo_modifiers(_active_mods)
	for mod in combo_mods:
		modifier_component.add_modifier(mod)

	# Build weapon ability with mods baked into ProjectileConfig/effects
	_weapon_ability = WeaponFactory.build_weapon_ability(_weapon_id, _weapon_data, _active_mods)

	# Runtime combo passives (Static Strike, etc.) applied as permanent player statuses
	var combo_passives: Array[StatusEffectDefinition] = WeaponFactory.build_combo_passives(_active_mods)
	for passive_def in combo_passives:
		status_effect_component.apply_status(passive_def, self, 1)

	# Wire as auto-attack through engine components
	# Orbit weapons are passive — orbs handle their own hits, no auto-attack signal needed
	var attack_interval: float = _weapon_ability.cooldown_base
	behavior_component.setup(modifier_component, attack_interval)
	if _weapon_data.get("behavior", "") != "orbit":
		behavior_component.auto_attack_requested.connect(_on_auto_attack)
	ability_component.setup_abilities(_weapon_ability, [], 1)
	_cache_projectile_base_stats()


func reload_mods() -> void:
	# Remove old mod modifiers (sources starting with "mod_" or "combo_")
	modifier_component.remove_by_source_prefix("mod_")
	modifier_component.remove_by_source_prefix("combo_")
	# Remove old combo passive statuses
	for passive_id in ["combo_static_strike"]:
		if status_effect_component.has_status(passive_id):
			status_effect_component.force_remove_status(passive_id, self)
	_load_weapon_mods()
	_load_combo()   ## re-assert the combo (and re-drop weapon auto-fire) after a mod rebuild
	if _has_instability_siphon:
		if not EventBus.on_kill.is_connected(_on_kill_siphon):
			EventBus.on_kill.connect(_on_kill_siphon)


func get_active_weapon_id() -> String:
	return _weapon_id

## Spawn the currently-equipped weapon as a pickup at the player's position.
## Called before switch_weapon so the old weapon can be re-looted.
func drop_current_weapon() -> void:
	if _weapon_id.is_empty():
		return
	var pickup: Area2D = WeaponPickupScript.new()
	pickup.weapon_id       = _weapon_id
	pickup.global_position = global_position
	get_parent().add_child(pickup)


## Swap to a different weapon mid-run (called when a weapon upgrade is chosen at level-up).
## Carries over any stat upgrades already applied; mods are cleared (new weapon has none).
func switch_weapon(weapon_id: String) -> void:
	if weapon_id == _weapon_id:
		return
	## Clean up current weapon
	_cleanup_orbit_orbs()
	if behavior_component.auto_attack_requested.is_connected(_on_auto_attack):
		behavior_component.auto_attack_requested.disconnect(_on_auto_attack)

	## Remove old weapon base-stat modifiers so new ones don't stack
	_set_base_stat("damage",         0.0)
	_set_base_stat("attack_speed",   0.0)
	_set_base_stat("projectile_count", 0.0)

	## Remove mod modifiers from old weapon
	modifier_component.remove_by_source_prefix("mod_")
	modifier_component.remove_by_source_prefix("combo_")
	for passive_id in ["combo_static_strike"]:
		if status_effect_component.has_status(passive_id):
			status_effect_component.force_remove_status(passive_id, self)

	## Load new weapon data
	_weapon_id   = weapon_id
	_weapon_data = WeaponData.ALL.get(weapon_id, WeaponData.ALL["Hurled Steel"])
	_set_base_stat("damage",          _weapon_data.get("damage", 18.0))
	_set_base_stat("attack_speed",    _weapon_data.get("attack_speed", 1.0))
	_set_base_stat("projectile_count", _weapon_data.get("projectile_count", 1))

	## Build new weapon ability (no mods — the player didn't bring a loadout for this weapon)
	_active_mods   = []
	_weapon_ability = WeaponFactory.build_weapon_ability(_weapon_id, _weapon_data, _active_mods)

	## Re-wire behavior and ability components
	var attack_interval: float = _weapon_ability.cooldown_base
	behavior_component.setup(modifier_component, attack_interval)
	if _weapon_data.get("behavior", "") != "orbit":
		behavior_component.auto_attack_requested.connect(_on_auto_attack)
	ability_component.setup_abilities(_weapon_ability, [], 1)
	_cache_projectile_base_stats()
	## Rebuild the combo for the new weapon's damage (Fighter keeps its class combo).
	_load_combo()

	if _weapon_data.get("behavior") == "orbit":
		call_deferred("_setup_orbit_orbs")


func _cache_projectile_base_stats() -> void:
	## Snapshot base pierce/scale/radius from the built ProjectileConfig so
	## _on_auto_attack can apply player stat upgrades on top without compounding.
	if _weapon_ability == null:
		return
	for effect in _weapon_ability.effects:
		if effect is SpawnProjectilesEffect:
			_base_proj_pierce     = effect.projectile.pierce_count
			_base_proj_scale      = effect.projectile.visual_scale
			_base_proj_hit_radius = effect.projectile.hit_radius
			return
	_base_proj_pierce     = 0
	_base_proj_scale      = Vector2.ONE
	_base_proj_hit_radius = 8.0


func _on_auto_attack(ability: AbilityDefinition, targets: Array) -> void:
	## Engine callback: BehaviorComponent resolved targets.
	## Stats are synced and locked in NOW (swing-start); projectile fires at swing-end.
	if not is_alive:
		return
	## Manual aim may whiff (no enemies in the cursor line/arc) — still play the swing so
	## beams/arcs render toward the cursor; damage just resolves to an empty set.
	var manual_aim: bool = _pending_aim_dir != Vector2.ZERO
	if targets.is_empty() and not manual_aim:
		return
	attack_target = targets[0] if not targets.is_empty() else null

	# Sync live stats into weapon effects — locked in at swing-start
	var proj_count: int = int(get_stat("projectile_count"))
	var pierce_bonus: int = int(get_stat("pierce"))
	var size_mult: float = get_stat("projectile_size")
	for effect in ability.effects:
		if effect is SpawnProjectilesEffect:
			effect.count = proj_count
			## -1 = pierce-all (e.g. The Deep's Pull); never downgrade it with a finite bonus.
			effect.projectile.pierce_count = -1 if _base_proj_pierce == -1 else _base_proj_pierce + pierce_bonus
			effect.projectile.visual_scale = _base_proj_scale * size_mult
			effect.projectile.hit_radius   = _base_proj_hit_radius * size_mult
	## Beam: sync live projectile_count → targeting so next resolve picks up multi-beam
	if ability.tags.has("Beam") and ability.targeting != null:
		ability.targeting.max_targets = proj_count

	# Store pending shot — will be executed at the end of the attack animation
	_pending_ability = ability
	_pending_targets = targets  # Node2D refs; validity checked before firing

	# Play attack animation and schedule firing at the last frame
	if not _is_dying:
		_attack_anim_active = true
		_play_anim("attack")
	var frame_count: int = sprite.sprite_frames.get_frame_count("attack")
	var fps: float = sprite.sprite_frames.get_animation_speed("attack")
	var fire_delay: float = float(frame_count) / fps
	get_tree().create_timer(fire_delay).timeout.connect(_fire_pending_shot, CONNECT_ONE_SHOT)


func _fire_pending_shot() -> void:
	## Execute the stored projectile/beam/melee at the end of the swing animation.
	if not is_alive or _pending_ability == null:
		_clear_pending_shot()
		return
	var manual_aim: bool = _pending_aim_dir != Vector2.ZERO
	# Filter targets that are no longer valid (died during swing)
	var valid_targets: Array = _pending_targets.filter(func(t: Node) -> bool: return is_instance_valid(t))
	# Auto-fire only: if the original target died mid-swing, re-aim at the nearest live
	# enemy so the throw always releases. Manual aim keeps its cursor line — a whiff stays
	# a whiff, and the swing/beam still renders toward the cursor (no damage).
	if not manual_aim:
		if valid_targets.is_empty() and spatial_grid != null:
			var nearest: Node2D = spatial_grid.find_nearest(global_position, 1)
			if is_instance_valid(nearest):
				valid_targets.append(nearest)
		if valid_targets.is_empty():
			_clear_pending_shot()
			return

	EffectDispatcher.execute_effects(_pending_ability.effects, self, valid_targets, _pending_ability, combat_manager)
	EventBus.on_ability_used.emit(self, _pending_ability)

	# Weapon-specific visual feedback
	var scene_root: Node = get_tree().current_scene
	var tint: Color = _weapon_data.get("tint", Color.WHITE)
	if _pending_ability.tags.has("Beam"):
		if manual_aim:
			## One beam straight down the cursor line (corridor enemies already took the
			## hit); endpoint at max range so the beam reads even when it whiffs.
			var beam_range: float = _pending_ability.targeting.max_range if _pending_ability.targeting else 285.0
			var endpoint: Vector2 = global_position + _pending_aim_dir * beam_range
			PlayerVfxHelper.spawn_beam_flash(self, scene_root, global_position, endpoint, tint, _pending_ability.ability_id, 0)
			PlayerVfxHelper.cleanup_stale_beam_containers(self, 1)
			if "napalm" in _active_mods:
				_spawn_scorched_earth_patches(global_position, endpoint, scene_root)
		else:
			var active_beams: int = 0
			for i in valid_targets.size():
				if is_instance_valid(valid_targets[i]):
					PlayerVfxHelper.spawn_beam_flash(self, scene_root, global_position, valid_targets[i].global_position, tint, _pending_ability.ability_id, i)
					active_beams += 1
					if "napalm" in _active_mods:
						_spawn_scorched_earth_patches(global_position, valid_targets[i].global_position, scene_root)
			PlayerVfxHelper.cleanup_stale_beam_containers(self, active_beams)
	elif _pending_ability.tags.has("Melee"):
		var swing_dir: Vector2
		if manual_aim:
			swing_dir = _pending_aim_dir
		elif not valid_targets.is_empty() and is_instance_valid(valid_targets[0]):
			swing_dir = (valid_targets[0].global_position - global_position).normalized()
		else:
			swing_dir = Vector2.RIGHT
		## Range: read from the processed ability so size mod scaling is included.
		var range_px: float = _pending_ability.targeting.max_range
		## Arc: scale with size mod (same mult the factory applies to range).
		var arc_deg: float = _weapon_data.get("arc_degrees", 200.0)
		if "size" in _active_mods:
			arc_deg *= ModData.ALL["size"]["params"].get("size_mult", 1.5)
		PlayerVfxHelper.spawn_melee_arc(self, scene_root, global_position, swing_dir.angle(), range_px, deg_to_rad(arc_deg * 0.5), tint, _active_mods)
	elif _pending_ability.tags.has("Artillery") and not valid_targets.is_empty() and is_instance_valid(valid_targets[0]):
		var scatter    := Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
		var target_pos: Vector2 = valid_targets[0].global_position + scatter
		PlayerVfxHelper.spawn_artillery_marker(self, scene_root, target_pos, _weapon_data.get("aoe_radius", 64.0), _weapon_data.get("fuse_time", 1.0), tint)

	_clear_pending_shot()


func _clear_pending_shot() -> void:
	_pending_ability = null
	_pending_targets.clear()
	_pending_aim_dir = Vector2.ZERO


# --- Main loop ---

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	# Iframe countdown
	if _iframes_timer > 0.0:
		_iframes_timer -= delta
		if _iframes_timer <= 0.0:
			if _hit_flash_tween and _hit_flash_tween.is_valid():
				_hit_flash_tween.kill()
				_hit_flash_tween = null
			sprite.modulate = Color.WHITE

	# Movement (CC-aware)
	var move_blocked: bool = status_effect_component.is_disabled() or status_effect_component.is_movement_disabled()
	var input_dir := Vector2.ZERO
	if not move_blocked:
		input_dir = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up",   "move_down")
		).normalized()
	if input_dir.length_squared() > 0.0:
		_last_move_dir = input_dir

	# Dash: refill charges, then consume one on press (CC blocks both starting a dash
	# and is checked the same way the movement block is).
	_tick_dash_cooldown(delta)
	if not move_blocked and Input.is_action_just_pressed("dash"):
		_try_dash(input_dir)

	var move_speed_val: float = get_stat("move_speed")
	var target_velocity: Vector2 = input_dir * move_speed_val
	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			# Dash ended — drop i-frames and snap to normal movement so there's no
			# floaty residual velocity to slide on.
			is_invulnerable = false
			_set_dash_phasing(false)  # restore enemy body collision
			velocity = target_velocity
		else:
			# Ease-out impulse: high speed at start, tapering toward the tail.
			var p: float = 1.0 - (_dash_timer / DASH_DURATION)  ## 0 -> 1 over the dash
			var ease_factor: float = 1.0 - DASH_EASE_OUT * p * p
			velocity = _dash_dir * (_dash_speed_current * ease_factor)
	else:
		velocity = velocity.move_toward(target_velocity, 1500.0 * delta)
	velocity += knockback_velocity
	move_and_slide()
	# Snap sprite to pixel grid without discarding fractional physics position.
	# Rounding position itself loses sub-pixel accumulation each frame, cutting
	# diagonal speed by ~15% vs ~10% cardinal (diagonal per-axis step is smaller).
	if sprite:
		sprite.position = position.round() - position
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 1400.0 * delta)

	if sprite:
		_update_facing()
		## Legacy mirror-flip only for baked frames without directional rows.
		if not _has_dir_anims and input_dir.x != 0:
			sprite.flip_h = input_dir.x < 0
		if not _attack_anim_active and not _damage_anim_active and not _is_dying:
			if input_dir.length_squared() > 0:
				_play_anim("walk")
			else:
				_play_anim("idle")

	# Combo input bookkeeping + executor tick (cheap, runs every frame so held-tracking stays exact)
	if _combat_input:
		_combat_input.tick()
	if skill_component:
		skill_component.tick(delta)
	if choreography_runner and choreography_runner.is_running():
		# CC interrupts an active combo, same as it interrupts enemy choreography
		if status_effect_component.is_disabled():
			choreography_runner.interrupt()
		else:
			choreography_runner.tick(delta)

	# Attack: melee-combo characters run the combo graph; everyone else uses weapon fire.
	# BehaviorComponent.tick handles auto-attack timer and targeting.
	# Note: orchestrator also ticks behavior, but player needs per-frame firing
	# since orchestrator tick order is status→cooldown→behavior
	if not status_effect_component.is_disabled():
		if _combo_ability != null:
			_tick_combo()
		elif manual_fire_mode:
			_tick_manual_fire(delta)
		else:
			behavior_component.tick(delta, self)


# --- Manual fire (testing) ---

func toggle_manual_fire() -> bool:
	## Flip manual fire mode (driven by the F1 debug panel "Auto Fire" toggle). Manual is the
	## default; turning it off restores legacy auto-fire. Returns the new manual_fire_mode.
	manual_fire_mode = not manual_fire_mode
	## Reset the shared attack timer so the first shot after a mode switch is prompt.
	if behavior_component:
		behavior_component.auto_attack_timer = 0.0
	return manual_fire_mode


func _tick_manual_fire(delta: float) -> void:
	## Hold "fire" to shoot toward the mouse cursor at the weapon's normal cadence.
	## Reuses BehaviorComponent's timer + interval so attack-speed mods apply identically.
	if not Input.is_action_pressed("fire"):
		return
	behavior_component.auto_attack_timer -= delta
	if behavior_component.auto_attack_timer > 0.0:
		return
	var aa: AbilityDefinition = ability_component.get_auto_attack()
	if aa == null:
		return
	## Orbit weapons are passive (orbs self-manage their hits) — nothing to fire manually.
	if aa.tags.has("Orbit"):
		return
	var aim_pos: Vector2 = get_global_mouse_position()
	var aim_dir: Vector2 = aim_pos - global_position
	aim_dir = aim_dir.normalized() if aim_dir.length_squared() > 0.0 else _last_move_dir
	## Lock in the aim direction so _on_auto_attack / _fire_pending_shot render toward the
	## cursor and skip the auto re-aim. Resolve damage targets per weapon class (below).
	_pending_aim_dir = aim_dir
	_on_auto_attack(aa, _resolve_manual_targets(aa, aim_dir, aim_pos))
	behavior_component.auto_attack_timer = behavior_component.get_effective_attack_interval()


func _resolve_manual_targets(ability: AbilityDefinition, aim_dir: Vector2, aim_pos: Vector2) -> Array:
	## Pick the shot's targets from the cursor aim, per weapon class:
	##  • Beam  — real enemies along the aim ray (DealDamage hits them directly).
	##  • Melee — real enemies inside the swing arc toward the cursor.
	##  • Projectile/Spread — the phantom marker (direction stand-in; damage via collision).
	##  • Artillery — the phantom marker at the cursor (GroundZone detonates there).
	if ability.tags.has("Beam"):
		return _resolve_beam_targets(ability, aim_dir)
	if ability.tags.has("Melee"):
		return _resolve_melee_targets(ability, aim_dir)
	## Projectile / Spread / Artillery — marker provides the aim point.
	return [_get_aim_target(aim_pos)]


func _resolve_beam_targets(ability: AbilityDefinition, aim_dir: Vector2) -> Array:
	## Enemies within a thin corridor along the aim ray (in front, near the line),
	## nearest first, capped at the live projectile_count (multi-beam stat).
	if spatial_grid == null or ability.targeting == null:
		return []
	var max_range: float = ability.targeting.max_range
	var max_targets: int = maxi(1, int(get_stat("projectile_count")))
	const BEAM_HALF_WIDTH: float = 20.0
	var candidates: Array = spatial_grid.get_nearby_in_range(global_position, 1, max_range * max_range)
	var hits: Array = []
	for e in candidates:
		if not is_instance_valid(e) or not e.is_alive:
			continue
		var to_e: Vector2 = e.global_position - global_position
		var along: float = to_e.dot(aim_dir)
		if along <= 0.0:
			continue  ## behind the aim direction
		var perp: float = (to_e - aim_dir * along).length()
		if perp <= BEAM_HALF_WIDTH:
			hits.append(e)
	hits.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	if hits.size() > max_targets:
		hits = hits.slice(0, max_targets)
	return hits


func _resolve_melee_targets(ability: AbilityDefinition, aim_dir: Vector2) -> Array:
	## Enemies within max_range and inside the swing arc centred on the cursor direction.
	if spatial_grid == null or ability.targeting == null:
		return []
	var max_range: float = ability.targeting.max_range
	var arc_deg: float = _weapon_data.get("arc_degrees", 170.0)
	if "size" in _active_mods:
		arc_deg *= ModData.ALL["size"]["params"].get("size_mult", 1.5)
	var half_arc: float = deg_to_rad(arc_deg * 0.5)
	var candidates: Array = spatial_grid.get_nearby_in_range(global_position, 1, max_range * max_range)
	var hits: Array = []
	for e in candidates:
		if not is_instance_valid(e) or not e.is_alive:
			continue
		var to_e: Vector2 = e.global_position - global_position
		if to_e.length_squared() <= 0.0:
			hits.append(e)
			continue
		if absf(aim_dir.angle_to(to_e)) <= half_arc:
			hits.append(e)
	return hits


func _get_aim_target(aim_pos: Vector2 = Vector2.INF) -> Node2D:
	## Persistent invisible world-space marker parked at the mouse cursor; reused each shot.
	## Uses AimMarkerScript so it carries `is_alive` — the projectile spawn guards and
	## EffectDispatcher read that off the target and would crash on a bare Node2D.
	if _aim_marker == null or not is_instance_valid(_aim_marker):
		_aim_marker = AimMarkerScript.new()
		_aim_marker.name = "ManualAimMarker"
		_aim_marker.top_level = true
		get_tree().current_scene.add_child(_aim_marker)
	_aim_marker.global_position = aim_pos if aim_pos != Vector2.INF else get_global_mouse_position()
	return _aim_marker


# --- Melee combo (ChoreographyRunner host) ---
## Active only when _combo_ability is set (melee-combo weapon/character). The runner drives the
## graph; branch conditions read _combat_input. See docs/combat_chain_architecture.md.

func set_combo_ability(ability: AbilityDefinition) -> void:
	## Install (or clear) the melee combo graph. Called by _load_combo on character/weapon load.
	if choreography_runner and choreography_runner.is_running():
		choreography_runner.interrupt()
	_combo_ability = ability
	## A combo character doesn't auto-fire its weapon — the combo IS the attack. Drop the auto-attack
	## hookup so neither the player loop nor the orchestrator fires the weapon underneath the combo.
	if ability != null and behavior_component \
			and behavior_component.auto_attack_requested.is_connected(_on_auto_attack):
		behavior_component.auto_attack_requested.disconnect(_on_auto_attack)


func _load_combo() -> void:
	## Melee-combo characters drive a ChoreographyRunner combo graph + neutral skills instead of
	## weapon auto-fire. Data-driven off CharacterData "melee_kit" — a new combo character is a new
	## ChainFactory/SkillFactory case + a "melee_kit" field, no edits here. The weapon feeds damage.
	var char_id: String = ProgressionManager.selected_character
	var char_data: Dictionary = CharacterData.ALL.get(char_id, {})
	var kit_id: String = char_data.get("melee_kit", "")
	if kit_id != "":
		var kit: Dictionary = ChainFactory.build_kit(kit_id, _weapon_data)
		set_combo_ability(kit.get("light"))
		_combo_heavy = kit.get("heavy")
		_combo_channel = kit.get("channel")
	else:
		set_combo_ability(null)
		_combo_heavy = null
		_combo_channel = null
	## RMB specials are combo abilities now, not numbered skills.
	if skill_component:
		skill_component.clear()


func _tick_combo() -> void:
	## From neutral: LMB starts the light combo; RMB tap starts the heavy combo (Uppercut→Cataclysm),
	## RMB hold starts the Taunt channel. Mid-combo RMB is handled by the runner's branches, not here,
	## since this returns early while the runner is active.
	if choreography_runner == null or choreography_runner.is_running():
		_rmb_pending = false   ## a combo started under us — drop any pending neutral RMB
		return

	if Input.is_action_just_pressed("light_attack"):
		## Consume the opening tap so the first cancel window doesn't read it as an advance.
		if _combat_input:
			_combat_input.consume("light_attack")
		choreography_runner.start(_combo_ability, [self])
		return

	## Neutral RMB: distinguish tap (heavy combo) from hold (Taunt channel) via held duration.
	if _combat_input == null:
		return
	if Input.is_action_just_pressed("heavy_attack"):
		_rmb_pending = true
	if _rmb_pending:
		if _combat_input.held_for("heavy_attack") >= TAUNT_HOLD_THRESHOLD:
			_start_taunt_channel()
			_rmb_pending = false
		elif Input.is_action_just_released("heavy_attack"):
			## Consume so Uppercut's follow-up window doesn't read this same tap as the Cataclysm advance.
			_combat_input.consume("heavy_attack")
			if _combo_heavy != null:
				choreography_runner.start(_combo_heavy, [self])
			_rmb_pending = false


func _start_taunt_channel() -> void:
	if _combo_channel == null:
		return
	## Slow the player ~20% while channeling — trade-off for the ongoing shockwave.
	modifier_component.remove_by_source_prefix("combo_taunt")
	_add_modifier("move_speed", "bonus", -0.20, "combo_taunt")
	choreography_runner.start(_combo_channel, [self])


# --- ChoreographyRunner host interface ---

func choreo_sprite() -> AnimatedSprite2D:
	return sprite


func choreo_resolve_targets(_rule: TargetingRule) -> Array:
	## Combos self-center (AoE around the player); no external retargeting needed.
	return [self]


func choreo_fire_effects(effects: Array, _targets: Array, ability: AbilityDefinition) -> void:
	## Route each combo/skill effect to the right target set:
	##  • AreaDamageEffect — self-centers: fire on [self] so EffectDispatcher resolves the AoE around
	##    the player and excludes us. Radius scales with the melee_range stat (the "Reach" hook),
	##    applied to a duplicate so the base resource isn't compounded across swings.
	##  • DisplacementEffect (Uppercut fling) — dispatched per-enemy (the system displaces one target
	##    per call), targeting nearby enemies, knockback away from the player.
	##  • anything else — fire on the nearby-enemy set.
	var reach: float = _melee_range()
	## Bomb detonation: this callback IS the hit_frame moment — swap the tossed bomb for the
	## package explosion at its world landing spot.
	var is_bomb: bool = sprite != null and String(sprite.animation).begins_with("bomb")
	if is_bomb:
		_detonate_bomb_fx(reach)
	## Holy Hammer (Paladin): the slam also launches the hammerdin spiral — blessed hammers
	## corkscrewing out from the Warden (HolyHammer nodes carry their own damage/visuals).
	if sprite != null and String(sprite.animation).begins_with("hammer"):
		_spawn_holy_hammers(reach)
	var cur_anim: String = String(sprite.animation) if sprite else ""
	## Companion summons: the ignition burst also spawns/refreshes the kit's companion.
	## (Order matters — "summon_blood" must not fall into the generic "summon" case.)
	if cur_anim.begins_with("summon_blood"):
		_spawn_blood_elemental()
	elif cur_anim.begins_with("summon"):
		_spawn_fire_familiar()
	var is_torrent: bool = cur_anim.begins_with("torrent")
	var is_teleport: bool = cur_anim.begins_with("teleport_out")
	var is_extract: bool = cur_anim.begins_with("extract")
	var is_spikes: bool = cur_anim.begins_with("spikes")
	var is_vamp_rip: bool = cur_anim.begins_with("vampirize")
	var is_vamp_drink: bool = cur_anim.begins_with("consume")
	var self_effects: Array = []
	var enemy_effects: Array = []
	var proj_effects: Array = []
	var buff_effects: Array = []
	var aoe_radius: float = 0.0
	for e in effects:
		if e is AreaDamageEffect:
			if is_equal_approx(reach, 1.0):
				self_effects.append(e)
			else:
				var scaled: AreaDamageEffect = e.duplicate()
				scaled.aoe_radius = e.aoe_radius * reach
				self_effects.append(scaled)
			if aoe_radius <= 0.0:
				aoe_radius = e.aoe_radius * reach
		elif e is SpawnProjectilesEffect:
			proj_effects.append(e)
		elif e is ApplyStatusEffectData and e.apply_to_self:
			buff_effects.append(e)   ## self-buffs (Extract Power) — applied to the player
		else:
			enemy_effects.append(e)

	## Vampirize extract beat: sample BEFORE the drain AoE dispatches — a drain that kills
	## its victims still counts as blood found (the kill must feed the drink).
	if is_vamp_rip:
		_vamp_hit = not _nearby_enemies(50.0 * reach).is_empty()

	if not self_effects.is_empty():
		## The bomb's blast centers on its landing point, the torrent a short way toward the
		## cursor (aim-marker targets); every other combo AoE self-centers on the player.
		var center: Node2D = self
		if is_bomb:
			center = _get_aim_target(_bomb_land)
		elif is_torrent:
			var t_aim: Vector2 = get_global_mouse_position() - global_position
			if t_aim.length_squared() >= 1.0:
				center = _get_aim_target(global_position + t_aim.normalized() * TORRENT_FORWARD)
		EffectDispatcher.execute_effects(self_effects, self, [center], ability, combat_manager)

	if not proj_effects.is_empty():
		## Cursor-aimed casts (Wizard/Blood Mage projectiles): "aimed_single"/"spread" read
		## source.attack_target — park it on the aim cursor, then route through the normal
		## projectile pipeline.
		attack_target = _get_aim_target()
		EffectDispatcher.execute_effects(proj_effects, self, [self], ability, combat_manager)

	if not buff_effects.is_empty():
		EffectDispatcher.execute_effects(buff_effects, self, [self], ability, combat_manager)

	## Teleport blinks AFTER its departure burst has resolved at the old position.
	if is_teleport:
		_do_teleport()
	## Extract Power: the pact's price — paid as the buff lands.
	if is_extract:
		_pay_blood_cost()
	## Blood Spikes: ground-burst sheet at the hit-zone radius.
	if is_spikes:
		_spawn_spikes_ground(aoe_radius)
	## Vampirize consume beat: drink the blood the extract beat found (heal + drain wisp).
	if is_vamp_drink and _vamp_hit:
		health.apply_healing(health.max_hp * VAMP_HEAL_FRAC)
		var victims: Array = _nearby_enemies(50.0 * reach)
		if not victims.is_empty():
			_spawn_drain_wisp(victims[0].global_position)

	if not enemy_effects.is_empty():
		var enemies: Array = _nearby_enemies(90.0 * reach)
		if not enemies.is_empty():
			for e in enemy_effects:
				if e is DisplacementEffect:
					if combat_manager and combat_manager.get("displacement_system"):
						for en in enemies:
							combat_manager.displacement_system.execute(self, ability, e, [en])
				else:
					EffectDispatcher.execute_effects([e], self, enemies, ability, combat_manager)


func _nearby_enemies(radius: float) -> Array:
	## Live enemies within `radius` of the player (faction 1 = enemies in the spatial grid).
	if spatial_grid == null:
		return []
	var out: Array = []
	for en in spatial_grid.get_nearby_in_range(global_position, 1, radius * radius):
		if is_instance_valid(en) and en.is_alive:
			out.append(en)
	return out


func choreo_on_phase_anim(phase: ChoreographyPhase) -> void:
	## Runner calls this when a combo node's body anim starts → play the matching swing effect, sized
	## to THIS node's hit-zone radius so the white edge marks exactly where the hitbox reaches.
	var anim: String = phase.animation
	var reach: float = _melee_range()
	var radius: float = _node_hit_radius(phase) * reach   ## effective hit-zone radius (incl. capped Reach)

	## Big-impact nodes with no _fx sheet (Taunt, Paladin Hammer) ring out a procedural
	## shockwave at the hit-zone radius instead.
	if anim == "taunt" or anim == "hammer":
		if _combo_fx:
			_combo_fx.visible = false
		_spawn_shockwave_ring(radius)
		return
	## Rogue Bomb: toss the package's spinning bomb projectile during the wind-up; the explosion
	## ("bomb_fx") is played at detonation by choreo_fire_effects, not at anim start.
	if anim == "bomb":
		if _combo_fx:
			_combo_fx.visible = false
		_start_bomb_toss()
		return
	## Wizard Fire Torrent: dedicated directional flame overlay ahead of the caster.
	if anim == "torrent":
		if _combo_fx:
			_combo_fx.visible = false
		_show_torrent_fx()
		return
	if _torrent_fx:
		_torrent_fx.visible = false   ## any non-torrent node ends the flame
	## Blood Mage Vampirize: Floating_Blood hovers over the Cursed through both channel beats.
	if anim == "vampirize" or anim == "consume":
		if _combo_fx:
			_combo_fx.visible = false
		_show_vamp_fx()
		return
	if _vamp_fx:
		_vamp_fx.visible = false      ## any non-vampirize node ends the float
	if _combo_fx == null or _combo_fx.sprite_frames == null:
		return
	## Facing variant of the swing effect when the fx sheet has directional rows.
	var fx: String = anim + "_fx"
	if _combo_fx.sprite_frames.has_animation(fx + "_" + _facing):
		fx = fx + "_" + _facing
		_combo_fx.flip_h = false
	elif _combo_fx.sprite_frames.has_animation(fx):
		_combo_fx.flip_h = sprite.flip_h
	else:
		_combo_fx.visible = false
		return
	## Centered, scaled so the white's outer edge sits on the node's hit-zone radius. Nodes with
	## no AreaDamage radius (projectile casts — e.g. Wizard bolts) play frame-matched at native
	## size, only growing with Reach.
	var s: float = (radius / FX_NATIVE_RADIUS) if radius > 0.0 else reach
	_combo_fx.position = Vector2.ZERO
	_combo_fx.scale = Vector2(s, s)
	_combo_fx.visible = true
	_combo_fx.play(fx)


func _node_hit_radius(phase: ChoreographyPhase) -> float:
	## The node's AreaDamage hit radius (0.0 if it has none, e.g. a pure-displacement node).
	for e in phase.effects:
		if e is AreaDamageEffect:
			return e.aoe_radius
	return 0.0


func _melee_range() -> float:
	## melee_range stat, capped at MELEE_RANGE_MAX so reach tops out at the end-of-the-road size.
	return minf(get_stat("melee_range"), MELEE_RANGE_MAX)


func _on_combo_fx_finished() -> void:
	if _combo_fx:
		_combo_fx.visible = false
		_combo_fx.position = Vector2.ZERO   ## undo any bomb-landing offset


func _start_bomb_toss() -> void:
	## Toss the Throw Bomb package's spinning projectile from the player toward the cursor
	## (clamped throw range), world-anchored so it doesn't ride along with the player. The
	## directional cell of the 3×3 projectile grid is picked from the throw octant.
	if _bomb_toss == null:
		_bomb_toss = AnimatedSprite2D.new()
		_bomb_toss.name = "BombToss"
		_bomb_toss.top_level = true   ## world space — the bomb is NOT attached to the player
		_bomb_toss.z_index = 1
		_bomb_toss.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sf := SpriteFrames.new()
		sf.clear_all()
		sf.add_animation(&"spin")
		sf.set_animation_loop(&"spin", true)
		sf.set_animation_speed(&"spin", 12.0)   ## frame 1/2 alternate = the fuse flicker
		_bomb_atlases.clear()
		for path in BOMB_PROJ_SHEETS:
			if not ResourceLoader.exists(path):
				continue
			var atlas := AtlasTexture.new()
			atlas.atlas = load(path)
			atlas.region = _bomb_cell(Vector2.DOWN)
			atlas.filter_clip = true
			sf.add_frame(&"spin", atlas)
			_bomb_atlases.append(atlas)
		## The package explosion, played at the landing point on detonation.
		sf.add_animation(&"explode")
		sf.set_animation_loop(&"explode", false)
		sf.set_animation_speed(&"explode", 20.0)
		if ResourceLoader.exists(BOMB_EXPLOSION_SHEET):
			var ex: Texture2D = load(BOMB_EXPLOSION_SHEET)
			for i in range(int(ex.get_width() / 32.0)):
				var cell := AtlasTexture.new()
				cell.atlas = ex
				cell.region = Rect2(i * 32, 0, 32, 32)
				cell.filter_clip = true
				sf.add_frame(&"explode", cell)
		_bomb_toss.sprite_frames = sf
		_bomb_toss.animation_finished.connect(_on_bomb_anim_finished)
		add_child(_bomb_toss)
	var aim: Vector2 = get_global_mouse_position() - global_position
	if aim.length_squared() < 1.0:
		aim = Vector2.DOWN
	_bomb_start = global_position
	_bomb_land = global_position + aim.limit_length(BOMB_THROW_MAX)
	for at in _bomb_atlases:
		at.region = _bomb_cell(aim)
	_bomb_toss.scale = Vector2.ONE
	_bomb_toss.global_position = _bomb_start
	_bomb_toss.visible = true
	_bomb_toss.play(&"spin")
	if _bomb_tween:
		_bomb_tween.kill()
	_bomb_tween = create_tween()
	_bomb_tween.tween_method(_bomb_arc_step, 0.0, 1.0, BOMB_TOSS_TIME)


func _bomb_arc_step(t: float) -> void:
	## Parabolic hop between the world-space start and landing points.
	if _bomb_toss:
		_bomb_toss.global_position = _bomb_start.lerp(_bomb_land, t) \
				+ Vector2(0.0, -BOMB_ARC_H * 4.0 * t * (1.0 - t))


## Octant → cell of the 3×3 directional projectile grid (screen y-down: row 0 = up, row 2 = down).
static func _bomb_cell(dir: Vector2) -> Rect2:
	var oct: int = wrapi(roundi(atan2(dir.y, dir.x) / (PI / 4.0)), 0, 8)   ## 0=E,1=SE,…,7=NE
	var cells: Array = [Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2),
			Vector2i(0, 1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var c: Vector2i = cells[oct]
	return Rect2(c.x * 32, c.y * 32, 32, 32)


func _spawn_fire_familiar() -> void:
	## One familiar at a time — resummon replaces (the old one disperses).
	if is_instance_valid(_fire_familiar):
		_fire_familiar.disperse()
	var fam := FireFamiliar.new()
	fam.player_ref = self
	fam.damage_type = ChainFactory._damage_type(_weapon_data)
	get_tree().current_scene.add_child(fam)
	var side: float = -1.0 if _facing.ends_with("left") else 1.0
	fam.global_position = global_position + Vector2(18.0 * side, -14.0)
	_fire_familiar = fam


func _do_teleport() -> void:
	## Blink to the cursor (clamped). The departure burst already fired at the old spot; the
	## teleport_in phase plays at the destination. CharacterBody2D depenetrates on the next
	## move_and_slide if the landing point clips a wall edge.
	var aim: Vector2 = get_global_mouse_position() - global_position
	if aim.length_squared() < 1.0:
		return
	global_position += aim.limit_length(TELEPORT_RANGE)


func _show_torrent_fx() -> void:
	## Directional Fire_Torrent_Effect (64px frames, 4 facing rows) pours toward the cursor
	## while the channel loops; repositioned/re-rowed on every tick re-entry.
	if _torrent_fx == null:
		_torrent_fx = AnimatedSprite2D.new()
		_torrent_fx.name = "TorrentFx"
		_torrent_fx.z_index = 1
		_torrent_fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sf := SpriteFrames.new()
		sf.clear_all()
		var tex: Texture2D = load(TORRENT_FX_SHEET)
		if tex:
			for facing in CharacterSpriteFactory.DIR_ROWS:
				var anim := StringName("t_" + facing)
				sf.add_animation(anim)
				sf.set_animation_loop(anim, true)
				sf.set_animation_speed(anim, 30.0)
				for i in range(int(tex.get_width() / 64.0)):
					var cell := AtlasTexture.new()
					cell.atlas = tex
					cell.region = Rect2(i * 64, int(CharacterSpriteFactory.DIR_ROWS[facing]) * 64, 64, 64)
					cell.filter_clip = true
					sf.add_frame(anim, cell)
		_torrent_fx.sprite_frames = sf
		add_child(_torrent_fx)
	var aim: Vector2 = get_global_mouse_position() - global_position
	if aim.length_squared() >= 1.0:
		_torrent_fx.position = aim.normalized() * TORRENT_FORWARD
	_torrent_fx.visible = true
	var anim_name := StringName("t_" + _facing)
	if _torrent_fx.animation != anim_name or not _torrent_fx.is_playing():
		_torrent_fx.play(anim_name)


func _spawn_blood_elemental() -> void:
	## One elemental at a time — resummon replaces (the old one banishes).
	if is_instance_valid(_blood_elemental):
		_blood_elemental.banish()
	var ele := BloodElemental.new()
	ele.player_ref = self
	ele.damage_type = ChainFactory._damage_type(_weapon_data)
	get_tree().current_scene.add_child(ele)
	var side: float = -1.0 if _facing.ends_with("left") else 1.0
	ele.global_position = global_position + Vector2(22.0 * side, 4.0)
	_blood_elemental = ele


func _pay_blood_cost() -> void:
	## Extract Power's price: flat cut of max HP, never lethal, outside the damage pipeline
	## (no dodge/armor/i-frames — a pact, not an attack).
	var cost: float = maxf(1.0, health.max_hp * BLOOD_COST_FRAC)
	health.current_hp = maxf(1.0, health.current_hp - cost)
	health.health_changed.emit(health.current_hp, health.max_hp)


func _spawn_spikes_ground(radius: float) -> void:
	## One-shot Blood_Spikes_AOE ground burst under the player, scaled to the hit zone.
	if not ResourceLoader.exists(SPIKES_AOE_SHEET):
		return
	var tex: Texture2D = load(SPIKES_AOE_SHEET)
	var burst := AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.clear_all()
	sf.add_animation(&"burst")
	sf.set_animation_loop(&"burst", false)
	sf.set_animation_speed(&"burst", 18.0)
	for i in range(int(tex.get_width() / 32.0)):
		var cell := AtlasTexture.new()
		cell.atlas = tex
		cell.region = Rect2(i * 32, 0, 32, 32)
		cell.filter_clip = true
		sf.add_frame(&"burst", cell)
	burst.sprite_frames = sf
	burst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	burst.z_index = 1
	get_tree().current_scene.add_child(burst)
	burst.global_position = global_position
	var s: float = (radius / FX_NATIVE_RADIUS) if radius > 0.0 else 2.0
	burst.scale = Vector2(s, s)
	burst.play(&"burst")
	burst.animation_finished.connect(burst.queue_free)


func _spawn_drain_wisp(at: Vector2) -> void:
	## One-shot Drain_Effect wisp at the drained victim.
	if not ResourceLoader.exists(DRAIN_WISP_SHEET):
		return
	var tex: Texture2D = load(DRAIN_WISP_SHEET)
	var wisp := AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.clear_all()
	sf.add_animation(&"drain")
	sf.set_animation_loop(&"drain", false)
	sf.set_animation_speed(&"drain", 14.0)
	for i in range(int(tex.get_width() / 32.0)):
		var cell := AtlasTexture.new()
		cell.atlas = tex
		cell.region = Rect2(i * 32, 0, 32, 32)
		cell.filter_clip = true
		sf.add_frame(&"drain", cell)
	wisp.sprite_frames = sf
	wisp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wisp.z_index = 1
	get_tree().current_scene.add_child(wisp)
	wisp.global_position = at
	wisp.play(&"drain")
	wisp.animation_finished.connect(wisp.queue_free)


func _show_vamp_fx() -> void:
	## Floating_Blood loops above the Cursed while Vampirize channels.
	if _vamp_fx == null:
		_vamp_fx = AnimatedSprite2D.new()
		_vamp_fx.name = "VampFx"
		_vamp_fx.z_index = 1
		_vamp_fx.position = Vector2(0.0, -18.0)
		_vamp_fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sf := SpriteFrames.new()
		sf.clear_all()
		var tex: Texture2D = load(FLOATING_BLOOD_SHEET)
		if tex:
			sf.add_animation(&"float")
			sf.set_animation_loop(&"float", true)
			sf.set_animation_speed(&"float", 10.0)
			for i in range(int(tex.get_width() / 32.0)):
				var cell := AtlasTexture.new()
				cell.atlas = tex
				cell.region = Rect2(i * 32, 0, 32, 32)
				cell.filter_clip = true
				sf.add_frame(&"float", cell)
		_vamp_fx.sprite_frames = sf
		add_child(_vamp_fx)
	_vamp_fx.visible = true
	if not _vamp_fx.is_playing():
		_vamp_fx.play(&"float")


const HOLY_HAMMER_COUNT: int = 3

func _spawn_holy_hammers(reach: float) -> void:
	## Launch the blessed-hammer spiral: HOLY_HAMMER_COUNT hammers at staggered angles, each
	## spiraling out around the (moving) player. Max spiral radius scales with melee_range,
	## damage reads the live damage stat inside each hammer.
	var dtype: String = ChainFactory._damage_type(_weapon_data)
	for i in range(HOLY_HAMMER_COUNT):
		var hammer := HolyHammer.new()
		hammer.player_ref = self
		hammer.damage_type = dtype
		hammer.start_angle = TAU * float(i) / float(HOLY_HAMMER_COUNT)
		hammer.max_radius = 120.0 * reach
		get_tree().current_scene.add_child(hammer)


func _detonate_bomb_fx(reach: float) -> void:
	## Swap the tossed bomb for the package explosion at its world landing spot. Starts at the
	## sheet's native size and scales ONLY with the melee_range stat (Reach mods / level picks),
	## matching the blast's damage radius (ChainFactory keys it to the same native size).
	if _bomb_tween:
		_bomb_tween.kill()
	if _bomb_toss == null or _bomb_toss.sprite_frames == null \
			or not _bomb_toss.sprite_frames.has_animation(&"explode"):
		return
	_bomb_toss.global_position = _bomb_land
	_bomb_toss.scale = Vector2.ONE * reach
	_bomb_toss.visible = true
	_bomb_toss.play(&"explode")


func _on_bomb_anim_finished() -> void:
	if _bomb_toss and _bomb_toss.animation == &"explode":
		_bomb_toss.visible = false
		_bomb_toss.scale = Vector2.ONE


func _spawn_shockwave_ring(radius: float) -> void:
	## Expanding orange ring that rings out from the player to the hit-zone edge, then fades.
	## Spawned each Taunt tick. top_level so it stays put in the world as it expands.
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(1.0, 0.55, 0.10, 0.9)
	ring.closed = true
	var pts := PackedVector2Array()
	for i in 28:
		var a: float = TAU * float(i) / 28.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	ring.points = pts
	ring.top_level = true
	ring.z_index = 1
	get_tree().current_scene.add_child(ring)
	ring.global_position = global_position
	ring.scale = Vector2(0.15, 0.15)
	var t := ring.create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector2.ONE, 0.45)
	t.tween_property(ring, "modulate:a", 0.0, 0.45)
	t.chain().tween_callback(ring.queue_free)


func choreo_execute_displacement(disp, targets: Array) -> void:
	if combat_manager and combat_manager.get("displacement_system"):
		combat_manager.displacement_system.execute(self, _combo_ability, disp, targets)


func choreo_evaluate_condition(condition: Resource, phase: ChoreographyPhase) -> bool:
	## Input-driven branch conditions (the combo's vocabulary). HP/count conditions could be added
	## here too, but the player's combos don't use them yet.
	if _combat_input == null:
		return false
	if condition is ConditionInputHeld:
		var held: bool = _combat_input.held_for(condition.action) >= condition.min_duration
		return held != condition.negate   ## negate → pass on release (channel exit)
	if condition is ConditionInputBuffered:
		var window: float = condition.within_window
		if window <= 0.0:
			window = phase.wait_duration   ## default to the phase's cancel window
		if _combat_input.was_buffered(condition.action, window):
			## Consume so a single tap can't satisfy a later node's window too.
			_combat_input.consume(condition.action)
			return true
		return false
	return false


func choreo_set_flags(untargetable: bool, invulnerable: bool) -> void:
	is_untargetable = untargetable
	if invulnerable:
		is_invulnerable = true


func choreo_on_start(_ability: AbilityDefinition) -> void:
	## Keep walk/idle from clobbering combo anims; mark attacking for the engine.
	_attack_anim_active = true
	_damage_anim_active = false
	is_attacking = true


func choreo_on_end() -> void:
	_attack_anim_active = false
	is_attacking = false
	is_untargetable = false
	if _combo_fx:
		_combo_fx.visible = false
	## An un-detonated bomb toss (combo interrupted mid-wind-up) disappears; a detonated
	## explosion is world-anchored and finishes on its own.
	if _bomb_toss and _bomb_toss.animation != &"explode":
		if _bomb_tween:
			_bomb_tween.kill()
		_bomb_toss.visible = false
	if _torrent_fx:
		_torrent_fx.visible = false
	if _vamp_fx:
		_vamp_fx.visible = false
	_vamp_hit = false
	## Drop the Taunt channel slow if it was active (no-op otherwise).
	modifier_component.remove_by_source_prefix("combo_taunt")
	## Only drop invulnerability if a dash isn't currently granting it.
	if _dash_timer <= 0.0:
		is_invulnerable = false
	if sprite and is_alive and not _is_dying and sprite.sprite_frames \
			and sprite.sprite_frames.has_animation("idle"):
		_play_anim("idle")


# --- Dash ---

func _max_dash_charges() -> int:
	## dash_charges resolves through the modifier system; clamp to int >= 1.
	return maxi(1, int(round(get_stat("dash_charges"))))


func _dash_cooldown_seconds() -> float:
	## Per-charge refill time, resolved through the modifier system. Floored so stacked
	## "Quick Recovery" (-% dash_cooldown) picks can't drive it to <=0, which would
	## leave the refill clock permanently expired and stop charges regenerating.
	return maxf(0.1, get_stat("dash_cooldown"))


func _set_dash_phasing(phasing: bool) -> void:
	## Physically pass through enemy bodies during the dash. The dash i-frames only block
	## damage; without this the player's body still collides INTO enemies (mask bit 2) and
	## enemies collide INTO the player (player layer bit 1), so a dash bumps to a halt on
	## the first body. Toggling both bits lets the dash slip through the crowd.
	## Walls are NOT on these bits, so phasing never lets the player clip through walls.
	set_collision_mask_value(2, not phasing)   ## stop colliding into enemies (layer 2)
	set_collision_layer_value(1, not phasing)  ## stop enemies colliding into us (player layer 1)


func _reset_dash_state() -> void:
	## Full charges, no active dash, timers cleared. Called on spawn and run restart.
	_dash_timer = 0.0
	_dash_cooldown_timer = 0.0
	_dash_dir = Vector2.ZERO
	_dash_speed_current = 0.0
	_dash_charges = _max_dash_charges()
	is_invulnerable = false
	_set_dash_phasing(false)  # ensure enemy body collision is restored after any reset


func _tick_dash_cooldown(delta: float) -> void:
	## Refill one charge at a time on a per-charge cooldown (read live so upgrades apply).
	var max_charges: int = _max_dash_charges()
	if _dash_charges >= max_charges:
		_dash_cooldown_timer = 0.0
		return
	if _dash_cooldown_timer <= 0.0:
		## Safety: a charge is missing but no refill is queued — start one.
		_dash_cooldown_timer = _dash_cooldown_seconds()
		return
	_dash_cooldown_timer -= delta
	if _dash_cooldown_timer <= 0.0:
		_dash_charges += 1
		## Queue the next refill if still below max; otherwise stop.
		_dash_cooldown_timer = _dash_cooldown_seconds() if _dash_charges < max_charges else 0.0


func _try_dash(input_dir: Vector2) -> void:
	## Consume a charge and start a dash impulse. No-op while already dashing or at 0 charges.
	if _dash_timer > 0.0 or _dash_charges <= 0:
		return
	var dir: Vector2 = input_dir
	if dir.length_squared() <= 0.0:
		dir = _last_move_dir
	if dir.length_squared() <= 0.0:
		dir = Vector2.RIGHT
	## Dash-cancels an in-progress combo.
	if choreography_runner and choreography_runner.is_running():
		choreography_runner.interrupt()
	_dash_dir = dir.normalized()
	_dash_speed_current = get_stat("dash_speed")
	_dash_timer = DASH_DURATION
	is_invulnerable = true
	_set_dash_phasing(true)  # slip through enemy bodies for the dash window
	_dash_charges -= 1
	## Start the refill clock if it isn't already running (don't reset a charge mid-refill).
	if _dash_cooldown_timer <= 0.0:
		_dash_cooldown_timer = _dash_cooldown_seconds()
	if sprite and not _has_dir_anims and absf(_dash_dir.x) > 0.01:
		sprite.flip_h = _dash_dir.x < 0
	_spawn_dash_vfx()


func _spawn_dash_vfx() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		PlayerVfxHelper.spawn_dash_cue(self, scene_root, sprite, global_position, _dash_dir)
	## Small camera nudge in the dash direction for a punchy departure.
	var cam := get_viewport().get_camera_2d()
	if cam and is_instance_valid(cam):
		var ct := cam.create_tween()
		ct.tween_property(cam, "offset", _dash_dir * 4.0, 0.05)
		ct.tween_property(cam, "offset", Vector2.ZERO, 0.12)


# --- Stat helpers ---

func get_stat(stat_name: String) -> float:
	## Query a stat through the modifier system.
	## Base value lives as an "add" modifier with source "base".
	## Upgrades add more "add" or "bonus" modifiers.
	var base: float = modifier_component.sum_modifiers(stat_name, "add")
	var bonus: float = modifier_component.sum_modifiers(stat_name, "bonus")
	return base * (1.0 + bonus)


func get_armor() -> float:
	var base_armor: float = modifier_component.sum_modifiers("Physical", "resist")
	# Warden passive: double armor below 50% HP
	if _passive_id == "warden_passive" and health.current_hp < health.max_hp * 0.5:
		return base_armor * 2.0
	return base_armor


func is_dead() -> bool:
	return not is_alive


func is_invisible() -> bool:
	## Shade dodge triggers brief invisibility
	return status_effect_component.has_status("shade_invisible") if status_effect_component else false


func apply_knockback(force: Vector2) -> void:
	if _iframes_timer > 0.0 or is_invulnerable:
		return
	var armor_val: float = get_armor()
	var reduction: float = armor_val / (armor_val + 15.0)
	knockback_velocity += force * (1.0 - reduction)


# --- Damage ---

func take_damage(hit_data) -> void:
	if not is_alive or god_mode:
		return
	if _iframes_timer > 0.0:
		return
	if is_invulnerable:
		return
	# NOTE: Dodge is handled by DamageCalculator Step 4 — all incoming hits
	# already went through the pipeline. If the hit wasn't dodged, it reaches here.
	# Shade invisibility on dodge is triggered by EventBus.on_dodge (see _ready).

	CombatUtils.process_incoming_damage(self, hit_data)

	# Player-specific reactions
	_iframes_timer = IFRAME_DURATION
	_start_hit_flash()
	var amount: float = hit_data.amount if hit_data is HitData else 0.0
	# Damage animation — interrupts attack, does not block movement.
	# Forgiving combo rule: small chip hits during a combo flash only (keep comboing); a real
	# hit (>10) interrupts the combo and plays the damage reaction.
	if not _is_dying:
		var combo_active: bool = choreography_runner != null and choreography_runner.is_running()
		if combo_active and amount <= 10.0:
			pass  # flash already played; let the combo continue
		else:
			if combo_active:
				choreography_runner.interrupt()
			_attack_anim_active = false
			_damage_anim_active = true
			_play_anim("damage")
	if ExtractionManager.is_channeling and amount > 10.0:
		ExtractionManager.interrupt_channel()


func _on_sprite_animation_finished() -> void:
	## During a combo the runner owns animation flow — forward and keep combat flags set.
	if choreography_runner and choreography_runner.is_running():
		choreography_runner.notify_animation_finished()
		return
	## Clear one-shot animation flags so walk/idle logic resumes.
	## Death is handled by its own await — don't clear _is_dying here.
	var anim: String = sprite.animation
	if anim == "attack":
		_attack_anim_active = false
	elif anim == "damage":
		_damage_anim_active = false


func _on_sprite_frame_changed() -> void:
	## Forward to the combo runner so it can fire effects on the active phase's hit_frame.
	if choreography_runner and choreography_runner.is_running():
		choreography_runner.notify_frame_changed()


func _start_hit_flash() -> void:
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	sprite.modulate = Color(5.0, 5.0, 5.0, 1.0)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.07)
	var blinks: int = int((IFRAME_DURATION - 0.07) / 0.14)
	for _i in range(blinks):
		_hit_flash_tween.tween_property(sprite, "modulate:a", 0.12, 0.07)
		_hit_flash_tween.tween_property(sprite, "modulate:a", 1.0,  0.07)
	var cam := get_viewport().get_camera_2d()
	if cam and is_instance_valid(cam):
		var st := cam.create_tween()
		st.tween_property(cam, "offset",
			Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0)), 0.05)
		st.tween_property(cam, "offset", Vector2.ZERO, 0.14)


func _on_dodge_received(_source, target, _hit_data) -> void:
	if target != self:
		return
	_trigger_dodge()


func _trigger_dodge() -> void:
	## Shade invisibility on dodge via engine StatusEffectDefinition — Shade only
	if _passive_id != "shade_passive":
		return
	StatusFactory.build_all()
	status_effect_component.apply_status(StatusFactory.shade_invisible, self)
	sprite.modulate = Color(0.72, 0.52, 1.0, 0.35)
	status_effect_component.status_expired.connect(
		func(sid: String):
			if sid == "shade_invisible" and is_instance_valid(self) and is_alive:
				if _iframes_timer <= 0.0:
					sprite.modulate = Color.WHITE
	, CONNECT_ONE_SHOT)


func heal(amount: float) -> void:
	if not is_alive:
		return
	health.apply_healing(amount)
	EventBus.on_heal.emit(self, self, amount)


# --- XP / leveling ---

func add_xp(amount: float) -> void:
	if not is_alive:
		return
	xp += amount
	var xp_needed := _xp_to_next_level()
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		leveled_up.emit(level)
		xp_needed = _xp_to_next_level()
	xp_changed.emit(xp, _xp_to_next_level())


func _xp_to_next_level() -> float:
	return xp_base * (1.0 + (level - 1) * xp_growth)


# --- Upgrade application ---

func apply_stat_upgrade(upgrade: Dictionary) -> void:
	## Status-type upgrades apply a permanent passive status with trigger listeners
	if upgrade.get("type") == "status":
		var status_def := StatusFactory.get_by_id(upgrade["status_id"])
		if status_def and status_effect_component:
			status_effect_component.apply_status(status_def, self)
		return

	var stat_name: String = upgrade.stat
	var value: float      = upgrade.value
	var mod := ModifierDefinition.new()
	# "damage" percent upgrades → "All" bonus (engine convention for generic damage)
	if stat_name == "damage" and upgrade.type == "percent":
		mod.target_tag = "All"
	else:
		mod.target_tag = stat_name
	if upgrade.type == "flat":
		mod.operation = "add"
	elif upgrade.type == "percent":
		mod.operation = "bonus"
	mod.value = value
	mod.source_name = "upgrade"
	modifier_component.add_modifier(mod)

	if stat_name == "max_hp" and upgrade.type == "flat":
		health.max_hp = get_stat("max_hp")
		heal(value)
	if stat_name == "pickup_radius":
		_update_pickup_radius()
	if stat_name == "dash_charges":
		## Make the new charge(s) available immediately (clamped to the new cap) instead
		## of waiting a full cooldown for the raised cap to fill in.
		_dash_charges = mini(_max_dash_charges(), _dash_charges + int(round(value)))


func remove_stat_upgrade(upgrade: Dictionary) -> void:
	## For evolution recipes that remove prerequisite upgrades.
	if upgrade.get("type") == "status":
		if status_effect_component:
			status_effect_component.remove_status(upgrade["status_id"])
		return
	## Finds and removes the first matching modifier.
	var stat_name: String = upgrade.stat
	var value: float      = upgrade.value
	var op: String = "add" if upgrade.type == "flat" else "bonus"
	for mod in modifier_component.get_all_modifiers():
		if mod.target_tag == stat_name and mod.operation == op \
				and mod.source_name == "upgrade" and absf(mod.value - value) < 0.001:
			modifier_component.remove_modifier(mod)
			break
	if stat_name == "max_hp":
		health.max_hp = get_stat("max_hp")
		health.current_hp = minf(health.current_hp, health.max_hp)
	if stat_name == "pickup_radius":
		_update_pickup_radius()


# --- Pickup collection ---

func _update_pickup_radius() -> void:
	if pickup_shape and pickup_shape.shape:
		pickup_shape.shape.radius = get_stat("pickup_radius")


func _on_pickup_area_entered(area: Area2D) -> void:
	if area.has_method("start_magnet"):
		area.start_magnet(self)


# --- Void instability debuff ---
## Apply void_touched when instability enters Volatile tier (≥70); remove with a
## hysteresis band at <60 to prevent flickering. Phase 1 is exempt (tutorial phase).

const VOID_APPLY_THRESHOLD: float = 70.0
const VOID_REMOVE_THRESHOLD: float = 60.0

func _on_instability_changed(new_value: float) -> void:
	_check_void_touched(new_value)


func _on_phase_started(phase_num: int) -> void:
	## Re-evaluate in case instability was already above threshold when phase begins.
	if phase_num >= 2:
		_check_void_touched(GameManager.instability)


func _check_void_touched(instability_value: float) -> void:
	if not is_alive or not status_effect_component:
		return
	if GameManager.phase_number < 2:
		## Phase 1 exempt — remove debuff if it somehow exists
		if status_effect_component.has_status("void_touched"):
			status_effect_component.remove_status("void_touched")
		return
	if instability_value >= VOID_APPLY_THRESHOLD \
			and not status_effect_component.has_status("void_touched"):
		StatusFactory.build_all()
		status_effect_component.apply_status(StatusFactory.void_touched, self)
	elif instability_value < VOID_REMOVE_THRESHOLD \
			and status_effect_component.has_status("void_touched"):
		status_effect_component.remove_status("void_touched")


# --- Instability Siphon ---

func _on_kill_siphon(killer: Node, victim: Node) -> void:
	if killer == self and victim.is_in_group("enemies"):
		GameManager.modify_instability(-1)


# --- Orbit orbs ---

func _setup_orbit_orbs() -> void:
	_cleanup_orbit_orbs()
	var count: int = _weapon_data.get("orbit_count", 3)
	var radius: float = _weapon_data.get("orbit_radius", 64.0)
	var spd: float = _weapon_data.get("orbit_speed", 1.8)
	var tint: Color = _weapon_data.get("tint", Color.WHITE)

	## Read size multiplier from active mods
	var size_mult: float = 1.0
	for mod_id in _active_mods:
		var mod_data: Dictionary = ModData.ALL.get(mod_id, {})
		if mod_data.get("effect_type", "") == "size":
			size_mult = mod_data.get("params", {}).get("size_mult", 1.5)
			break

	var orb_effects: Array = _weapon_ability.effects.duplicate() if _weapon_ability else []

	for i in range(count):
		var orb: Area2D = OrbitOrbScript.new()
		orb.player_ref = self
		orb.orbit_radius = radius
		orb.orbit_speed = spd
		orb.orbit_offset = TAU * float(i) / float(count)
		orb.tint = tint
		orb.hit_radius = 7.0
		orb.size_mult = size_mult
		orb.on_hit_effects = orb_effects
		orb.combat_manager_ref = combat_manager
		get_tree().current_scene.add_child(orb)
		_orbit_orbs.append(orb)


func _cleanup_orbit_orbs() -> void:
	for orb in _orbit_orbs:
		if is_instance_valid(orb):
			orb.queue_free()
	_orbit_orbs.clear()


# --- Death ---

func _on_health_died(_entity: Node2D) -> void:
	if not is_alive:
		return
	is_alive = false
	_is_dying = true
	if choreography_runner and choreography_runner.is_running():
		choreography_runner.interrupt()
	if trigger_component:
		trigger_component.cleanup()
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
		_hit_flash_tween = null
	sprite.modulate = Color.WHITE
	knockback_velocity = Vector2.ZERO
	_cleanup_orbit_orbs()
	# Play death animation then trigger game-over flow
	_attack_anim_active = false
	_damage_anim_active = false
	_play_anim("death")   ## death sheets are single-row → falls back to the base slice
	await sprite.animation_finished
	EventBus.on_death.emit(self)
	died.emit()
	GameManager.on_player_died()


func reset_stats() -> void:
	## Called on run restart — clear all temporary modifiers.
	if choreography_runner and choreography_runner.is_running():
		choreography_runner.interrupt()
	modifier_component.remove_modifiers_by_source("upgrade")
	modifier_component.remove_by_source_prefix("mod_")
	xp = 0.0
	level = 1
	_active_mods.clear()
	is_alive = true
	_is_dying = false
	_attack_anim_active = false
	_damage_anim_active = false
	_pending_ability = null
	_pending_targets.clear()
	_pending_aim_dir = Vector2.ZERO
	_iframes_timer = 0.0
	knockback_velocity = Vector2.ZERO
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
		_hit_flash_tween = null
	sprite.modulate = Color.WHITE
	_cleanup_orbit_orbs()
	if is_instance_valid(_aim_marker):
		_aim_marker.queue_free()
	_aim_marker = null
	_reset_dash_state()
	health.setup(_base_stats["max_hp"])
	_update_pickup_radius()


# --- Internal helpers ---

func _add_modifier(tag: String, op: String, value: float, source: String) -> void:
	var mod := ModifierDefinition.new()
	mod.target_tag = tag
	mod.operation = op
	mod.value = value
	mod.source_name = source
	modifier_component.add_modifier(mod)


## Debug: swap in a new mod list and rebuild the weapon ability in place.
## Removes old mod/combo modifiers, applies the new set, rebuilds _weapon_ability.
## Does NOT touch stat upgrades, health, or the behavior signal connection.
func debug_reload_mods(mod_ids: Array) -> void:
	modifier_component.remove_by_source_prefix("mod_")
	modifier_component.remove_by_source_prefix("combo_")
	_active_mods = mod_ids
	_has_instability_siphon = "instability_siphon" in _active_mods
	for m in WeaponFactory.build_mod_modifiers(_active_mods):
		modifier_component.add_modifier(m)
	for m in WeaponFactory.build_combo_modifiers(_active_mods):
		modifier_component.add_modifier(m)
	_weapon_ability = WeaponFactory.build_weapon_ability(_weapon_id, _weapon_data, _active_mods)
	var combo_passives: Array[StatusEffectDefinition] = WeaponFactory.build_combo_passives(_active_mods)
	for passive_def in combo_passives:
		status_effect_component.apply_status(passive_def, self, 1)
	behavior_component.setup(modifier_component, _weapon_ability.cooldown_base)


func _spawn_scorched_earth_patches(from: Vector2, to: Vector2, scene_root: Node) -> void:
	var mod_params: Dictionary = ModData.ALL.get("napalm", {}).get("params", {})
	var patch_count: int  = int(mod_params.get("patch_count",   5))
	var patch_dmg: float  = mod_params.get("patch_damage",   5.0)
	var patch_dur: float  = mod_params.get("patch_duration", 10.0)
	var patch_rad: float  = mod_params.get("patch_radius",   30.0)
	for p in patch_count:
		var t: float     = (float(p) + 0.5) / float(patch_count)
		var pos: Vector2 = from.lerp(to, t)
		_spawn_burn_patch(pos, patch_dmg, patch_rad, patch_dur, scene_root)


func _spawn_burn_patch(pos: Vector2, dmg_per_sec: float, radius: float, duration: float, scene_root: Node) -> void:
	var area := Area2D.new()
	area.top_level        = true
	area.global_position  = pos
	area.collision_layer  = 0
	area.collision_mask   = 2  # enemies
	area.monitoring       = true
	area.monitorable      = false
	scene_root.add_child(area)

	var shape  := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape   = circle
	area.add_child(shape)

	# Ground glow: approximated circle via Polygon2D
	var poly   := Polygon2D.new()
	var pts    := PackedVector2Array()
	for i in 20:
		var a: float = (float(i) / 20.0) * TAU
		pts.append(Vector2(cos(a), sin(a)) * radius)
	poly.polygon = pts
	poly.color   = Color(1.0, 0.30, 0.0, 0.22)
	area.add_child(poly)

	# Fire particles
	var particles := CPUParticles2D.new()
	particles.amount               = 14
	particles.lifetime             = 1.0
	particles.one_shot             = false
	particles.explosiveness        = 0.0
	particles.direction            = Vector2(0.0, -1.0)
	particles.spread               = 40.0
	particles.initial_velocity_min = 15.0
	particles.initial_velocity_max = 50.0
	particles.gravity              = Vector2.ZERO
	particles.scale_amount_min     = 2.0
	particles.scale_amount_max     = 5.0
	particles.color                = Color(1.0, 0.45, 0.05)
	area.add_child(particles)
	particles.emitting = true

	# Track bodies entering / exiting the patch
	var bodies_in_area: Array = []
	area.body_entered.connect(func(b: Node2D): bodies_in_area.append(b))
	area.body_exited.connect(func(b: Node2D): bodies_in_area.erase(b))

	# Damage timer — auto-stops when area is freed
	var player_ref: Node2D = self
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.one_shot  = false
	area.add_child(timer)
	timer.timeout.connect(func() -> void:
		for body in bodies_in_area.duplicate():
			if is_instance_valid(body) and body.has_method("take_damage") and is_instance_valid(player_ref):
				body.take_damage(HitData.create(dmg_per_sec, "fire", player_ref, body, null))
	)
	timer.start()

	# Fade out then free
	area.get_tree().create_timer(duration - 0.5).timeout.connect(func() -> void:
		if is_instance_valid(area):
			particles.emitting = false
			var t := area.create_tween()
			t.tween_property(area, "modulate:a", 0.0, 0.5)
			t.tween_callback(area.queue_free)
	)


func _set_base_stat(stat_name: String, value: float) -> void:
	## Update a base stat by removing the old "base" modifier and adding a new one.
	for mod in modifier_component.get_all_modifiers():
		if mod.target_tag == stat_name and mod.source_name == "base" and mod.operation == "add":
			modifier_component.remove_modifier(mod)
			break
	_add_modifier(stat_name, "add", value, "base")
