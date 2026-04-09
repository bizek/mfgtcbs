extends CharacterBody2D

## Player — Movement, stats, health, leveling, and passive abilities.
## Weapon firing is delegated to WeaponController.

signal health_changed(current: float, maximum: float)
signal xp_changed(current: float, needed: float)
signal leveled_up(new_level: int)
signal died

## Base stats (The Drifter) — damage/attack_speed overridden by weapon at _ready
var stats: Dictionary = {
	"max_hp":          100.0,
	"hp":              100.0,
	"armor":           0.0,
	"move_speed":      200.0,
	"damage":          18.0,
	"attack_speed":    1.0,
	"crit_chance":     0.05,
	"crit_multiplier": 1.5,
	"pickup_radius":   50.0,
	"projectile_count": 1,
	"pierce":          0,
	"projectile_size": 1.0,
}

## Stat modifiers accumulated from upgrades (level-up choices)
var flat_mods: Dictionary = {}
var percent_mods: Dictionary = {}

## Stat modifiers from equipped weapon mods — separate so they can be reloaded mid-run
var _mod_flat: Dictionary = {}

## XP and leveling
var xp: float = 0.0
var level: int = 1
var xp_base: float = 10.0
var xp_growth: float = 0.3

## Weapon controller
var _weapon_controller: WeaponController = null
var _weapon_id: String = ""
var _weapon_data: Dictionary = {}

## ── Mod system ────────────────────────────────────────────────────────────────
var _active_mods: Array = []
var _has_instability_siphon: bool = false

## ── Character passive system ──────────────────────────────────────────────────
var _passive_id: String = "none"

## Scavenger: bonus loot find percentage
var loot_find: float = 0.0

## Shade: dodge and invisibility
var _dodge_chance: float = 0.0
var _invisible: bool = false
var _invisible_timer: float = 0.0

## Herald: ability bonuses
var ability_damage_mult: float = 1.0
var ability_cdr_mult: float = 1.0
var ability_slots: int = 1

## Spatial grid for fast enemy lookups (set by main_arena.gd)
var enemy_grid: SpatialGrid = null

## State
var _is_dead: bool = false
var god_mode: bool = false

## Hit iframes
var _iframes_timer: float = 0.0
const IFRAME_DURATION: float = 0.55
var _hit_flash_tween: Tween = null

## Knockback
var knockback_velocity: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var pickup_area: Area2D = $PickupCollector
@onready var pickup_shape: CollisionShape2D = $PickupCollector/CollisionShape

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("player")
	_load_character_stats()
	_load_equipped_weapon()
	_apply_passive_mods()
	_load_weapon_mods()
	_update_pickup_radius()
	health_changed.emit(stats.hp, get_stat("max_hp"))
	pickup_area.area_entered.connect(_on_pickup_area_entered)

	if _has_instability_siphon:
		CombatManager.entity_killed.connect(_on_entity_killed_siphon)

# ─── Character loading ────────────────────────────────────────────────────────

func _load_character_stats() -> void:
	var char_id: String = ProgressionManager.selected_character
	var char_data: Dictionary = CharacterData.ALL.get(char_id, CharacterData.ALL["The Drifter"])
	stats["max_hp"]     = char_data.get("base_hp", 100.0)
	stats["armor"]      = char_data.get("base_armor", 0.0)
	stats["move_speed"] = char_data.get("base_move_speed", 200.0)
	stats["hp"]         = stats["max_hp"]
	_passive_id         = char_data.get("passive_id", "none")

# ─── Weapon loading ──────────────────────────────────────────────────────────

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

	stats["damage"]           = _weapon_data.get("damage", 18.0)
	stats["attack_speed"]     = _weapon_data.get("attack_speed", 1.0)
	stats["projectile_count"] = _weapon_data.get("projectile_count", 1)

	## Setup weapon controller
	var proj_scene: PackedScene = preload("res://scenes/projectile.tscn")
	_weapon_controller = WeaponController.new()
	_weapon_controller.name = "WeaponController"
	add_child(_weapon_controller)
	_weapon_controller.setup(self, _weapon_data, _weapon_id, proj_scene)

