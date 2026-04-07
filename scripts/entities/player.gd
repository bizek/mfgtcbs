extends CharacterBody2D

## Player — Movement, auto-fire weapon system, stats, health, leveling.
## Reads the selected character from ProgressionManager at run start to apply
## character-specific base stats and passive abilities.

signal health_changed(current: float, maximum: float)
signal xp_changed(current: float, needed: float)
signal leveled_up(new_level: int)
signal died

const OrbitOrbScript := preload("res://scripts/entities/orbit_orb.gd")

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
	"extraction_speed": 1.0,
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

## Weapon system
var fire_timer: float = 0.0
var projectile_scene: PackedScene
var _weapon_data: Dictionary = {}     ## active weapon definition from WeaponData.ALL
var _weapon_id: String = ""           ## active weapon key (for mod lookups)
var _orbit_orbs: Array = []           ## spawned orb nodes (Lightning Orb only)

## ── Mod system ────────────────────────────────────────────────────────────────
## Active mod IDs for the current weapon this run
var _active_mods: Array = []
var _has_instability_siphon: bool = false

## ── Character passive system ──────────────────────────────────────────────────
var _passive_id: String = "none"

## Scavenger: bonus loot find percentage (applied to drop rate checks externally)
var loot_find: float = 0.0

## Shade: dodge and invisibility
var _dodge_chance: float = 0.0
var _invisible: bool = false
var _invisible_timer: float = 0.0

## Herald: ability bonuses (ready for when active abilities are implemented)
var ability_damage_mult: float = 1.0
var ability_cdr_mult: float = 1.0
var ability_slots: int = 1

## Spatial grid for fast enemy lookups (set by main_arena.gd)
var enemy_grid: SpatialGrid = null

## State
var _is_dead: bool = false
var god_mode: bool = false  ## Debug: player takes no damage when true

## Hit iframes — player is invincible for IFRAME_DURATION seconds after each hit.
## This creates a window of safety and makes damage feel deliberate instead of chip-heavy.
var _iframes_timer: float = 0.0
const IFRAME_DURATION: float = 0.55   ## 0.55 s of iframes per hit
var _hit_flash_tween: Tween = null

## Knockback — applied by apply_knockback(), added to velocity each frame and decayed.
var knockback_velocity: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var pickup_area: Area2D = $PickupCollector
@onready var pickup_shape: CollisionShape2D = $PickupCollector/CollisionShape

func _ready() -> void:
	add_to_group("player")
	projectile_scene = preload("res://scenes/projectile.tscn")
	_load_character_stats()
	_load_equipped_weapon()
	_apply_passive_mods()
	_load_weapon_mods()
	_update_pickup_radius()
	health_changed.emit(stats.hp, get_stat("max_hp"))
	pickup_area.area_entered.connect(_on_pickup_area_entered)

	## Instability Siphon: reduce instability by 1 on each kill
	if _has_instability_siphon:
		CombatManager.entity_killed.connect(_on_entity_killed_siphon)

# ─── Character loading ─────────────────────────────────────────────────────────

## Apply the selected character's base stats (HP, armor, move speed).
## Called before weapon loading so weapon can override damage/attack_speed on top.
func _load_character_stats() -> void:
	var char_id: String = ProgressionManager.selected_character
	var char_data: Dictionary = CharacterData.ALL.get(char_id, CharacterData.ALL["The Drifter"])

	stats["max_hp"]         = char_data.get("base_hp",         100.0)
	stats["armor"]          = char_data.get("base_armor",       0.0)
	stats["move_speed"]     = char_data.get("base_move_speed", 200.0)
	stats["hp"]             = stats["max_hp"]
	_passive_id             = char_data.get("passive_id",      "none")

# ─── Weapon loading ────────────────────────────────────────────────────────────

