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
const OrbitOrbScript := preload("res://scripts/entities/orbit_orb.gd")

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

	# Register base stats as "add" modifiers so the engine can query them
	for stat_name in _base_stats:
		var mod := ModifierDefinition.new()
		mod.target_tag = stat_name
		mod.operation = "add"
		mod.value = _base_stats[stat_name]
		mod.source_name = "base"
		modifier_component.add_modifier(mod)

	# Base armor
	var base_armor: float = char_data.get("base_armor", 0.0)
	if base_armor > 0.0:
		var armor_mod := ModifierDefinition.new()
		armor_mod.target_tag = "Physical"
		armor_mod.operation = "resist"
		armor_mod.value = base_armor
		armor_mod.source_name = "base_armor"
		modifier_component.add_modifier(armor_mod)

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
	match _passive_id:
		"scavenger_passive":
			_add_modifier("pickup_radius", "bonus", 0.25, "passive_scavenger")
		"spark_passive":
			_add_modifier("crit_multiplier", "add", 0.75, "passive_spark")
		"shade_passive":
			_add_modifier("dodge_chance", "add", 0.15, "passive_shade")
		"herald_passive":
			_add_modifier("All", "bonus", 0.30, "passive_herald")
			_add_modifier("All", "cooldown_reduce", 0.20, "passive_herald")
		"cursed_passive":
			_add_modifier("max_hp", "bonus", 0.20, "passive_cursed")
			_add_modifier("Physical", "resist", 0.20, "passive_cursed")
			_add_modifier("move_speed", "bonus", 0.20, "passive_cursed")
			_add_modifier("All", "bonus", 0.20, "passive_cursed")
			# Re-setup health with modified max
			var new_max: float = get_stat("max_hp")
			health.setup(new_max)


# --- Mod loading ---

func _load_weapon_mods() -> void:
	_active_mods = ProgressionManager.get_weapon_mods(_weapon_id)
	_has_instability_siphon = "instability_siphon" in _active_mods

	# Stat mods (crit, lifesteal) as ModifierDefinitions
	var stat_mods: Array[ModifierDefinition] = WeaponFactory.build_mod_modifiers(_active_mods)
	for mod in stat_mods:
		modifier_component.add_modifier(mod)

	# Build weapon ability with mods baked into ProjectileConfig/effects
	_weapon_ability = WeaponFactory.build_weapon_ability(_weapon_id, _weapon_data, _active_mods)

	# Wire as auto-attack through engine components
	var attack_interval: float = _weapon_ability.cooldown_base
	behavior_component.setup(modifier_component, attack_interval)
	behavior_component.auto_attack_requested.connect(_on_auto_attack)
	ability_component.setup_abilities(_weapon_ability, [], 1)


func reload_mods() -> void:
	# Remove old mod modifiers (all sources starting with "mod_")
	for mod in modifier_component.get_all_modifiers().duplicate():
		if mod.source_name.begins_with("mod_"):
			modifier_component.remove_modifier(mod)
	_load_weapon_mods()
	if _has_instability_siphon:
		if not EventBus.on_kill.is_connected(_on_kill_siphon):
			EventBus.on_kill.connect(_on_kill_siphon)


func get_active_weapon_id() -> String:
	return _weapon_id


