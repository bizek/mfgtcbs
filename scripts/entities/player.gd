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
	"move_speed":      200.0,
	"pickup_radius":   50.0,
	"projectile_count": 1,
	"pierce":          0,
	"projectile_size": 1.0,
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

## Knockback
var knockback_velocity: Vector2 = Vector2.ZERO

## Orbit orbs (Lightning Orb weapon)
var _orbit_orbs: Array = []
const OrbitOrbScript     := preload("res://scripts/entities/orbit_orb.gd")
const WeaponPickupScript := preload("res://scripts/pickups/weapon_pickup.gd")

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


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("player")
	_setup_components()
	_load_character_stats()
	_load_equipped_weapon()
	_apply_passive_mods()
	_load_weapon_mods()
	_update_pickup_radius()
	health_changed.emit(health.current_hp, health.max_hp)
	pickup_area.area_entered.connect(_on_pickup_area_entered)

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


# --- Weapon loading ---

func _load_equipped_weapon() -> void:
	var char_id: String = ProgressionManager.selected_character
	var char_data: Dictionary = CharacterData.ALL.get(char_id, CharacterData.ALL["The Drifter"])
	var weapon_id: String = char_data.get("starting_weapon", "Standard Sidearm")

	if char_id == "The Drifter":
		weapon_id = ProgressionManager.selected_weapon
		if weapon_id.is_empty():
			weapon_id = "Standard Sidearm"

	_weapon_id   = weapon_id
	_weapon_data = WeaponData.ALL.get(weapon_id, WeaponData.ALL["Standard Sidearm"])

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
	_weapon_data = WeaponData.ALL.get(weapon_id, WeaponData.ALL["Standard Sidearm"])
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
	## Engine callback: BehaviorComponent resolved targets, fire the weapon.
	if not is_alive or targets.is_empty():
		return
	attack_target = targets[0]
	# Sync live stats into weapon effects before firing
	var proj_count: int = int(get_stat("projectile_count"))
	var pierce_bonus: int = int(get_stat("pierce"))
	var size_mult: float = get_stat("projectile_size")
	for effect in ability.effects:
		if effect is SpawnProjectilesEffect:
			effect.count = proj_count
			effect.projectile.pierce_count = _base_proj_pierce + pierce_bonus
			effect.projectile.visual_scale = _base_proj_scale * size_mult
			effect.projectile.hit_radius   = _base_proj_hit_radius * size_mult
	EffectDispatcher.execute_effects(ability.effects, self, targets, ability, combat_manager)
	EventBus.on_ability_used.emit(self, ability)

	# Weapon-specific visual feedback
	var scene_root: Node = get_tree().current_scene
	var tint: Color = _weapon_data.get("tint", Color.WHITE)
	if ability.tags.has("Beam") and is_instance_valid(targets[0]):
		PlayerVfxHelper.spawn_beam_flash(self, scene_root, global_position, targets[0].global_position, tint)
	elif ability.tags.has("Melee"):
		var swing_dir: Vector2 = (targets[0].global_position - global_position).normalized() if is_instance_valid(targets[0]) else Vector2.RIGHT
		var range_px: float = _weapon_data.get("range", 55.0)
		var arc_deg: float  = _weapon_data.get("arc_degrees", 200.0)
		PlayerVfxHelper.spawn_melee_arc(self, scene_root, global_position, swing_dir.angle(), range_px, deg_to_rad(arc_deg * 0.5), tint)
	elif ability.tags.has("Artillery") and is_instance_valid(targets[0]):
		var scatter    := Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
		var target_pos: Vector2 = targets[0].global_position + scatter
		PlayerVfxHelper.spawn_artillery_marker(self, scene_root, target_pos, _weapon_data.get("aoe_radius", 64.0), _weapon_data.get("fuse_time", 1.0), tint)


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
	var input_dir := Vector2.ZERO
	if not status_effect_component.is_disabled() and not status_effect_component.is_movement_disabled():
		input_dir = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up",   "move_down")
		).normalized()

	var move_speed_val: float = get_stat("move_speed")
	var target_velocity: Vector2 = input_dir * move_speed_val
	velocity = velocity.move_toward(target_velocity, 2600.0 * delta)
	velocity += knockback_velocity
	move_and_slide()
	position = position.round()  # pixel-snap: prevents sub-pixel blur on high-Hz monitors
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 1400.0 * delta)

	if sprite:
		if input_dir.x != 0:
			sprite.flip_h = input_dir.x < 0
		if input_dir.length_squared() > 0:
			sprite.play("walk")
		else:
			sprite.play("idle")

	# Auto-fire via engine BehaviorComponent (suppressed during CC)
	# BehaviorComponent.tick handles auto-attack timer and targeting
	# Note: orchestrator also ticks behavior, but player needs per-frame firing
	# since orchestrator tick order is status→cooldown→behavior
	if not status_effect_component.is_disabled():
		behavior_component.tick(delta, self)


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
	if _iframes_timer > 0.0:
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
	if ExtractionManager.is_channeling and amount > 10.0:
		ExtractionManager.interrupt_channel()


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
	if trigger_component:
		trigger_component.cleanup()
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
		_hit_flash_tween = null
	sprite.modulate = Color.WHITE
	knockback_velocity = Vector2.ZERO
	_cleanup_orbit_orbs()
	EventBus.on_death.emit(self)
	died.emit()
	GameManager.on_player_died()


func reset_stats() -> void:
	## Called on run restart — clear all temporary modifiers.
	modifier_component.remove_modifiers_by_source("upgrade")
	modifier_component.remove_by_source_prefix("mod_")
	xp = 0.0
	level = 1
	_active_mods.clear()
	is_alive = true
	_iframes_timer = 0.0
	knockback_velocity = Vector2.ZERO
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
		_hit_flash_tween = null
	sprite.modulate = Color.WHITE
	_cleanup_orbit_orbs()
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


func _set_base_stat(stat_name: String, value: float) -> void:
	## Update a base stat by removing the old "base" modifier and adding a new one.
	for mod in modifier_component.get_all_modifiers():
		if mod.target_tag == stat_name and mod.source_name == "base" and mod.operation == "add":
			modifier_component.remove_modifier(mod)
			break
	_add_modifier(stat_name, "add", value, "base")