func _load_equipped_weapon() -> void:
	## Every character has a fixed starting weapon except The Drifter,
	## who uses whatever the player has equipped in the Armory.
	var char_id: String = ProgressionManager.selected_character
	var char_data: Dictionary = CharacterData.ALL.get(char_id, CharacterData.ALL["The Drifter"])
	var weapon_id: String = char_data.get("starting_weapon", "Standard Sidearm")

	if char_id == "The Drifter":
		## Drifter uses player-selected weapon from Armory
		weapon_id = ProgressionManager.selected_weapon
		if weapon_id.is_empty():
			weapon_id = "Standard Sidearm"

	_weapon_id   = weapon_id
	_weapon_data = WeaponData.ALL.get(weapon_id, WeaponData.ALL["Standard Sidearm"])

	## Override base stats from weapon data so upgrades apply on top correctly
	stats["damage"]           = _weapon_data.get("damage",          18.0)
	stats["attack_speed"]     = _weapon_data.get("attack_speed",     1.0)
	stats["projectile_count"] = _weapon_data.get("projectile_count", 1)

	## Behaviour-specific setup
	if _weapon_data.get("behavior") == "orbit":
		## Orbs are created deferred so get_tree().current_scene is ready
		call_deferred("_setup_orbit_orbs")

func _setup_orbit_orbs() -> void:
	var count: int    = _weapon_data.get("orbit_count",  3)
	var radius: float = _weapon_data.get("orbit_radius", 64.0)
	var speed: float  = _weapon_data.get("orbit_speed",  1.8)
	var tint: Color   = _weapon_data.get("tint",         Color.WHITE)

	for i in range(count):
		var orb: Area2D = OrbitOrbScript.new()
		orb.player_ref    = self
		orb.orbit_radius  = radius
		orb.orbit_speed   = speed
		orb.orbit_offset  = TAU * float(i) / float(count)
		orb.tint          = tint
		get_tree().current_scene.add_child(orb)
		_orbit_orbs.append(orb)

# ─── Passive application ───────────────────────────────────────────────────────

## Apply flat/percent stat mods and set passive-specific state variables.
## Called after _load_equipped_weapon so damage is set before Cursed multiplies it.
func _apply_passive_mods() -> void:
	match _passive_id:
		"scavenger_passive":
			percent_mods["pickup_radius"] = percent_mods.get("pickup_radius", 0.0) + 0.25
			loot_find = 0.15

		"spark_passive":
			## +0.75 flat crit multiplier → 1.5 base + 0.75 = 2.25× total
			flat_mods["crit_multiplier"] = flat_mods.get("crit_multiplier", 0.0) + 0.75

		"shade_passive":
			_dodge_chance = 0.15

		"herald_passive":
			ability_damage_mult = 1.30
			ability_cdr_mult    = 0.80
			ability_slots       = 2

		"cursed_passive":
			## +20% to all base stats (applied directly since percent_mods layer
			## sits on top of base stats; we want the character sheet stats boosted)
			stats["max_hp"]      *= 1.2
			stats["armor"]       *= 1.2
			stats["move_speed"]  *= 1.2
			stats["damage"]      *= 1.2    ## weapon damage already set above
			stats["hp"]           = stats["max_hp"]

# ─── Mod loading ──────────────────────────────────────────────────────────────

## Load active mods from the equipped weapon's mod slots.
## Safe to call mid-run (reload_mods) since _mod_flat is reset each time.
func _load_weapon_mods() -> void:
	_mod_flat.clear()
	_active_mods = ProgressionManager.get_weapon_mods(_weapon_id)
	_has_instability_siphon = "instability_siphon" in _active_mods

	## Apply passive stat bonuses from mods (only crit_amp affects flat stats)
	for mod_id in _active_mods:
		var mod_data: Dictionary = ModData.ALL.get(mod_id, {})
		var params: Dictionary   = mod_data.get("params", {})
		match mod_data.get("effect_type", ""):
			"crit":
				_mod_flat["crit_chance"] = _mod_flat.get("crit_chance", 0.0) \
					+ params.get("crit_chance_bonus", 0.0)
				_mod_flat["crit_multiplier"] = _mod_flat.get("crit_multiplier", 0.0) \
					+ params.get("crit_mult_bonus", 0.0)

## Called by mod_pickup when a mod is auto-equipped mid-run.
func reload_mods() -> void:
	_load_weapon_mods()
	## Re-wire siphon if newly acquired
	if _has_instability_siphon:
		if not CombatManager.entity_killed.is_connected(_on_entity_killed_siphon):
			CombatManager.entity_killed.connect(_on_entity_killed_siphon)

## Returns the active weapon's ID (used by mod_pickup to find an open slot).
func get_active_weapon_id() -> String:
	return _weapon_id

# ─── Main loop ─────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	## Iframe countdown
	if _iframes_timer > 0.0:
		_iframes_timer -= delta
		if _iframes_timer <= 0.0:
			## Iframes over — kill blink tween and restore sprite
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
			## Only restore opacity if we're not still flashing from a hit
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

	## Auto-fire tick
	fire_timer -= delta
	if fire_timer <= 0.0:
		_fire_weapon()
		fire_timer = 1.0 / get_stat("attack_speed")

