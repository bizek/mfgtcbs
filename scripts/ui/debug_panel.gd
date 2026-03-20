extends CanvasLayer

## DebugPanel — Development cheat panel. Hotkeys work regardless of panel visibility.
## Instantiated by MainArena only when GameManager.debug_mode is true.
##
## F1  — Toggle panel open / closed
## F2  — Toggle god mode (no damage)
## F3  — Instant level-up (one upgrade screen)
## F4  — Open extraction portal immediately

const LootDropScene   = preload("res://scenes/pickups/loot_drop.tscn")
const ModPickupScript = preload("res://scripts/pickups/mod_pickup.gd")

var player_ref: Node2D = null

var _panel: Control        ## Root panel container
var _god_btn: Button       ## Kept for live label/colour updates

func _ready() -> void:
	layer = 127  ## Above everything in-game, below nothing
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()

func setup(player: Node2D) -> void:
	player_ref = player

# ─── Input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.debug_mode:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1: _toggle_panel()
		KEY_F2: _cmd_god_mode()
		KEY_F3: _cmd_level_up_one()
		KEY_F4: _cmd_skip_extraction()

func _toggle_panel() -> void:
	_panel.visible = not _panel.visible

# ─── Panel construction ────────────────────────────────────────────────────────
## Layout targets the 480×270 design viewport.
## Panel: 188×218 px, anchored top-left with a 5 px margin from the left edge
## and positioned below the HUD health/XP rows (~45 px from top).

func _build_panel() -> void:
	var pc := PanelContainer.new()
	pc.position = Vector2(5.0, 45.0)
	pc.visible = false
	_panel = pc
	add_child(pc)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.04, 0.08, 0.93)
	bg.set_corner_radius_all(3)
	bg.set_content_margin_all(5.0)
	pc.add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(178.0, 0.0)
	vbox.add_theme_constant_override("separation", 4)
	pc.add_child(vbox)

	## Title row
	var title := Label.new()
	title.text = "DEBUG PANEL   [F1]"
	title.add_theme_font_size_override("font_size", 9)
	title.modulate = Color(1.0, 0.85, 0.2)
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	## Button definitions  [label, callable]
	var defs: Array = [
		["Give All Weapons",          _cmd_give_weapons],
		["Give All Mods",             _cmd_give_all_mods],
		["Spawn Random Mod",          _cmd_spawn_random_mod],
		["Give Resources +10k",       _cmd_give_resources],
		["Unlock All Characters",     _cmd_unlock_all_characters],
		["Skip to Extraction",        _cmd_skip_extraction],
		["Activate All Extractions",  _cmd_activate_all_extractions],
		["Spawn Keystone",            _cmd_spawn_keystone],
		["Level Up ×5",               _cmd_level_up_five],
		["Spawn Loot",                _cmd_spawn_loot],
		["God Mode: OFF",             _cmd_god_mode],
		["Kill All Enemies",          _cmd_kill_all],
	]

	for d in defs:
		var btn := Button.new()
		btn.text = d[0]
		btn.add_theme_font_size_override("font_size", 9)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(d[1])
		vbox.add_child(btn)
		if d[0].begins_with("God Mode"):
			_god_btn = btn

	## ── Enemy spawn section ───────────────────────────────────────────────────
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var spawn_label := Label.new()
	spawn_label.text = "SPAWN ENEMIES"
	spawn_label.add_theme_font_size_override("font_size", 8)
	spawn_label.modulate = Color(1.0, 0.5, 0.5)
	vbox.add_child(spawn_label)

	var spawn_defs: Array = [
		["Spawn Brute",   func(): _cmd_spawn_enemy("brute")],
		["Spawn Caster",  func(): _cmd_spawn_enemy("caster")],
		["Spawn Carrier", func(): _cmd_spawn_enemy("carrier")],
		["Spawn Stalker", func(): _cmd_spawn_enemy("stalker")],
		["Spawn Herald",  func(): _cmd_spawn_enemy("herald")],
		["Spawn Elite",   func(): _cmd_spawn_elite()],
	]

	for d in spawn_defs:
		var btn := Button.new()
		btn.text = d[0]
		btn.add_theme_font_size_override("font_size", 9)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(d[1])
		vbox.add_child(btn)

	## Hotkey hint strip
	var hints := Label.new()
	hints.text = "F1=Panel  F2=God  F3=Lvl  F4=Extract"
	hints.add_theme_font_size_override("font_size", 8)
	hints.modulate = Color(0.55, 0.55, 0.55)
	vbox.add_child(hints)

# ─── Commands ─────────────────────────────────────────────────────────────────

func _cmd_give_weapons() -> void:
	for weapon_id in WeaponData.ALL:
		ProgressionManager.add_weapon(weapon_id)
		if weapon_id not in GameManager.collected_weapons:
			GameManager.collected_weapons.append(weapon_id)

