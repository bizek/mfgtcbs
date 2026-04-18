extends CanvasLayer

## DebugPanel — Development cheat panel. Hotkeys work regardless of panel visibility.
## Instantiated by MainArena only when GameManager.debug_mode is true.
##
## F1  — Toggle panel open / closed
## F2  — Toggle god mode (no damage)
## F3  — Instant level-up (one upgrade screen)
## F4  — Open extraction portal immediately
## F5  — Spawn a test telegraph at cursor (telegraph VFX check)
## F6  — Spawn Phase 3 miniboss (Warped Colossus)
## F7  — Spawn Phase 5 final boss (Heart of the Deep) + flip extraction gate

var player_ref: Node2D = null

var _panel: Control        ## Root panel container
var _god_btn: Button       ## Kept for live label/colour updates
var _debug_draw_btn: Button

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
		KEY_F5: _cmd_spawn_test_telegraph()
		KEY_F6: _cmd_spawn_miniboss()
		KEY_F7: _cmd_spawn_final_boss()

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
	bg.set_content_margin_all(4.0)
	pc.add_theme_stylebox_override("panel", bg)

	## ScrollContainer caps panel height to fit within the 270px viewport.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(162.0, 216.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	pc.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(162.0, 0.0)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 1)
	scroll.add_child(vbox)

	## Title row
	var title := Label.new()
	title.text = "DEBUG  [F1]"
	title.add_theme_font_size_override("font_size", 11)
	title.modulate = Color(1.0, 0.85, 0.2)
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	## Power Up — highlighted entry at the top
	var power_btn := Button.new()
	power_btn.text = "Power Up (proj+dmg+mods)"
	power_btn.add_theme_font_size_override("font_size", 11)
	power_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	power_btn.modulate = Color(1.0, 0.9, 0.3)
	power_btn.pressed.connect(_cmd_power_up)
	vbox.add_child(power_btn)

	## Button definitions  [label, callable]
	var defs: Array = [
		["Give Resources +10k",  _cmd_give_resources],
		["Level Up ×5",          _cmd_level_up_five],
		["Skip to Extraction",   _cmd_skip_extraction],
		["God Mode: OFF",        _cmd_god_mode],
		["Kill All Enemies",     _cmd_kill_all],
		["Debug Draw: OFF",      _cmd_toggle_debug_draw],
	]

	for d in defs:
		var btn := Button.new()
		btn.text = d[0]
		btn.add_theme_font_size_override("font_size", 11)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(d[1])
		vbox.add_child(btn)
		if d[0].begins_with("God Mode"):
			_god_btn = btn
		if d[0].begins_with("Debug Draw"):
			_debug_draw_btn = btn

	## ── Enemy spawn section ───────────────────────────────────────────────────
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var spawn_label := Label.new()
	spawn_label.text = "SPAWN ENEMIES"
	spawn_label.add_theme_font_size_override("font_size", 9)
	spawn_label.modulate = Color(1.0, 0.5, 0.5)
	vbox.add_child(spawn_label)

	var spawn_defs: Array = [
		["Spawn Brute",   func(): _cmd_spawn_enemy("brute")],
		["Spawn Caster",  func(): _cmd_spawn_enemy("caster")],
		["Spawn Carrier", func(): _cmd_spawn_enemy("carrier")],
		["Spawn Stalker", func(): _cmd_spawn_enemy("stalker")],
		["Spawn Herald",  func(): _cmd_spawn_enemy("herald")],
		["Spawn Elite",   func(): _cmd_spawn_elite()],
		["Spawn Miniboss (F6)",   func(): _cmd_spawn_miniboss()],
		["Spawn Final Boss (F7)", func(): _cmd_spawn_final_boss()],
	]

	for d in spawn_defs:
		var btn := Button.new()
		btn.text = d[0]
		btn.add_theme_font_size_override("font_size", 11)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(d[1])
		vbox.add_child(btn)

	## Hotkey hint strip
	var hints := Label.new()
	hints.text = "F2=God  F3=Lvl  F4=Extract"
	hints.add_theme_font_size_override("font_size", 9)
	hints.modulate = Color(0.55, 0.55, 0.55)
	vbox.add_child(hints)

# ─── Commands ─────────────────────────────────────────────────────────────────