# ─── Stat helpers ──────────────────────────────────────────────────────────────

func get_stat(stat_name: String) -> float:
	var base: float = stats.get(stat_name, 0.0)
	var flat: float = flat_mods.get(stat_name, 0.0) + _mod_flat.get(stat_name, 0.0)
	var pct:  float = percent_mods.get(stat_name, 0.0)
	return (base + flat) * (1.0 + pct)

## Warden passive: armor doubles when below 50% HP.
func get_armor() -> float:
	var base_armor: float = get_stat("armor")
	if _passive_id == "warden_passive" and stats.hp < get_stat("max_hp") * 0.5:
		return base_armor * 2.0
	return base_armor

func is_dead() -> bool:
	return _is_dead

## Shade passive: enemies check this before chasing.
func is_invisible() -> bool:
	return _invisible

## Called by CombatManager after every hit attempt.
## Knockback only applies when the hit actually landed (iframes not active).
## This prevents being pinballed by enemies whose damage was blocked.
## Armor softens the force: 0 armor = full kick, 15 armor = 50%, 30 armor ≈ 33%.
func apply_knockback(force: Vector2) -> void:
	if _iframes_timer > 0.0:
		return  ## Already reacting to a hit — don't pile on the physics
	var armor_val: float = get_armor()
	var reduction: float = armor_val / (armor_val + 15.0)
	knockback_velocity += force * (1.0 - reduction)

# ─── Health ────────────────────────────────────────────────────────────────────

func take_damage(amount: float) -> void:
	if _is_dead or god_mode:
		return
	if _iframes_timer > 0.0:
		return  ## Still invincible from the last hit

	## Shade passive: 15% chance to dodge any incoming hit
	if _dodge_chance > 0.0 and randf() < _dodge_chance:
		_trigger_dodge()
		return

	stats.hp -= amount
	health_changed.emit(stats.hp, get_stat("max_hp"))

	_iframes_timer = IFRAME_DURATION
	_start_hit_flash()

	if stats.hp <= 0.0:
		stats.hp = 0.0
		_die()

## Bright white burst followed by rapid alpha-blink for the iframe window.
## Also shakes the camera so the hit registers in every sense.
func _start_hit_flash() -> void:
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()

	sprite.modulate = Color(5.0, 5.0, 5.0, 1.0)   ## Overexposed white burst

	## Build blink sequence timed to iframe duration:
	## 0.07 s fade to white, then rapid on/off blinks for the rest
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.07)
	var blinks: int = int((IFRAME_DURATION - 0.07) / 0.14)
	for _i in range(blinks):
		_hit_flash_tween.tween_property(sprite, "modulate:a", 0.12, 0.07)
		_hit_flash_tween.tween_property(sprite, "modulate:a", 1.0,  0.07)

	## Camera shake — magnitude 5 px, quick settle
	var cam := get_viewport().get_camera_2d()
	if cam and is_instance_valid(cam):
		var st := cam.create_tween()
		st.tween_property(cam, "offset",
			Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0)), 0.05)
		st.tween_property(cam, "offset", Vector2.ZERO, 0.14)

## Shade dodge: go invisible for 0.5s, enemies stop chasing.
func _trigger_dodge() -> void:
	_invisible       = true
	_invisible_timer = 0.5
	## Semi-transparent sprite to signal the dodge to the player
	sprite.modulate = Color(0.72, 0.52, 1.0, 0.35)

func heal(amount: float) -> void:
	if _is_dead:
		return
	stats.hp = minf(stats.hp + amount, get_stat("max_hp"))
	health_changed.emit(stats.hp, get_stat("max_hp"))

# ─── XP / leveling ────────────────────────────────────────────────────────────

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

# ─── Upgrade application ──────────────────────────────────────────────────────

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

# ─── Weapon dispatch ──────────────────────────────────────────────────────────

func _fire_weapon() -> void:
	match _weapon_data.get("behavior", "projectile"):
		"projectile": _fire_projectile_weapon()
		"spread":     _fire_spread_weapon()
		"beam":       _fire_beam_weapon()
		"orbit":      pass  ## Orbs handle themselves — no fire logic needed
		"artillery":  _fire_artillery_weapon()
		"melee":      _fire_melee_weapon()