# ─── Passive application ─────────────────────────────────────────────────────

func _apply_passive_mods() -> void:
	match _passive_id:
		"scavenger_passive":
			percent_mods["pickup_radius"] = percent_mods.get("pickup_radius", 0.0) + 0.25
			loot_find = 0.15
		"spark_passive":
			flat_mods["crit_multiplier"] = flat_mods.get("crit_multiplier", 0.0) + 0.75
		"shade_passive":
			_dodge_chance = 0.15
		"herald_passive":
			ability_damage_mult = 1.30
			ability_cdr_mult    = 0.80
			ability_slots       = 2
		"cursed_passive":
			stats["max_hp"]     *= 1.2
			stats["armor"]      *= 1.2
			stats["move_speed"] *= 1.2
			stats["damage"]     *= 1.2
			stats["hp"]          = stats["max_hp"]

# ─── Mod loading ─────────────────────────────────────────────────────────────

func _load_weapon_mods() -> void:
	_mod_flat.clear()
	_active_mods = ProgressionManager.get_weapon_mods(_weapon_id)
	_has_instability_siphon = "instability_siphon" in _active_mods

	for mod_id in _active_mods:
		var mod_data: Dictionary = ModData.ALL.get(mod_id, {})
		var params: Dictionary   = mod_data.get("params", {})
		match mod_data.get("effect_type", ""):
			"crit":
				_mod_flat["crit_chance"] = _mod_flat.get("crit_chance", 0.0) \
					+ params.get("crit_chance_bonus", 0.0)
				_mod_flat["crit_multiplier"] = _mod_flat.get("crit_multiplier", 0.0) \
					+ params.get("crit_mult_bonus", 0.0)

	## Sync mods to weapon controller
	if _weapon_controller:
		_weapon_controller.set_mods(_active_mods)

func reload_mods() -> void:
	_load_weapon_mods()
	if _has_instability_siphon:
		if not CombatManager.entity_killed.is_connected(_on_entity_killed_siphon):
			CombatManager.entity_killed.connect(_on_entity_killed_siphon)

func get_active_weapon_id() -> String:
	return _weapon_id

# ─── Main loop ───────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	## Iframe countdown
	if _iframes_timer > 0.0:
		_iframes_timer -= delta
		if _iframes_timer <= 0.0:
			if _hit_flash_tween and _hit_flash_tween.is_valid():
				_hit_flash_tween.kill()
				_hit_flash_tween = null
			if not _invisible:
				sprite.modulate = Color.WHITE

	## Shade invisibility countdown
	if _invisible:
		_invisible_timer -= delta
		if _invisible_timer <= 0.0:
			_invisible = false
			if _iframes_timer <= 0.0:
				sprite.modulate = Color.WHITE

	## Movement
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up",   "move_down")
	).normalized()

	var target_velocity: Vector2 = input_dir * get_stat("move_speed")
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

	## Auto-fire via weapon controller
	if _weapon_controller:
		_weapon_controller.tick(delta)

# ─── Stat helpers ────────────────────────────────────────────────────────────

func get_stat(stat_name: String) -> float:
	var base: float = stats.get(stat_name, 0.0)
	var flat: float = flat_mods.get(stat_name, 0.0) + _mod_flat.get(stat_name, 0.0)
	var pct:  float = percent_mods.get(stat_name, 0.0)
	return (base + flat) * (1.0 + pct)

func get_armor() -> float:
	var base_armor: float = get_stat("armor")
	if _passive_id == "warden_passive" and stats.hp < get_stat("max_hp") * 0.5:
		return base_armor * 2.0
	return base_armor

func is_dead() -> bool:
	return _is_dead

func is_invisible() -> bool:
	return _invisible