func _cmd_power_up() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	## Offense — simulates ~level 80 min-max offensive build
	player_ref.apply_stat_upgrade({"id": "dbg_proj",  "stat": "projectile_count", "type": "flat",    "value": 10.0})
	player_ref.apply_stat_upgrade({"id": "dbg_dmg",   "stat": "damage",           "type": "percent", "value": 3.0})   ## +300%
	player_ref.apply_stat_upgrade({"id": "dbg_as",    "stat": "attack_speed",     "type": "percent", "value": 1.8})   ## +180% → ~2.8× speed
	player_ref.apply_stat_upgrade({"id": "dbg_pierce","stat": "pierce",           "type": "flat",    "value": 8.0})
	player_ref.apply_stat_upgrade({"id": "dbg_size",  "stat": "projectile_size",  "type": "percent", "value": 1.25})  ## +125%
	player_ref.apply_stat_upgrade({"id": "dbg_crit",  "stat": "crit_chance",      "type": "flat",    "value": 0.35})  ## +35% → 40% total
	player_ref.apply_stat_upgrade({"id": "dbg_critd", "stat": "crit_multiplier",  "type": "flat",    "value": 1.25})  ## +125% → 2.75× on crit
	player_ref.apply_stat_upgrade({"id": "dbg_spd",   "stat": "move_speed",       "type": "percent", "value": 0.75})  ## +75%
	player_ref.apply_stat_upgrade({"id": "dbg_rad",   "stat": "pickup_radius",    "type": "percent", "value": 2.4})   ## +240%
	## Survivability — enough to tank hits without god mode
	player_ref.apply_stat_upgrade({"id": "dbg_hp",    "stat": "max_hp",           "type": "flat",    "value": 200.0})
	player_ref.apply_stat_upgrade({"id": "dbg_armor", "stat": "armor",            "type": "flat",    "value": 15.0})
	## Equip all mods — activates every pairwise and triple combo simultaneously
	player_ref.debug_reload_mods(ModData.ORDER.duplicate())

func _cmd_give_resources() -> void:
	ProgressionManager.resources += 10000
	ProgressionManager.resources_changed.emit(ProgressionManager.resources)

func _cmd_skip_extraction() -> void:
	GameManager.debug_open_extraction()

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

func _cmd_god_mode() -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		return
	player_ref.god_mode = not player_ref.god_mode
	var on: bool = player_ref.god_mode
	if is_instance_valid(_god_btn):
		_god_btn.text = "God Mode: " + ("ON" if on else "OFF")
		_god_btn.modulate = Color(1.0, 0.35, 0.35) if on else Color.WHITE

func _cmd_kill_all() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(99999.0)

func _cmd_toggle_debug_draw() -> void:
	var orchestrator = get_tree().current_scene.get_node_or_null("CombatOrchestrator")
	if orchestrator and orchestrator.debug_draw:
		orchestrator.debug_draw.enabled = not orchestrator.debug_draw.enabled
		if _debug_draw_btn:
			_debug_draw_btn.text = "Debug Draw: ON" if orchestrator.debug_draw.enabled else "Debug Draw: OFF"
			_debug_draw_btn.modulate = Color(0.3, 1.0, 0.3) if orchestrator.debug_draw.enabled else Color.WHITE

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

func _cmd_spawn_test_telegraph() -> void:
	## Debug: spawn a circle telegraph at mouse position to sanity-check
	## the telegraph VFX pipeline.
	if not is_instance_valid(player_ref):
		return
	var arena: Node = player_ref.get_parent()
	if not arena or not arena.get("combat_manager"):
		return
	var cm: Node = arena.combat_manager
	if not cm.get("telegraph_manager"):
		return
	var effect := SpawnTelegraphEffect.new()
	effect.shape = "circle"
	effect.anchor = "target_position"
	effect.radius = 80.0
	effect.duration = 1.0
	effect.color = Color(1.0, 0.25, 0.2, 0.55)
	var marker := Node2D.new()
	arena.add_child(marker)
	marker.global_position = player_ref.get_global_mouse_position()
	cm.telegraph_manager.spawn(effect, player_ref, marker)
	var t := get_tree().create_timer(1.2)
	t.timeout.connect(func():
		if is_instance_valid(marker):
			marker.queue_free())

func _cmd_spawn_miniboss() -> void:
	## Debug: spawn the Phase 3 miniboss (Warped Colossus) near the player.
	EnemySpawnManager.debug_spawn_by_id("warped_colossus", false)

func _cmd_spawn_final_boss() -> void:
	## Debug: spawn the Phase 5 final boss near the player AND flip the
	## extraction gate so the HUD lock label + blocked channeling are testable
	## without waiting for Phase 5. Also fires the announcement flash.
	GameManager.final_boss_alive = true
	var disp_name: String = "The Heart of the Deep"
	var def: EnemyDefinition = EnemyRegistry.get_def("heart_of_the_deep")
	if def != null and def.enemy_name != "":
		disp_name = def.enemy_name
	GameManager.final_boss_spawned.emit(disp_name)
	EnemySpawnManager.debug_spawn_by_id("heart_of_the_deep", false)