# ─── Behavior: Projectile (Standard Sidearm / Warden's Repeater / Spark's Pistol / Herald's Beacon) ──

func _fire_projectile_weapon() -> void:
	var nearest := _get_nearest_enemy()
	if nearest == null:
		return

	var direction: Vector2 = (nearest.global_position - global_position).normalized()
	var proj_count: int    = int(get_stat("projectile_count"))
	var spread_deg: float  = _weapon_data.get("spread_angle", 10.0)

	for i in range(proj_count):
		var offset: float = 0.0
		if proj_count > 1:
			offset = deg_to_rad(-spread_deg * 0.5 + spread_deg * float(i) / float(proj_count - 1))
		_spawn_projectile(direction.rotated(offset))

# ─── Behavior: Spread (Frost Scattergun) ─────────────────────────────────────

func _fire_spread_weapon() -> void:
	var nearest := _get_nearest_enemy()
	if nearest == null:
		return

	var direction: Vector2 = (nearest.global_position - global_position).normalized()
	var proj_count: int    = _weapon_data.get("projectile_count", 5)
	var total_spread: float = _weapon_data.get("spread_angle", 52.0)

	for i in range(proj_count):
		var offset: float = 0.0
		if proj_count > 1:
			offset = deg_to_rad(
				-total_spread * 0.5 + total_spread * float(i) / float(proj_count - 1)
			)
		_spawn_projectile(direction.rotated(offset))

# ─── Behavior: Beam (Ember Beam) ─────────────────────────────────────────────

func _fire_beam_weapon() -> void:
	var nearest := _get_nearest_enemy()
	if nearest == null:
		return

	var max_range: float = _weapon_data.get("range", 285.0)
	if global_position.distance_to(nearest.global_position) > max_range:
		return

	CombatManager.resolve_hit(
		self, nearest,
		get_stat("damage"), get_stat("crit_chance"), get_stat("crit_multiplier")
	)

	## Apply mod effects for direct-hit weapons
	_apply_direct_hit_mods(nearest, get_stat("damage"))

	_spawn_beam_flash(nearest.global_position)

func _spawn_beam_flash(target_pos: Vector2) -> void:
	var tint: Color = _weapon_data.get("tint", Color(1.0, 0.42, 0.08))

	var line := Line2D.new()
	line.top_level = true
	line.add_point(global_position)
	line.add_point(target_pos)
	line.width          = 3.5
	line.default_color  = Color(tint.r, tint.g, tint.b, 0.92)

	var glow := Line2D.new()
	glow.top_level = true
	glow.add_point(global_position)
	glow.add_point(target_pos)
	glow.width          = 7.0
	glow.default_color  = Color(tint.r, tint.g, tint.b, 0.22)

	get_tree().current_scene.add_child(glow)
	get_tree().current_scene.add_child(line)

	var t := create_tween()
	t.tween_property(line, "modulate:a",  0.0, 0.06)
	t.tween_callback(line.queue_free)
	var t2 := create_tween()
	t2.tween_property(glow, "modulate:a", 0.0, 0.06)
	t2.tween_callback(glow.queue_free)

# ─── Behavior: Melee (Plasma Blade) ──────────────────────────────────────────