func _on_auto_attack(ability: AbilityDefinition, targets: Array) -> void:
	## Engine callback: BehaviorComponent resolved targets, fire the weapon.
	if not is_alive or targets.is_empty():
		return
	attack_target = targets[0]
	# Sync live stats into weapon effects before firing
	var proj_count: int = int(get_stat("projectile_count"))
	for effect in ability.effects:
		if effect is SpawnProjectilesEffect:
			effect.count = proj_count
	EffectDispatcher.execute_effects(ability.effects, self, targets, ability, combat_manager)
	EventBus.on_ability_used.emit(self, ability)

	# Weapon-specific visual feedback
	if ability.tags.has("Beam") and is_instance_valid(targets[0]):
		_spawn_beam_flash(targets[0].global_position)
	elif ability.tags.has("Melee"):
		var swing_dir: Vector2 = (targets[0].global_position - global_position).normalized() if is_instance_valid(targets[0]) else Vector2.RIGHT
		var range_px: float = _weapon_data.get("range", 55.0)
		var arc_deg: float = _weapon_data.get("arc_degrees", 200.0)
		_spawn_melee_arc(swing_dir.angle(), range_px, deg_to_rad(arc_deg * 0.5))
	elif ability.tags.has("Artillery") and is_instance_valid(targets[0]):
		var scatter := Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
		var target_pos: Vector2 = targets[0].global_position + scatter
		var aoe_radius: float = _weapon_data.get("aoe_radius", 64.0)
		var fuse_time: float = _weapon_data.get("fuse_time", 1.0)
		_spawn_artillery_marker(target_pos, aoe_radius, fuse_time)


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
	## Shade invisibility on dodge via engine StatusEffectDefinition
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
	for i in range(count):
		var orb: Area2D = OrbitOrbScript.new()
		orb.player_ref = self
		orb.orbit_radius = radius
		orb.orbit_speed = spd
		orb.orbit_offset = TAU * float(i) / float(count)
		orb.tint = tint
		get_tree().current_scene.add_child(orb)
		_orbit_orbs.append(orb)


func _cleanup_orbit_orbs() -> void:
	for orb in _orbit_orbs:
		if is_instance_valid(orb):
			orb.queue_free()
	_orbit_orbs.clear()


# --- Weapon visual feedback ---

func _spawn_beam_flash(target_pos: Vector2) -> void:
	var tint: Color = _weapon_data.get("tint", Color(1.0, 0.42, 0.08))
	var scene_root: Node = get_tree().current_scene

	var line := Line2D.new()
	line.top_level = true
	line.add_point(global_position)
	line.add_point(target_pos)
	line.width = 3.5
	line.default_color = Color(tint.r, tint.g, tint.b, 0.92)

	var glow := Line2D.new()
	glow.top_level = true
	glow.add_point(global_position)
	glow.add_point(target_pos)
	glow.width = 7.0
	glow.default_color = Color(tint.r, tint.g, tint.b, 0.22)

	scene_root.add_child(glow)
	scene_root.add_child(line)

	var t := create_tween()
	t.tween_property(line, "modulate:a", 0.0, 0.06)
	t.tween_callback(line.queue_free)
	var t2 := create_tween()
	t2.tween_property(glow, "modulate:a", 0.0, 0.06)
	t2.tween_callback(glow.queue_free)


func _spawn_melee_arc(center_angle: float, range_px: float, arc_half: float) -> void:
	var tint: Color = _weapon_data.get("tint", Color(0.48, 0.80, 1.0))
	var segments: int = 12
	var scene_root: Node = get_tree().current_scene

	var points: PackedVector2Array = []
	points.append(Vector2.ZERO)
	for i in range(segments + 1):
		var a: float = center_angle - arc_half + (float(i) / float(segments)) * arc_half * 2.0
		points.append(Vector2(cos(a), sin(a)) * range_px)

	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = Color(tint.r, tint.g, tint.b, 0.48)
	scene_root.add_child(poly)
	poly.global_position = global_position

	var edge_points: PackedVector2Array = []
	for i in range(segments + 1):
		var a: float = center_angle - arc_half + (float(i) / float(segments)) * arc_half * 2.0
		edge_points.append(Vector2(cos(a), sin(a)) * range_px)

	var edge := Line2D.new()
	edge.top_level = true
	for p in edge_points:
		edge.add_point(poly.global_position + p)
	edge.width = 3.0
	edge.default_color = Color(tint.r, tint.g, tint.b, 0.85)
	scene_root.add_child(edge)

	var t := create_tween()
	t.tween_property(poly, "modulate:a", 0.0, 0.13)
	t.tween_callback(poly.queue_free)
	var t2 := create_tween()
	t2.tween_property(edge, "modulate:a", 0.0, 0.13)
	t2.tween_callback(edge.queue_free)