func apply_knockback(force: Vector2) -> void:
	if _iframes_timer > 0.0:
		return
	var armor_val: float = get_armor()
	var reduction: float = armor_val / (armor_val + 15.0)
	knockback_velocity += force * (1.0 - reduction)

# ─── Health ──────────────────────────────────────────────────────────────────

func take_damage(amount: float) -> void:
	if _is_dead or god_mode:
		return
	if _iframes_timer > 0.0:
		return

	if _dodge_chance > 0.0 and randf() < _dodge_chance:
		_trigger_dodge()
		return

	if ExtractionManager.is_channeling and amount > 10.0:
		ExtractionManager.interrupt_channel()

	stats.hp -= amount
	health_changed.emit(stats.hp, get_stat("max_hp"))
	_iframes_timer = IFRAME_DURATION
	_start_hit_flash()

	if stats.hp <= 0.0:
		stats.hp = 0.0
		_die()

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

func _trigger_dodge() -> void:
	_invisible       = true
	_invisible_timer = 0.5
	sprite.modulate = Color(0.72, 0.52, 1.0, 0.35)

func heal(amount: float) -> void:
	if _is_dead:
		return
	stats.hp = minf(stats.hp + amount, get_stat("max_hp"))
	health_changed.emit(stats.hp, get_stat("max_hp"))

# ─── XP / leveling ───────────────────────────────────────────────���──────────

func add_xp(amount: float) -> void:
	if _is_dead:
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

# ─── Upgrade application ────────────────────────────────────────────────────

func apply_stat_upgrade(upgrade: Dictionary) -> void:
	var stat_name: String = upgrade.stat
	var value: float      = upgrade.value
	if upgrade.type == "flat":
		flat_mods[stat_name] = flat_mods.get(stat_name, 0.0) + value
		if stat_name == "max_hp":
			heal(value)
	elif upgrade.type == "percent":
		percent_mods[stat_name] = percent_mods.get(stat_name, 0.0) + value

	if stat_name == "pickup_radius":
		_update_pickup_radius()

func remove_stat_upgrade(upgrade: Dictionary) -> void:
	var stat_name: String = upgrade.stat
	var value: float      = upgrade.value
	if upgrade.type == "flat":
		flat_mods[stat_name] = flat_mods.get(stat_name, 0.0) - value
		if stat_name == "max_hp":
			current_hp = minf(current_hp, get_stat("max_hp"))
	elif upgrade.type == "percent":
		percent_mods[stat_name] = percent_mods.get(stat_name, 0.0) - value

	if stat_name == "pickup_radius":
		_update_pickup_radius()

# ─── Pickup collection ───────────────────────────────────────────────────────

func _update_pickup_radius() -> void:
	if pickup_shape and pickup_shape.shape:
		pickup_shape.shape.radius = get_stat("pickup_radius")

func _on_pickup_area_entered(area: Area2D) -> void:
	if area.has_method("start_magnet"):
		area.start_magnet(self)

# ─── Instability Siphon ─────────────────────────────────────────────────────

func _on_entity_killed_siphon(_killer: Node, victim: Node, _pos: Vector2) -> void:
	if victim.is_in_group("enemies"):
		GameManager.modify_instability(-1)

# ─── Death ───────────────────────────────────────────────────────────────────

func _die() -> void:
	_is_dead = true
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
		_hit_flash_tween = null
	sprite.modulate = Color.WHITE
	knockback_velocity = Vector2.ZERO
	if _weapon_controller:
		_weapon_controller.cleanup()
	died.emit()
	GameManager.on_player_died()

func reset_stats() -> void:
	stats.hp = stats.max_hp
	xp = 0.0
	level = 1
	flat_mods.clear()
	percent_mods.clear()
	_mod_flat.clear()
	_active_mods.clear()
	_is_dead = false
	_iframes_timer = 0.0
	knockback_velocity = Vector2.ZERO
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
		_hit_flash_tween = null
	sprite.modulate = Color.WHITE
	_update_pickup_radius()