func _fire_melee_weapon() -> void:
	var nearest := _get_nearest_enemy()
	var swing_dir: Vector2 = Vector2.RIGHT
	if nearest != null:
		swing_dir = (nearest.global_position - global_position).normalized()

	var range_px: float   = _weapon_data.get("range",       55.0)
	var arc_deg: float    = _weapon_data.get("arc_degrees", 200.0)
	var arc_half: float   = deg_to_rad(arc_deg * 0.5)
	var center_angle: float = swing_dir.angle()

	var melee_candidates: Array = enemy_grid.get_nearby_in_range(global_position, range_px) if enemy_grid else get_tree().get_nodes_in_group("enemies")
	for enemy in melee_candidates:
		if not is_instance_valid(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - global_position
		if to_enemy.length() > range_px:
			continue
		var angle_diff: float = absf(wrapf(to_enemy.angle() - center_angle, -PI, PI))
		if angle_diff > arc_half:
			continue
		CombatManager.resolve_hit(
			self, enemy,
			get_stat("damage"), get_stat("crit_chance"), get_stat("crit_multiplier")
		)
		_apply_direct_hit_mods(enemy, get_stat("damage"))

	_spawn_melee_arc(center_angle, range_px, arc_half)

func _spawn_melee_arc(center_angle: float, range_px: float, arc_half: float) -> void:
	var tint: Color  = _weapon_data.get("tint", Color(0.48, 0.80, 1.0))
	var segments: int = 12

	var points: PackedVector2Array = []
	points.append(Vector2.ZERO)
	for i in range(segments + 1):
		var a: float = center_angle - arc_half + (float(i) / float(segments)) * arc_half * 2.0
		points.append(Vector2(cos(a), sin(a)) * range_px)

	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color   = Color(tint.r, tint.g, tint.b, 0.48)
	get_tree().current_scene.add_child(poly)
	poly.global_position = global_position

	var edge_points: PackedVector2Array = []
	for i in range(segments + 1):
		var a: float = center_angle - arc_half + (float(i) / float(segments)) * arc_half * 2.0
		edge_points.append(Vector2(cos(a), sin(a)) * range_px)

	var edge := Line2D.new()
	edge.top_level = true
	for p in edge_points:
		edge.add_point(poly.global_position + p)
	edge.width         = 3.0
	edge.default_color = Color(tint.r, tint.g, tint.b, 0.85)
	get_tree().current_scene.add_child(edge)

	var t := create_tween()
	t.tween_property(poly,  "modulate:a", 0.0, 0.13)
	t.tween_callback(poly.queue_free)
	var t2 := create_tween()
	t2.tween_property(edge, "modulate:a", 0.0, 0.13)
	t2.tween_callback(edge.queue_free)

# ─── Behavior: Artillery (Void Mortar) ───────────────────────────────────────

func _fire_artillery_weapon() -> void:
	var nearest := _get_nearest_enemy()
	if nearest == null:
		return

	var max_range: float = _weapon_data.get("range", 380.0)
	if global_position.distance_to(nearest.global_position) > max_range:
		return

	var scatter := Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
	var target_pos: Vector2 = nearest.global_position + scatter

	var aoe_radius: float = _weapon_data.get("aoe_radius", 64.0)
	var fuse_time: float  = _weapon_data.get("fuse_time",   1.0)
	var tint: Color       = _weapon_data.get("tint",        Color(0.38, 0.08, 0.62))

	var dmg:     float = get_stat("damage")
	var crit_ch: float = get_stat("crit_chance")
	var crit_m:  float = get_stat("crit_multiplier")

	_spawn_mortar_marker(target_pos, aoe_radius, fuse_time, dmg, crit_ch, crit_m, tint)

func _spawn_mortar_marker(
		pos: Vector2, radius: float, fuse: float,
		dmg: float, crit_ch: float, crit_m: float, tint: Color) -> void:

	var marker := Node2D.new()
	marker.global_position = pos
	get_tree().current_scene.add_child(marker)

	var preview := ColorRect.new()
	preview.color    = Color(tint.r, tint.g, tint.b, 0.18)
	preview.size     = Vector2(radius * 2.0, radius * 2.0)
	preview.position = Vector2(-radius, -radius)
	marker.add_child(preview)

	var bd: float = radius * 2.0
	var bt: float = 2.0
	var bc: Color = Color(tint.r, tint.g, tint.b, 0.72)
	for side in 4:
		var b := ColorRect.new()
		b.color = bc
		match side:
			0: b.size = Vector2(bd, bt); b.position = Vector2(-radius, -radius)
			1: b.size = Vector2(bd, bt); b.position = Vector2(-radius,  radius - bt)
			2: b.size = Vector2(bt, bd); b.position = Vector2(-radius, -radius)
			3: b.size = Vector2(bt, bd); b.position = Vector2( radius - bt, -radius)
		marker.add_child(b)

	var dot := ColorRect.new()
	dot.color    = Color(tint.r + 0.3, tint.g + 0.1, tint.b + 0.3, 1.0)
	dot.size     = Vector2(7.0, 7.0)
	dot.position = Vector2(-3.5, -3.5)
	marker.add_child(dot)

	var warn := create_tween().set_loops(int(fuse * 6.0))
	warn.tween_property(preview, "modulate:a", 0.15, fuse / 12.0)
	warn.tween_property(preview, "modulate:a", 1.0,  fuse / 12.0)

	get_tree().create_timer(fuse).timeout.connect(
		func():
			if is_instance_valid(marker):
				_detonate_mortar(pos, radius, dmg, crit_ch, crit_m, tint)
				marker.queue_free()
	)

func _detonate_mortar(
		pos: Vector2, radius: float,
		dmg: float, crit_ch: float, crit_m: float, tint: Color) -> void:

	var mortar_targets: Array = enemy_grid.get_nearby_in_range(pos, radius) if enemy_grid else get_tree().get_nodes_in_group("enemies")
	for enemy in mortar_targets:
		if not is_instance_valid(enemy):
			continue
		if pos.distance_to(enemy.global_position) <= radius:
			CombatManager.resolve_hit(self, enemy, dmg, crit_ch, crit_m)
			_apply_direct_hit_mods(enemy, dmg)

	var ring := ColorRect.new()
	ring.color    = Color(tint.r, tint.g, tint.b, 0.55)
	ring.size     = Vector2(radius * 2.0, radius * 2.0)
	ring.position = pos - Vector2(radius, radius)
	get_tree().current_scene.add_child(ring)

	var rt := create_tween()
	rt.tween_property(ring, "scale",       Vector2(1.5, 1.5), 0.22).set_trans(Tween.TRANS_EXPO)
	rt.parallel().tween_property(ring, "modulate:a", 0.0,          0.22)
	rt.tween_callback(ring.queue_free)

	var particles := CPUParticles2D.new()
	particles.global_position        = pos
	particles.amount                 = 20
	particles.lifetime               = 0.6
	particles.one_shot               = true
	particles.explosiveness          = 0.95
	particles.direction              = Vector2.ZERO
	particles.spread                 = 180.0
	particles.initial_velocity_min   = 80.0
	particles.initial_velocity_max   = 200.0
	particles.gravity                = Vector2.ZERO
	particles.scale_amount_min       = 3.0
	particles.scale_amount_max       = 8.0
	particles.color                  = tint
	get_tree().current_scene.add_child(particles)
	particles.emitting = true
	get_tree().create_timer(1.2).timeout.connect(
		func(): if is_instance_valid(particles): particles.queue_free()
	)

# ─── Mod application helpers ──────────────────────────────────────────────────

## Apply all active mods to a freshly-spawned projectile.
func _apply_mods_to_projectile(proj: Node) -> void:
	for mod_id in _active_mods:
		var mod_data: Dictionary = ModData.ALL.get(mod_id, {})
		var params: Dictionary   = mod_data.get("params", {})
		match mod_data.get("effect_type", ""):
			"pierce":
				proj.pierce_count = maxi(proj.pierce_count, params.get("pierce_count", 3))
			"chain":
				proj.mod_chain              = true
				proj.mod_chain_range        = params.get("chain_range",      120.0)
				proj.mod_chain_damage_mult  = params.get("chain_damage_mult",  0.6)
			"explosive":
				proj.mod_explosive          = true
				proj.mod_explosive_radius   = params.get("radius",     40.0)
				proj.mod_explosive_damage_mult = params.get("damage_mult", 0.3)
			"elemental":
				proj.mod_status        = params.get("element", "")
				proj.mod_status_params = params
			"lifesteal":
				proj.mod_lifesteal = params.get("steal_pct", 0.05)
			"size":
				proj.scale_factor *= params.get("size_mult", 1.5)

## Apply mod hit effects for direct-damage weapons (beam, melee, artillery).
## Chain and explosive generate their own visuals / hits.
func _apply_direct_hit_mods(enemy: Node, raw_damage: float) -> void:
	if not is_instance_valid(enemy):
		return
	for mod_id in _active_mods:
		var mod_data: Dictionary = ModData.ALL.get(mod_id, {})
		var params: Dictionary   = mod_data.get("params", {})
		match mod_data.get("effect_type", ""):
			"elemental":
				if enemy.has_method("apply_status"):
					enemy.apply_status(params.get("element", ""), params)
			"lifesteal":
				heal(raw_damage * params.get("steal_pct", 0.05))
			"chain":
				_do_chain_hit(enemy.global_position, enemy,
					raw_damage * params.get("chain_damage_mult", 0.6),
					params.get("chain_range", 120.0))
			"explosive":
				_do_explosion(enemy.global_position,
					raw_damage * params.get("damage_mult", 0.3),
					params.get("radius", 40.0))

## Spawn a chain bounce from direct-hit weapons (beam / melee / artillery).
func _do_chain_hit(origin: Vector2, origin_enemy: Node, dmg: float, range_px: float) -> void:
	var nearest: Node2D = null
	var nearest_dist: float = range_px
	var chain_candidates: Array = enemy_grid.get_nearby_in_range(origin, range_px) if enemy_grid else get_tree().get_nodes_in_group("enemies")
	for enemy in chain_candidates:
		if not is_instance_valid(enemy) or enemy == origin_enemy:
			continue
		var dist: float = origin.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	if nearest == null or not nearest.has_method("take_damage"):
		return
	nearest.take_damage(dmg)
	## Visual arc
	var line := Line2D.new()
	line.top_level = true
	line.add_point(origin)
	line.add_point(nearest.global_position)
	line.width = 1.5
	line.default_color = Color(0.35, 0.75, 1.0, 0.75)
	get_tree().current_scene.add_child(line)
	var t := line.create_tween()
	t.tween_property(line, "modulate:a", 0.0, 0.14)
	t.tween_callback(line.queue_free)

## Explosion for direct-hit weapons.
func _do_explosion(pos: Vector2, dmg: float, radius: float) -> void:
	var explosion_targets: Array = enemy_grid.get_nearby_in_range(pos, radius) if enemy_grid else get_tree().get_nodes_in_group("enemies")
	for enemy in explosion_targets:
		if not is_instance_valid(enemy):
			continue
		if pos.distance_to(enemy.global_position) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(dmg)
	var ring := ColorRect.new()
	ring.color    = Color(1.0, 0.48, 0.08, 0.50)
	ring.size     = Vector2(radius * 2.0, radius * 2.0)
	ring.position = pos - Vector2(radius, radius)
	ring.top_level = true
	get_tree().current_scene.add_child(ring)
	var rt := ring.create_tween()
	rt.tween_property(ring, "scale",       Vector2(1.6, 1.6), 0.18).set_trans(Tween.TRANS_EXPO)
	rt.parallel().tween_property(ring, "modulate:a", 0.0,          0.18)
	rt.tween_callback(ring.queue_free)

# ─── Shared helpers ────────────────────────────────────────────────────────────

func _get_nearest_enemy() -> Node2D:
	if enemy_grid:
		return enemy_grid.find_nearest(global_position)
	## Fallback: linear scan (only if grid isn't wired yet)
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest

func _spawn_projectile(direction: Vector2) -> void:
	var proj: Area2D = projectile_scene.instantiate()
	proj.global_position = global_position
	proj.direction       = direction
	proj.damage          = get_stat("damage")
	proj.crit_chance     = get_stat("crit_chance")
	proj.crit_multiplier = get_stat("crit_multiplier")
	proj.pierce_count    = int(get_stat("pierce"))
	proj.scale_factor    = get_stat("projectile_size")
	proj.source          = self

	if _weapon_data.has("projectile_speed"):
		proj.speed = _weapon_data["projectile_speed"]
	if _weapon_data.has("lifetime"):
		proj.lifetime = _weapon_data["lifetime"]

	proj.modulate = _weapon_data.get("tint", Color.WHITE)

	## Apply mod effects (pierce, chain, explosive, elemental, lifesteal, size)
	_apply_mods_to_projectile(proj)

	get_tree().current_scene.add_child(proj)

# ─── Pickup collection ─────────────────────────────────────────────────────────

func _update_pickup_radius() -> void:
	if pickup_shape and pickup_shape.shape:
		pickup_shape.shape.radius = get_stat("pickup_radius")

func _on_pickup_area_entered(area: Area2D) -> void:
	if area.has_method("start_magnet"):
		area.start_magnet(self)

# ─── Instability Siphon ────────────────────────────────────────────────────────

func _on_entity_killed_siphon(_killer: Node, victim: Node, _pos: Vector2) -> void:
	if victim.is_in_group("enemies"):
		GameManager.modify_instability(-1)

# ─── Death ────────────────────────────────────────────────────────────────────

func _die() -> void:
	_is_dead = true
	## Kill any in-progress hit flash so the sprite doesn't keep blinking after death
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
		_hit_flash_tween = null
	sprite.modulate = Color.WHITE
	knockback_velocity = Vector2.ZERO
	_cleanup_weapon_state()
	died.emit()
	GameManager.on_player_died()

func _cleanup_weapon_state() -> void:
	for orb in _orbit_orbs:
		if is_instance_valid(orb):
			orb.queue_free()
	_orbit_orbs.clear()

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