func _spawn_artillery_marker(pos: Vector2, radius: float, fuse: float) -> void:
	var tint: Color = _weapon_data.get("tint", Color(0.38, 0.08, 0.62))
	var scene_root: Node = get_tree().current_scene

	var marker := Node2D.new()
	marker.global_position = pos
	scene_root.add_child(marker)

	var preview := ColorRect.new()
	preview.color = Color(tint.r, tint.g, tint.b, 0.18)
	preview.size = Vector2(radius * 2.0, radius * 2.0)
	preview.position = Vector2(-radius, -radius)
	marker.add_child(preview)

	# Border
	var bd: float = radius * 2.0
	var bt: float = 2.0
	var bc: Color = Color(tint.r, tint.g, tint.b, 0.72)
	for side in 4:
		var b := ColorRect.new()
		b.color = bc
		match side:
			0: b.size = Vector2(bd, bt); b.position = Vector2(-radius, -radius)
			1: b.size = Vector2(bd, bt); b.position = Vector2(-radius, radius - bt)
			2: b.size = Vector2(bt, bd); b.position = Vector2(-radius, -radius)
			3: b.size = Vector2(bt, bd); b.position = Vector2(radius - bt, -radius)
		marker.add_child(b)

	var dot := ColorRect.new()
	dot.color = Color(tint.r + 0.3, tint.g + 0.1, tint.b + 0.3, 1.0)
	dot.size = Vector2(7.0, 7.0)
	dot.position = Vector2(-3.5, -3.5)
	marker.add_child(dot)

	# Warning pulse
	var warn := create_tween().set_loops(int(fuse * 6.0))
	warn.tween_property(preview, "modulate:a", 0.15, fuse / 12.0)
	warn.tween_property(preview, "modulate:a", 1.0, fuse / 12.0)

	# Detonation burst visual on timer expiry
	get_tree().create_timer(fuse).timeout.connect(
		func():
			if is_instance_valid(marker):
				_spawn_artillery_burst(pos, radius, tint)
				marker.queue_free()
	)


func _spawn_artillery_burst(pos: Vector2, radius: float, tint: Color) -> void:
	var scene_root: Node = get_tree().current_scene

	var ring := ColorRect.new()
	ring.color = Color(tint.r, tint.g, tint.b, 0.55)
	ring.size = Vector2(radius * 2.0, radius * 2.0)
	ring.position = pos - Vector2(radius, radius)
	scene_root.add_child(ring)

	var rt := create_tween()
	rt.tween_property(ring, "scale", Vector2(1.5, 1.5), 0.22).set_trans(Tween.TRANS_EXPO)
	rt.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
	rt.tween_callback(ring.queue_free)

	var particles := CPUParticles2D.new()
	particles.global_position = pos
	particles.amount = 20
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 200.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 8.0
	particles.color = tint
	scene_root.add_child(particles)
	particles.emitting = true
	get_tree().create_timer(1.2).timeout.connect(
		func(): if is_instance_valid(particles): particles.queue_free()
	)


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
	for mod in modifier_component.get_all_modifiers().duplicate():
		if mod.source_name.begins_with("mod_"):
			modifier_component.remove_modifier(mod)
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


func _set_base_stat(stat_name: String, value: float) -> void:
	## Update a base stat by removing the old "base" modifier and adding a new one.
	for mod in modifier_component.get_all_modifiers():
		if mod.target_tag == stat_name and mod.source_name == "base" and mod.operation == "add":
			modifier_component.remove_modifier(mod)
			break
	_add_modifier(stat_name, "add", value, "base")