func _cmd_give_all_mods() -> void:
	## Add one copy of every mod to the player's owned_mods inventory
	for mod_id in ModData.ORDER:
		ProgressionManager.owned_mods.append(mod_id)
	ProgressionManager.save_data()

func _cmd_spawn_random_mod() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	var mod_ids: Array = ModData.ORDER
	if mod_ids.is_empty():
		return
	var mod_id: String = mod_ids[randi() % mod_ids.size()]
	var offset := Vector2(randf_range(-80.0, 80.0), randf_range(-80.0, 80.0))
	var pickup: Area2D = ModPickupScript.new()
	pickup.mod_id          = mod_id
	pickup.global_position = player_ref.global_position + offset
	get_tree().current_scene.add_child(pickup)

func _cmd_give_resources() -> void:
	ProgressionManager.resources += 10000
	ProgressionManager.resources_changed.emit(ProgressionManager.resources)

func _cmd_skip_extraction() -> void:
	GameManager.debug_open_extraction()

func _cmd_activate_all_extractions() -> void:
	## Enables guarded + sacrifice + locked; also gives player a keystone to test locked.
	var arena := get_tree().current_scene
	if arena and arena.has_method("debug_activate_all_extractions"):
		arena.debug_activate_all_extractions()
	## Also open the timed portal
	GameManager.debug_open_extraction()

func _cmd_spawn_keystone() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	## Only spawn if player doesn't already hold one
	if GameManager.player_has_keystone:
		return
	var KeystoneScript = load("res://scripts/pickups/keystone_pickup.gd")
	if KeystoneScript == null:
		return
	var pickup: Area2D = KeystoneScript.new()
	pickup.global_position = player_ref.global_position + Vector2(60.0, 0.0)
	get_tree().current_scene.add_child(pickup)

func _cmd_level_up_one() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	## Give exactly enough XP to trigger one level-up, retaining any leftover XP.
	var needed: float = player_ref._xp_to_next_level() - player_ref.xp + 0.1
	player_ref.add_xp(needed)

func _cmd_level_up_five() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	## Calculate XP for exactly 5 levels from current state, then add it all at once.
	## The while loop inside add_xp fires leveled_up once per threshold crossed,
	## so 5 upgrade screens will queue up sequentially as the player picks each one.
	var sim_level: int = player_ref.level
	var sim_xp: float = player_ref.xp
	var total: float = 0.0
	for _i in range(5):
		var to_next: float = player_ref.xp_base * (1.0 + (sim_level - 1) * player_ref.xp_growth)
		total += maxf(to_next - sim_xp, 0.0) + 0.1
		sim_xp = 0.0
		sim_level += 1
	player_ref.add_xp(total)

func _cmd_spawn_loot() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	for _i in range(5):
		var offset := Vector2(randf_range(-64.0, 64.0), randf_range(-64.0, 64.0))
		var drop: Area2D = LootDropScene.instantiate()
		drop.global_position = player_ref.global_position + offset
		drop.value = randf_range(10.0, 30.0)
		get_tree().current_scene.add_child(drop)

func _cmd_god_mode() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	player_ref.god_mode = not player_ref.god_mode
	var on: bool = player_ref.god_mode
	if is_instance_valid(_god_btn):
		_god_btn.text = "God Mode: " + ("ON" if on else "OFF")
		_god_btn.modulate = Color(1.0, 0.35, 0.35) if on else Color.WHITE

func _cmd_unlock_all_characters() -> void:
	for char_id in CharacterData.ALL:
		if char_id not in ProgressionManager.unlocked_characters:
			ProgressionManager.unlocked_characters.append(char_id)
	ProgressionManager.save_data()

func _cmd_kill_all() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			GameManager.register_kill()
			enemy.queue_free()

func _cmd_spawn_enemy(type: String) -> void:
	const PATHS: Dictionary = {
		"brute":   "res://scenes/enemies/brute.tscn",
		"caster":  "res://scenes/enemies/caster.tscn",
		"carrier": "res://scenes/enemies/carrier.tscn",
		"stalker": "res://scenes/enemies/stalker.tscn",
		"herald":  "res://scenes/enemies/herald.tscn",
	}
	if not PATHS.has(type):
		return
	var path: String = PATHS[type]
	if not ResourceLoader.exists(path):
		push_warning("DebugPanel: scene not found — " + path)
		return
	var scene: PackedScene = load(path)
	EnemySpawnManager.debug_spawn(scene, false)

func _cmd_spawn_elite() -> void:
	## Spawn a random eligible enemy type as an Elite
	const ELITE_PATHS: Array = [
		"res://scenes/enemies/fodder.tscn",
		"res://scenes/enemies/brute.tscn",
		"res://scenes/enemies/caster.tscn",
	]
	var path: String = ELITE_PATHS[randi() % ELITE_PATHS.size()]
	if not ResourceLoader.exists(path):
		return
	var scene: PackedScene = load(path)
	EnemySpawnManager.debug_spawn(scene, true)
